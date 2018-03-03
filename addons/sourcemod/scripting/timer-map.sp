#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ripext>
#include <timer>
#include <timer-map>
#include <timer-map-methodmaps>
#include <easy-request>

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

//Map
MapInfo g_map_info;
char g_map_name[32];
bool g_round_started;

//Zoning
int g_grid_size[MAXPLAYERS + 1];
bool g_grid_snapping[MAXPLAYERS + 1];

ZoneType g_draw_zone_type[MAXPLAYERS + 1];
DrawMode g_draw_zone_mode[MAXPLAYERS + 1];
int g_draw_zone_value[MAXPLAYERS + 1];
bool g_draw_zone_maxvel[MAXPLAYERS + 1];
float g_draw_zone_start[MAXPLAYERS + 1][3];
float g_draw_zone_end[MAXPLAYERS + 1][3];
char g_draw_zone_filter[MAXPLAYERS + 1][32];

//Zones
ArrayList/*<Zone>*/ g_zones;
bool g_zones_loaded;
int g_total_zones;
int g_beam_type;
bool g_baked_triggers_hooked;
bool g_show_triggers[MAXPLAYERS + 1];

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
    description = "Handles map configuration for timer.", 
    version = PLUGIN_VERSION, 
    url = "http://www.sourcemod.net/"
};

public void OnPluginStart() 
{
    LoadTranslations("timer-map.phrases");
    cvar_api_url = CreateConVar("timer_api_url", "", "The API URL");
    cvar_api_key = CreateConVar("timer_api_key", "", "The API key");
    AutoExecConfig(true);

    event_zone_enter = CreateGlobalForward("OnTimerZoneEnter", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    event_zone_exit = CreateGlobalForward("OnTimerZoneExit", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    event_map_info_update = CreateGlobalForward("OnMapInfoUpdate", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    RegAdminCmd("sm_triggername", Command_TriggerName, ADMFLAG_ROOT);
    RegAdminCmd("sm_tn", Command_TriggerName, ADMFLAG_ROOT);
    RegAdminCmd("sm_filtername", Command_FilterName, ADMFLAG_ROOT);
    RegAdminCmd("sm_insertmap", Command_InsertMap, ADMFLAG_ROOT);
    RegAdminCmd("sm_zonemenu", Command_ZoneMenu, ADMFLAG_ROOT);
    RegAdminCmd("sm_prehopmode", Command_SetPrehopMode, ADMFLAG_ROOT);
    RegConsoleCmd("sm_triggers", Command_ShowTriggers);

    g_zones = new ArrayList();

    switch(GetEngineVersion()) 
    {
        case Engine_TF2:  
        {
            HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_Post);
            HookEvent("arena_round_start", OnRoundStart, EventHookMode_Post);
        } 
        case Engine_CSGO:  
        {
            HookEvent("round_freeze_end", OnRoundStart, EventHookMode_Post);
        } 
        default:  
        {
            HookEvent("round_start", OnRoundStart, EventHookMode_Post);
        }
    }
}

public void OnMapStart() 
{
    PrecacheModel("models/error.mdl", true);
    g_beam_type = PrecacheModel("materials/sprites/physbeam.vmt");
    
    GetCurrentMap(g_map_name, sizeof(g_map_name));
    g_round_started = false;
    g_zones_loaded = false;
    g_total_zones = 0;
    g_baked_triggers_hooked = false;

    for (int i = 0; i < g_zones.Length; i++) 
    {
        Zone zone = g_zones.Get(i);
        delete zone;
    }

    g_zones.Clear();

    if (g_map_info != null) 
    {
        delete g_map_info; 
        g_map_info = null;
    }

    //late laod
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i))
        {
            OnClientPostAdminCheck(i);	
        }	
    }

    if (api_found)
    {
        LoadMapConfiguration();
    }

    CreateTimer(STATIC_ZONE_REFRESH, DrawZone, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) 
{
    g_round_started = true;
    
    if (g_zones_loaded) 
    {
        DestroyAllTriggers();
        DeployAllZones();
    }
    
    return Plugin_Handled;
}

