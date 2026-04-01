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

# Get area of postal codes
plz_area_df <- plz |> 
  mutate(area_plz = st_area(geometry)) |> 
  st_drop_geometry()

intersections <- st_intersection(plz, wk) |> 
  mutate(area_intersection = st_area(geometry)) |>
  left_join(plz_area_df, by = join_by(postcode)) |> 
  arrange(postcode, desc(area_intersection)) |> 
  group_by(postcode) |> 
  mutate(prop_overlap = as.numeric(area_intersection / area_plz),
         prop_overlap = round(prop_overlap, digits = 3)) |> 
  filter(prop_overlap >= 0.001) |> # Precision: 0.1%
  mutate(overlap_rank = row_number(),
         status = if_else(overlap_rank == 1,
                          "Correctly assigned",
                          "Incorrectly assigned"),
         status = factor(status, levels = c("Incorrectly assigned",
                                            "Correctly assigned")))


# Get comparison graphs ---------------------------------------------------

p_plz <- plz |> 
  ggplot() +
  geom_sf() +
  labs(title = "Postal code geometries") +
  theme_minimal()

p_intersections <- intersections |> 
  ggplot(aes(fill = status)) +
  geom_sf() +
  labs(title = "Geometric intersections\nwith electoral districts",
       fill = "") +
  theme_minimal()

ggsave("figures/intersections.png", plot = p_plz + p_intersections)


# Remove geometric attributes ---------------------------------------------

tab_intersections <- intersections |> 
  st_drop_geometry() |> 
  mutate(intersection_id = paste(postcode, 
                                 formatC(WKR_NR, 
                                         width = 3, format = "d", flag = "0"), 
                                 sep = "_")) |> 
  select(intersection_id,
         plz = postcode,
         wkr_nr = WKR_NR,
         wkr_name = WKR_NAME,
         land_nr = LAND_NR,
         land_name = LAND_NAME,
         prop_overlap)

tab_best_match <- tab_intersections |> 
  group_by(plz) |> 
  slice_max(prop_overlap, with_ties = FALSE) |> 
  select(-c(intersection_id))


# Plot distribution of shared area ----------------------------------------

p_bar <-tab_intersections |> 
  group_by(plz) |> 
  summarize(n_intersecting_wk = n()) |> 
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

p_hist <- tab_intersections |> 
  arrange(plz, desc(prop_overlap)) |> 
  group_by(plz) |> 
  mutate(status = if_else(row_number() == 1,
                          "Matched",
                          "Unmatched"),
         status = factor(status, 
                         levels = c("Unmatched", "Matched"))) |> 
  ggplot(aes(x = prop_overlap, color = status, fill = status)) +
  geom_histogram(boundary = 0, binwidth = 0.05) +
  labs(x = "Shared area with postal code",
       y = "Number of geometric intersections") +
  scale_x_continuous(breaks = seq(0, 1, 0.1)) +
  labs(color = "",
       fill = "") +
  theme_minimal() 

ggsave("figures/hist_shared_area.png", plot = p_hist)


# Export final tables -----------------------------------------------------

write_csv(tab_intersections, "data/tab_intersections.csv")
write_csv(tab_best_match, "data/tab_best_match.csv")
