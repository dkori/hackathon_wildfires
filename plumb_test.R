library(plumber)
library(sf)
library(httr)
library(dplyr)
library(leaflet)
library(tigris)
# ca_shapefile<-states(cb=TRUE)%>%
#   filter(NAME == "California")%>%
#   st_transform("+init=EPSG:4326")
# current_fires<-read_sf(unzip("wildfire_Perimeters-shp.zip",files="Public_NIFS_Perimeters.shp"),
#                        crs="+init=EPSG:4326")%>%
#   st_join(ca_shapefile,
#           left=FALSE)%>%
#   st_make_valid()%>%
#   select(geometry)%>%
#   slice(1:30)%>%
#   # create an ID column for each wildfire
#   mutate(fire_id = n())

rest <- plumb("api.R")
rest$run(port=8000)