-- ============================================================================
-- Deckard — Representative test dataset
-- ----------------------------------------------------------------------------
-- NOT FOR PRODUCTION. Used to populate a local DB for manual / e2e testing.
--
-- Usage (clean DB):
--     docker compose down -v
--     docker compose up -d                                      # creates schema
--     docker compose exec api python -m app.scripts.sync_genres # 19 genres
--     docker compose exec -T db psql -U deckard -d deckard < resources/test_dataset.sql
--
-- Or just run the SQL through DBeaver / psql on a fresh schema.
--
-- ---------------------------------------------------------------------------
-- Test password (ALL users):  Password123!
-- The hash below was produced by app.security.hash_password (bcrypt with the
-- standard sha256+base64 pre-hash). Same hash for every user — fine, since
-- bcrypt verifies against the plaintext, not against a recomputed hash.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. USERS (no FK dependencies)
-- ============================================================================
INSERT INTO users (id, email, username, password_hash, language, region) VALUES
    ('11111111-1111-1111-1111-111111111111', 'alice@example.com',   'alice',   '$2b$12$xC/i1pkEQ4Ja6iiSJ6MQWOZ6qlhpYZTSlOz6YKPd59KFMNnduR4a6', 'fr-FR', 'FR'),
    ('22222222-2222-2222-2222-222222222222', 'bob@example.com',     'bob',     '$2b$12$xC/i1pkEQ4Ja6iiSJ6MQWOZ6qlhpYZTSlOz6YKPd59KFMNnduR4a6', 'fr-FR', 'FR'),
    ('33333333-3333-3333-3333-333333333333', 'charlie@example.com', 'charlie', '$2b$12$xC/i1pkEQ4Ja6iiSJ6MQWOZ6qlhpYZTSlOz6YKPd59KFMNnduR4a6', 'fr-FR', 'FR'),
    ('44444444-4444-4444-4444-444444444444', 'diana@example.com',   'diana',   '$2b$12$xC/i1pkEQ4Ja6iiSJ6MQWOZ6qlhpYZTSlOz6YKPd59KFMNnduR4a6', 'en-US', 'US'),
    ('55555555-5555-5555-5555-555555555555', 'eve@example.com',     'eve',     '$2b$12$xC/i1pkEQ4Ja6iiSJ6MQWOZ6qlhpYZTSlOz6YKPd59KFMNnduR4a6', 'fr-FR', 'FR'),
    ('66666666-6666-6666-6666-666666666666', 'frank@example.com',   'frank',   '$2b$12$xC/i1pkEQ4Ja6iiSJ6MQWOZ6qlhpYZTSlOz6YKPd59KFMNnduR4a6', 'fr-FR', 'FR');

-- ============================================================================
-- 2. GENRES (idempotent — sync_genres normally populates these)
--    Only the ones referenced below.
-- ============================================================================
INSERT INTO genres (tmdb_id, name) VALUES
    (28,    'Action'),
    (12,    'Aventure'),
    (35,    'Comédie'),
    (80,    'Crime'),
    (18,    'Drame'),
    (14,    'Fantastique'),
    (10749, 'Romance'),
    (878,   'Science-Fiction'),
    (53,    'Thriller')
ON CONFLICT (tmdb_id) DO NOTHING;

