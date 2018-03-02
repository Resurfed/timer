void CreateConnection()
{
    if (!SQL_CheckConfig(DEFAULT_DB_CONFIG))
    {
        SetFailState("'%s' not found in 'sourcemod/configs/databases.cfg'", DEFAULT_DB_CONFIG);
    }
    Database.Connect(SQL_OnConnect, DEFAULT_DB_CONFIG);
}

public void SQL_OnConnect(Database db, char[] error, any data)
{
    if (db == null)
    {
        SetFailState("Database failure : %s", error);
    }

    g_database = db;
    LoadServerInfo();
    LoadMapConfiguration();

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i))
        {
            OnClientPostAdminCheck(i);
        }
    }
}

void LoadServerInfo()
{
    if (g_database == null)
    {
        return;
    }

    char query[512], hostName[64];
    GetServerHostName(hostName, sizeof hostName);
    Format(query, sizeof query, "INSERT INTO `cs_servers`(serverAddress, hostName) VALUES ('%s', '%s') ON DUPLICATE KEY UPDATE hostName = '%s';", g_serverIP, hostName, hostName);
    g_database.Query(callback_insertServer, query);
    Format(query, sizeof query, "SELECT serverID FROM `cs_servers` WHERE serverAddress = '%s'", g_serverIP);
    g_database.Query(callback_loadServer, query);
}

void LoadMapConfiguration()
{
    if (g_database == null)
    {
        return;
    }

    char query[512];
    Format(query, sizeof query, "SELECT zone, type, origin, angle, velocity FROM `cs_spawns` INNER JOIN `cs_maps` ON cs_spawns.mapID = cs_maps.mapID WHERE cs_maps.name = '%s';", g_currentMap);
    g_database.Query(callback_loadSpawns, query);

    Format(query, sizeof query, "SELECT stage, type, time, cs_players.name, steamid, cs_times.playerID FROM cs_times INNER JOIN cs_maps ON cs_times.mapid = cs_maps.mapid");
    Format(query, sizeof query, "%s LEFT JOIN cs_players ON cs_times.playerid = cs_players.playerid WHERE rank = 1 AND cs_maps.name = '%s' ORDER BY type, stage", query, g_currentMap);

    g_database.Query(callback_loadBestTimes, query);
}

void LoadUser(int client)
{
    if (g_database == null)
    {
        return;
    }

    char query[512], auth[32], userIP[32], name[32];

    GetClientAuthId(client, AuthId_Steam2, auth, sizeof auth, true);
    GetClientName(client, name, sizeof name);
    GetClientIP(client, userIP, sizeof userIP);

    int length = strlen(name) * 2 + 1;
    char[] escName = new char[length];
    g_database.Escape(name, escName, length);

    Format(query, sizeof query, " INSERT INTO `cs_players`(steamid, name, playerIP) values ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE name = VALUES(name), playerIP = VALUES(playerIP), dateUpdated = CURRENT_TIMESTAMP;", auth, escName, userIP);
    g_database.Query(callback_userInsert, query);

    Format(query, sizeof query, "SELECT playerID FROM cs_players WHERE steamid = '%s';", auth);
    g_database.Query(callback_userLoad, query, client);

    Format(query, sizeof query, "SELECT time, type, stage FROM cs_times INNER JOIN cs_players ON cs_players.playerID = cs_times.playerID INNER JOIN cs_maps ON cs_maps.mapID = cs_times.mapID WHERE cs_maps.name = '%s' AND cs_players.steamid = '%s' ORDER BY type, stage;", g_currentMap, auth);
    PrintToServer("Precallback: %s", query);
    g_database.Query(callback_userLoadTimes, query, client);

    Format(query, sizeof query, "SELECT hudConfig, hidepanel, sounds, colorScheme, chatMode, teleVelocity FROM cs_options INNER JOIN cs_players ON cs_players.playerID = cs_options.playerID WHERE cs_players.steamid = '%s';", auth);
    g_database.Query(callback_userLoadOptions, query, client);
}

