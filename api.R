# api.R
library(plumber)
library(sf)
library(httr)
library(dplyr)
library(leaflet)
library(tigris)
library(htmlwidgets)
library(devtools)
library(tidyr)
#remotes::install_github("r-spatial/mapview",upgrade="never")
library(mapview)
options(tigris_use_cache = TRUE)
#set path variable for pandocs
Sys.setenv(RSTUDIO_PANDOC="/opt/pandoc")
#print(rmarkdown::pandoc_available())

# download and save the shapefile for ca
# ca_shapefile<-states(cb=TRUE)%>%
#   filter(NAME == "California")%>%
#   st_transform("+init=EPSG:4326")
# save(ca_shapefile,file = "ca_shape.Rdata")

load("ca_shape.Rdata")

# download latest available wildfire info
wildfire_zip_url<-"https://opendata.arcgis.com/datasets/f72ebe741e3b4f0db376b4e765728339_0.zip?outSR=%7B%22latestWkid%22%3A4326%2C%22wkid%22%3A4326%7D"
# create tempfile
temp <- tempfile()
#store shelter zip in tempfile
download.file(wildfire_zip_url,temp)
# store the names of all the files in the zip
file_names<-unzip(temp,list=TRUE)["Name"]
#unzip all files
temp2<-unzip(temp,files = file_names$Name)

unlink(temp)


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
  mutate(fire_id = row_number())


# download shelters
shelter_zip_url<-"https://opendata.arcgis.com/datasets/d000037396514f70a2ba3683e037caee_0.zip"
# create tempfile
temp <- tempfile()
#store shelter zip in tempfile
download.file(shelter_zip_url,temp)
#unzip all files
temp2<-unzip(temp,files = c("National_Shelter_System_-_Open_Shelters.shx",
                            "National_Shelter_System_-_Open_Shelters.dbf",
                            "National_Shelter_System_-_Open_Shelters.shp",
                            "National_Shelter_System_-_Open_Shelters.cpg",
                            "National_Shelter_System_-_Open_Shelters.prj"))

shelter_data <- read_sf("National_Shelter_System_-_Open_Shelters.shp")%>%
  st_transform(crs="+init=EPSG:2163")

unlink(temp)

#* @get /add
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
check_wildfires<-function(lat,lon){
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
           tts = "You are in a risk/dangerous location by the wildfire. The wildfire is located %direction% of your location. Evacuate immediately and follow the directions provided in the County evacuation order")

  buffer_zones[["sev2"]]<-user_spatial%>%
    st_transform(crs="+init=EPSG:2163")%>%
    st_buffer(dist=48000)%>%
    mutate(severity=2,
           tts = "The wildfire is less than 30 miles away, %direction% of your location. Evacuate as soon as possible if you feel unsafe. Sensitive groups to air quality might want to avoid prolonged or heavy exertion outside. Check your County social media for evacuation warnings and evacuation orders.")

  buffer_zones[["sev3"]]<-user_spatial%>%
    st_transform(crs="+init=EPSG:2163")%>%
    st_buffer(dist=80000)%>%
    mutate(severity=3,
           tts = "There is a wild fire less than 50 miles away, %direction% of your location. Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Have you evacuation kit prepared if you feel unsafe or an evacuation warning is issued. Check your County social media for updates.")

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
    severe_match<-data.frame(severity=4,
                           tts="There are no wildfires nearby")
  }else{
    severe_match<-fire_match%>%
      # sort by increasing the severity
      arrange(severity)%>%
      # just keep the first row
      slice(1)
  }

  # write results to a list
  if(severe_match$severity==4){
    result = list("severity" = 4,
                  "tts" = severe_match$tts)
  }else{
    # if a fire was matched, calculate the direction of fire from user
    # first find the nearest fire to user
    nearest_fire_id<-user_spatial%>%
      st_join(current_fires%>%
                filter(fire_id%in%fire_match$fire_id),
              join = st_nearest_feature)%>%
      as.data.frame()%>%
      select(fire_id)%>%
      unlist()
    # find the centroid of the nearest fire
    nearest_fire_centroid<-current_fires%>%
      filter(fire_id==nearest_fire_id)%>%
      st_centroid()%>%
      as.data.frame()%>%
      # separate lat and lon
      mutate(geometry = gsub("c\\(","",geometry),
             geometry = gsub("\\)",'',geometry),
             lon_fire = gsub(", .*","",geometry)%>%as.numeric(),
             lat_fire = gsub('.*, ',"",geometry)%>%as.numeric(),
             join="join")%>%
      select(-geometry)
    # calculate direction from user
    nearest_fire_direction<-user_spatial%>%
      as.data.frame()%>%
      # separate lat and lon
      mutate(geometry = gsub("c\\(","",geometry),
             geometry = gsub("\\)",'',geometry),
             lon_user = gsub(", .*","",geometry)%>%as.numeric(),
             lat_user = gsub('.*, ',"",geometry)%>%as.numeric(),
             join="join")%>%
      select(-geometry)%>%
      # join in nearest fire centroid
      inner_join(nearest_fire_centroid)%>%
      # calculate cardinal directions
      mutate(north = lat_fire - lat_user,
             south = lat_user - lat_fire,
             east = lon_fire - lon_user,
             west = lon_user - lon_fire)%>%
      select(north,south,east,west)%>%
      gather()%>%
      arrange(desc(value))%>%
      slice(1)%>%
      select(key)%>%
      unlist()
      
    result= list("severity" = severe_match$severity,
                 "tts" = gsub('%direction%',nearest_fire_direction,severe_match$tts)
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
    severe_match<-data.frame(severity=4,
                           tts="There are no wildfires nearby")
  }else{
    severe_match<-fire_match%>%
      # sort by increasing the severity
      arrange(severity)%>%
      # just keep the first row
      slice(1)
  }
  

  if(return_map_image==TRUE & severe_match$severity<4){
    leaflet_map<-leaflet()%>%
      # set the zoom
      setView(lng=lon,lat,zoom=9)%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      # add any fires within the severity range
      addPolygons(data=current_fires%>%
                    st_simplify(dTolerance=.001)%>%
                    filter(fire_id%in%fire_match[fire_match$severity<=severe_match$severity,]$fire_id)%>%
                    st_transform(crs="+init=EPSG:4326"),
                  stroke=FALSE,
                  fillColor = "red",
                  fillOpacity=.5)%>%
      # add teh user's location
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

#* @get /find_shelter
find_shelter<-function(lat,lon){
  # make user coordinates into spatial frame, 2163
  user_spatial<-data.frame(lat=lat,lon=lon)%>%
    st_as_sf(coords=c("lon","lat"),
             crs="+init=EPSG:2163")
  # find the nearest shelter
  nearest_shelter<-user_spatial%>%
    st_join(shelter_data,
          join = st_nearest_feature)%>%
    # make dataframe
    as.data.frame()%>%
    # select relevant columns
    select(SHELTER_NA, ADDRESS, CITY, STATE, ZIP, SHELTER_ST)
  return(nearest_shelter)
  
}