from geoalchemy2.shape import from_shape
from shapely.geometry import Point, Polygon

from app.core.security import get_password_hash
from app.core.database import SessionLocal
from app.models.community import Community
from app.models.post import Post, Tag
from app.models.user import User


TEST_PASSWORD = "pawnder123"
NYC_LAT = 40.7128
NYC_LON = -74.0060


def point(longitude: float, latitude: float):
    return from_shape(Point(longitude, latitude), srid=4326)


def polygon(coordinates: list[tuple[float, float]]):
    return from_shape(Polygon(coordinates), srid=4326)


def get_or_create_user(db, *, email: str, full_name: str, role: str, longitude: float, latitude: float) -> User:
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        user = User(
            role=role,
            email=email,
            full_name=full_name,
            password_hash=get_password_hash(TEST_PASSWORD),
        )
        db.add(user)
        db.flush()

    user.role = role
    user.full_name = full_name
    user.last_known_location = point(longitude, latitude)
    return user


def get_or_create_tag(db, *, category: str, name: str) -> Tag:
    tag = db.query(Tag).filter(Tag.category == category, Tag.name == name).first()
    if tag is None:
        tag = Tag(category=category, name=name)
        db.add(tag)
        db.flush()
    return tag


def get_or_create_post(
    db,
    *,
    author: User,
    community: Community,
    title: str,
    description: str,
    post_type: str,
    longitude: float,
    latitude: float,
    status: str,
    tags: list[Tag],
) -> Post:
    post = db.query(Post).filter(Post.title == title, Post.author_id == author.id).first()
    if post is None:
        post = Post(
            author_id=author.id,
            community_id=community.id,
            title=title,
            description=description,
            post_type=post_type,
            status=status,
            location=point(longitude, latitude),
        )
        db.add(post)
        db.flush()

    post.description = description
    post.post_type = post_type
    post.status = status
    post.community_id = community.id
    post.location = point(longitude, latitude)
    post.tags = tags
    return post


def get_or_create_community(db, *, name: str, description: str, boundary: list[tuple[float, float]]) -> Community:
    community = db.query(Community).filter(Community.name == name).first()
    if community is None:
        community = Community(name=name, description=description)
        db.add(community)
        db.flush()

    community.description = description
    community.geofence_boundary = polygon(boundary)
    return community


