#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext>
#include <timer>

#pragma semicolon 1
#pragma newdecls required

HTTPClient http_client;
bool api_found;

ConVar cvar_api_url;
ConVar cvar_api_key;

char api_url[128];
char api_key[128];

//Events
Handle event_zone_enter;
Handle event_zone_exit; 
Handle event_map_info_update;

//Zoning
int grid_size[MAXPLAYERS + 1];
bool grid_snapping[MAXPLAYERS + 1];

ZoneType draw_zone_type[MAXPLAYERS + 1];
DrawMode draw_zone_mode[MAXPLAYERS + 1];
int draw_zone_value[MAXPLAYERS + 1];
bool draw_zone_maxvel[MAXPLAYERS + 1];
float draw_zone_start[MAXPLAYERS + 1][3];
float draw_zone_end[MAXPLAYERS + 1][3];
char draw_zone_filter[MAXPLAYERS + 1][32];

//Zones
int total_zones;
int beam_type;
bool triggers_hooked;
bool draw_triggers[MAXCLIENTS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{   
    CreateNative("GetMapConfiguration", nativecall_getMapInfo);
    RegPluginLibrary("timer-map");
    return APLRes_Success;
}

public Plugin myinfo =  
{   
    name = "Timer - Map", 
    author = PLUGIN_AUTHOR, 
    description = "Handles the map configuration for TimerSurf.", 
    version = PLUGIN_VERSION, 
    url = "http://www.sourcemod.net/"
};

public void OnPluginStart() 
{
    cvar_api_url = CreateConVar("timer_api_url", "", "The API URL");
    cvar_api_key = CreateConVar("timer_api_key", "", "The API key");
    
    AutoExecConfig(true);
    
    event_zone_enter = CreateGlobalForward("OnZoneEnter", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    event_zone_exit = CreateGlobalForward("OnZoneExit", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    event_map_info_update = CreateGlobalForward("OnMapInfoUpdate", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    RegConsoleCmd("sm_triggers", Command_ShowTriggers);
    RegAdminCmd("sm_triggername", Command_TriggerName, ADMFLAG_ROOT);
    RegAdminCmd("sm_filtername", Command_FilterName, ADMFLAG_ROOT);
    RegAdminCmd("sm_insertmap", Command_InsertMap, ADMFLAG_ROOT);
    RegAdminCmd("sm_zonemenu", Command_ZoneMenu, ADMFLAG_ROOT);

    HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_Post);
    HookEvent("arena_round_start", OnRoundStart, EventHookMode_Post);
}

public void OnMapStart() 
{
    PrecacheModel("models/error.mdl", true);
    beam_type = PrecacheModel("materials/sprites/physbeam.vmt");
}


//Map loading process
public void OnConfigsExecuted() 
{   
    cvar_api_url.GetString(api_url, sizeof(api_url));
    cvar_api_key.GetString(api_key, sizeof(api_key));
    
    char key[128];
    Format(key, sizeof key, "Token %s", g_api_key);

    timer_client = new HTTPClient(api_url);
    timer_client.SetHeader("Authorization", key);
    
    if (!api_found) 
    {
        FindWebAPI();
    }
}

void FindWebAPI()
{
    g_timer_client.Get("ping", OnWebAPIFound);
}

public void OnWebAPIFound(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid Response on Map Ping");
        g_api_found = false;
        return; 
    } 

    g_api_found = true;
    LoadMapConfiguration();
}

void LoadMapConfiguration() 
{
    char buffer[128];
    Format(buffer, sizeof(buffer), "maps/?name=%s", map_name);
    g_timer_client.Get(buffer, OnMapLoad);
}

public void OnMapLoad(HTTPResponse response, any value) 
{ 
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid response on Map Load.");
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
        InsertMap();
        return;
    }
    
    JSONArray results = view_as<JSONArray>(json_response.Get("results"));
    delete json_response;
    g_map = view_as<MapInfo>(results.Get(0));
    delete results;
    
    if (g_map.enable_baked_triggers && !g_global_triggers_hooked) 
    {
        HookBakedTriggers(true);
    }
    
    LoadZones();
}

void InsertMap()
{
    MapInfo map = new MapInfo();
    map.SetName(map_name);
    g_timer_client.Post("maps/", map, OnMapInsert);
}

public void OnMapInsert(HTTPResponse response, any value) 
{
    if (response.Status != HTTPStatus_Created) 
    { 
        LogError("Invalid response on map creation.");
        return; 
    } 
 
    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        return; 
    }

    g_map = view_as<MapInfo>(response.Data);
     
    if (g_map.enable_baked_triggers && !g_global_triggers_hooked) 
    {
        ToggleBakedTriggerHooks(true);
    }
    
    LoadZones();
}

