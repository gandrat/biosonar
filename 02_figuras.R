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


# 2. Query and Aggregate Data (Sightings + Detections) -----

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

# Close connection after fetching data
dbDisconnect(db_con)


# 3. Prepare Data for Plotting -----

plot_data <- records_raw |> 
  # Clean or standardize 'Indefinido' labels if needed
  mutate(
    subordem = ifelse(subordem == "Indefinido", "Subordem Indefinida", subordem),
    familia = ifelse(familia == "Indefinido", "Família Indefinida", familia),
    suborder_family = paste(subordem, "-", familia)
  ) |> 
  count(subordem, familia, suborder_family, record_type, name = "total_records")


# 4. Option A: Grouped Bar Chart by Suborder and Family (Faceted) -----

plot_faceted <- ggplot(
  data = plot_data,
  aes(
    x = fct_reorder(familia, total_records, .fun = sum),
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
  facet_grid(subordem ~ ., scales = "free_y", space = "free_y") +
  coord_flip() +
  scale_fill_manual(
    values = c(
      "Avistagem (Visual)" = "#1f78b4",
      "Detecção (Acústica)" = "#ff7f00"
    )
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    x = "Família",
    y = "Número de Registros",
    fill = "Método de Registro"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    strip.text.y = element_text(face = "bold", angle = 0)
  )

print(plot_faceted)


# 5. Option B: Single Axis Combined Label (Suborder - Family) -----

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


# 6. Export High-Resolution Plot for TCC -----

ggsave(
  filename = "figures/fig_sightings_vs_detections_family.jpg",
  plot = plot_combined,
  width = 17,
  height = 12,
  units = "cm",
  dpi = 300
)
