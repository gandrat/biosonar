# 0. Setup and Packages -----

# install.packages(c("DBI", "RPostgres", "dplyr", "ggplot2", "forcats"))

library(DBI)
library(RPostgres)
library(dplyr)
library(ggplot2)
library(forcats)


# 1. Database Connection -----

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


# 2. Bar plot taxon----------

## 2.1 Query and Aggregate Data (Sightings + Detections) -----

# Fetch Cetacea records from both tables joined with taxonomic info
sql_records <- "
  SELECT 
    sp.ordem,
    sp.subordem,
    sp.familia,
    'Avistagem (Visual)' AS record_type
  FROM public.sightings s
  INNER JOIN public.taxon sp ON s.taxon = sp.taxon
  
  UNION ALL

  SELECT 
    sp.ordem,
    sp.subordem,
    sp.familia,
    'Detecção (Acústica)' AS record_type
  FROM public.detections d
  INNER JOIN public.taxon sp ON d.taxon = sp.taxon
  ;
"

records_raw <- dbGetQuery(con, sql_records)

## 2.2. Prepare Data for Plotting -----

plot_data <- records_raw |> 
  # Clean or standardize 'Indefinido' labels if needed
  mutate(
    subordem = ifelse(subordem == "Indefinido", "Subordem Indefinida", subordem),
    familia = ifelse(familia == "Indefinido", "Família Indefinida", familia),
    suborder_family = paste(subordem, "-", familia)
  ) |> 
  count(subordem, familia, suborder_family, record_type, name = "total_records")


## 2.3. Option B: Single Axis Combined Label (Suborder - Family) -----

plot_combined <- ggplot(
  data = plot_data,
  aes(
    x = fct_reorder(suborder_family, total_records, .fun = sum),
    y = total_records,
    fill = record_type
  )
) +
  geom_col(position = position_dodge(preserve = "single"), width = 0.7) +
  geom_text(
    aes(label = total_records),
    position = position_dodge(width = 0.7),
    hjust = -0.2,
    size = 3.5
  ) +
  coord_flip() +
  scale_fill_manual(
    values = c(
      "Avistagem (Visual)" = "#1f78b4",
      "Detecção (Acústica)" = "#ff7f00"
    )
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    x = "Táxon",
    y = "Número de Registros",
    fill = "Tipo de Registro"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank()
  )

print(plot_combined)


## 2.5. Export High-Resolution Plot for TCC -----
ggsave(
  filename = "figures/avistagens_deteccao_taxon.jpg",
  plot = plot_combined,
  width = 17,
  height = 12,
  units = "cm",
  dpi = 300
)




# Extract just the date from the 'time' column and count occurrences
navp_daily <- navp |> 
  mutate(day = as.Date(time)) |> 
  count(day, name = "total_points")


# 3. Effort -----

navt<-st_read(con, "navigation_tracks")
navt<-navt%>%mutate(distance=as.numeric(st_length(geom))/1000)
plot_daily_points <- ggplot(data = navt, aes(x = day, y = distance)) +
  geom_col(fill = "#1f78b4", width = 0.7) + 
  
  # Format the X axis to show dates cleanly (e.g., "18 Apr")
  scale_x_date(date_labels = "%m-%Y", date_breaks = "1 month") +
  
  # Ensure the Y axis starts exactly at 0 and adds a little space at the top
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  
  labs(
    x = 'Data',
    y = "Distância (km)"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1) # Tilts date labels for better fit
  )

print(plot_daily_points)

ggsave(
  filename = "figures/esforco_data.jpg",
  plot = plot_daily_points,
  width = 17,
  height = 10,
  units = "cm",
  dpi = 300
)
