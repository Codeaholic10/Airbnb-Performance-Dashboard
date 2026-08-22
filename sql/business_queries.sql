-- Airbnb business analysis queries for PostgreSQL.
-- Assumes tables were created with sql/database_setup.sql.

SET search_path TO airbnb;

-- 1. Which cities have the largest supply, strongest review demand, and highest median prices?
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS review_count
    FROM reviews
    GROUP BY listing_id
)
SELECT
    l.city,
    COUNT(*) AS listings,
    COUNT(DISTINCT l.host_id) AS hosts,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.price))::numeric, 2) AS median_price,
    ROUND(AVG(l.review_scores_rating), 2) AS avg_rating,
    COALESCE(SUM(rc.review_count), 0) AS total_reviews,
    ROUND(100.0 * AVG(CASE WHEN l.host_is_superhost THEN 1 ELSE 0 END), 2) AS pct_superhost
FROM listings l
LEFT JOIN review_counts rc ON rc.listing_id = l.listing_id
GROUP BY l.city
ORDER BY listings DESC;

-- 2. What is the room-type mix and pricing profile of the marketplace?
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS review_count
    FROM reviews
    GROUP BY listing_id
)
SELECT
    l.room_type,
    COUNT(*) AS listings,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS listing_share_pct,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.price))::numeric, 2) AS median_price,
    ROUND(AVG(l.price), 2) AS avg_price,
    ROUND(AVG(COALESCE(rc.review_count, 0)), 2) AS avg_reviews_per_listing,
    ROUND(AVG(l.review_scores_rating), 2) AS avg_rating
FROM listings l
LEFT JOIN review_counts rc ON rc.listing_id = l.listing_id
GROUP BY l.room_type
ORDER BY listings DESC;

-- 3. Which cities have the highest superhost concentration?
SELECT
    city,
    COUNT(*) AS listings,
    SUM(CASE WHEN host_is_superhost THEN 1 ELSE 0 END) AS superhost_listings,
    ROUND(100.0 * AVG(CASE WHEN host_is_superhost THEN 1 ELSE 0 END), 2) AS pct_superhost,
    ROUND(AVG(review_scores_rating), 2) AS avg_rating
FROM listings
GROUP BY city
ORDER BY pct_superhost DESC;

-- 4. Which hosts operate the largest portfolios and how do those portfolios perform?
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS review_count
    FROM reviews
    GROUP BY listing_id
)
SELECT
    l.host_id,
    MIN(l.host_since) AS host_since,
    COUNT(*) AS listings,
    COUNT(DISTINCT l.city) AS cities_active,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.price))::numeric, 2) AS median_price,
    ROUND(AVG(l.review_scores_rating), 2) AS avg_rating,
    COALESCE(SUM(rc.review_count), 0) AS total_reviews
FROM listings l
LEFT JOIN review_counts rc ON rc.listing_id = l.listing_id
GROUP BY l.host_id
HAVING COUNT(*) >= 10
ORDER BY listings DESC, total_reviews DESC
LIMIT 25;

-- 5. Which neighborhoods have the strongest review demand within each city?
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS review_count
    FROM reviews
    GROUP BY listing_id
),
neighborhood_summary AS (
    SELECT
        l.city,
        l.neighbourhood,
        COUNT(*) AS listings,
        COALESCE(SUM(rc.review_count), 0) AS total_reviews,
        ROUND(AVG(COALESCE(rc.review_count, 0)), 2) AS avg_reviews_per_listing,
        ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.price))::numeric, 2) AS median_price,
        ROUND(AVG(l.review_scores_rating), 2) AS avg_rating
    FROM listings l
    LEFT JOIN review_counts rc ON rc.listing_id = l.listing_id
    WHERE l.neighbourhood IS NOT NULL
    GROUP BY l.city, l.neighbourhood
    HAVING COUNT(*) >= 50
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY total_reviews DESC, avg_reviews_per_listing DESC
        ) AS demand_rank
    FROM neighborhood_summary
)
SELECT *
FROM ranked
WHERE demand_rank <= 5
ORDER BY city, demand_rank;

-- 6. How has review activity changed by year?
SELECT
    EXTRACT(YEAR FROM date)::int AS review_year,
    COUNT(*) AS reviews,
    COUNT(DISTINCT listing_id) AS reviewed_listings,
    COUNT(DISTINCT reviewer_id) AS active_reviewers
FROM reviews
WHERE date IS NOT NULL
GROUP BY review_year
ORDER BY review_year;

-- 7. Which listings are potential high-value opportunities: highly rated, affordable, and frequently reviewed?
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS review_count
    FROM reviews
    GROUP BY listing_id
),
city_price_benchmarks AS (
    SELECT
        city,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS city_median_price
    FROM listings
    WHERE price > 0
    GROUP BY city
)
SELECT
    l.listing_id,
    l.name,
    l.city,
    l.neighbourhood,
    l.room_type,
    l.price,
    ROUND(cpb.city_median_price::numeric, 2) AS city_median_price,
    l.review_scores_rating,
    rc.review_count,
    l.instant_bookable,
    l.host_is_superhost
FROM listings l
JOIN review_counts rc ON rc.listing_id = l.listing_id
JOIN city_price_benchmarks cpb ON cpb.city = l.city
WHERE l.price > 0
  AND l.price <= cpb.city_median_price
  AND l.review_scores_rating >= 95
  AND rc.review_count >= 50
ORDER BY rc.review_count DESC, l.review_scores_rating DESC
LIMIT 50;

-- 8. Do response behavior and instant booking correlate with stronger listing performance?
WITH review_counts AS (
    SELECT listing_id, COUNT(*) AS review_count
    FROM reviews
    GROUP BY listing_id
)
SELECT
    COALESCE(l.host_response_time, 'Unknown') AS host_response_time,
    l.instant_bookable,
    COUNT(*) AS listings,
    ROUND(AVG(l.host_response_rate), 2) AS avg_response_rate,
    ROUND(AVG(l.host_acceptance_rate), 2) AS avg_acceptance_rate,
    ROUND(AVG(l.review_scores_rating), 2) AS avg_rating,
    ROUND(AVG(COALESCE(rc.review_count, 0)), 2) AS avg_reviews_per_listing,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.price))::numeric, 2) AS median_price
FROM listings l
LEFT JOIN review_counts rc ON rc.listing_id = l.listing_id
GROUP BY COALESCE(l.host_response_time, 'Unknown'), l.instant_bookable
ORDER BY avg_reviews_per_listing DESC, listings DESC;
