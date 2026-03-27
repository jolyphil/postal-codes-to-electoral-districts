# postal-codes-to-electoral-districts

## Goal

Produce a reproducible conversion table linking German postal codes (Postleitzahl / PLZ) to Bundestag electoral districts (Wahlkreise) for the 2025 federal election.

The output is a CSV mapping each PLZ to the electoral district with the largest area overlap.


## Data sources

**Postal-code geometries (GeoJSON, Brotli-compressed):** 

* yetz (2026). _postleitzahlen_. Release: 2026.02. https://github.com/yetzt/postleitzahlen/releases/tag/2026.02


**Electoral district geometries (shapefile ZIP)"**

* Bundeswahlleiterin (2025). _Bundestagswahl 2025: Karte der Wahlkreise zum Download_. Shapefile (SHP). Geometrie der Wahlkreise im Koordinatensystem UTM32 (nicht generalisiert). https://www.bundeswahlleiterin.de/bundestagswahlen/2025/wahlkreiseinteilung/downloads.html


## Output

Final conversion table is written to: [data/tab_plz_wkr.csv](data/tab_plz_wkr.csv).

**Columns:**

* `plz` — postal code
* `wkr_nr` — electoral district number
* `wkr_name` — electoral district name
* `land_nr` — federal state number
* `land_name` — federal state name


## System prerequisites

* R >= 4.1
* System libraries for sf: GDAL, GEOS, PROJ (install via your OS package manager)
* Internet connection to download data sources


## R packages required

* brotli
* dplyr
* httr2
* sf
* readr
