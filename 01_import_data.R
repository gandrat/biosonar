# 1. Setup and Packages -----

# install.packages(c("readODS", "DBI", "RPostgres", "RSQLite", "janitor", "sf"))

library(readODS)
library(DBI)
library(RPostgres)
library(dplyr)
library(sf)
library(janitor)

# Load environment variables for database credentials
readRenviron(".env")

# 2. Database Connection -------------------------------------------------------
con <- dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("DB_HOST"),
  port = Sys.getenv("DB_PORT"),
  dbname = Sys.getenv("DB_NAME"),
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD")
)

# 3. Sightings -------------------------------------------------------
# Read the first sheet from the ODS file
sightings_raw <- read_ods(path = 'input_data/Modelo_Planilha_avistagem.ods', sheet = 1)

# Filter coordinates and fix column types for PostGIS compatibility
sightings_clean <- sightings_raw |> 
  filter(!is.na(longitude), !is.na(latitude)) |> 
  mutate(
    # Ensure coordinates are numeric
    longitude = as.numeric(longitude),
    latitude = as.numeric(latitude),
    
    # Convert time columns (hms/difftime) to character so st_write doesn't drop them
    across(where(~ inherits(.x, c("hms", "difftime"))), as.character),
    
    # Convert all-NA logical columns to character to fix field_types_idx error
    across(where(~ is.logical(.x) && all(is.na(.x))), as.character),
    
    # Convert any list columns (if present) to character
    across(where(is.list), as.character)
  )

# Convert data frame to sf points (SIRGAS 2000 = EPSG:4674 | WGS84 = EPSG:4326)
sightings_sf <- st_as_sf(
  sightings_clean,
  coords = c("longitude", "latitude"), # Longitude (X) always comes first, then Latitude (Y)
  crs = 4674,
  remove = FALSE # Keeps original 'lon' and 'lat' columns in the attribute table
)

plot(sightings_sf)

# Standardize geometry column name to 'geom' (PostGIS best practice)
st_geometry(sightings_sf) <- "geom"


## 3.1. Export Spatial Table to PostGIS -----

# Write sf object directly to PostGIS with point geometry
st_write(
  obj = sightings_sf,
  dsn = con,
  layer = Id(schema = "public", table = "sightings"), # Specify schema and table name
  delete_layer = TRUE # Overwrites table if it already exists (use append = TRUE to add rows)
)

# Create a spatial index (GIST) to optimize spatial queries and QGIS rendering
dbExecute(con, "CREATE INDEX IF NOT EXISTS sightings_geom_idx ON public.sightings USING GIST (geom);")

# Optional: Cast character time columns to native PostgreSQL TIME type
sql_cast_time <- "
  ALTER TABLE public.sightings 
  ALTER COLUMN hora_inicio_avistagem TYPE TIME USING hora_inicio_avistagem::time,
  ALTER COLUMN hora_final_avistagem TYPE TIME USING hora_final_avistagem::time,
  ALTER COLUMN hora_entrada_area_exclusao TYPE TIME USING hora_entrada_area_exclusao::time,
  ALTER COLUMN hora_menor_dist TYPE TIME USING hora_menor_dist::time,
  ALTER COLUMN hora_desligamento_fonte TYPE TIME USING hora_desligamento_fonte::time;
"
dbExecute(con, sql_cast_time)

# 4. Detections -------------------------------------------------------
# Read the first sheet from the ODS file
detections_raw <- read_ods(path = 'input_data/Modelo_Planilha_deteccao.ods', sheet = 1)

# Filter coordinates and fix column types for PostGIS compatibility
detections_clean <- detections_raw |> 
  filter(!is.na(longitude), !is.na(latitude)) |> 
  mutate(
    # Ensure coordinates are numeric
    longitude = as.numeric(longitude),
    latitude = as.numeric(latitude),
    
    # Convert time columns (hms/difftime) to character so st_write doesn't drop them
    across(where(~ inherits(.x, c("hms", "difftime"))), as.character),
    
    # Convert all-NA logical columns to character to fix field_types_idx error
    across(where(~ is.logical(.x) && all(is.na(.x))), as.character),
    
    # Convert any list columns (if present) to character
    across(where(is.list), as.character)
  )

# Convert data frame to sf points (SIRGAS 2000 = EPSG:4674 | WGS84 = EPSG:4326)
detections_sf <- st_as_sf(
  detections_clean,
  coords = c("longitude", "latitude"), # Longitude (X) always comes first, then Latitude (Y)
  crs = 4674,
  remove = FALSE # Keeps original 'lon' and 'lat' columns in the attribute table
)