void LoadZones() 
{
    char buffer[128];
    Format(buffer, sizeof buffer, "zones/?map=%i", g_map.id);
    g_timer_client.Get(buffer, OnZonesLoaded);
}

public void OnZonesLoaded(HTTPResponse response, any value) 
{
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid response on Zone Load.");
        return; 
    } 

    if (response.Data == null) 
    { 
        LogError("Malformed JSON");
        return; 
    }
 
    //plugin reloaded
    if (g_round_started) 
    {
        DestroyAllTimerTriggers();
    }
    
    JSONObject json_response = view_as<JSONObject>(response.Data);
    JSONArray results = view_as<JSONArray>(json_response.Get("results"));
    delete json_response;
 
    if (results == null) 
    {
        delete results;
        return;
    }
 
    //todo - its already in json, no need to convert to arraylist
    for (int i = 0; i < results.Length; i++) 
    {
        int index = AddZoneToCache(view_as<Zone>(results.Get(i)));
        
        if (g_round_started) 
        {
            DeployZone(index);
        }
    }
    
    delete results;
    g_zones_loaded = true;
    CallMapLoadEvent();
}

public Action Command_ShowTriggers(int client, int args) 
{
    draw_triggers[client] = !draw_triggers[client];
    PrintToChat(client, "Timer | %s triggers.", g_showtriggers[client] ? "Showing" : "Hiding");
}

//set custom trigger name
public Action Command_TriggerName(int client, int args) 
{
    if (!args)
    {
        PrintToChat(client, "Error | No argument.");
    }

    char name[32];
    GetCmdArgString(name, sizeof(name));
    ZoneType type = ProcessLegacyZoneString(name, sizeof(name), draw_zone_value[client], draw_zone_maxvel[client]);
    
    if (type == Zone_Unknown) 
    {
        PrintToChat(client, "Warning | Could not interpret '%s'.", zoneName);
        return; 
    }
    
    g_draw_type[client] = type;
    PrintToChat(client, "Info | Zone info Set.");
    ShowZoneMenu(client);
}

//set custom trigger filter
public Action Command_FilterName(int client, int args) 
{
    if (!args) 
    {
        PrintToChat(client, "Info | Zone cache cleared.");
        draw_zone_filter[client] = "";
        return;
    }
    
    GetCmdArgString(draw_zone_filter[client], sizeof draw_zone_filter[]);
    PrintToChat(client, "Info | Filter name set as '%s'.", draw_zone_filter[client]);
}

public Action Command_InsertMap(int client, int args)
{
    if (g_map == null) 
    {
        return;
    }

    if (args !=  6) 
    {
        PrintToChat(client, "Info | Tier(1-6) Checkpoints Type(0 - Staged, 1 - Linear) \"Author\" Bonuses ZonesBaked(0, 1)");
        return;
    }

    char author[32], difficulty[16], type[16], checkpoints[16], bonuses[16], baked_triggers[16];

    GetCmdArg(1, difficulty, sizeof difficulty);
    GetCmdArg(2, checkpoints, sizeof checkpoints);
    GetCmdArg(3, type, sizeof type);
    GetCmdArg(4, author, sizeof author);
    GetCmdArg(5, bonuses, sizeof bonuses);
    GetCmdArg(6, baked_triggers, sizeof baked_triggers);
    
    g_map.SetAuthor(author);
    g_map.difficulty = StringToInt(difficulty);
    g_map.type = view_as<MapType>(StringToInt(type));
    g_map.checkpoints = StringToInt(checkpoints);
    g_map.bonuses = StringToInt(bonuses);
    g_map.enable_baked_triggers = view_as<bool>(StringToInt(baked_triggers));
    g_map.active = true;

    char buffer[128];
    Format(buffer, sizeof buffer, "maps/%i/", g_map.id);
    g_timer_client.Put(buffer, g_map, OnUpdateMap);
    CallMapLoadEvent();

    ToggleBakedTriggerHooks(g_map.enable_baked_triggers);
}

public Action Command_ZoneMenu(int client, int args) 
{
    ShowZoneMenu(client);
}