public void callback_userLoadTimes(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("User Time Loading Error : %s", error);
        return;
    }

    int stage, type;

    while (results.FetchRow())
    {

        type = results.FetchInt(1);
        stage = results.FetchInt(2);

        if (type == 1)
        {
            g_userBonusTimes[data][stage - 1] = results.FetchFloat(0);
        }
        else
        {
            g_userStageTimes[data][stage] = results.FetchFloat(0);
        }
    }

    g_userLoaded[data] = true;
    CallUserLoadEvent(data, g_userID[data]);

    char query[512];
    Format(query, sizeof query, "SELECT time, stagetime, zone, velocity FROM cs_cptimes INNER JOIN cs_maps ON cs_maps.mapID = cs_cptimes.mapID WHERE cs_maps.name = '%s' AND playerID = %i ORDER BY ZONE;", g_currentMap, g_userID[data]);
    g_database.Query(callback_userLoadCPTimes, query, data);
    PrintToServer("Callback: %s", query);
    return;
}

public void callback_userLoadCPTimes(Database db, DBResultSet results, char[] error, any data)
{
    if (results == null)
    {
        LogError("User Checkpoint Time Loading Error : %s", error);
        return;
    }

    int zone;

    while (results.FetchRow())
    {

        zone = results.FetchInt(2);

        if (data == -1)
        {
            g_mapCPTimes[zone] = results.FetchFloat(0);
            g_mapSCPTimes[zone] = results.FetchFloat(1);
            g_mapCPVelocity[zone] = results.FetchFloat(3);
        }
        else
        {
            g_userCPTimes[data][zone] = results.FetchFloat(0);
            g_userSCPTimes[data][zone] = results.FetchFloat(1);
            g_userCPVelocity[data][zone] = results.FetchFloat(3);
        }
    }
}

public
void callback_userInsert(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("User Insert Error : %s", error);
        return;
    }

    return;
}

public
void callback_userLoad(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("User Load Error : %s", error);
        return;
    }
    if (results.FetchRow())
    {
        g_userID[data] = results.FetchInt(0);
    }

    return;
}

public
void callback_userLoadOptions(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("User Options Loading Error : %s", error);
        return;
    }

    if (results.FetchRow())
    {

        char message[MAX_HUDCONFIG_LENGTH];
        results.FetchString(0, message, MAX_HUDCONFIG_LENGTH);

        if (!StrEqual(message, "", false) && message[0] != '0')
        {
            Format(g_hudConfigText[data], MAX_HUDCONFIG_LENGTH, "%s", message);
        }

        g_userPanelEnabled[data] = view_as<bool>(results.FetchInt(1));
        g_userSoundsEnabled[data] = view_as<bool>(results.FetchInt(2));

        int scheme = results.FetchInt(3);

        if (scheme < g_loadedColorSchemes && scheme > 0)
        {

            SetUserColorScheme(data, scheme);
            g_userChatColorScheme[data] = scheme;
        }

        g_userTelehopEnabled[data] = view_as<bool>(results.FetchInt(5));
    }

    return;
}

public
void callback_insertServer(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Server Insert Error : %s", error);
        return;
    }

    return;
}

public
void callback_loadServer(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Server Load Error : %s", error);
        return;
    }

    if (results.FetchRow())
    {
        g_serverID = results.FetchInt(0);
    }

    Call_StartForward(g_event_serverIDLoaded);
    Call_PushCell(g_serverID);
    Call_Finish();

    return;
}

public
void callback_loadSpawns(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Spawn Load Error : %s", error);
        return;
    }

    int zone, type;
    char cOrigin[96], cAngle[96], cVelocity[96];
    float origin[3], angle[3], velocity[3];

    while (results.FetchRow())
    {

        zone = results.FetchInt(0);
        type = results.FetchInt(1);
        results.FetchString(2, cOrigin, sizeof cOrigin);
        results.FetchString(3, cAngle, sizeof cAngle);
        results.FetchString(4, cVelocity, sizeof cVelocity);

        StringToVector(origin, cOrigin, "|");
        StringToVector(angle, cAngle, "|");
        StringToVector(velocity, cVelocity, "|");

        if (type == 0)
        {
            g_spawnStageAngles[zone] = angle;
            g_spawnStageOrigin[zone] = origin;
            g_spawnStageVelocity[zone] = velocity;
        }
        else if (type == 1)
        {
            g_spawnBonusAngles[zone - 1] = angle;
            g_spawnBonusOrigin[zone - 1] = origin;
            g_spawnBonusVelocity[zone - 1] = velocity;
        }
    }

    return;
}