plot(detections_sf)

# Standardize geometry column name to 'geom' (PostGIS best practice)
st_geometry(detections_sf) <- "geom"

## 4.1. Export Spatial Table to PostGIS -----

# Write sf object directly to PostGIS with point geometry
st_write(
  obj = detections_sf,
  dsn = con,
  layer = Id(schema = "public", table = "detections"), # Specify schema and table name
  delete_layer = TRUE # Overwrites table if it already exists (use append = TRUE to add rows)
)

# 5. Species and taxon names---------------
taxon <- read_ods(path = 'input_data/Modelo_Planilha_deteccao.ods', sheet = 2)%>%
  clean_names()

# Write species table to PostgreSQL
dbWriteTable(
  conn = con,
  name = Id(schema = "public", table = "taxon"),
  value = taxon,
  overwrite = TRUE,
  row.names = FALSE
)

# Set 'taxon' as Primary Key (required before linking a Foreign Key)
sql_add_pk <- "
  ALTER TABLE public.taxon 
  ADD CONSTRAINT taxon_pk PRIMARY KEY (taxon);
"
dbExecute(con, sql_add_pk)


# Check if any 'taxon' in 'sightings' is missing from 'species'
sql_check_orphans <- "
  SELECT DISTINCT s.taxon AS missing_in_species_table
  FROM public.sightings s
  LEFT JOIN public.taxon sp ON s.taxon = sp.taxon
  WHERE sp.taxon IS NULL AND s.taxon IS NOT NULL;
"
dbGetQuery(con, sql_check_orphans)

# 6. Create Constraints -----

# 3.1 Sightings: trim whitespace and set id_avist (TEXT) as Primary Key
dbExecute(con, "alter table public.sightings add column id serial primary key;")

# 3.2 Detections: trim whitespace and set id_detec (TEXT) as Primary Key
dbExecute(con, "UPDATE public.detections SET id_detec = TRIM(id_detec);")

dbExecute(con, "
  ALTER TABLE public.detections 
  ADD CONSTRAINT detections_pk PRIMARY KEY (id_detec);
")
# Link public.sightings(taxon) -> public.species(taxon)
sql_add_fk <- "
  ALTER TABLE public.sightings
  ADD CONSTRAINT sightings_species_fk
  FOREIGN KEY (taxon)
  REFERENCES public.taxon (taxon)
  ON UPDATE CASCADE
  ON DELETE RESTRICT;
"
dbExecute(con, sql_add_fk)

# Link public.detection(taxon) -> public.species(taxon)
sql_add_fk <- "
  ALTER TABLE public.detections
  ADD CONSTRAINT detections_species_fk
  FOREIGN KEY (taxon)
  REFERENCES public.taxon (taxon)
  ON UPDATE CASCADE
  ON DELETE RESTRICT;
"
dbExecute(con, sql_add_fk)

# 7. Create grid to SPUE----------
# Extract bounding box from the tracks to define the grid extent
sightings_utm <- st_transform(sightings, crs = 10857)

study_area_bbox <- st_bbox(sightings_utm)

# Create a 10km  grid (square polygons)
grid_base <- st_make_grid(
  study_area_bbox,
  cellsize = c(10000, 10000), 
  square = TRUE
)

# Convert to an sf object and assign a unique ID to each cell
grid_sf <- st_sf(
  id = 1:length(grid_base),
  geom = grid_base
)


grid_sf<-st_transform(grid_sf, crs=4674)

## Droping grids on land
mar <- read_sf(con, layer = "amazonia_azul")

grid_sf<-grid_sf%>%st_filter(mar, .predicate = st_intersects)

st_write(grid_sf, con, layer = "grid_10km", delete_layer = TRUE)

# Create a 1000m x 1000m grid (square polygons)
grid_base <- st_make_grid(
  study_area_bbox,
  cellsize = c(1000, 1000), 
  square = TRUE
)

# Convert to an sf object and assign a unique ID to each cell
grid_sf <- st_sf(
  id = 1:length(grid_base),
  geom = grid_base
)


grid_sf<-st_transform(grid_sf, crs=4674)

## Droping grids on land
grid_sf<-grid_sf%>%st_filter(mar, .predicate = st_intersects)

st_write(grid_sf, con, layer = "grid_1km", delete_layer = TRUE)

#8. Close database connection-------
dbDisconnect(con)
