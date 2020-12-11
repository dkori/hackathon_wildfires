# hackathon_wildfires

api.R contains a function called check_wildfires that takes lat and lon as inputs, and returns: 
+ the severity of the user's situation based on proximity to fire
+ the TTS response for that severity
+ if they are higher than severity 4, the multilinestring coordinates of the fires near the user (which can hopefully be used to render the wildfire on an Alexa screen device if we can't figure out a way to send an image through the REST API) 

plumb_test.R executes the code to read in wildfire information for California. It currently reads a static file but should be easily adaptable to read the most up-to-date information [from the source](https://opendata.arcgis.com/datasets/f72ebe741e3b4f0db376b4e765728339_0.zip?outSR=%7B%22latestWkid%22%3A4326%2C%22wkid%22%3A4326%7D)

"development code.R" was my sandbox for developing the code

At present the rest API has been tested locally and runs correctly, but we **still need to figure out deployment**. 

**Needed additions for MVP**
+ compute direction of wildfire from user. The script already identifies the individual fires that are in the severity range of the user, so this is just a matter of taking the centroid of those shapes (or some other central measure), figuring out what direction to assign to the fire based on lat/lon difference from user location, and building that into the TTS
+ find a way to deploy the REST API so the Alexa Skill can call it
+ figure out export format for multilinestring that are readable by Alexa

**hopeful extensions**
+ creating a map showing the fire(s) closest to the user and exporting it as a png image locally is trivial, but delivering it through the API could be tricky. Open to any ideas here.
