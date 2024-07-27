
--------------------------------------------
------ DATA CLEANING -----------------------
--------------------------------------------

UPDATE public.sf_airbnb_listings
SET bathrooms = NULL
WHERE bathrooms = '';

UPDATE public.sf_airbnb_listings
SET bedrooms = NULL
WHERE bedrooms = '';

ALTER TABLE public.sf_airbnb_listings ALTER COLUMN bedrooms TYPE int USING bedrooms::int;

UPDATE public.sf_airbnb_listings
SET beds = NULL
WHERE beds = '';

ALTER TABLE public.sf_airbnb_listings ALTER COLUMN beds TYPE int USING beds::int;

UPDATE public.sf_airbnb_listings
SET beds = NULL
WHERE beds = '';

UPDATE public.sf_airbnb_listings 
SET 
	review_scores_rating = NULLIF(review_scores_rating, ''),
	review_scores_accuracy = NULLIF(review_scores_accuracy, ''),
	review_scores_cleanliness = NULLIF(review_scores_cleanliness, ''),
	review_scores_checkin = NULLIF(review_scores_checkin, ''),
	review_scores_communication = NULLIF(review_scores_communication, ''),
	review_scores_location = NULLIF(review_scores_location, ''),
	review_scores_value = NULLIF(review_scores_value, '');


ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_rating TYPE numeric USING review_scores_rating::numeric;
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_accuracy TYPE numeric USING review_scores_accuracy::numeric;
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_cleanliness TYPE numeric USING review_scores_cleanliness::numeric;
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_checkin TYPE numeric USING review_scores_checkin::numeric;
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_communication TYPE numeric USING review_scores_communication::numeric;
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_location TYPE numeric USING review_scores_location::numeric;
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN review_scores_value TYPE numeric USING review_scores_value::numeric;

UPDATE public.sf_airbnb_listings
SET host_response_rate = NULL
WHERE host_response_rate = 'N/A';

-- Update response_rate to remove the percentage sign and convert to numeric
UPDATE public.sf_airbnb_listings 
SET host_response_rate = NULLIF(REPLACE(host_response_rate, '%', ''), '')::numeric;

-- Alter the response_rate column to numeric type
ALTER TABLE public.sf_airbnb_listings ALTER COLUMN host_response_rate TYPE numeric USING host_response_rate::numeric;

UPDATE public.sf_airbnb_listings 
SET host_response_rate = host_response_rate / 100.0;


ALTER TABLE public.sf_airbnb_listings
DROP COLUMN neighbourhood;


UPDATE public.sf_airbnb_listings
SET host_acceptance_rate = NULL
WHERE host_acceptance_rate = 'N/A';

UPDATE public.sf_airbnb_listings 
SET host_acceptance_rate = NULLIF(REPLACE(host_acceptance_rate, '%', ''), '')::numeric;

ALTER TABLE public.sf_airbnb_listings ALTER COLUMN host_acceptance_rate TYPE numeric USING host_acceptance_rate::numeric;

UPDATE public.sf_airbnb_listings 
SET host_acceptance_rate = host_acceptance_rate / 100.0;

UPDATE public.sf_airbnb_listings 
SET host_is_superhost = NULL
WHERE host_is_superhost = '';

ALTER TABLE public.sf_airbnb_listings RENAME COLUMN neighbourhood_cleansed TO neighborhood;

--- ZIPCODES for geomapping in Tableau

CREATE TABLE public.neighborhood_zipcode_mapping (
    neighborhood VARCHAR(70),
    zip_code VARCHAR(10)
);

INSERT INTO public.neighborhood_zipcode_mapping (neighborhood, zip_code) VALUES
('Potrero Hill', '94107'),
('Presidio Heights', '94118'),
('Outer Richmond', '94121'),
('Twin Peaks', '94131'),
('Bernal Heights', '94110'),
('Crocker Amazon', '94112'),
('Pacific Heights', '94115'),
('South of Market', '94103'),
('Presidio', '94129'),
('Glen Park', '94131'),
('Parkside', '94116'),
('Golden Gate Park', '94118'),
('Castro/Upper Market', '94114'),
('Lakeshore', '94132'),
('Visitacion Valley', '94134'),
('Noe Valley', '94114'),
('Nob Hill', '94109'),
('West of Twin Peaks', '94127'),
('Bayview', '94124'),
('Downtown/Civic Center', '94111'),
('Diamond Heights', '94131'), 
('Inner Sunset', '94122'),
('Marina', '94123'),
('Ocean View', '94112'),
('Inner Richmond', '94118'),
('Russian Hill', '94109'), 
('Western Addition', '94115'),
('Seacliff', '94121'),
('Outer Sunset', '94122'),
('Haight Ashbury', '94117'),
('Financial District', '94111'),
('Excelsior', '94112'),
('Outer Mission', '94112'),
('Mission', '94110'),
('North Beach', '94133'),
('Chinatown', '94133');
-- Add all necessary mappings

