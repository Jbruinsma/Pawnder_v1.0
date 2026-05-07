from typing import Optional, Any
from uuid import UUID

from sqlalchemy import cast
from geoalchemy2 import Geography

from fastapi import APIRouter, Query, Depends, HTTPException
from sqlalchemy import func, select, and_, Row, desc, union_all, delete, case
from sqlalchemy.orm import Session, defer
from starlette import status
from geoalchemy2.shape import from_shape
from shapely.geometry import Polygon

from app.core.security import get_current_user
from app.crud.crud_community import get_community_stats_query
from app.crud.crud_post import (
    create_post as db_create_post, bookmark_post_for_user,
    retrieve_posts_with_stats, retrieve_post_likes, get_post_stats_columns
)
from app.core.database import get_db
from app.models import Community, User, user_communities, Post, Tag, PostLikes, PostComments, CommentLikes
from app.schemas.common import Message
from app.schemas.community import NeighborhoodResponseModel, Neighborhood, CommunityCreateRequest, CommunityCreateResponse
from app.schemas.core import CoordinateSchema
from app.schemas.post import (
    CommunityPost, CommunityPostsResponse, PostCreationRequest,
    ExistingTagsResponseModel, ExistingTag, PostBookmarkResponseModel,
    PostLikeResponseModel, PostUnlikeResponseModel, CommunityPostCommentRequest, PostComment, PostUpdateRequest
)
from app.services.feed_engine import generate_algorithmic_feed
from app.utils.formatting_utils import format_post_with_stats, format_neighborhood_with_stats
from crud.crud_post import update_user_post

router = APIRouter(
    prefix="/community",
    tags=["5.0 Community Hub & Tagging"]
)


def _build_square_boundary(latitude: float, longitude: float, half_side_degrees: float = 0.01):
    return Polygon([
        (longitude - half_side_degrees, latitude - half_side_degrees),
        (longitude + half_side_degrees, latitude - half_side_degrees),
        (longitude + half_side_degrees, latitude + half_side_degrees),
        (longitude - half_side_degrees, latitude + half_side_degrees),
        (longitude - half_side_degrees, latitude - half_side_degrees),
    ])


@router.get(
    path="/new-feed",
    summary="Retrieve a user's feed based on post performance once they open the app"
)
async def retrieve_initial_feed(
        coords: CoordinateSchema = Depends(),
        current_user: User = Depends(get_current_user),
        session: Session = Depends(get_db)
):
    communities, raw_posts = generate_algorithmic_feed(
        session= session,
        current_user= current_user,
        coords= coords
    )

    applicable_tags = {
        tag.name
        for row in raw_posts
        for tag in row.Post.tags
    }

    found_pet_posts = []
    lost_pet_posts = []
    misc_posts = []

    for row in raw_posts:
        post_type = row.Post.post_type

        if post_type == "Found Pet":
            found_pet_posts.append(row)

        elif post_type == "Lost Pet":
            lost_pet_posts.append(row)

        else:
            misc_posts.append(row)

    return {
        "communities": [
            format_neighborhood_with_stats(row) for row in communities
        ],
        "applicable_tags": list(applicable_tags),
        "posts": {
            "lost": [ format_post_with_stats(row) for row in lost_pet_posts ],
            "found": [ format_post_with_stats(row) for row in found_pet_posts ],
            "misc": [ format_post_with_stats(row) for row in misc_posts ]
        }
    }


@router.get(
    path="/neighborhoods",
    summary="List available neighborhoods",
    response_model=NeighborhoodResponseModel
)
def get_neighborhoods(
        coords: CoordinateSchema = Depends(),
        current_user: User = Depends(get_current_user),
        session: Session = Depends(get_db)
):
    user_point = func.ST_SetSRID(
        func.ST_MakePoint(coords.longitude, coords.latitude),
        4326
    )

    user_geog = cast(user_point, Geography)
    comm_geog = cast(Community.geofence_boundary, Geography)

    member_count_subq = (
        select(func.count(user_communities.c.user_id))
        .where(user_communities.c.community_id == Community.id)
        .correlate(Community)
        .scalar_subquery()
    )

    distance = func.ST_Distance(comm_geog, user_geog)
    is_member_expr = user_communities.c.user_id.isnot(None)

    MEMBER_BOOST = 0.3
    POPULARITY_WEIGHT = 0.02
    DISTANCE_WEIGHT = 0.0001

    score = (
            case((is_member_expr, MEMBER_BOOST), else_=0.0)
            + func.ln(1 + func.coalesce(member_count_subq, 0)) * POPULARITY_WEIGHT
            - distance * DISTANCE_WEIGHT
    )

    base_stmt = (
        select(Community)
        .order_by(desc(score))
    )

    stmt = get_community_stats_query(current_user.id, base_stmt)

    results = session.execute(stmt).all()

    return NeighborhoodResponseModel(
        neighborhoods=[format_neighborhood_with_stats(row) for row in results]
    )


