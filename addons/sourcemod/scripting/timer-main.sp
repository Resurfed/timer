#include <sourcemod>
#include <sdktools>
#include <ripext>
#include <timer>
#include <timer-map>
#include <timer-main>
#include <timersurf-chat>
#include <mastersocket>
#include <updater>
#include <easy-request>

// Plugin 
Database g_database;
EngineVersion g_engine;
bool g_pluginChatLoaded = false;

// ConVars
ConVar g_cvar_velocityLimit;
ConVar g_cvar_hudRefreshRate;
ConVar g_cvar_soundMapComp;
ConVar g_cvar_soundBonusComp;
ConVar g_cvar_soundMapRecord;
ConVar g_cvar_soundStageRecord;
ConVar g_cvar_soundBonusRecord;

// Server
char g_serverIP[32];
ServerInfo g_server;

// Map Info
bool g_mapStaged;
bool g_mapAnyStaged;
bool g_mapLoaded;
bool g_mapTimesLoaded;

char g_currentMap[32];

int g_mapID;
int	g_mapZones;
int	g_mapBonuses;
JumpLimit g_mapPrehopMode;

int g_mapVelocityLimit;

// Map Spawns
float g_spawnStageAngles[MAX_STAGES + 1][3];
float g_spawnStageOrigin[MAX_STAGES + 1][3];
float g_spawnStageVelocity[MAX_STAGES + 1][3];
float g_spawnBonusAngles[MAX_BONUSES][3];
float g_spawnBonusOrigin[MAX_BONUSES][3];
float g_spawnBonusVelocity[MAX_BONUSES][3];

// Client Info 
int g_userID[MAXPLAYERS + 1];
bool g_userLoaded[MAXPLAYERS + 1];

// Client Trackers
bool g_userTimerEnabled[MAXPLAYERS + 1];
bool g_userInRun[MAXPLAYERS + 1];
bool g_userInZone[MAXPLAYERS + 1];

bool g_userFixInZone[MAXPLAYERS + 1];
int g_userFixZone[MAXPLAYERS + 1];
int g_userFixType[MAXPLAYERS + 1];
int g_userZone[MAXPLAYERS + 1];
TimerMode g_userMode[MAXPLAYERS + 1];

int g_userPrehops[MAXPLAYERS + 1];
int g_userPrehopLimiter[MAXPLAYERS + 1];

// Client Temp Times
float g_userTempTime[MAXPLAYERS + 1];
float g_userSTempTime[MAXPLAYERS + 1];
float g_userTempCPTimes[MAXPLAYERS + 1][MAX_STAGES + 1];
float g_userTempSCPTimes[MAXPLAYERS + 1][MAX_STAGES + 1];
float g_userTempCPVelocity[MAXPLAYERS + 1][MAX_STAGES + 1];

// Client Best Times
float g_userStageTimes[MAXPLAYERS + 1][MAX_STAGES + 1];
float g_userBonusTimes[MAXPLAYERS + 1][MAX_BONUSES];
float g_userCPTimes[MAXPLAYERS + 1][MAX_STAGES + 1];
float g_userSCPTimes[MAXPLAYERS + 1][MAX_STAGES + 1]; 
float g_userCPVelocity[MAXPLAYERS + 1][MAX_STAGES + 1];

// Client ResumeRun Cache
bool g_userResumeAllowed[MAXPLAYERS + 1];
int g_userResumeZone[MAXPLAYERS + 1];
float g_userResumeTempTime[MAXPLAYERS + 1];
float g_userResumeTempCPTimes[MAXPLAYERS + 1][MAX_STAGES + 1];
float g_userResumeTempSCPTime[MAXPLAYERS + 1][MAX_STAGES + 1];
float g_userResumeTempVelocity[MAXPLAYERS + 1][MAX_STAGES + 1];

// Map Best Times
char g_mapStageName[MAX_STAGES + 1][32];
char g_mapBonusName[MAX_BONUSES][32];
int g_mapStageUserID[MAX_STAGES + 1];

float g_mapStageTimes[MAX_STAGES + 1];
float g_mapBonusTimes[MAX_BONUSES];
float g_mapCPTimes[MAX_STAGES + 1];
float g_mapSCPTimes[MAX_STAGES + 1];
float g_mapCPVelocity[MAX_STAGES + 1];

// Client Options
bool g_userHudEnabled[MAXPLAYERS + 1];
bool g_userPanelEnabled[MAXPLAYERS + 1 ];
bool g_userSoundsEnabled[MAXPLAYERS + 1];
bool g_userTelehopEnabled[MAXPLAYERS + 1];
bool g_userUnsavedChanged[MAXPLAYERS + 1];

