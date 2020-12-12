library(sf)
library(httr)
library(dplyr)
library(leaflet)
library(tigris)
library(htmlwidgets)
# wildfire data url, out how to read from remote later: https://opendata.arcgis.com/datasets/f72ebe741e3b4f0db376b4e765728339_0.zip?outSR=%7B%22latestWkid%22%3A4326%2C%22wkid%22%3A4326%7D
library(webshot)

# build user info into a point dataframe

ca_shapefile<-states(cb=TRUE)%>%
  filter(NAME == "California")%>%
  st_transform("+init=EPSG:4326")

current_fires<-read_sf(unzip("wildfire_Perimeters-shp.zip",files="Public_NIFS_Perimeters.shp"),
                       crs="+init=EPSG:4326")%>%
  st_join(ca_shapefile,
          left=FALSE)%>%
  st_make_valid()%>%
  select(geometry)%>%
  #slice(1:30)%>%
  # create an ID column for each wildfire
  mutate(fire_id = n())

# create a data frame explaining TTS for each severity zone: 

# manually enter user location for now, will be given by function later
lat<-37.3631653
lon<--122.0047421

check_wildfires<-function(lat,lon,return_map_image=FALSE){
  # create a spatial dataframe out of the user's location
  user_spatial<-data.frame(lat=lat,lon=lon)%>%
    st_as_sf(coords=c("lon","lat"),
             crs="+init=EPSG:4326")
  # draw buffers around the user location corresponding to the severity rings
  # most severe = within 10 miles (16 km)
  buffer_zones<-list()
  buffer_zones[["most_severe"]]<-user_spatial%>%
    st_transform(crs="+init=EPSG:2163")%>%
    st_buffer(dist=16000)%>%
    mutate(severity=1,
           tts = "You are in a high risk location by the wildfire. The wildfire is with 10 miles of your location. Evacuate immediately and follow the directions provided in the County evacuation order.")
  
  buffer_zones[["sev2"]]<-user_spatial%>%
    st_transform(crs="+init=EPSG:2163")%>%
    st_buffer(dist=48000)%>%
    mutate(severity=2,
           tts = "Evacuate as soon as possible or leave if you feel unsafe. Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Check your County social media for evacuation warnings and evacuation orders.")
  
  buffer_zones[["sev3"]]<-user_spatial%>%
    st_transform(crs="+init=EPSG:2163")%>%
    st_buffer(dist=80000)%>%
    mutate(severity=3,
           tts = "Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Have you evacuation kit prepared if you feel unsafe or an evacuation warning is issued. Check your County social media for updates.")
  
  # combine the buffer zones into a dataframe
  buffer_zone_frame<-buffer_zones%>%
    lapply(as.data.frame)%>%
    bind_rows()%>%
    st_as_sf(crs="+init=EPSG:2163")
  
  
  # join the buffer zones with the california wildfire data
  fire_match<-buffer_zone_frame%>%
    # try to join with wildfires
    st_join(st_transform(current_fires,crs="+init=EPSG:2163"),
            left=FALSE)%>%
    # make a normal dataframe, we don't need spacial data either
    as.data.frame()
  
  # check if fire_match has 0 rows, which would indicate sev 4
  if(nrow(fire_match)==0){
    fire_match<-data.frame(severity=4,
                           tts="There are no wildfires nearby")
  }else{
    fire_match<-fire_match%>%
      # sort by increasing the severity
      arrange(severity)%>%
      # just keep the first row
      slice(1)
  }
  
  # write results to a list
  if(fire_match$severity==4){
    result = list("severity" = 4,
                  "tts" = fire_match$tts)
  }else{
    # if a fire was matched, calculate the spatial information for the fire
    fire_geo_info<-current_fires%>%
      filter(fire_id == fire_match$fire_id)%>%
      st_cast("MULTILINESTRING")%>%
      as.data.frame()%>%
      select(geometry)%>%
      unlist()
    result= list("severity" = fire_match$severity,
                 "tts" = fire_match$tts,
                 "fire_geography" = fire_geo_info)
  }
  return(result)
}







######################################## TESTING CODE BELOW HERE
# first buffer layer
# start<-Sys.time()
# zone1<-current_fires_2163%>%
#   st_transform(crs=EPSG_2_UTM)%>%
#   st_buffer(dist=5000,nQuadSegs=5)%>%
#   # st_difference(current_fires_2163%>%
#   #                 st_transform(crs=EPSG_2_UTM))%>%
#   st_transform(crs="+init=EPSG:4326")
# end<-Sys.time()
# end-start
# 
# 
# # test fires in leaflet

