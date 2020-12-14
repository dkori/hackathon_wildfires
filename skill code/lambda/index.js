/* *
 * This sample demonstrates handling intents from an Alexa skill using the Alexa Skills Kit SDK (v2).
 * Please visit https://alexa.design/cookbook for additional examples on implementing slots, dialog management,
 * session persistence, api calls, and more.
 * */
const Alexa = require('ask-sdk-core');
const AWS = require('aws-sdk');
const ddbAdapter = require('ask-sdk-dynamodb-persistence-adapter');
const axios = require('axios');
const utf8 = require('utf8');

const baseURL = "http://ec2-13-52-254-163.us-west-1.compute.amazonaws.com";

const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
    },
    handle(handlerInput) {
        const speakOutput = 'Welcome to the Alexa Wildfire Experience, you can ask: where is the fire';

        var persistentAttributes = getPersistentAttributes(handlerInput)
        console.log(JSON.stringify(persistentAttributes))
        
        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

const WhereIsFireHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'WhereIsFire';
    },
    async handle(handlerInput) {
        console.log("In WhereIsFireHandler");
        const directions = ["north","east", "south", "west"];
        var location;
        
        try {
            location = await retrieveGeoObject(handlerInput);
            console.log("location: "+JSON.stringify(location));
        } catch (err) {
            location = null;
        }
        
        if (!location) {
            return handlerInput.responseBuilder
                .speak("Sorry, unable to retrieve your location. Please enable location or address access.")
                .withShouldEndSession(true)
                .getResponse();
        }
        
        var status = await getPersistentAttribute(handlerInput, "status") || "live";
        
        var direction = null;
        if (status === "live" && location) {
            console.log("Using live data");
            var data = await callBackend(location);    
            console.log("data: "+JSON.stringify(data));
            const json = JSON.parse(data);
            status = json.severity;
            console.log("severity: "+status);
            if (json.direction) {
                direction = json.direction;
            }
        } else {
            direction = directions[Math.floor(Math.random() * directions.length)];
        }
        var speakOutput;
        var imageURL = "https://miro.medium.com/max/900/0*iMkCQLHxXw9gLWjD.";//getPictureURL(location);
        
        console.log("image: "+imageURL);
        
        switch(status) {
            case 4:
            case "safe":
                speakOutput = "There's no wildfires nearby.";
            break;
            case 3: 
            case "prepare":
                speakOutput = (direction ? "The wildfire is located "+direction+" from your location. " : "")+"Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Have your evacuation kit prepared if you feel unsafe or an evacuation warning is issued. Check your County social media for updates.";
            break;
            case 2: 
            case "leave":
                speakOutput = (direction ? "The wildfire is located "+direction+" from your location. " : "") + "Watch out for evacuation warnings or leave if you feel unsafe. Sensitive groups to air quality might want avoid prolonged or heavy exertion outside. Check your County social media for evacuation warnings and evacuation orders.";
            break;
            case 1: 
            case "evacuate":
                speakOutput = "You are in a risk location by the wildfire. "+(direction ? "The wildfire is located "+direction+" from your location. " : "")+"Evacuate immediately and follow the directions provided in the County evacuation order.";
            break;
            default:
                speakOutput = "Ooops, no valid status "+status;
        }
        
        return handlerInput.responseBuilder
            .speak(speakOutput)
            .withStandardCard("Wildfire Information", speakOutput, imageURL, imageURL)
            .withShouldEndSession(false)
            .getResponse();
    }
};

const SetStatusHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'SetStatus';
    },
    async handle(handlerInput) {
        console.log("In SetStatusHandler: "+JSON.stringify(handlerInput));
        
        var speakOutput;
        var newStatus = getSlotValue(handlerInput, "status");
        console.log("newStatus: "+newStatus);
        if (!newStatus) {
            speakOutput = "No valid status provided, options are: safe, prepare, leave, evacuate";
        } else {
            await setPersistentAttributes(handlerInput, {status: newStatus});
            console.log("set");
            speakOutput = "Status set to "+newStatus;
        }
        console.log("speak: "+speakOutput);
        return handlerInput.responseBuilder
            .speak(speakOutput)
            .withShouldEndSession(false)
            .getResponse();
    }
};

const GetWildfireShelterHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'GetWildfireShelter';
    },
    async handle(handlerInput) {
        console.log("In GetWildfireShelterHandler: "+JSON.stringify(handlerInput));
        
        var speakOutput = "Here is a list of shelters near you provided by FEMA: one, El Modena High School, located at 3920 Spring Street, ORANGE, California, 92869. By the way, you can ask me for directions.";
        // "There is no shelters near you at this moment"
        console.log("speak: "+speakOutput);
        return handlerInput.responseBuilder
            .speak(speakOutput)
            .withShouldEndSession(false)
            .withStandardCard("Wildfire Information", speakOutput)
            .getResponse();
    }
}

const TakeMeToWildfireShelterHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'TakeMeToWildfireShelter';
    },
    async handle(handlerInput) {
        console.log("In TakeMeToWildfireShelter: "+JSON.stringify(handlerInput));
        
        if (handlerInput && handlerInput.requestEnvelope && handlerInput.requestEnvelope.context && handlerInput.requestEnvelope.context.System && handlerInput.requestEnvelope.context.System.device && handlerInput.requestEnvelope.context.System.device.supportedInterfaces && handlerInput.requestEnvelope.context.System.device.supportedInterfaces.Geolocation) { 
                // device has navigation capabilities
        
            var speakOutput = "Navigation started";
            // "There is no shelters near you at this moment"
            console.log("speak: "+speakOutput);
            var res = handlerInput.responseBuilder
                .speak(speakOutput)
                .withShouldEndSession(true)
                .getResponse();
                
            res.directives = [
                        {
                            type: "Navigation.SetDestination",
                            destination: {
                                singleLineDisplayAddress: "shelter",
                                multipleLineDisplayAddress: "shelter",
                                name: "Shelter",
                                coordinate: {
                                    latitudeInDegrees: 33.78974233786115,
                                    longitudeInDegrees: -117.81273767438854
                                }
                            },
                            transportationMode: "DRIVING"
                        }];
            return res;
        } else {
            return handlerInput.responseBuilder
                .speak("Sorry, your device does not have navigation capabilites")
                .withShouldEndSession(true)
                .getResponse();
        }
    }
}


const HelpIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.HelpIntent';
    },
    handle(handlerInput) {
        const speakOutput = 'You can say: Where is fire';

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

const CancelAndStopIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && (Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.CancelIntent'
                || Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.StopIntent');
    },
    handle(handlerInput) {
        const speakOutput = 'Be safe!';

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .getResponse();
    }
};
/* *
 * FallbackIntent triggers when a customer says something that doesn’t map to any intents in your skill
 * It must also be defined in the language model (if the locale supports it)
 * This handler can be safely added but will be ingnored in locales that do not support it yet 
 * */
const FallbackIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.FallbackIntent';
    },
    handle(handlerInput) {
        const speakOutput = 'Sorry, I don\'t know about that. Please try again.';

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};
/* *
 * SessionEndedRequest notifies that a session was ended. This handler will be triggered when a currently open 
 * session is closed for one of the following reasons: 1) The user says "exit" or "quit". 2) The user does not 
 * respond or says something that does not match an intent defined in your voice model. 3) An error occurs 
 * */
const SessionEndedRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'SessionEndedRequest';
    },
    handle(handlerInput) {
        console.log(`~~~~ Session ended: ${JSON.stringify(handlerInput.requestEnvelope)}`);
        // Any cleanup logic goes here.
        return handlerInput.responseBuilder.getResponse(); // notice we send an empty response
    }
};
/* *
 * The intent reflector is used for interaction model testing and debugging.
 * It will simply repeat the intent the user said. You can create custom handlers for your intents 
 * by defining them above, then also adding them to the request handler chain below 
 * */
const IntentReflectorHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest';
    },
    handle(handlerInput) {
        const intentName = Alexa.getIntentName(handlerInput.requestEnvelope);
        const speakOutput = `You just triggered ${intentName}`;

        return handlerInput.responseBuilder
            .speak(speakOutput)
            //.reprompt('add a reprompt if you want to keep the session open for the user to respond')
            .getResponse();
    }
};
/**
 * Generic error handling to capture any syntax or routing errors. If you receive an error
 * stating the request handler chain is not found, you have not implemented a handler for
 * the intent being invoked or included it in the skill builder below 
 * */
const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        const speakOutput = 'Sorry, I had trouble doing what you asked. Please try again.';
        console.log(`~~~~ Error handled: ${JSON.stringify(error)}`);

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

/**
 * This handler acts as the entry point for your skill, routing all request and response
 * payloads to the handlers above. Make sure any new handlers or interceptors you've
 * defined are included below. The order matters - they're processed top to bottom 
 * */
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        WhereIsFireHandler,
        SetStatusHandler,
        GetWildfireShelterHandler,
        TakeMeToWildfireShelterHandler,
        HelpIntentHandler,
        CancelAndStopIntentHandler,
        FallbackIntentHandler,
        SessionEndedRequestHandler,
        IntentReflectorHandler)
    .addErrorHandlers(
        ErrorHandler)
    .withCustomUserAgent('sample/hello-world/v1.2')
    .withPersistenceAdapter(
        new ddbAdapter.DynamoDbPersistenceAdapter({
            tableName: process.env.DYNAMODB_PERSISTENCE_TABLE_NAME,
            createTable: false,
            dynamoDBClient: new AWS.DynamoDB({apiVersion: 'latest', region: process.env.DYNAMODB_PERSISTENCE_REGION})
        })
    )
    .lambda();
    
    
/**
 * Helper functions
 * */
 
 async function setPersistentAttributes(handlerInput, persists) {
    try {
        handlerInput.attributesManager.setPersistentAttributes(persists);
        await handlerInput.attributesManager.savePersistentAttributes();
        return true;
    } catch (err) {
        console.log("Error saving persistent attributes: "+JSON.stringify(err)+" with "+JSON.stringify(handlerInput));
        return false;
    }
}

async function setPersistentAttribute(handlerInput, name, value) {
    // trying persistent attributes
    try {
        var persists = await getPersistentAttributes(handlerInput);
        persists[name] = value;
        console.log("Updated persistent Attributes: "+JSON.stringify(persists));
        await setPersistentAttributes(handlerInput,persists)[name];
        return true;
    } catch (err) {
        console.log("Error saving persistent attributes: "+JSON.stringify(err));
        return false;
    }
}

async function getPersistentAttribute(handlerInput, name) {
    return (await getPersistentAttributes(handlerInput))[name];
}

async function getPersistentAttributes(handlerInput) {
    var persists = {}
    try {
        persists = await handlerInput.attributesManager.getPersistentAttributes() || {};
        console.log("Retrieved  persistent Attributes: "+JSON.stringify(persists));
    } catch (err) {
        console.log("Error retrieving persistent attributes: "+JSON.stringify(err));
    }
    return persists;
}

function getSlotValue(handlerInput, slotName) {
    const requestType = "intent";
    if (handlerInput &&
        handlerInput.requestEnvelope &&
        handlerInput.requestEnvelope.request &&
        handlerInput.requestEnvelope.request[requestType] &&
        handlerInput.requestEnvelope.request[requestType].slots &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName] &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority[0] &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority[0].values &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority[0].values[0] &&
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority[0].values[0].value && 
        handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority[0].values[0].value.name)
    {
        return handlerInput.requestEnvelope.request[requestType].slots[slotName].resolutions.resolutionsPerAuthority[0].values[0].value.name; 
    }
    return null;
}

