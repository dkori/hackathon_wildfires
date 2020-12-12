# api.R
library(plumber)
library(sf)
library(httr)
library(dplyr)
library(leaflet)
library(tigris)
library(htmlwidgets)
library(devtools)
remotes::install_github("r-spatial/mapview",upgrade="never")
library(mapview)
#set path variable for pandocs
Sys.setenv(RSTUDIO_PANDOC="/opt/pandoc")
#print(rmarkdown::pandoc_available())
ca_shapefile<-states(cb=TRUE)%>%
  filter(NAME == "California")%>%
  st_transform("+init=EPSG:4326")
# current_fires<-read_sf(unzip("wildfire_Perimeters-shp.zip",files="Public_NIFS_Perimeters.shp"),
#                        crs="+init=EPSG:4326")%>%
current_fires<-read_sf("Public_NIFS_Perimeters.shp",
                       crs="+init=EPSG:4326")%>%
  st_join(ca_shapefile,
          left=FALSE)%>%
  st_make_valid()%>%
  select(geometry)%>%
  #slice(1:30)%>%
  # create an ID column for each wildfire
  mutate(fire_id = n())#* @get /add
add <- function(x, y){
  return(as.numeric(x) + as.numeric(y))
}#* @get /add2
add2 <- function(x, y){ 
  list(result = as.numeric(x) + as.numeric(y))
}
#* @get /user_location
user_location<-function(lat=1,lon=2){
  return(paste0("Your location is: ",lat,", ",lon," ",Sys.time()))
}
#* @serializer unboxedJSON
#* @get /check_wildfire
check_wildfires<-function(lat,lon,return_map_image=FALSE,demo_map=TRUE){
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
                 "tts" = fire_match$tts#,
                 #"fire_geography" = fire_geo_info
                 )
  }
  return(result)
}

#* @serializer contentType list(type='image/png')
#* @get /map_wildfire
map_wildfire<-function(lat,lon,return_map_image=TRUE,demo_map=FALSE){
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
                 "tts" = fire_match$tts#,
                 #"fire_geography" = fire_geo_info
    )
  }
  
  if(return_map_image==TRUE# & fire_match$severity<4
  ){
    leaflet_map<-leaflet()%>%
      setView(lng=lon,lat,zoom=9)%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(data=current_fires%>%
                    st_simplify(dTolerance=.001)%>%
                    filter(fire_id == fire_match$fire_id)%>%
                    st_transform(crs="+init=EPSG:4326"),
                  stroke=FALSE,
                  fillColor = "red",
                  fillOpacity=.7)%>%
      addCircleMarkers(data=user_spatial,
                       stroke=FALSE,
                       fillColor="green",
                       fillOpacity=.5,
                       radius=8)
    if(demo_map==FALSE){
      # save the map
      # saveWidget(leaflet_map,"leaflet_map.html")
      mapview::mapshot(leaflet_map, file = "new_image.png")
      #result<-readBin("new_image.png",'raw',n = file.info("new_image.png")$size)
      return(readBin("new_image.png",'raw',n = file.info("new_image.png")$size))
    }else{
      # temp<-readBin("map_image.png",'raw',n = file.info("map_image.png")$size)
      # print(temp)
      #result<-readBin("map_image.png",'raw',n = file.info("map_image.png")$size)
      return(readBin("new_image.png",'raw',n = file.info("new_image.png")$size))
    }
    
  }
  return(result)
}

