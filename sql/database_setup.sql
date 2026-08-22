-- Airbnb database setup for PostgreSQL.
-- Run from the project root with:
--   psql -d your_database -f sql/database_setup.sql
--
-- The import commands use psql's client-side \copy so relative paths resolve from
-- the directory where psql is launched.

CREATE SCHEMA IF NOT EXISTS airbnb;

DROP TABLE IF EXISTS airbnb.reviews;
DROP TABLE IF EXISTS airbnb.listings;

CREATE TABLE airbnb.listings (
    listing_id BIGINT PRIMARY KEY,
    name TEXT,
    host_id BIGINT NOT NULL,
    host_since DATE,
    host_location TEXT,
    host_response_time TEXT,
    host_response_rate NUMERIC(6, 2),
    host_acceptance_rate NUMERIC(6, 2),
    host_is_superhost BOOLEAN,
    host_total_listings_count INTEGER,
    host_has_profile_pic BOOLEAN,
    host_identity_verified BOOLEAN,
    neighbourhood TEXT,
    district TEXT,
    city TEXT NOT NULL,
    latitude NUMERIC(9, 6),
    longitude NUMERIC(9, 6),
    property_type TEXT,
    room_type TEXT,
    accommodates INTEGER,
    bedrooms NUMERIC(6, 2),
    amenities TEXT,
    price NUMERIC(12, 2),
    minimum_nights INTEGER,
    maximum_nights INTEGER,
    review_scores_rating NUMERIC(5, 2),
    review_scores_accuracy NUMERIC(4, 2),
    review_scores_cleanliness NUMERIC(4, 2),
    review_scores_checkin NUMERIC(4, 2),
    review_scores_communication NUMERIC(4, 2),
    review_scores_location NUMERIC(4, 2),
    review_scores_value NUMERIC(4, 2),
    instant_bookable BOOLEAN
);

CREATE TABLE airbnb.reviews (
    listing_id BIGINT NOT NULL,
    review_id BIGINT,
    date DATE,
    reviewer_id BIGINT,
    CONSTRAINT fk_reviews_listing
        FOREIGN KEY (listing_id)
        REFERENCES airbnb.listings (listing_id)
);

\copy airbnb.listings FROM 'data/raw/Listings.csv' WITH (FORMAT csv, HEADER true, ENCODING 'LATIN1');
\copy airbnb.reviews FROM 'data/raw/Reviews.csv' WITH (FORMAT csv, HEADER true);

CREATE INDEX idx_listings_city ON airbnb.listings (city);
CREATE INDEX idx_listings_room_type ON airbnb.listings (room_type);
CREATE INDEX idx_listings_host_id ON airbnb.listings (host_id);
CREATE INDEX idx_reviews_listing_id ON airbnb.reviews (listing_id);
CREATE INDEX idx_reviews_date ON airbnb.reviews (date);
CREATE INDEX idx_reviews_reviewer_id ON airbnb.reviews (reviewer_id);

ANALYZE airbnb.listings;
ANALYZE airbnb.reviews;