int g_userChatColorScheme[MAXPLAYERS + 1];
char g_hudConfigText[MAXPLAYERS + 1][MAX_HUDCONFIG_LENGTH];

// Client Extras
int g_userSpecs[MAXPLAYERS + 1];
bool g_userHiddenSpec[MAXPLAYERS + 1];

// Timer Events
Handle g_event_mapStart;
Handle g_event_mapEnd;
Handle g_event_stageStart;
Handle g_event_stageEnd;
Handle g_event_bonusStart;
Handle g_event_bonusEnd;
Handle g_event_mapRanked;
Handle g_event_stageRanked;
Handle g_event_bonusRanked;
Handle g_event_playerLoad;
Handle g_event_timerToggle;
Handle g_event_serverIDLoaded;

//Sounds
char g_soundMapComp[64];
char g_soundBonusComp[64];
char g_soundMapRecord[64];
char g_soundBonusRecord[64];
char g_soundStageRecord[64];

// Other Extras
ArrayList g_array_schemeNames;
int g_loadedColorSchemes;

public Plugin myinfo =
{
	name = "TimerSurf | Timer",
	author = PLUGIN_AUTHOR,
	description = "Handles the timer configuration for TimerSurf.",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	CreateNative("IsTimerEnabled", Native_GetEnabledValue);
	CreateNative("GetServerID", Native_GetServerID); 
	RegPluginLibrary("timersurf-timer");
	return APLRes_Success;
}