@router.post(
    path= "/neighborhoods",
    summary= "Create a neighborhood",
    response_model= CommunityCreateResponse,
    status_code= status.HTTP_201_CREATED,
)
def create_neighborhood(
        payload: CommunityCreateRequest,
        current_user: User = Depends(get_current_user),
        session: Session = Depends(get_db)
):
    existing = session.execute(
        select(Community.id).where(func.lower(Community.name) == payload.name.strip().lower())
    ).scalar()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A community with this name already exists."
        )

    community = Community(
        name=payload.name.strip(),
        description=payload.description.strip(),
        geofence_boundary=from_shape(
            _build_square_boundary(payload.latitude, payload.longitude),
            srid=4326,
        ),
        image_url= payload.image_url
    )

    session.add(community)
    current_user.joined_communities.append(community)
    session.commit()
    session.refresh(community)

    return CommunityCreateResponse(
        message=f"Created {community.name}",
        community= Neighborhood(
            id= str(community.id),
            name= community.name,
            description= community.description or "",
            image_url= community.image_url,
            post_count= 0,
            member_count= 1,
            is_member= True
        )
    )


@router.get(
    path= "/neighborhoods/{community_id}"
)
async def retrieve_community(
        community_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    base_stmt = (
        select(Community)
        .where(Community.id == community_id)
    )

    stmt = get_community_stats_query(current_user.id, base_stmt)
    results = session.execute(stmt).first()

    if not results:
        raise HTTPException(status_code=404, detail="Community not found")

    return format_neighborhood_with_stats(results)


@router.post("/neighborhoods/{community_id}/join", summary="Join a neighborhood")
def join_neighborhood(
        community_id: UUID,
        current_user: User = Depends(get_current_user),
        session: Session = Depends(get_db)
) -> Message:
    current_user_id: UUID = current_user.id

    stmt = (
        select(
            Community,
            User,
            user_communities.c.user_id.label("is_member")
        )
        .select_from(Community)
        .outerjoin(User, User.id == current_user_id)
        .outerjoin(
            user_communities,
            and_(
                user_communities.c.community_id == Community.id,
                user_communities.c.user_id == User.id
            )
        )
        .where(Community.id == community_id)
    )

    result: Optional[Row[Any]] = session.execute(stmt).first()

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Community not found"
        )

    community: Community
    user: Optional[User]
    is_member: Optional[UUID]
    community, user, is_member = result

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if is_member is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a member of this community"
        )

    user.joined_communities.append(community)

    try:
        session.commit()
    except Exception:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error"
        )

    return Message(
        message=f"Successfully joined {community.name}"
    )


@router.get(
    path="/my-neighborhoods",
    summary="List the current user's saved neighborhoods",
    response_model=NeighborhoodResponseModel,
)
def get_my_neighborhoods(
        current_user: User = Depends(get_current_user),
        session: Session = Depends(get_db)
):
    base_stmt = select(Community)

    stmt = get_community_stats_query(current_user.id, base_stmt).where(
        user_communities.c.user_id == current_user.id
    )

    results = session.execute(stmt).all()

    return NeighborhoodResponseModel(
        neighborhoods=[format_neighborhood_with_stats(row) for row in results]
    )

