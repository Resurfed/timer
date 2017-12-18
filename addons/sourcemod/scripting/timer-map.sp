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

ZoneType zone_type[MAXPLAYERS + 1];
DrawMode zone_status[MAXPLAYERS + 1];
bool zone_maxvel[MAXPLAYERS + 1];
float zone_start_location[MAXPLAYERS + 1][3];
float zone_end_location[MAXPLAYERS + 1][3];
char zone_filter[MAXPLAYERS + 1][32];

//Zones
int total_zones;
int beam_type;

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
	int count = json_response.GetInt("count");
 
	if (!count) 
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

public Action Command_TriggerName(int client, int args) 
{

}

public Action Command_FilterName(int client, int args) 
{

}

public Action Command_InsertMap(int client, int args)
{
    
}

public Action Command_ZoneMenu(int client, int args) 
{

}

void CreateEngineTrigger(float start[3], float end[3], char[] type, char[] name, char[] filter) 
{	
	end[2] += ORIGIN_BUFFER;

	//convert start/end vectors from world coordinates to distance from origin
	float center[3] = 0.0;
	GetBoxCenter(end, start, middle);
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