public
void callback_loadBestTimes(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Map Time Load Error : %s", error);
        return;
    }

    int stage, type, bestPlayerID;

    while (results.FetchRow())
    {

        stage = results.FetchInt(0);
        type = results.FetchInt(1);

        //am i doing anything with completions? might just have db generate it.

        if (stage == 0)
        {
            bestPlayerID = results.FetchInt(5);
        }

        if (type == 0)
        {

            g_mapStageTimes[stage] = results.FetchFloat(2);
            results.FetchString(3, g_mapStageName[stage], sizeof g_mapStageName[]);
        }
        else
        {

            g_mapBonusTimes[stage - 1] = results.FetchFloat(2);
            results.FetchString(3, g_mapBonusName[stage - 1], sizeof g_mapBonusName[]);
        }
    }

    g_mapTimesLoaded = true;

#if defined _DEBUG
    PrintToServer("timersurf-timer DB RESULT times loaded");
#endif

    char query[512];
    Format(query, sizeof query, "SELECT time, stagetime, zone, velocity FROM cs_cptimes INNER JOIN cs_maps ON cs_maps.mapID = cs_cptimes.mapID WHERE cs_maps.name = '%s' AND playerID = %i ORDER BY ZONE;", g_currentMap, bestPlayerID);
    g_database.Query(callback_userLoadCPTimes, query, -1);
    return;
}

void StoreTime(int client, int zone, int type, float time)
{
    char query[512];
    Format(query, sizeof query, "INSERT INTO cs_times(mapID, playerID, stage, type, time, serverID, dateUpdated) VALUES (%i, %i, %i, %i, %f, %i, CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE time=values(time), serverID=values(serverID), dateUpdated=CURRENT_TIMESTAMP ", g_mapID, g_userID[client], zone, type, time, g_serverID);

    DataPack pack = CreateDataPack();
    pack.WriteCell(client);
    pack.WriteCell(zone);
    pack.WriteCell(type);

    g_database.Query(callback_insertTimes, query, pack);

    return;
}

void StoreCPTime(client)
{

    char query[1524];

    Format(query, sizeof query, "INSERT INTO cs_cptimes(playerID, mapid, zone, time, stageTime, velocity) VALUES");
    for (new i = 0; i < g_mapZones; i++)
    {
        Format(query, sizeof query, "%s%s (%i, %i, %i, %f, %f, %f)", query, (i == 0 ? "" : ","), g_userID[client], g_mapID, i + 1, g_userCPTimes[client][i + 1], g_userSCPTimes[client][i + 1], g_userCPVelocity[client][i + 1]);
    }

    Format(query, sizeof query, "%s ON DUPLICATE KEY UPDATE time = VALUES(time), stageTime = values(stageTime), velocity = values(velocity);", query);
    g_database.Query(callback_insertCPTimes, query);

    return;
}

public
void callback_insertCPTimes(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Checkpoint Time Insert Error : %s", error);
        return;
    }

    return;
}

public
void callback_insertTimes(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Time Insert Error : %s", error);
        return;
    }

    int client, zone, type;

    ResetPack(data);
    client = ReadPackCell(data);
    zone = ReadPackCell(data);
    type = ReadPackCell(data);

    char recordingQuery[256];
    Format(recordingQuery, sizeof recordingQuery, "getTimeRecordingID(mapID, playerID, stage, type)");

    char query[916];
    Format(query, sizeof query, "SELECT getTimeRank(mapID, playerID, stage, type), getTimeComps(mapID, stage, type), %s, getRecordingRank((%s)) FROM cs_times WHERE mapid = '%i' and playerID = '%i' AND stage = '%i' AND type = '%i' limit 1", recordingQuery, recordingQuery, g_mapID, g_userID[client], zone, type);
    g_database.Query(callback_getTimeRank, query, data);
}

