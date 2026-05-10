# DUMMY DATA INSERTS. WE ONLY USED THIS FOR TESTING PURPOSES.

TRUNCATE TABLE post_tags, bookmarks, post_likes, post_comments, comment_likes, messages, posts, tags, users, communities CASCADE;

INSERT INTO communities (id, name, description, geofence_boundary) VALUES
('10000000-0000-0000-0000-000000000001', 'Queens', 'The Queens Community', ST_SetSRID(ST_GeomFromText('POLYGON((-73.96 40.80, -73.70 40.80, -73.70 40.50, -73.96 40.50, -73.96 40.80))'), 4326)),
('10000000-0000-0000-0000-000000000002', 'Brooklyn', 'The Brooklyn Community', ST_SetSRID(ST_GeomFromText('POLYGON((-74.04 40.74, -73.85 40.74, -73.85 40.57, -74.04 40.57, -74.04 40.74))'), 4326)),
('10000000-0000-0000-0000-000000000003', 'Manhattan', 'The Manhattan Community', ST_SetSRID(ST_GeomFromText('POLYGON((-74.02 40.88, -73.91 40.88, -73.91 40.70, -74.02 40.70, -74.02 40.88))'), 4326));

INSERT INTO users (id, role, email, password_hash, full_name, last_known_location) VALUES
('20000000-0000-0000-0000-000000000001', 'Community User', 'sheila@example.com', 'hashed_pass', 'Sheila Carr', ST_SetSRID(ST_MakePoint(-73.87, 40.74), 4326)),
('20000000-0000-0000-0000-000000000002', 'Community User', 'martha@example.com', 'hashed_pass', 'Martha Ellis', ST_SetSRID(ST_MakePoint(-73.94, 40.67), 4326)),
('20000000-0000-0000-0000-000000000003', 'Community User', 'manny@example.com', 'hashed_pass', 'Manny Ortiz', ST_SetSRID(ST_MakePoint(-73.97, 40.78), 4326)),
('20000000-0000-0000-0000-000000000004', 'Community User', 'noah@example.com', 'hashed_pass', 'Noah Fields', ST_SetSRID(ST_MakePoint(-73.82, 40.71), 4326)),
('20000000-0000-0000-0000-000000000005', 'Shelter/Moderator', 'shelter@example.com', 'hashed_pass', 'City Pet Rescue', ST_SetSRID(ST_MakePoint(-73.90, 40.75), 4326));

INSERT INTO tags (id, category, name) VALUES
('30000000-0000-0000-0000-000000000001', 'Species', 'Bird'),
('30000000-0000-0000-0000-000000000002', 'Status', 'LostPet'),
('30000000-0000-0000-0000-000000000003', 'Location', 'Queens'),
('30000000-0000-0000-0000-000000000004', 'Species', 'Cat'),
('30000000-0000-0000-0000-000000000005', 'Location', 'Brooklyn'),
('30000000-0000-0000-0000-000000000006', 'Location', 'Manhattan'),
('30000000-0000-0000-0000-000000000007', 'Status', 'FoundPet'),
('30000000-0000-0000-0000-000000000008', 'Species', 'Hedgehog'),
('30000000-0000-0000-0000-000000000009', 'Species', 'Dog');

INSERT INTO posts (id, author_id, community_id, post_type, title, description, image_url, location, status, created_at) VALUES
('40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Lost', 'Help me find my Parrot', 'Sony mimic tweets and was last seen in Elmhurst.', 'mock://sample-post/parrot', ST_SetSRID(ST_MakePoint(-73.87, 40.74), 4326), 'Active', '2026-03-10 16:32:00'),
('40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Lost', 'Let''s bring Georgie home', 'White and brown cat near downtown Brooklyn.', 'mock://sample-post/georgie', ST_SetSRID(ST_MakePoint(-73.98, 40.69), 4326), 'Active', '2026-03-09 08:00:00'),
('40000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Found', 'Who''s hedgehog is this', 'Found near 96th street around noon.', 'mock://sample-post/hedgehog', ST_SetSRID(ST_MakePoint(-73.95, 40.78), 4326), 'Active', '2026-03-10 15:10:00'),
('40000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'Found', 'Found this lil cockateel', 'Tame and responds to whistles. Found in Queens.', 'mock://sample-post/cockatiel', ST_SetSRID(ST_MakePoint(-73.82, 40.71), 4326), 'Active', '2026-03-08 16:00:00'),

('40000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'Adoption', 'Pearline', 'Siamese, 4 months old', 'mock://sample-pet/pearline', ST_SetSRID(ST_MakePoint(-73.88, 40.75), 4326), 'Active', NOW()),
('40000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', 'Adoption', 'Scooba', 'Dalmatian, 2 yrs old', 'mock://sample-pet/scooba', ST_SetSRID(ST_MakePoint(-73.95, 40.65), 4326), 'Active', NOW()),
('40000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000003', 'Adoption', 'Table', 'Calico, 1 month old', 'mock://sample-pet/table', ST_SetSRID(ST_MakePoint(-73.97, 40.75), 4326), 'Active', NOW());

INSERT INTO post_tags (post_id, tag_id) VALUES
('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001'),
('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002'),
('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003'),
('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000004'),
('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002'),
('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000005'),
('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000007'),
('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000008'),
('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000006');