def seed() -> None:
    db = SessionLocal()
    try:
        explorer = get_or_create_user(
            db,
            email="geo.explorer@justinbruinsma.com",
            full_name="Geo Explorer",
            role="Community User",
            longitude=NYC_LON,
            latitude=NYC_LAT,
        )
        reporter = get_or_create_user(
            db,
            email="neighborhood.reporter@justinbruinsma.com",
            full_name="Neighborhood Reporter",
            role="Community User",
            longitude=-74.0048,
            latitude=40.7136,
        )
        shelter = get_or_create_user(
            db,
            email="rescue.partner@justinbruinsma.com",
            full_name="Rescue Partner",
            role="Shelter/Moderator",
            longitude=-74.0082,
            latitude=40.7119,
        )

        dog_tag = get_or_create_tag(db, category="Species", name="Dog")
        cat_tag = get_or_create_tag(db, category="Species", name="Cat")
        lost_tag = get_or_create_tag(db, category="Status", name="Lost")
        found_tag = get_or_create_tag(db, category="Status", name="Found")
        bird_tag = get_or_create_tag(db, category="Species", name="Bird")
        rodent_tag = get_or_create_tag(db, category="Species", name="Rodent")
        lostpet_tag = get_or_create_tag(db, category="Status", name="LostPet")
        foundpet_tag = get_or_create_tag(db, category="Status", name="FoundPet")
        brooklyn_tag = get_or_create_tag(db, category="Location", name="Brooklyn")
        queens_tag = get_or_create_tag(db, category="Location", name="Queens")

        # ── Communities ──────────────────────────────────────────
        tribeca_watch = get_or_create_community(
            db,
            name="Tribeca Watch",
            description="Downtown Tribeca neighborhood pet alerts.",
            boundary=[
                (-74.0080, 40.7115), (-74.0038, 40.7115),
                (-74.0038, 40.7148), (-74.0080, 40.7148),
                (-74.0080, 40.7115),
            ],
        )

        queens_watch = get_or_create_community(
            db,
            name="Queens Watch",
            description="Pet alerts across Queens neighborhoods.",
            boundary=[
                (-73.9500, 40.7282), (-73.7900, 40.7282),
                (-73.7900, 40.7682), (-73.9500, 40.7682),
                (-73.9500, 40.7282),
            ],
        )

        manhattan_hub = get_or_create_community(
            db,
            name="Manhattan Hub",
            description="Central Manhattan pet community.",
            boundary=[
                (-74.0200, 40.7000), (-73.9700, 40.7000),
                (-73.9700, 40.7900), (-74.0200, 40.7900),
                (-74.0200, 40.7000),
            ],
        )

        # ── Tribeca Watch Posts ───────────────────────────────────
        get_or_create_post(
            db, author=reporter, community=tribeca_watch,
            title="Golden retriever seen near Tribeca park",
            description="Friendly dog spotted near the benches around lunch time.",
            post_type="Sighting", longitude=-74.0057, latitude=40.7132,
            status="Active", tags=[dog_tag, found_tag],
        )
        get_or_create_post(
            db, author=shelter, community=tribeca_watch,
            title="Missing tabby cat with blue collar",
            description="Last seen near the corner deli two blocks east.",
            post_type="Lost Pet", longitude=-74.0049, latitude=40.7123,
            status="Active", tags=[cat_tag, lost_tag, lostpet_tag],
        )
        get_or_create_post(
            db, author=reporter, community=tribeca_watch,
            title="Small brown dog by Hudson walkway",
            description="Nervous dog running north along the waterfront path.",
            post_type="Sighting", longitude=-74.0074, latitude=40.7141,
            status="Active", tags=[dog_tag],
        )

        # ── Queens Watch Posts ────────────────────────────────────
        get_or_create_post(
            db, author=reporter, community=queens_watch,
            title="Help me find my Parrot",
            description="My parrot has been missing for 2 hours, last seen in our backyard in Elmhurst. He responds to his name Sony.",
            post_type="Lost Pet", longitude=-73.8830, latitude=40.7370,
            status="Active", tags=[bird_tag, lostpet_tag, queens_tag],
        )
        get_or_create_post(
            db, author=explorer, community=queens_watch,
            title="Found this lil cockatiel",
            description="Found a cockatiel perched on my window this afternoon. Very tame, responds to whistles.",
            post_type="Sighting", longitude=-73.8650, latitude=40.7480,
            status="Active", tags=[bird_tag, foundpet_tag, queens_tag],
        )
        get_or_create_post(
            db, author=shelter, community=queens_watch,
            title="Lost terrier mix near Flushing",
            description="Small white terrier mix, very friendly. Last seen near Main St Flushing.",
            post_type="Lost Pet", longitude=-73.8300, latitude=40.7580,
            status="Active", tags=[dog_tag, lostpet_tag, queens_tag],
        )

        # ── Manhattan Hub Posts ───────────────────────────────────
        get_or_create_post(
            db, author=shelter, community=manhattan_hub,
            title="Who's hedgehog is this",
            description="Found a friendly hedgehog near 96th street around noon. Looks domesticated and well cared for.",
            post_type="Sighting", longitude=-73.9680, latitude=40.7851,
            status="Active", tags=[foundpet_tag],
        )
        get_or_create_post(
            db, author=reporter, community=manhattan_hub,
            title="Let's bring Georgie home",
            description="Georgie slipped out of our apartment this morning. White and brown cat near downtown Manhattan.",
            post_type="Lost Pet", longitude=-73.9850, latitude=40.7580,
            status="Active", tags=[cat_tag, lostpet_tag],
        )
        get_or_create_post(
            db, author=explorer, community=manhattan_hub,
            title="Stray cat near Central Park",
            description="Friendly orange tabby hanging around the south entrance of Central Park.",
            post_type="Sighting", longitude=-73.9734, latitude=40.7644,
            status="Active", tags=[cat_tag, foundpet_tag],
        )

        db.commit()

        print("Seed complete.")
        print(f"Tribeca Watch id: {tribeca_watch.id}")
        print(f"Queens Watch id:  {queens_watch.id}")
        print(f"Manhattan Hub id: {manhattan_hub.id}")

    finally:
        db.close()

if __name__ == "__main__":
    seed()