-- 2. Create a view to calculate the total effort (in kilometers) per grid cell
CREATE table grid_10km_effort AS
SELECT 
    g.id,
    
    -- ST_Intersection cuts the tracks exactly at the grid cell boundaries.
    -- Casting to ::geography forces PostGIS to calculate the true metric length 
    -- over the GRS80 ellipsoid (SIRGAS 2000), regardless of the EPSG:4674 projection.
    -- Finally, dividing by 1000 converts meters to kilometers.
    COALESCE(
        SUM(ST_Length(ST_Intersection(t.geom, g.geom)::geography)) / 1000.0, 
        0
    ) AS total_effort_km,
    
    g.geom
FROM 
    grid_10km g
JOIN 
    navigation_tracks t 
    ON ST_Intersects(g.geom, t.geom)
GROUP BY 
    g.id, 
    g.geom;
	
	
-- Create the final analysis table integrating effort, sightings, and detections
CREATE view grid_10km_analysis AS

-- 1. CTE to count sightings per grid cell
WITH count_sightings AS (
    SELECT 
        g.id, 
        COUNT(s.*) AS total_sightings
    FROM 
        grid_10km_effort g
    JOIN 
        sightings s 
        ON ST_Intersects(g.geom, s.geom)
    -- If you need to filter only cetaceans here, add the JOIN with the species table:
    -- JOIN species sp ON s.taxon = sp.taxon WHERE sp.ordem = 'Cetacea'
    GROUP BY 
        g.id
),

-- 2. CTE to count acoustic detections per grid cell
count_detections AS (
    SELECT 
        g.id, 
        COUNT(d.*) AS total_detections
    FROM 
        grid_10km_effort g
    JOIN 
        detections d 
        ON ST_Intersects(g.geom, d.geom)
    GROUP BY 
        g.id
)

-- 3. Main query combining effort with the aggregated counts
SELECT 
    g.id,
    g.total_effort_km,
    
    -- Replace NULL with 0 for cells without sightings/detections
    COALESCE(s.total_sightings, 0) AS total_sightings,
    COALESCE(d.total_detections, 0) AS total_detections,
    
    -- Calculate Sightings Per Unit Effort (SPUE)
    -- Uses NULLIF to prevent division by zero, though your grid_10km_effort 
    -- table shouldn't have 0 effort due to the INNER JOIN in your previous step
    COALESCE(s.total_sightings, 0) / NULLIF(g.total_effort_km, 0) AS sightings_per_km,
    
    -- Calculate Detections Per Unit Effort (DPUE)
    COALESCE(d.total_detections, 0) / NULLIF(g.total_effort_km, 0) AS detections_per_km,
    
    g.geom
FROM 
    grid_10km_effort g
LEFT JOIN 
    count_sightings s 
    ON g.id = s.id
LEFT JOIN 
    count_detections d 
    ON g.id = d.id;