-- ============================================================================
-- 3. MOVIES (no FK dependencies)
--    Real TMDB IDs, fields kept minimal but realistic.
-- ============================================================================
INSERT INTO movies (tmdb_id, title, original_title, overview, release_date, runtime, poster_path, backdrop_path, original_language, vote_average) VALUES
    (550,   'Fight Club',                            'Fight Club',                          'Le narrateur, sans identité précise, va devenir membre du Fight Club.', '1999-10-15', 139, '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg', '/52AfXWuXCHn3UjD17rBruA9f5qb.jpg', 'en', 8.4),
    (603,   'Matrix',                                'The Matrix',                          'Un hacker découvre la vraie nature de la réalité.',                      '1999-03-31', 136, '/p96dm7sCMn4VYAStA6siNz30G1r.jpg', '/ncEsesgOJDNrTUED89hYbA117wo.jpg', 'en', 8.2),
    (27205, 'Inception',                             'Inception',                           'Dom Cobb est un voleur de secrets dans les rêves.',                      '2010-07-15', 148, '/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg', '/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg', 'en', 8.4),
    (155,   'The Dark Knight : Le Chevalier noir',  'The Dark Knight',                     'Batman affronte le Joker à Gotham.',                                     '2008-07-16', 152, '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', '/dqK9Hag1054tghRQSqLSfrkvQnA.jpg', 'en', 8.5),
    (13,    'Forrest Gump',                          'Forrest Gump',                        'La vie de Forrest, simple d''esprit mais témoin de l''histoire des USA.', '1994-07-06', 142, '/saHP97rTPS5eLmrLQEcANmKrsFl.jpg', '/8YlbVYAyzMnjkpZbAgQzD3SrSAS.jpg', 'en', 8.5),
    (680,   'Pulp Fiction',                          'Pulp Fiction',                        'Plusieurs histoires entrelacées de pègre de Los Angeles.',               '1994-10-14', 154, '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg', '/suaEOtk1N1sgg2MTM7oZd2cfVp3.jpg', 'en', 8.5),
    (19995, 'Avatar',                                'Avatar',                              'Sur la lune Pandora, un Marine paraplégique se met à exister via un avatar.', '2009-12-15', 162, '/jRXYjXNq0Cs2TcJjLkki24MLp7u.jpg', '/Yc9q6QuWrMp9nuDm5R8ExNqbEWU.jpg', 'en', 7.6),
    (122,   'Le Seigneur des anneaux : Le Retour du Roi', 'The Lord of the Rings: The Return of the King', 'Aragorn marche vers le trône pendant que Frodon poursuit sa quête.',          '2003-12-17', 201, '/8BPZO0Bf8TeAy8znF43z8soK3ys.jpg', '/n6vEzWZxsf02CkntJjALfBs6F8B.jpg', 'en', 8.5);

-- ============================================================================
-- 4. PERSONS (no FK dependencies — referenced by movie_cast / movie_crew)
-- ============================================================================
INSERT INTO persons (tmdb_id, name, profile_path) VALUES
    (819,  'Edward Norton',     '/8nytsqL59SFJTVYVrN72k6qkGgJ.jpg'),
    (287,  'Brad Pitt',         '/m09Y1YfPPeNYYUSHnnVqahkrC1o.jpg'),
    (7467, 'David Fincher',     '/jpV1Xz1KKZIQk7uIdM5gj2C0vKW.jpg'),
    (6384, 'Keanu Reeves',      '/4D0PpNI0kmP58hgrwGC3wCjxhnm.jpg'),
    (1212, 'Laurence Fishburne','/eUcjxFEpdFqaIzNhPHcSCfgYNwx.jpg'),
    (138,  'Quentin Tarantino', '/1gjcpAa99FAOWGnrUvHEXXsRs7o.jpg'),
    (31,   'Tom Hanks',         '/xndWFsBlClOJFRdhSt4NBwiPq2o.jpg'),
    (109,  'Elijah Wood',       '/cRgxckqRpKMNHbeg4qLuS3wKuTu.jpg');

-- ============================================================================
-- 5. MOVIE_GENRES  (FK: movies, genres)
-- ============================================================================
INSERT INTO movie_genres (movie_id, genre_id) VALUES
    -- Fight Club : Drame, Thriller
    (550, 18), (550, 53),
    -- Matrix : Action, Science-Fiction
    (603, 28), (603, 878),
    -- Inception : Action, Science-Fiction, Aventure
    (27205, 28), (27205, 878), (27205, 12),
    -- Dark Knight : Action, Crime, Drame
    (155, 28), (155, 80), (155, 18),
    -- Forrest Gump : Drame, Romance, Comédie
    (13, 18), (13, 10749), (13, 35),
    -- Pulp Fiction : Thriller, Crime
    (680, 53), (680, 80),
    -- Avatar : Action, Aventure, Science-Fiction
    (19995, 28), (19995, 12), (19995, 878),
    -- LOTR ROTK : Aventure, Fantastique, Action
    (122, 12), (122, 14), (122, 28);

-- ============================================================================
-- 6. MOVIE_CAST  (FK: movies, persons)
-- ============================================================================
INSERT INTO movie_cast (movie_id, person_id, character, cast_order) VALUES
    -- Fight Club
    (550, 819, 'The Narrator', 0),
    (550, 287, 'Tyler Durden', 1),
    -- Matrix
    (603, 6384, 'Neo',       0),
    (603, 1212, 'Morpheus',  1),
    -- Forrest Gump
    (13,  31,  'Forrest Gump', 0),
    -- LOTR
    (122, 109, 'Frodo Baggins', 0);

-- ============================================================================
-- 7. MOVIE_CREW  (FK: movies, persons)
-- ============================================================================
INSERT INTO movie_crew (movie_id, person_id, job, department) VALUES
    (550, 7467, 'Director', 'Directing'),
    (680, 138,  'Director', 'Directing');

