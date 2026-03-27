# TASKS: 
#   - Download and decompress shapes of german postcode areas from yetz (GitHub)
#   - Download and decompress shapes of electoral districts from 
#     Bundeswahlleitering
# -------------------------------------------------------------------------

library(brotli) # Decompress Brotli files
library(httr2)  # Download files

# Postal codes ------------------------------------------------------------

# Source: 
# yetz (2026). postleitzahlen. Release: 2026.02. 
# https://github.com/yetzt/postleitzahlen/releases/tag/2026.02

yetz_url <- "https://github.com/yetzt/postleitzahlen/releases/download/2026.02/postleitzahlen.geojson.br"
yetz_br_file <- tempfile()
yetz_geojson_file <- "data-raw/yetz/postleitzahlen.geojson"

# Download BR file
request(yetz_url) |>
  req_perform(path = yetz_br_file)

# Decompress and save GEOJSON file
yetz_br_file |> 
  readBin(raw(), file.info(yetz_br_file)$size) |> 
  brotli_decompress() |> 
  writeBin(yetz_geojson_file)


# Electoral districts -----------------------------------------------------

# Source:
# Bundeswahlleiterin (2025). Bundestagswahl 2025: Karte der Wahlkreise zum Download. 
# https://www.bundeswahlleiterin.de/bundestagswahlen/2025/wahlkreiseinteilung/downloads.html

bwl_url <- "https://www.bundeswahlleiterin.de/dam/jcr/b3656fdd-eb0c-4721-ba02-9e7fdf558475/btw25_geometrie_wahlkreise_vg250_shp.zip"
bwl_zip_file <- tempfile()
bwl_dir <- "data-raw/bundeswahlleiterin/"

# Download ZIP file
request(bwl_url) |>
  req_perform(path = bwl_zip_file)

# Decompress ZIP file and save SHP file
bwl_zip_file |> 
  unzip(exdir = bwl_dir)