ALTER TABLE public.sf_airbnb_listings
ADD COLUMN zip_code VARCHAR(10);

UPDATE public.sf_airbnb_listings l
SET zip_code = z.zip_code
FROM public.neighborhood_zipcode_mapping z
WHERE l.neighborhood = z.neighborhood;




-------------------------------------------------------------------------------------------------
----- EXPLORATORY ANALYSIS -----
-------------------------------------------------------------------------------------------------

SELECT COUNT(*)
FROM sf_airbnb_listings sal;

-- Which neighborhoods in San Francisco have the highest concentration of superhosts

SELECT 
neighborhood, COUNT(*) 
FROM sf_airbnb_listings sal
WHERE host_is_superhost = 't'
GROUP BY neighborhood
ORDER BY COUNT DESC;

-- How does price vary by neighborhood (Most to least expensive)

SELECT neighborhood, ROUND(AVG(price), 2) AS average_price
FROM sf_airbnb_listings sal 
WHERE price NOTNULL 
GROUP BY neighborhood 
ORDER BY average_price DESC;

-- How does price correlate with the number of bedrooms and bathrooms

SELECT bedrooms, bathrooms, ROUND(AVG(price), 2) AS average_price
FROM sf_airbnb_listings sal 
WHERE price NOTNULL AND bedrooms NOTNULL 
GROUP BY bedrooms, bathrooms 
ORDER BY bedrooms, bathrooms;

-- What is the relationship between availability and number of reviews

SELECT number_of_reviews, AVG(availability_30), AVG(availability_60), AVG(availability_90), AVG(availability_365)
FROM sf_airbnb_listings sal
WHERE number_of_reviews NOTNULL
GROUP BY number_of_reviews
ORDER BY number_of_reviews; -- no relationship between availability and number of reviews

-- Average review scores by room type

SELECT 
    room_type,
    AVG(review_scores_rating)
FROM 
    public.sf_airbnb_listings sal 
GROUP BY room_type;

-- Which neighborhoods have the highest and lowest average review scores for 'Entire home/apt' listings, and 
-- how do these scores compare to 'Private room' listings in the same neighborhoods?

CREATE TEMPORARY TABLE avg_review_scores_neighborhood AS
WITH AvgReviewScores AS (
    SELECT
        neighborhood,
        room_type,
        AVG(review_scores_rating) AS avg_review_score
    FROM
        public.sf_airbnb_listings sal 
    WHERE
        room_type IN ('Entire home/apt', 'Private room')
    GROUP BY
        neighborhood, room_type
)
SELECT
    a.neighborhood,
    a.room_type AS entire_home,
    a.avg_review_score AS avg_review_score_entire_home,
    b.room_type AS private_room,
    b.avg_review_score AS avg_review_score_private_room
FROM
    AvgReviewScores a
JOIN
    AvgReviewScores b ON a.neighborhood = b.neighborhood
WHERE
    a.room_type = 'Entire home/apt'
    AND b.room_type = 'Private room'
ORDER BY
    avg_review_score_entire_home DESC;
   
 SELECT * FROM avg_review_scores_neighborhood;
   

   
 ----------------------------------------------
  --- If one is looking to buy an airbnb property in San Francisco, what would the best neighborhood be?
 ----------------------------------------------
   

WITH MetricsByNeighborhood AS (
    SELECT
        neighborhood,
        AVG(review_scores_rating) AS avg_review_score,
        ROUND(AVG(price * (90 - availability_90)), 2) AS avg_revenue_90,
        ROUND((1 - AVG(availability_90) / 90.0) * 100, 2) AS occupancy_rate
    FROM
        public.sf_airbnb_listings
    WHERE
        room_type = 'Entire home/apt'
    GROUP BY
        neighborhood
    HAVING COUNT(*) >= 10
),
MinMaxValues AS (
    SELECT
        MIN(avg_review_score) AS min_review_score,
        MAX(avg_review_score) AS max_review_score,
        MIN(avg_revenue_90) AS min_revenue_90,
        MAX(avg_revenue_90) AS max_revenue_90,
        MIN(occupancy_rate) AS min_occupancy_rate,
        MAX(occupancy_rate) AS max_occupancy_rate
    FROM
        MetricsByNeighborhood
),
NormalizedData AS (
    SELECT
        a.neighborhood,
        (a.avg_review_score - mmv.min_review_score) / (mmv.max_review_score - mmv.min_review_score) AS norm_review_score,
        (a.avg_revenue_90 - mmv.min_revenue_90) / (mmv.max_revenue_90 - mmv.min_revenue_90) AS norm_revenue_90,
        (a.occupancy_rate - mmv.min_occupancy_rate) / (mmv.max_occupancy_rate - mmv.min_occupancy_rate) AS norm_occupancy_rate
    FROM
        MetricsByNeighborhood a,
        MinMaxValues mmv
)
SELECT
    d.neighborhood,
    norm_review_score,
    norm_revenue_90,
    norm_occupancy_rate,
    (0.5 * norm_revenue_90 +
     0.3 * norm_occupancy_rate +
     0.2 * norm_review_score) AS combined_score,
     p.median_price as median_home_price
