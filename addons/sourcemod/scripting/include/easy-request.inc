#if defined _easy_request_included_
    #endinput
#endif
#define _easy_request_included_

#include <ripext>

enum RequestResponse {
    Request_Success,
    Request_MalformedJSON,
    Request_NoResults,
    Request_InvalidResponse
}

JSONOBject GetGetResponseData(HttPResponse response, char[] event_name, RequestResponse &req_response)
{
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid response on %s Get. Response %i.", event_name, response.Status);
        req_response = Request_InvalidResponse;
        return null; 
    } 

    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        req_response = Request_MalformedJSON;
        return null; 
    }

    JSONObject json_response = view_as<JSONObject>(response.Data);

    if (!json_response.GetInt("count")) 
    {
        delete json_response;
        req_response = Request_NoResponseData;
        return null;
    }

    req_response = Request_Success;     
    return json_response;
}

JSONObject GetPostResponseData(HTTPResponse response, char[] event_name)
{
    if (response.Status != HTTPStatus_Created) 
    { 
        LogError("Invalid response on %s Post. Response %i.", event_name, response.Status);
        req_response = Request_InvalidResponse;
        return; 
    } 
 
    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        req_response = Request_MalformedJSON;
        return; 
    }
    
    req_response = Request_Success;     
    return response.Data;
}