-- ============================================================================
-- 8. FRIENDSHIPS  (FK: users)
-- ----------------------------------------------------------------------------
--  Asymmetric model — each row is one direction. Designed to cover all states.
--
--    Alice  ─►  Bob       accepted          (and Bob ─► Alice accepted — mutual)
--    Alice  ─►  Charlie   accepted          (and Charlie ─► Alice accepted — mutual)
--    Alice  ─►  Diana     accepted          (Diana never befriended Alice back — asymmetric)
--    Alice  ─►  Eve       pending           (Eve hasn't decided)
--    Alice  ─►  Frank     rejected          (Frank rejected Alice)
--    Bob    ─►  Charlie   accepted          (Charlie hasn't befriended Bob — asymmetric)
--    Bob    ─►  Diana     pending           (Diana hasn't responded yet)
-- ============================================================================
INSERT INTO friendships (requester_id, addressee_id, status) VALUES
    ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'accepted'),
    ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'accepted'),
    ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'accepted'),
    ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'accepted'),
    ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'accepted'),
    ('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 'pending'),
    ('11111111-1111-1111-1111-111111111111', '66666666-6666-6666-6666-666666666666', 'rejected'),
    ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'accepted'),
    ('22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', 'pending');

-- ============================================================================
-- 9. FAVORITES  (FK: users, movies)
-- ============================================================================
INSERT INTO favorites (user_id, movie_id) VALUES
    -- Alice : 1 fav (peu active)
    ('11111111-1111-1111-1111-111111111111', 680),
    -- Bob : 3 favs (gros geek SF/thriller)
    ('22222222-2222-2222-2222-222222222222', 550),
    ('22222222-2222-2222-2222-222222222222', 603),
    ('22222222-2222-2222-2222-222222222222', 27205),
    -- Charlie : 3 favs (varié)
    ('33333333-3333-3333-3333-333333333333', 550),
    ('33333333-3333-3333-3333-333333333333', 13),
    ('33333333-3333-3333-3333-333333333333', 27205),
    -- Diana : 2 favs (épique)
    ('44444444-4444-4444-4444-444444444444', 122),
    ('44444444-4444-4444-4444-444444444444', 19995);

-- ============================================================================
-- 10. RATINGS  (FK: users, movies)
--     Stored as half-stars 0..10  (e.g. 9 = 4.5★, 10 = 5★)
-- ============================================================================
INSERT INTO ratings (user_id, movie_id, rating) VALUES
    -- Alice
    ('11111111-1111-1111-1111-111111111111', 680, 9),     -- Pulp Fiction 4.5
    ('11111111-1111-1111-1111-111111111111', 155, 10),    -- Dark Knight 5
    -- Bob
    ('22222222-2222-2222-2222-222222222222', 603, 10),    -- Matrix 5
    ('22222222-2222-2222-2222-222222222222', 155, 8),     -- Dark Knight 4
    ('22222222-2222-2222-2222-222222222222', 550, 9),     -- Fight Club 4.5
    -- Charlie
    ('33333333-3333-3333-3333-333333333333', 27205, 10),  -- Inception 5
    ('33333333-3333-3333-3333-333333333333', 19995, 6),   -- Avatar 3
    ('33333333-3333-3333-3333-333333333333', 13, 9),      -- Forrest Gump 4.5
    -- Diana
    ('44444444-4444-4444-4444-444444444444', 122, 10),    -- LOTR 5
    ('44444444-4444-4444-4444-444444444444', 13, 8),      -- Forrest Gump 4
    ('44444444-4444-4444-4444-444444444444', 19995, 9);   -- Avatar 4.5

-- ============================================================================
-- 11. WATCHLIST  (FK: users, movies)
-- ============================================================================
INSERT INTO watchlist (user_id, movie_id) VALUES
    ('11111111-1111-1111-1111-111111111111', 19995),  -- Alice : Avatar
    ('22222222-2222-2222-2222-222222222222', 122),    -- Bob   : LOTR
    ('33333333-3333-3333-3333-333333333333', 19995),  -- Charlie: Avatar
    ('44444444-4444-4444-4444-444444444444', 27205);  -- Diana : Inception

-- ============================================================================
-- 12. WATCHED  (FK: users, movies)
-- ============================================================================
INSERT INTO watched (user_id, movie_id) VALUES
    ('11111111-1111-1111-1111-111111111111', 680),
    ('11111111-1111-1111-1111-111111111111', 155),
    ('22222222-2222-2222-2222-222222222222', 550),
    ('22222222-2222-2222-2222-222222222222', 603),
    ('22222222-2222-2222-2222-222222222222', 155),
    ('22222222-2222-2222-2222-222222222222', 27205),
    ('33333333-3333-3333-3333-333333333333', 550),
    ('33333333-3333-3333-3333-333333333333', 27205),
    ('33333333-3333-3333-3333-333333333333', 13),
    ('33333333-3333-3333-3333-333333333333', 19995),
    ('44444444-4444-4444-4444-444444444444', 122),
    ('44444444-4444-4444-4444-444444444444', 19995),
    ('44444444-4444-4444-4444-444444444444', 13);

