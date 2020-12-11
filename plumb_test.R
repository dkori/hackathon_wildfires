library(plumber)
library(sf)
library(httr)
library(dplyr)
library(leaflet)
library(tigris)
# wildfire data url, out how to read from remote later: https://opendata.arcgis.com/datasets/f72ebe741e3b4f0db376b4e765728339_0.zip?outSR=%7B%22latestWkid%22%3A4326%2C%22wkid%22%3A4326%7D



ca_shapefile<-states(cb=TRUE)%>%
  filter(NAME == "California")%>%
  st_transform("+init=EPSG:4326")

current_fires<-read_sf(unzip("wildfire_Perimeters-shp.zip",files="Public_NIFS_Perimeters.shp"),
                       crs="+init=EPSG:4326")%>%
  st_join(ca_shapefile,
          left=FALSE)%>%
  st_make_valid()%>%
  select(geometry)%>%
  slice(1:30)%>%
  # create an ID column for each wildfire
  mutate(fire_id = n())


rest <- plumb("api.R")
rest$run(port=8010)