@router.get(
    path="/posts",
    summary="List community posts"
)
async def get_posts(
        community_id: UUID,
        limit: int = Query(default=25, ge=1),
        offset: int = Query(default=1, ge=1),
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    if limit < offset:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="max_range cannot be less than min_range"
        )

    community_exists_stmt = select(Community.id).where(Community.id == community_id)
    if not session.execute(community_exists_stmt).scalar():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Community not found"
        )

    adjusted_limit: int = limit - offset + 1
    adjusted_offset: int = offset - 1

    post_rows = retrieve_posts_with_stats(
        session=session,
        limit=adjusted_limit,
        offset=adjusted_offset,
        community_id=community_id,
        current_user_id=current_user.id
    )

    formatted_posts = [
        format_post_with_stats(row) for row in post_rows
    ]

    return CommunityPostsResponse(
        posts=formatted_posts
    )


@router.post(
    path= "/posts",
    summary= "Create a new community post",
    status_code= status.HTTP_201_CREATED
)
def create_post(
        payload: PostCreationRequest,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    stmt = (
        union_all(
            select(User.id).where(User.id == payload.author_id),
            select(Community.id).where(Community.id == payload.community_id)
        )
    )
    combined_check = session.execute(stmt).scalars().all()

    if len(combined_check) < 2:
        author_exists = any(uid == payload.author_id for uid in combined_check)
        if not author_exists:
            raise HTTPException(status_code= 404, detail= "Author not found")

        if current_user.id != payload.author_id:
            raise HTTPException(
                status_code= 403,
                detail= "You cannot post on the behalf of another user"
            )

        raise HTTPException(status_code= 404, detail= "Community not found")

    try:
        new_post: Post = db_create_post(
            session= session,
            payload= payload
        )
        session.commit()
        session.refresh(new_post)

        return {
            "status": "success",
            "post_id": str(new_post.id),
            "message": "Post created successfully"
        }

    except Exception:
        session.rollback()
        raise HTTPException(
            status_code= 500,
            detail= "An error occurred while creating the post"
        )


@router.put(
    path= "/posts/{post_id}",
    summary= "Update a specific post"
)
def update_post(
        post_id: UUID,
        payload: PostUpdateRequest,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):

    current_user_id = current_user.id

    post = session.execute(
        select(Post).where(Post.id == post_id)
    ).scalars().first()

    if not post:
        raise HTTPException(status_code= 404, detail= "Post not found")

    if (current_user_id != post.author_id) or (current_user_id != payload.author_id):
        raise HTTPException(
            status_code= 403,
            detail= "You cannot update a post on the behalf of another user"
        )

    try:
        updated_post = update_user_post(
            session= session,
            payload= payload,
            existing_post= post
        )

        session.commit()
        session.refresh(updated_post)

        stmt = (
            select(*get_post_stats_columns(current_user_id))
            .join(Post.author)
            .where(Post.id == updated_post.id)
        )

        row = session.execute(stmt).first()
        if not row:
            raise HTTPException(status_code= 404, detail= "Post not found")

        return {
            "status": "success",
            "post_id": str(updated_post.id),
            "message": "Post updated successfully",
            "updated_post": format_post_with_stats(row)
        }

    except Exception:

        session.rollback()
        raise HTTPException(
            status_code= 400,
            detail= "Failed to update your post"
        )

@router.delete("/posts/{post_id}", summary="Delete a post")
def delete_post(
    post_id: UUID,
    session: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    post = session.execute(
        select(Post).where(Post.id == post_id)
    ).scalars().first()

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if post.author_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this post")

    session.delete(post)
    session.commit()
    return {"status": "success", "message": "Post deleted"}

@router.get(
    path="/posts/{post_id}",
    summary="Get a specific post",
    response_model=Optional[CommunityPost]
)
def get_post(
        post_id: UUID,
        current_user: User = Depends(get_current_user),
        session: Session = Depends(get_db)
) -> Optional[CommunityPost]:
    stmt = (
        select(*get_post_stats_columns(current_user.id))
        .join(Post.author)
        .where(Post.id == post_id)
    )

    row = session.execute(stmt).first()
    if not row:
        return None

    return format_post_with_stats(row)


@router.post(
    path="/posts/{post_id}/bookmark",
    summary="Bookmark a post",
    response_model=PostBookmarkResponseModel
)
def bookmark_post(
    post_id: UUID,
    session: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result: Optional[bool] = bookmark_post_for_user(
        session=session,
        post_id=post_id,
        user_id=current_user.id
    )

    if result is None:
        raise HTTPException(status_code=404, detail="Post not found")

    if not result:
        raise HTTPException(status_code=409, detail="Post already bookmarked")

    return PostBookmarkResponseModel(
        message="Post bookmarked"
    )

@router.get(
    path="/tags",
    summary="Get all available tags",
    response_model=ExistingTagsResponseModel
)
def get_tags(
        search: Optional[str] = Query(None),
        session: Session = Depends(get_db)
) -> ExistingTagsResponseModel:
    stmt = select(Tag).limit(15)

    if search:
        stmt = stmt.where(Tag.name.contains(search))

    db_tags = session.execute(stmt).scalars().all()

    return ExistingTagsResponseModel(
        tags=[
            ExistingTag(
                tag_id=tag.id,
                name=tag.name,
                category=tag.category
            ) for tag in db_tags
        ]
    )

@router.post(
    path="/posts/{post_id}/like",
    summary="Like a post",
    response_model=PostLikeResponseModel
)
async def like_post(
        post_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    stmt = select(
        select(Post.id).where(Post.id == post_id).exists(),
        select(PostLikes.post_id).where(
            PostLikes.post_id == post_id,
            PostLikes.user_id == current_user.id
        ).exists()
    )

    post_exists, like_exists = session.execute(stmt).first()

    if not post_exists:
        raise HTTPException(status_code=404, detail="Post not found")
    if like_exists:
        raise HTTPException(status_code=400, detail="You have already liked this post")

    new_like = PostLikes(
        post_id=post_id,
        user_id=current_user.id
    )

    session.add(new_like)
    session.commit()

    return PostLikeResponseModel(
        message="Post liked successfully",
        post_id=post_id,
        new_like_count=retrieve_post_likes(
            session= session,
            post_id= post_id
        )
    )

@router.delete(
    path="/posts/{post_id}/like",
    summary="Unlike a post"
)
async def unlike_post(
        post_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    stmt = (
        delete(PostLikes)
        .where(PostLikes.post_id == post_id, PostLikes.user_id == current_user.id)
    )

    result = session.execute(stmt)

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Like not found")

    session.commit()

    return PostUnlikeResponseModel(
        message="Post unliked successfully",
        post_id=post_id,
        new_like_count=retrieve_post_likes(
            session=session,
            post_id=post_id
        )
    )


@router.get(
    path="/posts/{post_id}/comments",
    summary="Get comments for a post"
)
async def get_post_comments(
        post_id: UUID,
        limit: int = Query(default=25, ge=1),
        offset: int = Query(default=1, ge=1),
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    if limit < offset:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="limit cannot be less than offset"
        )

    like_count_sub = (
        select(func.count(CommentLikes.id))
        .where(CommentLikes.comment_id == PostComments.id)
        .correlate(PostComments)
        .scalar_subquery()
    )

    you_liked_sub = (
        select(CommentLikes.id)
        .where(
            and_(
                CommentLikes.comment_id == PostComments.id,
                CommentLikes.user_id == current_user.id
            )
        )
        .correlate(PostComments)
        .exists()
    )

    stmt = (
        select(
            PostComments,
            func.coalesce(like_count_sub, 0).label("like_count"),
            you_liked_sub.label("you_liked")
        )
        .join(PostComments.user)
        .where(PostComments.post_id == post_id)
        .order_by(PostComments.created_at.desc())
        .offset(offset - 1)
        .limit(limit)
    )

    result = session.execute(stmt).all()

    return {
        "comments": [
            PostComment(
                comment_id=row.PostComments.id,
                post_id=row.PostComments.post_id,
                user_id=row.PostComments.user_id,
                author_name=row.PostComments.user.full_name,
                replying_to_id=row.PostComments.replying_to_id,
                content=row.PostComments.content,
                created_at=row.PostComments.created_at,
                like_count=row.like_count,
                you_liked=row.you_liked
            ) for row in result
        ]
    }


@router.post(
    path="/posts/{post_id}/comments",
    summary="Add a comment to a post",
    response_model=PostComment
)
async def add_comment(
        post_id: UUID,
        new_comment_request: CommunityPostCommentRequest,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    query_items = [select(Post.id).where(Post.id == post_id).exists()]

    if new_comment_request.replying_to_id:
        query_items.append(
            select(PostComments.id).where(
                PostComments.id == new_comment_request.replying_to_id,
                PostComments.post_id == post_id
            ).exists()
        )

    stmt = select(*query_items)
    results = session.execute(stmt).first()

    if not results[0]:
        raise HTTPException(status_code=404, detail="Post not found")

    if new_comment_request.replying_to_id and not results[1]:
        raise HTTPException(status_code=404, detail="Parent comment not found")

    new_comment = PostComments(
        post_id=post_id,
        user_id=current_user.id,
        replying_to_id=new_comment_request.replying_to_id,
        content=new_comment_request.content
    )

    session.add(new_comment)
    session.commit()
    session.refresh(new_comment)

    return PostComment(
        comment_id= new_comment.id,
        post_id= post_id,
        user_id= current_user.id,
        replying_to_id= new_comment_request.replying_to_id,
        content= new_comment_request.content,
        created_at= new_comment.created_at,
        you_liked= False
    )


@router.post(
    path= "/posts/{post_id}/comments/{comment_id}/like",
    summary="Like a comment"
)
async def like_comment(
        post_id: UUID,
        comment_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    stmt = (
        select(PostComments)
        .join(Post, PostComments.post_id == Post.id)
        .where(
            Post.id == post_id,
            PostComments.id == comment_id
        )
    )

    result = session.execute(stmt)
    comment = result.scalars().first()

    if not comment:
        raise HTTPException(
            status_code=404,
            detail="Comment not found or does not belong to the specified post"
        )

    comment_like = CommentLikes(
        comment_id=comment_id,
        user_id=current_user.id
    )

    session.add(comment_like)
    session.commit()

    return {"status": "success"}


@router.delete(
    path="/posts/{post_id}/comments/{comment_id}/like",
    summary= "Unlike a comment"
)
async def unlike_comment(
        post_id: UUID,
        comment_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    stmt = (
        select(CommentLikes)
        .join(PostComments, CommentLikes.comment_id == PostComments.id)
        .join(Post, PostComments.post_id == Post.id)
        .where(
            Post.id == post_id,
            PostComments.id == comment_id,
            CommentLikes.user_id == current_user.id
        )
    )

    result = session.execute(stmt)
    like_record = result.scalars().first()

    if not like_record:
        raise HTTPException(
            status_code=404,
            detail="Like record not found for this comment and post"
        )

    session.delete(like_record)
    session.commit()

    return {"status": "success"}


@router.get("/users/{user_id}/posts", summary="Get posts by a user")
def get_user_posts(
        user_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    stmt = (
        select(*get_post_stats_columns(current_user.id))
        .join(Post.author)
        .where(Post.author_id == user_id)
        .order_by(desc(Post.created_at))
    )

    rows = session.execute(stmt).all()

    return CommunityPostsResponse(
        posts=[format_post_with_stats(row) for row in rows]
    )

@router.get("/bookmarks", summary="Get bookmarked posts for current user")
def get_user_bookmarks(
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    from app.models.user import bookmarks as bookmarks_table

    stmt = (
        select(*get_post_stats_columns(current_user.id))
        .join(bookmarks_table, bookmarks_table.c.post_id == Post.id)
        .join(Post.author)
        .where(bookmarks_table.c.user_id == current_user.id)
        .order_by(desc(Post.created_at))
        .options(defer(Post.location))
    )

    rows = session.execute(stmt).all()

    return CommunityPostsResponse(
        posts=[format_post_with_stats(row) for row in rows]
    )

@router.delete("/posts/{post_id}/bookmark", summary="Remove a bookmark")
def remove_bookmark(
        post_id: UUID,
        session: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    from app.models.user import bookmarks as bookmarks_table

    result = session.execute(
        select(bookmarks_table).where(
            bookmarks_table.c.user_id == current_user.id,
            bookmarks_table.c.post_id == post_id
        )
    ).first()

    if not result:
        raise HTTPException(status_code=404, detail="Bookmark not found")

    session.execute(
        bookmarks_table.delete().where(
            bookmarks_table.c.user_id == current_user.id,
            bookmarks_table.c.post_id == post_id
        )
    )
    session.commit()

    return {"status": "success", "message": "Bookmark removed"}
