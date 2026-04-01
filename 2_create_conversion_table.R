# TASKS: 
#   - Harmonize geometries and compute intersections
#   - Calculate intersection areas and overlap shares
#   - Rank overlaps per postal code
#   - Select the district with the maximum overlap
#   - Export results as CSV tables and png figures
# -------------------------------------------------------------------------

library(dplyr)
library(ggplot2)
library(patchwork)
library(readr)
library(sf)

options(scipen=999)

# Load geodata ------------------------------------------------------------

plz <- "data-raw/yetz/postleitzahlen.geojson" |> 
  st_read() |> 
  st_transform(25832) |>  # Transform postal codes to UTM32 coordinate reference system
  st_make_valid() |> 
  group_by(postcode)  |> 
  summarise(geometry = st_union(geometry)) |>  # Merge 2 polygons for postcode 75378
  st_collection_extract("POLYGON")

wk  <- "data-raw/bundeswahlleiterin/btw25_geometrie_wahlkreise_vg250.shp" |> 
  st_read() |> 
  st_make_valid() |> 
  st_collection_extract("POLYGON")


# Get intersections -------------------------------------------------------

intersections <- st_intersection(plz, wk) |> 
  mutate(area_intersection = st_area(geometry)) |> 
  arrange(postcode, desc(area_intersection)) |> 
  group_by(postcode) |> 
  mutate(overlap_rank = row_number(),
         n_intersecting_wk = n(),
         keep = if_else(overlap_rank == 1,
                        "Correctly assigned",
                        "Incorrectly assigned"),
         keep = factor(keep, levels = c("Incorrectly assigned",
                                        "Correctly assigned")))


# Get comparison graphs ---------------------------------------------------

p_plz <- plz |> 
  ggplot() +
  geom_sf() +
  labs(title = "Postal code geometries") +
  theme_minimal()

p_intersections <- intersections |> 
  ggplot(aes(fill = keep)) +
  geom_sf() +
  labs(title = "Geometric intersections\nwith electoral districts") +
  labs(fill = "") +
  theme_minimal()

ggsave("figures/intersections.png", plot = p_plz + p_intersections)


# Get share of postal code covered ----------------------------------------

# Get area of postal codes
plz_area_df <- plz |> 
  mutate(area_plz = st_area(geometry)) |> 
  st_drop_geometry()

shared_area_df <- intersections |> 
  st_drop_geometry() |> 
  left_join(plz_area_df, by = join_by(postcode)) |> 
  group_by(postcode) |> 
  mutate(area_shared_with_wk = as.numeric(area_intersection / area_plz))


# Plot distribution of shared area ----------------------------------------

p_bar <- shared_area_df |> 
  group_by(postcode) |> 
  summarize(n_intersecting_wk = first(n_intersecting_wk)) |> 
  group_by(n_intersecting_wk) |> 
  summarize(n = n()) |> 
  mutate(pct = (n / sum(n)) * 100,
         pct_str = sprintf("%.1f", pct)) |> 
  ggplot(aes(x = factor(n_intersecting_wk), 
             y = pct,
             label = pct_str)) +
  geom_col() +
  geom_text(vjust = -0.5) +
  labs(x = "Number of intersecting electoral districts per postal code",
       y = "Percent (%)") + 
  theme_minimal()

ggsave("figures/n_intersecting_wk.png", plot = p_bar)

p_hist <- shared_area_df |> 
  ggplot(aes(x = area_shared_with_wk)) +
  geom_histogram(boundary = 0, binwidth = 0.05) +
  labs(x = "Shared area with postal code",
       y = "Number of geometric intersections") +
  scale_x_continuous(breaks = seq(0, 1, 0.1)) +
  theme_minimal() 

ggsave("figures/hist_shared_area.png", plot = p_hist)


# Export final tables -----------------------------------------------------

tab_intersections <- shared_area_df |> 
  mutate(intersection_id = paste(postcode, WKR_NR, sep = "_")) |> 
  select(intersection_id,
         plz = postcode,
         wkr_nr = WKR_NR,
         wkr_name = WKR_NAME,
         land_nr = LAND_NR,
         land_name = LAND_NAME,
         prop_overlap = area_shared_with_wk)

write_csv(tab_intersections, "data/tab_intersections.csv")

tab_best_match <- shared_area_df |> 
  group_by(postcode) |> 
  slice_max(area_shared_with_wk, with_ties = FALSE) |> 
  select(plz = postcode,
         wkr_nr = WKR_NR,
         wkr_name = WKR_NAME,
         land_nr = LAND_NR,
         land_name = LAND_NAME)

write_csv(tab_best_match, "data/tab_best_match.csv")