public void OnPluginStart() 
{
	LoadTranslations("timersurf.phrases");
	g_engine = GetEngineVersion();
	CreateConnection();

	/* Sounds */
	g_cvar_velocityLimit = CreateConVar("ts_zone_maxvelocity", "360", "Maximum velocity for exiting a zone.");
	g_cvar_hudRefreshRate = CreateConVar("ts_hud_refreshrate", "0.5", "Refresh rate of users center hud.");
	g_cvar_soundMapComp = CreateConVar("ts_sound_mapcompletion", "", "Sound to play on map completion.");
	g_cvar_soundBonusComp = CreateConVar("ts_sound_bonuscompletion", "", "Sound to play on bonus completion.");
	g_cvar_soundMapRecord = CreateConVar("ts_sound_maprecord", "", "Sound to play on map record.");
	g_cvar_soundStageRecord = CreateConVar("ts_sound_stagerecord", "", "Sound to play on stage record.");
	g_cvar_soundBonusRecord = CreateConVar("ts_sound_bonusrecord", "", "Sound to play on bonus record.");

	/* Forwards / Natives*/
	g_event_mapStart = CreateGlobalForward("OnPlayerMapStart", ET_Event, Param_Cell);
	g_event_mapEnd = CreateGlobalForward("OnPlayerMapEnd", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float);
	g_event_mapRanked = CreateGlobalForward("OnPlayerMapRanked", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_event_stageStart = CreateGlobalForward("OnPlayerStageStart", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_event_stageEnd = CreateGlobalForward("OnPlayerStageEnd", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
	g_event_stageRanked = CreateGlobalForward("OnPlayerStageRanked", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_event_bonusStart = CreateGlobalForward("OnPlayerBonusStart", ET_Event, Param_Cell, Param_Cell);
	g_event_bonusEnd = CreateGlobalForward("OnPlayerBonusEnd", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float);
	g_event_bonusRanked = CreateGlobalForward("OnPlayerBonusRanked", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_event_playerLoad = CreateGlobalForward("OnPlayerTimerLoad", ET_Event, Param_Cell, Param_Cell);
	g_event_timerToggle = CreateGlobalForward("OnTimerToggle", ET_Event, Param_Cell, Param_Cell);
	g_event_serverIDLoaded = CreateGlobalForward("OnServerIDLoaded", ET_Event, Param_Cell);
	
	/* Commands */
	RegConsoleCmd("sm_b", Command_ToBonus, "Timer | Teleport to selected bonus");
	RegConsoleCmd("sm_bonus", Command_ToBonus, "Timer | Teleport to selected bonus");
	RegConsoleCmd("sm_gb", Command_GoBack, "Timer | Teleport to previous stage");
	RegConsoleCmd("sm_goback", Command_GoBack, "Timer | Teleport to previous stage");
	RegConsoleCmd("sm_r", Command_Restart, "Timer | Restart the map");
	RegConsoleCmd("sm_restart", Command_Restart, "Timer | Restart the map");
	RegConsoleCmd("sm_resume", Command_ResumeRun, "Timer | Continue saved run after disabling timer or going to spectate");
	RegConsoleCmd("sm_s", Command_ToStage, "Timer | Teleport to selected stage");
	RegConsoleCmd("sm_stage", Command_ToStage, "Timer | Teleport to selected stage");
	RegConsoleCmd("sm_teleport", Command_Teleport, "Timer | Restart current stage / map");
	RegConsoleCmd("sm_timer", Command_ToggleTimer, "Timer | Disables / Enables your timer");
	RegConsoleCmd("sm_options", Command_Options, "Timer | Shows timer configuration options");
	RegConsoleCmd("sm_hudconfig", Command_SetHudConfig, "Timer | Modify your center hud");
	RegConsoleCmd("sm_stop", Command_StopTimer, "Timer | Stops your timer");
	RegConsoleCmd("sm_specinfo", Command_SpecInfo, "Timer | View your spectators");
	RegConsoleCmd("sm_hidespec", Command_HideSpec, "Timer | Hides you from spectator list");
	RegConsoleCmd("sm_checkpoint", Command_ShowCheckpoint, "Timer | Shows selected player's checkpoint");
	RegConsoleCmd("sm_cp", Command_ShowCheckpoint, "Timer | Shows selected player's checkpoint");
	RegConsoleCmd("sm_hud", Command_HideHud, "Timer | Hide players hud.")
	RegConsoleCmd("sm_leaderboard", Command_Leaderboard, "");

	RegAdminCmd("sm_setspawn", Command_SetSpawn, ADMFLAG_ROOT);
	RegAdminCmd("sm_setbspawn", Command_SetBonusSpawn, ADMFLAG_ROOT);
	RegAdminCmd("sm_prehopmode", Command_SetPrehopMode, ADMFLAG_ROOT);

	/* Event Hooks */
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookConVarChange(g_cvar_velocityLimit, ConVarChanged_VelocityLimit);
	
	GetServerIP(g_serverIP, sizeof g_serverIP);
	Format(g_serverIP, sizeof g_serverIP, "%s:%i", g_serverIP, GetServerPort());

	AutoExecConfig(true, "timersurf-timer");
	
	if (LibraryExists("updater")) {
        Updater_AddPlugin(UPDATE_URL)
   	}
}

#include "timer\timer-main-base.sp"
#include "timer\timer-main-db.sp"
#include "timer\timer-main-hud.sp"
#include "timer\timer-main-commands.sp"
#include "timer\timer-main-actions.sp"
#include "timer\timer-main-leaderboard.sp"


public void OnLibraryAdded(const char[] name) 
{
	if (StrEqual(name, "timersurf-chat")) 
    {
		g_pluginChatLoaded = true;
	}
	
	if (StrEqual(name, "updater")) 
    {
        Updater_AddPlugin(UPDATE_URL)
    }
}

public void OnLibraryRemoved(const char[] name) 
{
	if (StrEqual(name, "timersurf-chat")) 
    {
		g_pluginChatLoaded = false;
	}
}

public void OnMapStart() 
{
	CreateTimer(g_cvar_hudRefreshRate.FloatValue, HUDTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	CreateTimer(2.0, TrackerTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	GetCurrentMap(g_currentMap, sizeof g_currentMap);
	ClearMapVariables();

    //sounds
	g_cvar_soundBonusRecord.GetString(g_soundBonusRecord, sizeof g_soundBonusRecord);
	g_cvar_soundStageRecord.GetString(g_soundStageRecord, sizeof g_soundStageRecord);
	g_cvar_soundMapRecord.GetString(g_soundMapRecord, sizeof g_soundMapRecord);
	g_cvar_soundMapComp.GetString(g_soundMapComp, sizeof g_soundMapComp);
	g_cvar_soundBonusComp.GetString(g_soundBonusComp, sizeof g_soundBonusComp);

    //sounds must be precached before use
	if (g_soundBonusRecord[0]) 
    {
		PrecacheSound(g_soundBonusRecord, true)
	}
	if (g_soundStageRecord[0]) 
    {
		PrecacheSound(g_soundStageRecord, true);
	}
	if (g_soundMapRecord[0]) 
    {
		PrecacheSound(g_soundMapRecord, true);
	}
	if (g_soundMapComp[0]) 
    {
		PrecacheSound(g_soundMapComp, true);
	}
	if (g_soundBonusComp[0]) 
    {
		PrecacheSound(g_soundBonusComp, true);
	}

	//Plugin late load
	int mapID, stages, bonuses, mapType, tier, prehop;
	if (GetTimerMapInfo(mapID, stages, bonuses, mapType, tier, prehop)) 
    {
		g_mapID = mapID;
		g_mapZones = stages;
		g_mapBonuses = bonuses;
		g_mapStaged = (mapType != 1);//1 is linear
		g_mapAnyStaged = (mapType == 2);//2 is any-order staged map
		g_mapPrehopMode = view_as<JumpLimit>(prehop);
		g_mapLoaded = true;
	}	

	if (g_database != null) 
    {
		LoadMapConfiguration();
	}
}

public void OnClientPostAdminCheck(client) 
{
	ClearUserVariables(client);
	LoadUser(client);
}

public int OnTimerMapLoad(int mapID, int stages, int bonuses, int mapType, int tier, int prehop, bool active) 
{ 
	g_mapLoaded = active;
	g_mapID = mapID;
	g_mapZones = stages;
	g_mapBonuses = bonuses;
	g_mapStaged = (mapType != 1);//1 is linear
	g_mapAnyStaged = (mapType == 2);//2 is any-order staged map
	g_mapPrehopMode = view_as<JumpLimit>(prehop);
	return 0;
}

void ClearMapVariables() 
{
	g_mapID = 0;
	g_mapZones = 0;
	g_mapBonuses = 0;
	g_mapPrehopMode = JumpLimit_Disabled;
	g_mapLoaded = false;
	g_mapTimesLoaded = false;

	if (g_server != null)
	{
		delete g_server;
		g_server = null;
	}

	for (int i = 0; i < MAX_STAGES + 1; i++) 
    {
		g_spawnStageAngles[i] = ZERO_VECTOR;
		g_spawnStageOrigin[i] = ZERO_VECTOR;
		g_spawnStageVelocity[i] = ZERO_VECTOR;

		g_mapStageName[i] = "";
		g_mapStageUserID[i] = 0;
		g_mapStageTimes[i] = 0.0;
		g_mapCPTimes[i] = 0.0;
		g_mapSCPTimes[i] = 0.0;
		g_mapCPVelocity[i] = 0.0;
	}

	for (int i = 0; i < MAX_BONUSES; i++) 
    {
		g_spawnBonusAngles[i] = ZERO_VECTOR;
		g_spawnBonusOrigin[i] = ZERO_VECTOR;
		g_spawnBonusVelocity[i] = ZERO_VECTOR;
		g_mapBonusName[i] = "";
		g_mapBonusTimes[i] = 0.0;
	}
	
	g_Leaderboard_times = new ArrayList(20, MAX_RANKS);
	g_Leaderboard_clients = new ArrayList(30, MAX_RANKS);
	g_Leaderboard_names = new ArrayList(30, MAX_RANKS);
	
	for (new i = 0; i < g_Leaderboard_clients.Length; i++)
	{
		g_Leaderboard_times.Set(i, 0.0);
		g_Leaderboard_clients.Set(i, 0);
		g_Leaderboard_names.SetString(i, "");
	}

	g_mapVelocityLimit = g_cvar_velocityLimit.IntValue;
}

void ClearUserVariables(int client) 
{
	g_userID[client] = 0;
	g_userLoaded[client] = false;
	g_userTimerEnabled[client] = true;
	g_userInRun[client] = false;
	g_userInZone[client] = false;
	g_userZone[client] = 0;
	g_userMode[client] = Timer_Stopped;
	g_userTempTime[client] = 0.0;
	g_userSTempTime[client] = 0.0;

	g_userResumeAllowed[client] = false;
	g_userResumeZone[client] = false;
	g_userResumeTempTime[client] = 0.0;

	for (int i = 0; i < MAX_STAGES+1; i++) 
    {
		g_userTempCPTimes[client][i] = 0.0;
		g_userTempSCPTimes[client][i] = 0.0;
		g_userStageTimes[client][i] = 0.0;
		g_userCPTimes[client][i] = 0.0;
		g_userSCPTimes[client][i] = 0.0;
		g_userTempCPVelocity[client][i] = 0.0;
		g_userCPVelocity[client][i] = 0.0;

		g_userResumeTempCPTimes[client][i] = 0.0;
		g_userResumeTempSCPTime[client][i] = 0.0;
		g_userResumeTempVelocity[client][i] = 0.0;
	}
	
	for (int i = 0; i < MAX_BONUSES; i++) 
    {
		g_userBonusTimes[client][i] = 0.0;
	}
	
	g_userHudEnabled[client] = true;
	g_userPanelEnabled[client] = true;
	g_userSoundsEnabled[client] = true;
	g_userTelehopEnabled[client] = true;

	g_userHiddenSpec[client] = false;
	g_userChatColorScheme[client] = 0;
	g_userUnsavedChanged[client] = false;

	g_userFixInZone[client] = false;
	g_userFixZone[client] = -1;
	g_userFixType[client] = -1;

	g_userPrehops[client] = 0;
	g_userPrehopLimiter[client] = 0;

	if (g_engine == Engine_CSGO) 
    {
		Format(g_hudConfigText[client], sizeof g_hudConfigText[], DEFAULT_CSGO_HUD);
	}
	else 
    {
		Format(g_hudConfigText[client], sizeof g_hudConfigText[], DEFAULT_SOURCE_HUD);
	}
}