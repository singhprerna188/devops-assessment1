-- 001_init.sql
-- Creates the core schema for the hotel booking assessment.

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    hotel_id      VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    checkin_date  DATE NOT NULL,
    checkout_date DATE NOT NULL,
    amount        NUMERIC(12, 2) NOT NULL,
    status        VARCHAR(50) NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS booking_events (
    id         BIGSERIAL PRIMARY KEY,
    booking_id UUID NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload    JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Indexing for the reporting query in Part 5:
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- The query filters on (city, created_at) and groups/aggregates on
-- (org_id, status). A composite B-tree index leading with the equality
-- predicate (city) and then the range predicate (created_at) lets Postgres
-- do a single index range scan instead of a full table scan, and the
-- trailing columns (org_id, status, amount) are included so the whole
-- query can be answered directly from the index (an index-only scan),
-- without a second trip to the heap for every matching row.
-- See README.md "Query Optimization" for the full explanation + EXPLAIN
-- ANALYZE before/after comparison.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- Supports the FK join / lookups from booking_events -> hotel_bookings.
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id
    ON booking_events (booking_id);
