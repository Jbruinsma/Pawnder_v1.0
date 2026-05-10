CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role VARCHAR NOT NULL,
    email VARCHAR NOT NULL UNIQUE,
    password_hash VARCHAR NOT NULL,
    full_name VARCHAR NOT NULL,
    last_known_location geometry(POINT, 4326),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_users_email ON users (email);

CREATE TABLE communities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL UNIQUE,
    description VARCHAR,
    image_url VARCHAR,
    geofence_boundary geometry(POLYGON, 4326)
);

CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR NOT NULL,
    name VARCHAR NOT NULL
);

CREATE TABLE user_communities (
    user_id UUID NOT NULL REFERENCES users(id),
    community_id UUID NOT NULL REFERENCES communities(id),
    PRIMARY KEY (user_id, community_id)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id),
    receiver_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES users(id),
    community_id UUID NOT NULL REFERENCES communities(id),
    post_type VARCHAR NOT NULL,
    title VARCHAR NOT NULL,
    description TEXT NOT NULL,
    image_url VARCHAR,
    location geometry(POINT, 4326) NOT NULL,
    status VARCHAR DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    edited BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_posts_author_id ON posts (author_id);
CREATE INDEX ix_posts_community_id ON posts (community_id);

CREATE TABLE post_tags (
    post_id UUID NOT NULL REFERENCES posts(id),
    tag_id UUID NOT NULL REFERENCES tags(id),
    PRIMARY KEY (post_id, tag_id)
);

CREATE TABLE bookmarks (
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    PRIMARY KEY (user_id, post_id)
);

CREATE TABLE post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id),
    user_id UUID NOT NULL REFERENCES users(id),
    CONSTRAINT _user_post_like_uc UNIQUE (post_id, user_id)
);

CREATE INDEX ix_post_likes_post_id ON post_likes (post_id);
CREATE INDEX ix_post_likes_user_id ON post_likes (user_id);

CREATE TABLE post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id),
    user_id UUID NOT NULL REFERENCES users(id),
    replying_to_id UUID REFERENCES post_comments(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_post_comments_post_id ON post_comments (post_id);
CREATE INDEX ix_post_comments_user_id ON post_comments (user_id);
CREATE INDEX ix_post_comments_replying_to_id ON post_comments (replying_to_id);

CREATE TABLE comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES post_comments(id),
    user_id UUID NOT NULL REFERENCES users(id),
    CONSTRAINT _user_comment_like_uc UNIQUE (comment_id, user_id)
);

CREATE INDEX ix_comment_likes_comment_id ON comment_likes (comment_id);
CREATE INDEX ix_comment_likes_user_id ON comment_likes (user_id);