public void OnMapEnd() 
{
    if (g_baked_triggers_hooked)
    {
        HookBakedTriggers(false);
    }
}

//Map loading process
public void OnConfigsExecuted() 
{   
    cvar_api_url.GetString(api_url, sizeof(api_url));
    cvar_api_key.GetString(api_key, sizeof(api_key));
    
    char key[128];
    Format(key, sizeof key, "Token %s", api_key);

    http_client = new HTTPClient(api_url);
    http_client.SetHeader("Authorization", key);
    
    if (!api_found) 
    {
        FindWebAPI();
    }
}

public void OnClientPostAdminCheck(int client) 
{
    g_show_triggers[client] = false;
    g_draw_zone_value[client] = 0;
    g_draw_zone_maxvel[client] = false;
    g_draw_zone_type[client] = Zone_Unknown;	
    g_grid_size[client] = DEFAULT_GRID_SNAP;
    g_grid_snapping[client] = true;
}

void FindWebAPI()
{
    http_client.Get("maps/", OnWebAPIFound);
}

public void OnWebAPIFound(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_OK) 
    { 
        LogError("Invalid Response on Map Ping. Response %i.", response.Status);
        api_found = false;
        return; 
    } 

    api_found = true;
    LoadMapConfiguration();
}

void LoadMapConfiguration() 
{

    int arg_size = (str_len(g_map_name) * 3) + 1;
    char[] formatted_arg = char[arg_size];
    URLEncode(g_map_name, formatted_arg, arg_size);

    char buffer[128];
    Format(buffer, sizeof(buffer), "maps/?name=%s", arg_size);
    http_client.Get(buffer, OnMapLoad);
}

public void OnMapLoad(HTTPResponse response, any value)
{
    ResponseInfo response_info;
    JSONArray results = GetGetResponseResultsArray(response, info, "map");

    if (response_info == Request_EmptyResultSet)
    {
        InsertMap();
        return;
    }
    else if (response_info != Request_Success)
    {
        return;
    }

    g_map_info = results.Get(0);
    delete results;

    if (g_map_info.enable_baked_triggers && !g_baked_triggers_hooked) 
    {
        HookBakedTriggers(true);
    }

    LoadZones();
}

void InsertMap()
{
    MapInfo map = new MapInfo();
    map.SetName(g_map_name);
    http_client.Post("maps/", map, OnMapInsert);
    delete map;
}

public void OnMapInsert(HTTPResponse response, any value) 
{
    ResponseInfo response_info;
    JSONObject json_object = GetPostResponseObject(response, info, "map");

    if (response_info != Request_Success) 
    {   
        return;
    } 

    g_map_info = view_as<MapInfo>(json_object);

    if (g_map_info.enable_baked_triggers && !g_baked_triggers_hooked) 
    {
        HookBakedTriggers(true);
    }
    
    LoadZones();
}

void LoadZones() 
{
    /* In case of plugin reload */
    if (g_round_started) 
    {
        DestroyAllTriggers();
    }

    char buffer[128];
    Format(buffer, sizeof buffer, "maps/zones/?map=%i", g_map_info.id);
    http_client.Get(buffer, OnZonesLoaded);
}

