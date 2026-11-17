# 1. Setup and Packages -----

# install.packages(c("readODS", "DBI", "RPostgres", "RSQLite", "janitor", "sf"))
library(DBI)
library(RPostgres)
library(dplyr)
library(sf)
library(lubridate)
library(ggplot2)

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

# 3. Load and Process CSV--------------
nav<-read.csv2('input_data/navigation/pts_navegacao.csv')

head(nav)

##Converting data types-----

navp<-nav%>%transmute(id=Indice,
                      time=dmy_hms(paste(Data,Hora_Dado)),
                      lon=Longitude,
                      lat=Latitude)

navp <- st_as_sf(
  navp,
  coords = c("lon", "lat"), # Specify X (Longitude) and Y (Latitude) columns
  crs = 4674,               # EPSG:4674 = SIRGAS 2000 (Use 4326 if data is WGS84)
  remove = FALSE            # Set to FALSE to keep 'lon' and 'lat' columns in the table
)
st_geometry(navp) <- "geom"
head(navp)

#4. Exporting to DB
st_write(
  obj = navp,
  dsn = con,
  layer = Id(schema = "public", table = "navigation_points"),
  delete_layer = TRUE # Overwrites the table if it already exists
)




# 1. Convert Points to Daily Tracks -----

# Assuming your spatial points object is named 'navp_sf'
nav_tracks <- navp |> 
  
  # 1.1 Sort by time (CRITICAL: prevents the line from zigzagging randomly)
  arrange(time) |> 
  
  # 1.2 Extract the date to create a grouping column
  mutate(day = as.Date(time)) |> 
  
  # 1.3 Group records by day
  group_by(day) |> 
  
  # 1.4 Filter out days with only 1 point (a LINESTRING requires at least 2 vertices)
  filter(n() > 1) |> 
  
  # 1.5 Combine points per day and cast them into a continuous line
  summarise(geom = st_cast(st_combine(geom), "LINESTRING"))


# 2. Check the Result -----

print(nav_tracks)

# Quickly visualize the result in R before exporting
plot(st_geometry(nav_tracks), col = "blue", main = "Daily Navigation Tracks")


# 3. Export to PostgreSQL/PostGIS (Optional) -----
dbExecute(con,'drop table if exists navigation_tracks cascade;')
st_write(nav_tracks, con, layer = "navigation_tracks", delete_layer = TRUE)