FROM
    NormalizedData d
JOIN
    (SELECT neighborhood, median_price FROM public.median_sale_prices) p
ON d.neighborhood = p.neighborhood
ORDER BY
	combined_score desc
LIMIT 15;


 ----------------------------------------------
  --- Does being a superhost matter? I.e does revenue and ratings increase if you are a superhost?
 ----------------------------------------------

SELECT
	CASE WHEN host_is_superhost = 't' THEN 'Superhost' ELSE 'Not Superhost' END AS host_type,
    ROUND(AVG(price), 2) AS avg_listing_price,
    ROUND(AVG(price * (90 - availability_90)), 2) AS avg_revenue_90,
    ROUND((1 - AVG(availability_90) / 90.0) * 100, 2) AS occupancy_rate
FROM
    public.sf_airbnb_listings
WHERE
    host_is_superhost IS NOT NULL  
GROUP BY
    host_is_superhost;


WITH TopRatedHosts AS 
(SELECT 
    DISTINCT host_id,
    host_name,
    host_is_superhost,
    number_of_reviews,
    review_scores_rating
FROM public.sf_airbnb_listings sal 
WHERE review_scores_rating IS NOT NULL AND host_is_superhost IS NOT NULL AND number_of_reviews >= 10
ORDER BY review_scores_rating DESC 
LIMIT 100
)
SELECT 
    CASE WHEN host_is_superhost = 't' THEN 'Superhost' ELSE 'Not Superhost' END AS host_type, COUNT(*)
FROM TopRatedHosts
GROUP BY host_is_superhost;


----------------------------------------------
  --- How much do the top Airbnb earners make and how does it compare to the average?
  --- What metrics do they have that differentiate themselves from the average airbnb listing in San Francisco?
 ----------------------------------------------

CREATE TEMPORARY TABLE TopEarners AS (
    WITH RankedHosts AS (
        SELECT 
            host_id,
            host_name,
            listing_url,
            ROUND(price * (365 - availability_365), 2) AS annual_revenue,
            ROW_NUMBER() OVER (PARTITION BY host_id ORDER BY ROUND(price * (365 - availability_365), 2) DESC) AS rn
        FROM public.sf_airbnb_listings sal
    )
    SELECT 
        host_id,
        host_name,
        listing_url,
        annual_revenue
    FROM RankedHosts
    WHERE rn = 1
    ORDER BY annual_revenue DESC
    LIMIT 100
);

SELECT * FROM TopEarners;

-- Average revenue of a top 100 Airbnb listing compared to the average Airbnb listing in San Francisco
SELECT 
    ROUND(AVG(annual_revenue), 0) AS avg_annual_top100,
    ROUND((SELECT AVG(price * (365 - availability_365)) FROM sf_airbnb_listings sal), 0) AS avg_annual_revenue
FROM TopEarners;

-- Top earning Airbnb listings by neighborhood
SELECT  
    neighborhood, 
    COUNT(*) as num_listings
FROM sf_airbnb_listings sal 
WHERE listing_url IN (SELECT listing_url FROM TopEarners)
GROUP BY neighborhood
ORDER BY num_listings DESC;


-- Comparing listing size/accomdation of Top earners to the average airbnb listings
SELECT
    'Top 100 Earner' AS category,
    AVG(accommodates) AS num_accommodate,
    AVG(bedrooms) AS avg_bed,
    AVG(bathrooms) AS avg_bath
FROM sf_airbnb_listings sal 
WHERE listing_url IN (SELECT listing_url FROM TopEarners)
UNION ALL
SELECT
    'Average Airbnb Listing' AS category,
    AVG(accommodates) AS num_accommodate,
    AVG(bedrooms) AS avg_bed,
    AVG(bathrooms) AS avg_bath
FROM sf_airbnb_listings sal 
WHERE room_type = 'Entire home/apt';