user_spatial<-data.frame(lat=lat,lon=lon)%>%
  st_as_sf(coords=c("lon","lat"),
           crs="+init=EPSG:4326")
# draw buffers around the user location corresponding to the severity rings
# most severe = within 10 miles (16 km)
buffer_zones<-list()
buffer_zones[["most_severe"]]<-user_spatial%>%
  st_transform(crs="+init=EPSG:2163")%>%
  st_buffer(dist=16000)%>%
  mutate(severity=1,
         tts = "You are in a high risk location by the wildfire. The wildfire is with 10 miles of your location. Evacuate immediately and follow the directions provided in the County evacuation order.")

buffer_zones[["sev2"]]<-user_spatial%>%
  st_transform(crs="+init=EPSG:2163")%>%
  st_buffer(dist=48000)%>%
  mutate(severity=2,
         tts = "Evacuate as soon as possible or leave if you feel unsafe. Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Check your County social media for evacuation warnings and evacuation orders.")

buffer_zones[["sev3"]]<-user_spatial%>%
  st_transform(crs="+init=EPSG:2163")%>%
  st_buffer(dist=80000)%>%
  mutate(severity=3,
         tts = "Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Have you evacuation kit prepared if you feel unsafe or an evacuation warning is issued. Check your County social media for updates.")

# combine the buffer zones into a dataframe
buffer_zone_frame<-buffer_zones%>%
  lapply(as.data.frame)%>%
  bind_rows()%>%
  st_as_sf(crs="+init=EPSG:2163")

zone1<-buffer_zone_frame%>%slice(1)%>%st_transform(crs="+init=EPSG:4326")
zone2<-buffer_zone_frame%>%slice(2)%>%st_transform(crs="+init=EPSG:4326")
zone3<-buffer_zone_frame%>%slice(3)%>%st_transform(crs="+init=EPSG:4326")


# join the buffer zones with the california wildfire data
fire_match<-buffer_zone_frame%>%
  # try to join with wildfires
  st_join(st_transform(current_fires,crs="+init=EPSG:2163"),
          left=FALSE)%>%
  # make a normal dataframe, we don't need spacial data either
  as.data.frame()

# check if fire_match has 0 rows, which would indicate sev 4
if(nrow(fire_match)==0){
  fire_match<-data.frame(severity=4,
                         tts="There are no wildfires nearby")
}else{
  fire_match<-fire_match%>%
    # sort by increasing the severity
    arrange(severity)%>%
    # just keep the first row
    slice(1)
}

test2<-leaflet()%>%
  setView(lng=lon,lat,zoom=10)%>%
  addProviderTiles(providers$CartoDB.Positron)%>%
  # addPolygons(data=zone1,
  #             strok = FALSE,
  #             fillColor = "blue")%>%
  # addPolygons(data=current_fires%>%
  #               st_as_sf(crs="+init=EPSG:4326"),
  #             stroke=FALSE,
  #             fillColor = "red",
  #             fillOpacity=.3)%>%
  addCircleMarkers(data=user_spatial,
                   stroke=FALSE,
                   fillColor="green",
                   fillOpacity=1,
                   radius=5)%>%
  addPolygons(data=current_fires%>%
                st_simplify(dTolerance=.001)%>%
                filter(fire_id == fire_match$fire_id)%>%
                st_transform(crs="+init=EPSG:4326"),
              stroke=FALSE,
              fillColor = "red",
              fillOpacity=.5)#%>%
  # addPolygons(data=zone1,
  #             stroke=FALSE,
  #             fillColor = "grey",
  #             fillOpacity=.6)%>%
  # addPolygons(data=zone2,
  #             stroke=FALSE,
  #             fillColor="blue",
  #             fillOpacity=.3)%>%
  # addPolygons(data=zone3,
  #             stroke=FALSE,
  #             fillColor="green",
  #             fillOpacity=.3)

test2
test2
# addPolygons(data=most_severe%>%
#               st_transform(crs="+init=EPSG:4326"))
#   
# 
# 
# user_location<-function(lat=1,lon=2){
#   return(paste0("Your location is: ",lat,", ",lon))
# }
# 
htmlwidgets::saveWidget(test2,"test_save3.html")
fileName <- 'test_save2.html'
webshot("test_save2.html", file = "test_plot.png",
        cliprect = "viewport")

test_read<-readChar(fileName, file.info(fileName)$size)
test_read
mapview::mapshot(test2, file = "test_image.png")
test2