-- ============================================================================
-- 13. FEATURED_MOVIES  (FK: movies)
--     id has no DB default — gen_random_uuid() builtin (Postgres 13+).
--   * Inception : active right now
--   * Fight Club : already expired (test fallback path of /movies/featured)
-- ============================================================================
INSERT INTO featured_movies (id, movie_id, starts_at, ends_at) VALUES
    (gen_random_uuid(), 27205, NOW() - INTERVAL '2 days', NOW() + INTERVAL '5 days'),
    (gen_random_uuid(), 550,   NOW() - INTERVAL '30 days', NOW() - INTERVAL '23 days');

COMMIT;

-- ============================================================================
-- QUICK SANITY CHECK (run after the COMMIT)
-- ============================================================================
-- SELECT 'users'           AS t, count(*) FROM users
-- UNION ALL SELECT 'movies',           count(*) FROM movies
-- UNION ALL SELECT 'genres',           count(*) FROM genres
-- UNION ALL SELECT 'movie_genres',     count(*) FROM movie_genres
-- UNION ALL SELECT 'persons',          count(*) FROM persons
-- UNION ALL SELECT 'movie_cast',       count(*) FROM movie_cast
-- UNION ALL SELECT 'movie_crew',       count(*) FROM movie_crew
-- UNION ALL SELECT 'friendships',      count(*) FROM friendships
-- UNION ALL SELECT 'favorites',        count(*) FROM favorites
-- UNION ALL SELECT 'ratings',          count(*) FROM ratings
-- UNION ALL SELECT 'watchlist',        count(*) FROM watchlist
-- UNION ALL SELECT 'watched',          count(*) FROM watched
-- UNION ALL SELECT 'featured_movies',  count(*) FROM featured_movies;

-- ============================================================================
-- TEST SCENARIOS THIS DATA COVERS
-- ============================================================================
--   Auth & profile  : 6 logins possibles (Password123!)
--   Asymmetric friends : Alice→Diana accepted but Diana→Alice n'existe pas
--                        Diana ne peut PAS voir Alice ; Alice peut voir Diana.
--   Mutual friends      : Alice↔Bob, Alice↔Charlie
--   Pending request     : Alice→Eve (Eve doit voir l'incoming)
--   Rejected request    : Alice→Frank (test re-send qui re-pend la ligne)
--   Friend's profile    : Alice peut GET /users/{bob_id}/* (200), Bob peut GET /users/{alice_id}/* (200),
--                         Diana ne peut PAS GET /users/{alice_id}/* (403)
--   Recommendations from friends, pour Alice :
--     Signaux des amis (Bob, Charlie, Diana) — Alice exclut sa propre collection :
--       favorites=680, ratings={680,155}, watchlist=19995, watched={680,155}
--       Donc exclus de ses recos = {680, 155, 19995}
--
--     Threshold high rating = rating >= 8 (inclusif, donc 4.0★ qualifie).
--
--       Inception (27205) = Bob fav (+4) + Charlie fav (+4) + Charlie rating 10 (+3)
--                         + Bob watched (+2) + Charlie watched (+2) + Diana watchlist (+1) = 16
--       Fight Club (550)  = Bob fav (+4) + Charlie fav (+4) + Bob rating 9 (+3)
--                         + Bob watched (+2) + Charlie watched (+2) = 15
--       Forrest Gump (13) = Charlie fav (+4) + Charlie rating 9 (+3) + Diana rating 8 (+3)
--                         + Charlie watched (+2) + Diana watched (+2) = 14
--       LOTR (122)        = Diana fav (+4) + Diana rating 10 (+3) + Diana watched (+2)
--                         + Bob watchlist (+1) = 10
--       Matrix (603)      = Bob fav (+4) + Bob rating 10 (+3) + Bob watched (+2) = 9
--       (Dark Knight et Avatar exclus car déjà dans la collection d'Alice)
--     Classement attendu : Inception > Fight Club > Forrest Gump > LOTR > Matrix
--   Featured           : GET /movies/featured retourne Inception (active window)
--   Search             : GET /users/search?q=ar -> Charlie (matches "char...") et nada pour les autres