async function getAddress(handlerInput) {
    const accessToken = handlerInput.requestEnvelope.context.System.apiAccessToken;
    const apiEndpoint = handlerInput.requestEnvelope.context.System.apiEndpoint
    const deviceId = handlerInput.requestEnvelope.context.System.device.deviceId;
    
    console.log("access token: "+accessToken);
    console.log("end point: "+apiEndpoint);
    console.log("device id: "+deviceId);
        
    return new Promise((resolve, reject) => {
            request(
                apiEndpoint+"/v1/devices/"+deviceId+"/settings/address", 
                { 
                    headers: {
                        'Authorization': 'Bearer '+accessToken,
                        'Accept': 'application/json'
                    } 
                }, 
                (err, res, body) => {
                    console.log(JSON.stringify(res));
                    if (err || (!res) || (res.statusCode !== 200)) { 
                        console.log("err:"+JSON.stringify(err));
                        
                        reject(); 
                        //resolve({ coordinate: { latitudeInDegrees: 37.25219377387704, longitudeInDegrees: -121.75872714133992 } });
                    } else {
                        const address = JSON.parse(body)
                        console.log(address)
                        resolve(address);
                    }
                }
            );
        })
}

async function retrieveGeoObject(handlerInput) {
    var isGeoSupported = handlerInput.requestEnvelope.context.System.device.supportedInterfaces.Geolocation;
    var geoObject = handlerInput.requestEnvelope.context.Geolocation;
    console.log("Geolocation extracted: "+JSON.stringify(geoObject));
    if (!isGeoSupported) {
        console.log("Geolocation not supported, trying address");
        
        const address = await getAddress(handlerInput);
        
        return new Promise((resolve, reject) => {
            console.log("Geocoding Address");
            request(
                "https://maps.googleapis.com/maps/api/geocode/json?address="+
                    utf8.encode(address.addressLine1)+","+
                    (address.addressLine2 ? utf8.encode(address.addressLine2)+"," : "")+
                    (address.addressLine3 ? utf8.encode(address.addressLine3)+"," : "")+
                    utf8.encode(address.city)+","+
                    utf8.encode(address.stateOrRegion)+" "+
                    utf8.encode(address.postalCode)+","+
                    utf8.encode(address.countryCode)+
                    "&key=AIzaSyBqIYXsgpWykaEn35H_g4EscKKpzwqgSFg",
                (err, res, body) => {
                    const json = JSON.parse(res.body);
                    console.log(JSON.stringify(json));
                    if (err || (!res) || (res.statusCode !== 200) || (!json) || (!json.results) || (json.results.length < 1)) { 
                        console.log("Error geocoding address: "+JSON.stringify(err));
                        reject();
                    }
                    resolve({ coordinate: { latitudeInDegrees: json.results[0].geometry.location.lat, longitudeInDegrees: json.results[0].geometry.location.lng } })
                }
            )
        })
    }
    return geoObject;
}


// sample requests for testing in a browser
// price list: https://creativecommons.tankerkoenig.de/json/list.php?lat=52.52099975265203&lng=13.43803882598877&rad=4&sort=price&type=diesel&apikey=07760764-9a19-5588-8320-306cb8bda02b
// station details: https://creativecommons.tankerkoenig.de/json/detail.php?id=005056ba-7cb6-1ed2-bceb-90e59ad2cd35&apikey=07760764-9a19-5588-8320-306cb8bda02b
const request = require('request');

function callBackend(location) {
    return new Promise((resolve, reject) => {
        const url = baseURL+"/check_wildfires?lat="+location.coordinate.latitudeInDegrees+"&lon="+location.coordinate.longitudeInDegrees;
        
        request(url, { json: false }, (err, res, body) => {
            if (err) { 
                console.log("err:"+JSON.stringify(err));
                reject(err); 
            }
            resolve(body);
        });
    })

/*  This did not work and I never figured out why
    //const url = "http://ec2-54-193-45-188.us-west-1.compute.amazonaws.com/user_location";
    const url = "http://www.google.com";
    console.log("Accessing "+url);
    return axios.get(url, {
        params: {
            lat: 10, //location.coordinate.latitudeInDegrees,
            log: 29, //location.coordinate.longitudeInDegrees
        }
    }).catch(err => {
        console.log("Error: "+JSON.stringify(err));
        return null;
    });
*/
}

function getPictureURL(location) {
    return baseURL+"/map_wildfire?lat="+location.coordinate.latitudeInDegrees+"&lon="+location.coordinate.longitudeInDegrees;
}

async function test() {
    await callBackend({});
}

//test();