public
void callback_getTimeRank(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Get Time Rank Error : %s", error);
        return;
    }

    int client, zone, type;
    ResetPack(data);
    client = ReadPackCell(data);
    zone = ReadPackCell(data);
    type = ReadPackCell(data);
    CloseHandle(data);

    int rank, completions, recordingID, recordingRank;

    if (results.FetchRow())
    {
        rank = results.FetchInt(0);
        completions = results.FetchInt(1);
        recordingID = results.FetchInt(2);
        recordingRank = results.FetchInt(3);
    }

    bool broadcastAll = (zone == 0 && rank <= MAX_TOPTIMES || rank == 1);
    char message[512];

    if (zone == 0 && type == 0)
    {
        Format(message, sizeof message, "%sthe Map", message);
    }
    else
    {
        Format(message, sizeof message, "%s%s %i", message, type ? "Bonus" : "Stage", zone);
    }

    if (broadcastAll)
    {
        char name[32];
        GetClientName(client, name, sizeof name);
        Format(message, sizeof message, "<info>Info | <name>%s <message>finished %s with Rank <int>%i<message>/<int>%i<message>!", name, message, rank, completions);
    }
    else
    {
        Format(message, sizeof message, "<info>Info | <message>Ranked <int>%i<message>/<int>%i<message> for %s<message>!", rank, completions, message);
    }

    if (broadcastAll)
    {
        PrintTimerMessageAll(client, message)
    }
    else
    {
        PrintTimerMessage(client, message)
    }

    if (rank <= MAX_TOPTIMES)
    {
        char query[256];
        FormatEx(query, sizeof query, "call timesOrderRank(%i, %i, %i, %i);", g_mapID, zone, type, MAX_TOPTIMES);
        g_database.Query(callback_callTimeOrderRank, query, data);
    }

    if (zone == 0)
    {
        CallMapRankedEvent(client, rank, completions, recordingID, recordingRank);
    }
    else if (type == 0)
    {
        CallStageRankedEvent(client, zone, rank, completions, recordingID, recordingRank);
    }
    else
    {
        CallBonusRankedEvent(client, zone, rank, completions, recordingID, recordingRank);
    }

    return;
}

public
void callback_callTimeOrderRank(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("Time Order Rank Error : %s", error);
        return;
    }

    return;
}

void SavePlayerSettings(client, bool hudSettings)
{

    char query[512];

    if (hudSettings)
    {
        FormatEx(query, sizeof query, "INSERT INTO cs_options (playerid, hudConfig) VALUES(%i, '%s') ON DUPLICATE KEY UPDATE hudConfig = VALUES(hudConfig);", g_userID[client], g_hudConfigText[client]);
    }
    else
    {
        FormatEx(query, sizeof query, "INSERT INTO cs_options (playerid, hidepanel, sounds, colorscheme, televelocity) VALUES(%i, %i, %i, %i, %i) ON DUPLICATE KEY UPDATE hidepanel = VALUES(hidepanel), sounds = VALUES(sounds), colorscheme=VALUES(colorscheme), televelocity=VALUES(televelocity);", g_userID[client], g_userPanelEnabled[client], g_userSoundsEnabled[client], g_userChatColorScheme[client], g_userTelehopEnabled[client]);
    }
    g_database.Query(callback_saveUserSettings, query, client);

    return;
}
public
void callback_saveUserSettings(Database db, DBResultSet results, char[] error, any data)
{

    if (results == null)
    {
        LogError("User Options Insert Error : %s", error);
        return;
    }

    PrintTimerMessage(data, "<info>Info | <message>Changes Saved!");

    return;
}

public
bool SendCrossServerRecordNotification(int client, int stage, int type)
{

    GlobalMsg message = new GlobalMsg();

    char buffer[32];

    FormatEx(buffer, sizeof buffer, "NewRecord");
    message.AddString("type", buffer);

    GetClientName(client, buffer, sizeof buffer);
    message.AddString("name", buffer);
    message.AddString("map", g_currentMap);

    if (stage == 0)
    {
        FormatEx(buffer, sizeof buffer, "Map");
    }
    else if (type == 1)
    {
        FormatEx(buffer, sizeof buffer, "Bonus %i", stage);
    }
    else
    {
        FormatEx(buffer, sizeof buffer, "Stage %i", stage);
    }
    message.AddString("timetype", buffer);
    message.Send();
}

public
int Socket_DataReceived(StringMap dataTable)
{

    char type[32];
    dataTable.GetString("type", type, sizeof type);

    if (!StrEqual(type, "NewRecord"))
    {
        return;
    }

    char name[32], map[32], timetype[32];
    dataTable.GetString("name", name, sizeof name);
    dataTable.GetString("map", map, sizeof map);
    dataTable.GetString("timetype", timetype, sizeof timetype);

    PrintTimerMessageAll(0, "<info>Global | <name>%s <message>broke the <info>%s <message>%s record!", name, map, timetype);
    return;
}

stock bool GetServerIP(char[] buffer, int maxlen)
{

    ConVar cvar_serverIP = FindConVar("ip");
    cvar_serverIP.GetString(buffer, maxlen);

    return (cvar_serverIP != null);
}

stock int GetServerPort()
{

    ConVar cvar_hostPort = FindConVar("hostport");

    return cvar_hostPort.IntValue;
}

stock bool GetServerHostName(char[] buffer, maxlen)
{

    ConVar cvar_hostName = FindConVar("hostname");
    cvar_hostName.GetString(buffer, maxlen);
    return (cvar_hostName != null);
}