void ShowZoneMenu(int client)
{
    Menu menu = new Menu(MenuHandler_ZoneMenu);

    char title[64];
    Format(title, sizeof(title), "<Draw Zone Menu>\n \n");
    Format(title, sizeof(title), "%sType: %s \n", title, draw_zone_type_names[draw_zone_type[client] + 1]);
    Format(title, sizeof(title), "%sValue: %s \n", title, draw_zone_value[client]);
    Format(title, sizeof(title), "%sVelocity Limit: %s \n", title, draw_zone_maxvel[client] ? "True" : "False");
    Format(title, sizeof(title), "%sFilter: %s \n", title, draw_zone_filter[client]);
    Format(title, sizeof(title), "%sSnapping: %s \n \n", title, grid_size[client]);

    menu.SetTitle(title);
    menu.AddItem("", "[Start Draw]");
    menu.AddItem("", "[End Draw]");
    menu.AddItem("", "[Upload] \n \n");
    
    if (g_draw_grid_snapping[client]) 
    {
        menu.AddItem("", "Toggle Snapping\n Enabled\n ");
        menu.AddItem("", "Increase Grid");
        menu.AddItem("", "Decrease Grid\n ");
    }
    else 
    {
        menu.AddItem("", "Toggle Snapping\n Disabled\n ");
        menu.AddItem("", "Increase Grid", ITEMDRAW_DISABLED);
        menu.AddItem("", "Decrease Grid\n ", ITEMDRAW_DISABLED);
    }
    
    menu.AddItem("", "Trigger List\n ");
    menu.AddItem("", "Reset\n ");
    menu.AddItem("", "Close Editor");
    menu.Pagination = MENU_NO_PAGINATION;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneMenu(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        if (choice == 0)
        {
            StartZoneDraw(client);
            ShowZoneMenu(client);
        }

        else if (choice == 1)
        {
            EndZoneDraw(client);
            ShowZoneMenu(client);
        }

        else if (choice == 2)
        {
            SaveZone(client);
            ShowZoneMenu(client);
        }

        else if (choice == 3)
        {
            grid_snapping[client] = !grid_snapping[client];
            ShowZoneMenu(client);
        }

        else if (choice == 4)
        {
            grid_size[client] = grid_size[client] < MAX_SNAP_LIMIT ? grid_size[client] * 2 : MAX_SNAP_LIMIT;
            ShowZoneMenu(param1);
        }

        else if (choice == 5)
        {
            grid_size[client] = RoundToCeil(grid_size[client] / 2.0);
            ShowZoneMenu(client);
        }

        else if (choice == 6)
        {
            ShowZoneList(client); 
        }

        else if (choice == 7)
        {
            draw_zone_mode[client] = DrawMode_Stopped;
            ShowZoneMenu(client);
        }
    }

    else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void StartZoneDraw(int client) 
{
    
    if (draw_zone_mode[client] != DrawMode_Active) 
    {
        CreateTimer(0.1, Timer_DrawCustomZone, client, TIMER_REPEAT);
        draw_zone_mode[client] = DrawMode_Active;
    }
    
    GetClientSnappedOrigin(client, draw_zone_start[client], grid_size[client], true, grid_snapping[client]);
    ShowZoneMenu(client);
}

void EndZoneDraw(int client) 
{    
    draw_zone_mode[client] = DrawMode_Frozen;
    GetClientSnappedOrigin(client, draw_zone_end[client], grid_size[client], true, grid_snapping[client]);
    ShowZoneMenu(client);
}

void SaveZone(int client) 
{   
    draw_zone_mode[client] = DrawMode_Stopped;
    
    Zone zone = new Zone();
    zone.value = draw_zone_value[client];
    zone.type = draw_zone_type[client];
    zone.velocity = draw_zone_maxvel[client];
    zone.map = g_map.id;
    zone.SetFilterName(draw_zone_filter[client]);
    zone.SetStartCoordinates(draw_zone_start[client]);
    zone.SetEndCoordinates(draw_zone_end[client]);
    
    int index = AddZoneToCache(zone);
    StoreZone(client, zone, index);
    DeployZone(index);
    PrintToChat(client, "Info | Zone created.");
}

void StoreZone(int client, Zone zone, int index) 
{
    DataPack pack = new DataPack();
    pack.WriteCell(client);
    pack.WriteCell(index);
    g_timer_client.Post("zones/", zone, OnZoneInserted, pack);
}

public void OnZoneInserted(HTTPResponse response, any data) 
{
    if (response.Status != HTTPStatus_Created) 
    { 
        delete data;
        LogError("Invalid response on zone insertion.");
        return; 
    } 
 
    if (response.Data == null) 
    {
        delete data;
        LogError("Malformed JSON");
        return; 
    }
 
    DataPack pack = data;
    pack.Reset();
    int client = pack.ReadCell();
    int index = pack.ReadCell();
    delete pack;

    Zone zone = view_as<Zone>(response.Data);
    (view_as<Zone>(g_zones.Get(index))).id = zone.id;
    
    PrintToChatAll("<info>Info |<message> Zone <int>#%i<message> created.", zone.id);   
    delete zone;    
}

void ShowZoneList(int client) 
{    
    Menu menu = new Menu(MenuHandler_ZoneList);
    menu.SetTitle("<Loaded Zone List>\n ");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    
    if (!g_total_zones) 
    {
        menu.AddItem("", "[No Custom Triggers]", ITEMDRAW_DISABLED);
        menu.Display(client, MENU_TIME_FOREVER);
        return;
    }
    
    char buffer[128], cindex[10];
    
    for (int i = 0; i < total_zones; i++) 
    {
        Zone zone = view_as<Zone>(g_zones.Get(i));  
        IntToString(i, cindex, sizeof(cindex));
        FormatEx(buffer, sizeof buffer, "#%i | %s %i", i + 1, zone_type_names[view_as<int>(zone.type) + 1], zone.value);
        menu.AddItem(cindex, buffer);
    }
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneList(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        char cindex[10];
        menu.GetItem(choice, cindex, sizeof cindex);
        int index = StringToInt(cindex);
        ShowZoneInfo(client, index);
    }

    else if (action == MenuAction_Cancel)
    {
        if (choice == MenuCancel_ExitBack) 
        {
            ShowZoneMenu(client);
        }
    }

    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowZoneInfo(int client, int index) {
    
    float start[3], end[3];
    char filter[32], zone_id[10], buffer[384];
    
    Zone zone = g_zones.Get(index);
    zone.GetStartCoordinates(start);
    zone.GetEndCoordinates(end);
    zone.GetFilterName(filter, sizeof filter);
    
    FormatEx(zone_id, sizeof zone_id, "%i", zone.id);
    FormatEx(buffer, sizeof buffer, "<Custom Zone>\n \nZone ID : %i\n \n \nFilter Name : %s\n \nMin : %.1f %.1f %.1f\n \nMax : %.1f %.1f %.1f \n \n", zone.id, filter, start[0], start[1], start[2], end[0], end[1], end[2]);
    
    Menu menu = new Menu(MenuHandler_ZoneInfo);
    menu.SetTitle(buffer);
    menu.AddItem(zone_id, "Delete Trigger", (zone.id == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneInfo(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        if (!choice)
        {
            char cindex[16];
            menu.GetItem(choice, cindex, sizeof(cindex));
            int index = StringToInt(cindex);
            DeleteZone(client, index);
            ShowTriggerList(client);
        }
    }

    else if (action == MenuAction_Cancel)
    {
        if (choice == MenuCancel_ExitBack)
        {
            ShowZoneList(client);
        }
    }

    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void CreateEngineTrigger(float start[3], float end[3], char[] type, char[] name, char[] filter) 
{   
    end[2] += ORIGIN_BUFFER;

    float center[3] = 0.0;
    GetBoxCenter(end, start, middle);
   
    //convert start and end vectors from world coordinates to distance from origin
    SubtractVectors(start, center, start);
    SubtractVectors(end, center, end);
    AbsVector(start);
    AbsVector(end);
    ScaleVector(start, -1.0);

    //create the trigger
    int trigger = CreateEntityByName(type);
    DispatchKeyValue(trigger, "spawnflags", "1");
    DispatchKeyValue(trigger, "targetname", name);

    if (filter[0]) 
    {
        DispatchKeyValue(trigger, "filtername", filter);
    }

    DispatchKeyValue(trigger, "wait", "0");
    DispatchSpawn(trigger);
    ActivateEntity(trigger);
    TeleportEntity(trigger, center, NULL_VECTOR, NULL_VECTOR);

    SetEntityModel(trigger, "models/error.mdl");
    SetEntPropVector(trigger, Prop_Send, "m_vecMins", start);
    SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", end);
    SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
    int iEffects = GetEntProp(trigger, Prop_Send, "m_fEffects");
    iEffects |= 0x020;
    SetEntProp(trigger, Prop_Send, "m_fEffects", iEffects);

    //hook the new trigger
    HookSingleEntityOutput(trigger, "OnStartTouch", OnCustomStartTouch);
    HookSingleEntityOutput(trigger, "OnEndTouch", OnCustomEndTouch);
}

void GetBoxCenter(float min[3], float max[3], float center[3]) 
{   
    float distance[3];
    SubtractVectors(max, min, distance);
    ScaleVector(distance, 0.5);
    AddVectors(min, distance, center);
}

void DestroyAllTriggers() 
{   
    char name[32];
    int trigger = -1;
    
    while ((trigger = FindEntityByClassname(trigger, "trigger_multiple")) != -1) 
    {   
        if (IsValidEntity(trigger) 
        && GetEntPropString(trigger, Prop_Data, "m_iName", name, sizeof name) 
        && StrContains(name, "timer_zone_") != -1) 
        {
            UnhookSingleEntityOutput(trigger, "OnStartTouch", OnCustomStartTouch);
            UnhookSingleEntityOutput(trigger, "OnEndTouch", OnCustomEndTouch);
            AcceptEntityInput(trigger, "Kill");
        }       
    }
}

void DestroyTrigger(int index) 
{   
    char name[32], compare[32];
    Format(name, sizeof(name), "timer_zone_%i", index);
    
    int trigger = -1;
    
    while ((trigger = FindEntityByClassname(trigger, "trigger_multiple")) != -1) 
    {   
        if (!IsValidEntity(trigger)) 
        {
            continue;
        }
        
        GetEntPropString(trigger, Prop_Data, "m_iName", compare, sizeof(compare));
        
        if (!StrEqual(name, compare, false)) 
        {
            continue;
        }
        
        UnhookSingleEntityOutput(trigger, "OnStartTouch", OnCustomStartTouch);
        UnhookSingleEntityOutput(trigger, "OnEndTouch", OnCustomEndTouch);
        AcceptEntityInput(trigger, "Kill");
        break;
    }
}

public void ToggleBakedTriggerHooks (bool enable) 
{
    if (enable && !triggers_hooked) 
    {
        triggers_hooked = true;
        HookEntityOutput("trigger_multiple", "OnStartTouch", OnBakedStartTouch);
        HookEntityOutput("trigger_multiple", "OnEndTouch", OnBakedEndTouch);
    }
    else if (!enable && triggers_hooked) 
    {
        triggers_hooked = false;
        UnhookEntityOutput("trigger_multiple", "OnStartTouch", OnBakedStartTouch);
        UnhookEntityOutput("trigger_multiple", "OnEndTouch", OnBakedEndTouch);
    }
}

void DrawLaserBox(float start[3], float end[3], int color[4], float life, bool force) {
    
    float point[8][3];
    float size = 3.0;
    
    point[0][0] = end[0];
    point[0][1] = end[1];
    point[0][2] = start[2];
    
    point[1][0] = start[0];
    point[1][1] = end[1];
    point[1][2] = start[2];
    
    point[2][0] = end[0];
    point[2][1] = start[1];
    point[2][2] = start[2];
    
    point[3][0] = start[0];
    point[3][1] = start[1];
    point[3][2] = start[2];
    
    point[4][0] = end[0];
    point[4][1] = end[1];
    point[4][2] = end[2] + ORIGIN_BUFFER;
    
    point[5][0] = start[0];
    point[5][1] = end[1];
    point[5][2] = end[2] + ORIGIN_BUFFER;
    
    point[6][0] = end[0];
    point[6][1] = start[1];
    point[6][2] = end[2] + ORIGIN_BUFFER;
    
    point[7][0] = start[0];
    point[7][1] = start[1];
    point[7][2] = end[2] + ORIGIN_BUFFER;
    
    TE_SetupBeamPoints(point[4], point[5], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[4], point[6], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[7], point[6], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[7], point[5], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[0], point[1], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[0], point[2], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[0], point[4], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[3], point[2], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[3], point[1], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[3], point[7], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[1], point[5], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
    TE_SetupBeamPoints(point[2], point[6], g_beam, 0, 0, 0, life, size, size, 0, 0.0, color, 0); TE_SendToAllowed(force, 0.0);
}

void TE_SendToAllowed(bool force, float delay) 
{
    if (force) 
    {
        return TE_SendToAll(delay);
    }

    int total_clients = 0;
    int[] clients = new int[MaxClients];
    
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsClientInGame(i) && g_show_user_triggers[i]) 
        {
            clients[total_clients++] = i;
        }
    }
    
    return TE_Send(clients, total_clients, delay);
}