void LoadServerInfo()
{
    char buffer[128];
    Format(buffer, sizeof(buffer), "servers/?Address=%s", g_map_name);
    http_client.Get(buffer, OnServerLoad);
}

public void OnServerLoad(HTTPResponse response, any value) 
{ 
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid response on Server Load. Response %i.", response.Status);
        return; 
    } 

    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        return; 
    }

    JSONObject json_response = view_as<JSONObject>(response.Data);
 
    if (!json_response.GetInt("count")) 
    {
        delete json_response;
        InsertServer();
        return;
    }

    JSONArray results = view_as<JSONArray>(json_response.Get("results"));
    delete json_response;

    g_server_info = results.get(0);
    delete results;

    Call_StartForward(g_event_server_id_loaded);
    Call_PushCell(g_server_id);
    Call_Finish();
}

void InsertServer()
{
    ServerInfo server = new ServerInfo();
 
    char host_name[64];
    GetServerHostName(host_name, sizeof(host_name));

    server.SetName(host_name);
    http_client.Post("maps/", server, OnServerInsert);
    delete server;
}

public void OnMapInsert(HTTPResponse response, any value) 
{
    if (response.Status != HTTPStatus_Created) 
    { 
        LogError("Invalid response on map creation. Response %i.", response.Status);
        return; 
    } 
 
    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        return; 
    }

    g_server_info = view_as<MapInfo>(response.Data);
}

void LoadClient(int client)
{
    char auth[32];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);

    char buffer[128];
    Format(buffer, sizeof(buffer), "servers/steamid=%s", auth);
    http_client.Get(buffer, OnClientLoad, client);
}

public void OnClientLoad(HTTPResponse response, any client) 
{ 
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid response on Player Load. Response %i.", response.Status);
        return; 
    } 

    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        return; 
    }

    JSONObject json_response = view_as<JSONObject>(response.Data);
 
    if (!json_response.GetInt("count")) 
    {
        delete json_response;
        InsertClient();
        return;
    }

    JSONArray results = view_as<JSONArray>(json_response.Get("results"));
    delete json_response;

    g_client_info[client] = results.get(0);
    delete results;

    LoadClientRecords(client);
}

void LoadClientRecords(int client)
{

}

void InsertClient(int client)
{
    char name[32], auth[32], ip[32];

    GetClientName(client, name, sizeof(name));
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);
    GetClientIP(client, userIP, sizeof(userIP));

    ClientInfo client_info = new ClientInfo();

    client_info.SetName(name);
    client_info.SetAuth(auth);
    client_info.SetAddress(ip);

    http_client.Post("players/", client_info, OnClientInsert);
    delete server;
}

