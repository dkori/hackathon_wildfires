# Hackathon - Wildfires
This is the back end for our hackathon entry - an Alexa auto skill that gives customers pertinent information about nearby wildfires to stay safe and have peace of mind. 

[Wildfire data](https://gis.data.ca.gov/datasets/f72ebe741e3b4f0db376b4e765728339_0)

[FEMA Shelter data](https://gis.fema.gov/arcgis/rest/services/NSS/OpenShelters/MapServer)

We use a docker container running R to deploy REST APIs that our Alexa skill calls to retrieve the correct information for the customer. The container deploys the **following APIs**:
+ check_wildfires - endpoints: lat, lon. This API places the user into one of four risk zones based on proximity to wildfires, delivers TTS instructions based on the severity, and informs the user of the direction from the nearest fire. The response in JSON format contains the appropriate TTS response, as well the severity and direction to allow app-side overwriting of the TTS response for quick fixes. 
+ map_wildfires - endpoints: lat, lon, demo_map. Returns a png image of a map of all fires within the user's risk zone. Set demo_map=FALSE to make this feature live
+ find_shelters - endpoints: lat, lon. Returns the name, address, and status of the nearest shelter to the user's location. 

api.R contains the functions that generate the REST APIs

plumb_test.R executes the code for local testing pre-docker

"development code.R" was my sandbox for developing the code

