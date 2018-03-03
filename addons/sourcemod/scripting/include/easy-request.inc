#if defined _easy_request_included_
    #endinput
#endif
#define _easy_request_included_

#include <ripext>

enum ResponseInfo {
    Request_Success,
    Request_MalformedJSON,
    Request_EmptyResultSet,
    Request_InvalidResponse
}

stock JSONArray GetGetResponseResultsArray(HTTPResponse response, ResponseInfo &req_response, char[] event_name)
{
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid response on %s Get Request. Response %i.", event_name, response.Status);
        req_response = Request_InvalidResponse;
        return null; 
    } 

    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        req_response = Request_MalformedJSON;
        return null; 
    }

    JSONObject response_data = view_as<JSONObject>(response.Data);

    if (!response_data.GetInt("count"))
    {
        req_response = Request_EmptyResultSet;
        delete response_data;
        return null;
    }

    req_response = Request_Success;     
    JSONArray results = view_as<JSONArray>(response_data.Get("results"));
    delete response_data;
    return results;
}

stock JSONObject GetPostResponseObject(HTTPResponse response, ResponseInfo req_response, char[] event_name)
{
    if (response.Status != HTTPStatus_Created) 
    { 
        LogError("Invalid response on %s Post Request. Response %i.", event_name, response.Status);
        req_response = Request_InvalidResponse;
        return null; 
    } 
 
    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        req_response = Request_MalformedJSON;
        return null; 
    }
    
    req_response = Request_Success;     
    return view_as<JSONObject>(response.Data);
}