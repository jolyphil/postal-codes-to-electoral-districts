# TASKS: 
#   - Load geodata
#   - Compute geometric intersections
#   - Find best electoral district to match each postal code
#   - Export conversion table as CSV file
# -------------------------------------------------------------------------

library(dplyr)
library(readr)
library(sf)


# Load geodata ------------------------------------------------------------

plz <- "data-raw/yetz/postleitzahlen.geojson" |> 
  st_read() |> 
  st_transform(25832) |>  # Transform postal codes to UTM32 coordinate reference system
  st_make_valid() |> 
  group_by(postcode)  |> 
  summarise(geometry = st_union(geometry)) |>  # Merge 2 polygons for postcode 75378
  st_collection_extract()

wk  <- "data-raw/bundeswahlleiterin/btw25_geometrie_wahlkreise_vg250.shp" |> 
  st_read() |> 
  st_make_valid() |> 
  st_collection_extract()


# Get intersections -------------------------------------------------------

intersections <- st_intersection(plz, wk)
intersections$area_intersection <- st_area(intersections)

tab_plz_wkr <- intersections  |> 
  group_by(postcode) |> 
  slice_max(area_intersection) |> # Keep electoral district with largest 
                                  # intersection. Note: Distribution of overlaps
                                  # is highly bimodal at 0 and 1. 
  st_drop_geometry() |> 
  select(plz = postcode,
         wkr_nr = WKR_NR,
         wkr_name = WKR_NAME, 
         land_nr = LAND_NR, 
         land_name = LAND_NAME)


# Export to CSV -----------------------------------------------------------

write_csv(tab_plz_wkr, "data/tab_plz_wkr.csv")

