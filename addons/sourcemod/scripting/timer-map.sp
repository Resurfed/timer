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

    switch (GetEngineVersion()) 
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

#include "zones\timer-map-editor.sp"

public void OnMapStart() 
{
    PrecacheModel("models/error.mdl", true);
    g_beam_type = PrecacheModel("materials/sprites/physbeam.vmt");

    ClearMapVariables();
    GetCurrentMap(g_map_name, sizeof(g_map_name));

    /* In case of late load */
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

    /* Timer for global zone draw */
    CreateTimer(STATIC_ZONE_REFRESH, DrawZone, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void ClearMapVariables()
{
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
    int arg_size = (strlen(g_map_name) * 3) + 1;
    char[] formatted_arg = new char[arg_size];
    URLEncode(g_map_name, formatted_arg, arg_size);

    char buffer[128];
    Format(buffer, sizeof(buffer), "maps/?name=%s", arg_size);
    http_client.Get(buffer, OnMapLoad);
}

public void OnMapLoad(HTTPResponse response, any value)
{
    ResponseInfo response_info;
    JSONArray results = GetGetResponseResultsArray(response, response_info, "map");

    if (response_info == Request_EmptyResultSet)
    {
        InsertMap();
        return;
    }
    else if (response_info != Request_Success)
    {
        return;
    }

    g_map_info = view_as<MapInfo>(results.Get(0));
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
    JSONObject json_object = GetPostResponseObject(response, response_info, "map");

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
    JSONArray results = GetGetResponseResultsArray(response, response_info, "zone");

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
    if (!IsValidClient(client)) 
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
    if (!IsValidClient(client)) 
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
    if (!IsValidClient(client)) 
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
    if (!IsValidClient(client)) 
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