public void OnZonesLoaded(HTTPResponse response, any value) 
{
    ResponseInfo response_info;
    JSONArray results = GetGetResponseResultsArray(response, info, count, "zone");

    if (response_info != Request_Success) 
    {   
        return;
    } 

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

int AddZoneToCache(Zone zone) 
{
    g_zones.Push(zone);
    return g_total_zones++;
}

public Action Command_ShowTriggers(int client, int args) 
{
    g_show_triggers[client] = !g_show_triggers[client];
    PrintToChat(client, "%t", g_show_triggers[client] ? "Enabled Trigger" : "Disabled Trigger");
}

//set custom trigger name
public Action Command_TriggerName(int client, int args) 
{
    if (!args)
    {
        PrintToChat(client, "%t", "No Argument");
        return;
    }

    char name[32];
    GetCmdArgString(name, sizeof(name));
    ZoneType type = ProcessLegacyZoneString(name, sizeof(name), g_draw_zone_value[client], g_draw_zone_maxvel[client]);
    
    if (type != Zone_Unknown)
    {
        g_draw_zone_type[client] = type;
        PrintToChat(client, "%t", "Zone Info Set");
        ShowZoneMenu(client);
    }
    else
    {
        PrintToChat(client, "%t", "Invalid Zone Name", name);
        return; 
    }
}

//set custom trigger filter
public Action Command_FilterName(int client, int args) 
{
    if (!args) 
    {
        Format(g_draw_zone_filter[client], sizeof(g_draw_zone_filter[]), "");
        PrintToChat(client, "%t", "Zone Cache Cleared");
        return;
    }
    
    GetCmdArgString(g_draw_zone_filter[client], sizeof(g_draw_zone_filter[]));
    PrintToChat(client, "%t", "Filter Name Set", g_draw_zone_filter[client]);
}

public Action Command_SetPrehopMode(int client, int args) 
{
	if (g_map_info == null) 
    {
		return;
	}

	if (!args) 
    {
		return;
	}
	
	char cmode[12];
	GetCmdArg(1, cmode, sizeof cmode);
	int mode = StringToInt(cmode);

	if (mode >= 0 && mode < sizeof(zone_type_names)) 
    {
		g_map_info.prevent_prehop = view_as<bool>(mode);
		char buffer[128];
		Format(buffer, sizeof buffer, "maps/%i/", g_map_info.id);
		http_client.Put(buffer, g_map_info, OnMapUpdate);		
	}
}

public Action Command_InsertMap(int client, int args)
{
    if (g_map_info == null) 
    {
        return;
    }

    if (args !=  6) 
    {
        PrintToChat(client, "%t", "Insert Map Help");
        return;
    }

    char author[32], difficulty[16], type[16], checkpoints[16], bonuses[16], baked_triggers[16];

    GetCmdArg(1, difficulty, sizeof difficulty);
    GetCmdArg(2, checkpoints, sizeof checkpoints);
    GetCmdArg(3, type, sizeof type);
    GetCmdArg(4, author, sizeof author);
    GetCmdArg(5, bonuses, sizeof bonuses);
    GetCmdArg(6, baked_triggers, sizeof baked_triggers);
    
    g_map_info.SetAuthor(author);
    g_map_info.difficulty = StringToInt(difficulty);
    g_map_info.type = view_as<MapType>(StringToInt(type));
    g_map_info.checkpoints = StringToInt(checkpoints);
    g_map_info.bonuses = StringToInt(bonuses);
    g_map_info.enable_baked_triggers = view_as<bool>(StringToInt(baked_triggers));
    g_map_info.active = true;

    char buffer[128];
    Format(buffer, sizeof buffer, "maps/%i/", g_map_info.id);
    http_client.Put(buffer, g_map_info, OnMapUpdate);
    CallMapLoadEvent();

    HookBakedTriggers(g_map_info.enable_baked_triggers);
}

public void OnMapUpdate(HTTPResponse response, any value) 
{
	if (response.Status != HTTPStatus_OK) 
    { 
		LogError("Invalid Response on Map Update");
		return; 
	} 
}

public Action Command_ZoneMenu(int client, int args) 
{
    ShowZoneMenu(client);
}

void ShowZoneMenu(int client)
{
    Menu menu = new Menu(MenuHandler_ZoneMenu);
    char title[128];
    Format(title, sizeof(title), "<Draw Zone Menu>\n \n");
    Format(title, sizeof(title), "%sType: %s \n \n", title, zone_type_names[view_as<int>(g_draw_zone_type[client]) + 1]);
    Format(title, sizeof(title), "%sValue: %i \n \n", title, g_draw_zone_value[client]);
    Format(title, sizeof(title), "%sFilter: %s \n \n", title, g_draw_zone_filter[client]);
    Format(title, sizeof(title), "%sVelocity Limit: %s \n \n", title, g_draw_zone_maxvel[client] ? "True" : "False");
    Format(title, sizeof(title), "%sSnapping: %i \n \n", title, g_grid_size[client]);

    menu.SetTitle(title);
    menu.AddItem("", "[Start Draw]");
    menu.AddItem("", "[End Draw]");
    menu.AddItem("", "[Upload] \n \n");
    
    if (g_grid_snapping[client]) 
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
    
    menu.AddItem("", "Zone List\n ");
    menu.AddItem("", "Reset\n ");
    menu.AddItem("", "Close");
    menu.Pagination = MENU_NO_PAGINATION;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneMenu(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        if (choice == MenuChoice_StartDraw)
        {
            StartZoneDraw(client);
            ShowZoneMenu(client);
        }

        else if (choice == MenuChoice_EndDraw)
        {
            EndZoneDraw(client);
            ShowZoneMenu(client);
        }

        else if (choice == MenuChoice_Upload)
        {
            SaveZone(client);
            ShowZoneMenu(client);
        }

        else if (choice == MenuChoice_ToggleSnapping)
        {
            g_grid_snapping[client] = !g_grid_snapping[client];
            ShowZoneMenu(client);
        }

        else if (choice == MenuChoice_IncreaseGrid)
        {
            g_grid_size[client] = g_grid_size[client] < MAX_SNAP_LIMIT ? g_grid_size[client] * 2 : MAX_SNAP_LIMIT;
            ShowZoneMenu(client);
        }

        else if (choice == MenuChoice_DecreaseGrid)
        {
            g_grid_size[client] = RoundToCeil(g_grid_size[client] / 2.0);
            ShowZoneMenu(client);
        }

        else if (choice == MenuChoice_ZoneList)
        {
            ShowZoneList(client); 
        }

        else if (choice == MenuChoice_Reset)
        {
            g_draw_zone_mode[client] = DrawMode_Stopped;
            ShowZoneMenu(client);
        }
    }

    else if (action == MenuAction_End) 
    {
        delete menu;
    }

    return 0;
}

void StartZoneDraw(int client) 
{
    if (g_draw_zone_mode[client] != DrawMode_Active) 
    {
        CreateTimer(0.1, DrawDevZone, client, TIMER_REPEAT);
        g_draw_zone_mode[client] = DrawMode_Active;
    }
    
    if (g_grid_snapping[client])
    {
        GetClientSnappedOrigin(client, g_draw_zone_start[client], g_grid_size[client], true);
    }
    else
    {
        GetClientAbsOrigin(client, g_draw_zone_start[client]);
    }

    ShowZoneMenu(client);
}

void EndZoneDraw(int client) 
{    
    g_draw_zone_mode[client] = DrawMode_Frozen;

    if (g_grid_snapping[client])
    {
        GetClientSnappedOrigin(client, g_draw_zone_end[client], g_grid_size[client], true);
    }
    else 
    {
        GetClientAbsOrigin(client, g_draw_zone_end[client]);
    }

    ShowZoneMenu(client);
}

void SaveZone(int client) 
{   
    g_draw_zone_mode[client] = DrawMode_Stopped;
    
    Zone zone = new Zone();
    zone.value = g_draw_zone_value[client];
    zone.type = g_draw_zone_type[client];
    zone.velocity = g_draw_zone_maxvel[client];
    zone.map = g_map_info.id;
    zone.SetFilterName(g_draw_zone_filter[client]);
    zone.SetStartCoordinates(g_draw_zone_start[client]);
    zone.SetEndCoordinates(g_draw_zone_end[client]);
    
    int index = AddZoneToCache(zone);
    StoreZone(client, zone, index);
    DeployZone(index);
    PrintToChat(client, "%t", "Zone Created");
}

void StoreZone(int client, Zone zone, int index) 
{
    http_client.Post("maps/zones/", zone, OnZoneInserted, index);
}

public void OnZoneInserted(HTTPResponse response, any value) 
{
    ResponseInfo response_info;
    JSONObject json_object = GetPostResponseObject(response, req_response, "zone");
    
    if (response_info != Request_Success) 
    {
        return;
    }

    PrintToChatAll("%t", "Zone Inserted", zone.id);
    Zone zone = view_as<Zone>(json_object);
    Zone active_zone = view_as<Zone>(g_zones.Get(value));

    active_zone.id = zone.id;
    delete zone;
}

void DeleteZone(int client, int zoneID) 
{
	//Mark as deleted
	for (int i = 0; i < g_zones.Length; i++) 
    {
		Zone zone = view_as<Zone>(g_zones.Get(i));
		if (zone.id == zoneID) 
        {
			zone.id = -1;
			break;	
		}	
	}

	//Send request
	char buffer[128];
	Format(buffer, sizeof buffer, "zones/%i", zoneID);
	http_client.Delete(buffer, OnZoneDelete, client);
}

public void OnZoneDelete(HTTPResponse response, any data)
{
	if (response.Status != HTTPStatus_OK) 
    { 
		LogError("Invalid Response on zone deletion");
		return; 
	}
	
	if ( data > -1 ) 
    {
		PrintToChat(data, "<info>Info |<message> Zone deleted. Changes will take effect on next map load.");
	}
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
    
    for (int i = 0; i < g_total_zones; i++) 
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

void ShowZoneInfo(int client, int index) 
{    
    float start[3], end[3];
    char filter[32], zone_id[10], buffer[384];
    
    Zone zone = g_zones.Get(index);
    zone.GetStartCoordinates(start);
    zone.GetEndCoordinates(end);
    zone.GetFilterName(filter, sizeof filter);
    
    FormatEx(zone_id, sizeof zone_id, "%i", zone.id);
    Format(buffer, sizeof(buffer), "<Custom Zone>\n \n");
    Format(buffer, sizeof(buffer), "%sZone ID: %i\n \n", buffer, zone.id);
    Format(buffer, sizeof(buffer), "%sFilter: %s\n \n", buffer, filter);
    Format(buffer, sizeof(buffer), "%sStart: %.1f %.1f %.1f\n \n", buffer, start[0], start[1], start[2]);
    Format(buffer, sizeof(buffer), "%sEnd: %.1f %.1f %.1f\n \n", buffer, end[0], end[1], end[2]);

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
            ShowZoneList(client);
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

public Action DrawDevZone(Handle Timer, any data) 
{
    switch (g_draw_zone_mode[data]) 
    {
        case DrawMode_Stopped:
        {
            return Plugin_Stop;
        }
        case DrawMode_Active:  
        {
            float temp_zone_max[3];

            if (g_grid_snapping[data]) 
                GetClientSnappedOrigin(data, temp_zone_max, g_grid_size[data], true);
            else 
                GetClientAbsOrigin(data, temp_zone_max);
                
            DrawLaserBox(g_draw_zone_start[data], temp_zone_max, {255, 255, 255, 255}, 0.1, true);
        }
        case DrawMode_Frozen:  
        {
            DrawLaserBox(g_draw_zone_start[data], g_draw_zone_end[data], {120, 80, 30, 255}, 0.1, true);
        }
    }

    return Plugin_Continue;
}

public Action DrawZone(Handle Timer) 
{
    if (!g_zones_loaded || !g_round_started) 
    {
        return Plugin_Continue;
    }
    
    for (int i = 0; i < g_total_zones; i++) 
    {	
        float start[3], end[3];
        Zone zone = g_zones.Get(i);
        zone.GetStartCoordinates(start);
        zone.GetEndCoordinates(start);

        DrawLaserBox(start, end, {0, 128, 192, 255}, 1.0, false);
    }
    
    return Plugin_Continue;
}

void DeployAllZones() 
{
    for (int i = 0; i < g_total_zones; i++)
    {
        DeployZone(i);
    }
}

void DeployZone(int i) 
{
    Zone zone = g_zones.Get(i);
    char trigger_name[18], filter[56];
    float start[3], end[3];
    
    FormatEx(trigger_name, sizeof(trigger_name), "timer_zone_%i", i);
    zone.GetFilterName(filter, sizeof(filter));
    zone.GetStartCoordinates(start);
    zone.GetEndCoordinates(end);
    
    CreateEngineTrigger(start, end, "trigger_multiple", trigger_name, filter);
}

void CreateEngineTrigger(float start[3], float end[3], char[] type, char[] name, char[] filter) 
{   
    end[2] += ORIGIN_BUFFER;

    //get center of box
    float center[3] = 0.0;
    SubtractVectors(start, end, center);
    ScaleVector(center, 0.5);
    AddVectors(end, center, center);   

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

stock void DestroyTrigger(int index) 
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

void HookBakedTriggers(bool enable) 
{
    if (enable && !g_baked_triggers_hooked) 
    {
        g_baked_triggers_hooked = true;
        HookEntityOutput("trigger_multiple", "OnStartTouch", OnBakedStartTouch);
        HookEntityOutput("trigger_multiple", "OnEndTouch", OnBakedEndTouch);
    }
    else if (!enable && g_baked_triggers_hooked) 
    {
        g_baked_triggers_hooked = false;
        UnhookEntityOutput("trigger_multiple", "OnStartTouch", OnBakedStartTouch);
        UnhookEntityOutput("trigger_multiple", "OnEndTouch", OnBakedEndTouch);
    }
}

void DrawLaserBox(float start[3], float end[3], int color[4], float lifetime, bool force) 
{   
    end[2] += ORIGIN_BUFFER;
    float vertices[6][3];

    for (int i = 0; i < 3; i++)
    {
        vertices[i] = start;
        vertices[i][i]= end[i];	
        vertices[i+3] = end;
        vertices[i+3][i] = start[i];

        DrawBeam(start, vertices[i], color, lifetime, force);
        DrawBeam(end, vertices[i + 3], color, lifetime, force);
    }

    DrawBeam(vertices[0], vertices[4], color, lifetime, force);
    DrawBeam(vertices[0], vertices[5], color, lifetime, force);
    DrawBeam(vertices[1], vertices[5], color, lifetime, force);

    DrawBeam(vertices[3], vertices[1], color, lifetime, force);
    DrawBeam(vertices[3], vertices[2], color, lifetime, force);
    DrawBeam(vertices[4], vertices[2], color, lifetime, force);
    end[2] -= ORIGIN_BUFFER;
}

void DrawBeam(float start[3], float end[3], color[4], float lifetime, bool force)
{
    float size = 3.0;
    TE_SetupBeamPoints(start, end, g_beam_type, 0, 0, 0, lifetime, size, size, 0, 0.0, color, 0); 
    
    if (force)
    {
        TE_SendToAll(0.0);
    }
    else
    {
        TE_SendToAllowed(0.0);
    }
}

void TE_SendToAllowed(float delay) 
{
    int total_clients = 0;
    int[] clients = new int[MaxClients];
    
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsClientInGame(i) && g_show_triggers[i]) 
        {
            clients[total_clients++] = i;
        }
    }
    
    return TE_Send(clients, total_clients, delay);
}

public void OnCustomStartTouch(const char[] output, int caller, int client, float delay) 
{	
	if (!isValidClient(client)) 
    {
		return;
	}
	
	char trigger_name[32];
	GetEntPropString(caller, Prop_Data, "m_iName", trigger_name, sizeof trigger_name);
	ReplaceString(trigger_name, sizeof trigger_name, "timer_zone_", "");
	int index = StringToInt(trigger_name);
	
	Zone zone = g_zones.Get(index);
	int fix_value = zone.value;
	
	if (zone.type == Zone_End && fix_value <= 0) 
    {
		fix_value = g_map_info.checkpoints;
	}
	
	Call_StartForward(event_zone_enter);
	Call_PushCell(client);
	Call_PushCell(zone.type);
	Call_PushCell(fix_value);
	Call_PushCell(zone.velocity);
	Call_Finish();
}

public void OnCustomEndTouch(const char[] output, int caller, int client, float delay) 
{	
	if (!isValidClient(client)) 
    {
		return;
	}
	
	char trigger_name[32];
	GetEntPropString(caller, Prop_Data, "m_iName", trigger_name, sizeof(trigger_name));
	ReplaceString(trigger_name, sizeof(trigger_name), "timer_zone_", "");
	int index = StringToInt(trigger_name);
	
	Zone zone = g_zones.Get(index);
	int fix_value = zone.value;
	
	if (zone.type == Zone_End && fix_value <= 0) 
    {
		fix_value = g_map_info.checkpoints;
	}
	
	Call_StartForward(event_zone_exit);
	Call_PushCell(client);
	Call_PushCell(zone.type);
	Call_PushCell(fix_value);
	Call_PushCell(zone.velocity);
	Call_Finish();
}

public void OnBakedStartTouch(const char[] output, int caller, int client, float delay) 
{	
	if (!isValidClient(client)) 
    {
		return;
	}
	
	char trigger_name[64]; int value; bool velocity_enabled;
	GetEntPropString(caller, Prop_Data, "m_iName", trigger_name, sizeof trigger_name);
	ZoneType type = ProcessLegacyZoneString(trigger_name, sizeof trigger_name, value, velocity_enabled);
	
	if (type == Zone_Unknown) 
    {
		return;
	}
	
	Call_StartForward(event_zone_enter);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_PushCell(value);
	Call_PushCell(velocity_enabled);
	Call_Finish();
}

public void OnBakedEndTouch(const char[] output, int caller, int client, float delay) 
{
	if (!isValidClient(client)) 
    {
		return;
	}
	
	char trigger_name[64]; int value; bool velocity_enabled;
	GetEntPropString(caller, Prop_Data, "m_iName", trigger_name, sizeof trigger_name);
	ZoneType type = ProcessLegacyZoneString(trigger_name, sizeof trigger_name, value, velocity_enabled);
	
	if (type == Zone_Unknown) 
    {
		return;
	}
	
	Call_StartForward(event_zone_exit);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_PushCell(value);
	Call_PushCell(velocity_enabled);
	Call_Finish();
}

//sorry
ZoneType ProcessLegacyZoneString(char[] trigger_name, int max_length, int &value, bool &max_velocity) 
{	
	value = -1;
	max_velocity = false;
	
	if (TruncateStringSearch(trigger_name, max_length, "cst_")) 
    {	
		if (strcmp(trigger_name, "tele", true) == 0) 
        {
			return Zone_Tele;
		}
		
		else if (strcmp(trigger_name, "nextstage", true) == 0) 
        {
			return Zone_NextStage;
		}
		
		else if (strcmp(trigger_name, "restart", true) == 0) 
        {
			return Zone_Restart;
		}
		
		else if (TruncateStringSearch(trigger_name, max_length, "tostage ")) 
        {
			value = StringToInt(trigger_name);
			return Zone_ToStage;
		}
		
		else if (TruncateStringSearch(trigger_name, max_length, "tobonus ")) 
        {
			value = StringToInt(trigger_name);
			return Zone_ToBonus;
		}
		
		else if (TruncateStringSearch(trigger_name, max_length, "nojump")) 
        {
			return Zone_NoJump;
		}
	}
	
	else if (TruncateStringSearch(trigger_name, max_length, "maxvelsoft")) 
    {	
		value = StringToInt(trigger_name);
		return Zone_MaxVelocitySoft;
	}
	
	else if (TruncateStringSearch(trigger_name, max_length, "maxvel ")
		 || TruncateStringSearch(trigger_name, max_length, "vt_mv ")) 
    {
		value = StringToInt(trigger_name);
		return Zone_MaxVelocity;
	}
	
	else if (strcmp(trigger_name, "end_zone", true) == 0) 
    {
		value = g_map_info.checkpoints;
		return Zone_End;
	}
	
	else if (strcmp(trigger_name, "start_zone", true) == 0) 
    {	
		value = 1;
		max_velocity = true;
		return Zone_Start;
	}
	
	else if (strcmp(trigger_name, "start_zone TH", false) == 0) 
    {	
		value = 1;
		return Zone_Start;
	}
	
	else if (TruncateStringSearch(trigger_name, max_length, "stage")) 
    {	
		value = StringToInt(trigger_name);

		if (ReplaceString(trigger_name, max_length, "_start", "", false)) 
        {	
			max_velocity = (ReplaceString(trigger_name, max_length, " TH", "", false) == 0);
			return Zone_Start;
		}
		else if (ReplaceString(trigger_name, max_length, "_end", "", false)) 
        {
			return Zone_End;
		}

		return Zone_Unknown;
	}
	
	else if (TruncateStringSearch(trigger_name, max_length, "bonus")) 
    {	
		value = StringToInt(trigger_name);
		
		if (ReplaceString(trigger_name, max_length, "_start", "", false)) 
        {	
			max_velocity = (ReplaceString(trigger_name, max_length, " TH", "", false) == 0);
			return Zone_BStart;
		}
		else if (ReplaceString(trigger_name, max_length, "_end", "", false)) 
        {
			return Zone_BEnd;
		}

		return Zone_Unknown;
	}
	
	else if (TruncateStringSearch(trigger_name, max_length, "checkpoint_")) 
    {
		value = StringToInt(trigger_name) + 1;
		return Zone_Start;
	}
	
	return Zone_Unknown;
}

bool TruncateStringSearch(char[] buffer, int max_length, const char[] search) 
{
	int search_size = strlen(search);
	int index;

	for (index = 0; index < max_length; index++) 
    {
		if (index >= search_size) 
        {
			break;
		} 

		if (buffer[index] != search[index]) 
        {
			return false;
		}
	}

	for (index = 0; index < max_length; index++) 
    {
		if (index + search_size < max_length) 
        {
			buffer[index] = buffer[index + search_size];
		}
		else 
        {
			buffer[index] = 0;
			break;
		}
	}
	return true;
}

void CallMapLoadEvent() 
{	
    Call_StartForward(event_map_info_update);
    Call_PushCell(g_map_info.id);
    Call_PushCell(g_map_info.checkpoints);
    Call_PushCell(g_map_info.bonuses);
    Call_PushCell(g_map_info.type);
    Call_PushCell(g_map_info.difficulty);
    Call_PushCell(g_map_info.prevent_prehop);
    Call_PushCell(g_map_info.active);
    Call_Finish();
}

public int nativecall_getMapInfo(Handle plugin, int numParams) 
{	
    SetNativeCellRef(1, g_map_info.id);
    SetNativeCellRef(2, g_map_info.checkpoints);
    SetNativeCellRef(3, g_map_info.bonuses);
    SetNativeCellRef(4, g_map_info.type);
    SetNativeCellRef(5, g_map_info.difficulty);
    SetNativeCellRef(6, g_map_info.prevent_prehop);
    
    return (g_map_info.active && g_zones_loaded);
}