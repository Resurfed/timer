void LoadServerInfo()
{
    int arg_size = (str_len(g_serverIP) * 3) + 1;
    char[] formatted_arg = char[arg_size];
    URLEncode(g_serverIP, formatted_arg, arg_size);

    char buffer[128];
    Format(buffer, sizeof(buffer), "servers/?Address=%s", formatted_arg);
    http_client.Get(buffer, OnServerLoad);
}

public void OnServerLoad(HTTPResponse response, any value) 
{ 
    ResponseInfo response_info;
    JSONArray results = GetGetResponseResultsArray(response, info, "server");

    if (response_info == Request_EmptyResultSet)
    {
        InsertServer();
    }

    if (response_info != Request_Success)
    {
        return;
    }

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

void LoadClient(int client)
{
    char auth[32];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);

    int arg_size = (str_len(auth) * 3) + 1;
    char[] formatted_arg = char[arg_size];
    URLEncode(auth, formatted_arg, arg_size);

    char buffer[128];
    Format(buffer, sizeof(buffer), "servers/steamid=%s", formatted_arg);
    http_client.Get(buffer, OnClientLoad, client);
}

public void OnClientLoad(HTTPResponse response, any client)
{
    ResponseInfo response_info;
    JSONArray results = GetGetResponseResultsArray(response, info, "client");

    if (response_info == Request_EmptyResultSet)
    {
        InsertClient();
        return;
    }
    else if (response_info != Request_Success)
    {
        return;
    }

    g_client_info[client] = results.get(0);
    delete results;

    LoadClientRecords(client);
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

