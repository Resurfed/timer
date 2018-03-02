#if defined _timer_main_included_
#endinput
#endif
#define _timer_main_included_

#define DEFAULT_MAX_PREHOPS 2
#define PREHOP_RESET_TIME 0.2
#define AVERAGE_JUMPTIME 1.6
#define MAX_HUDCONFIG_LENGTH 16
#define DEFAULT_CSGO_HUD "AG#c|M#EH"
#define DEFAULT_SOURCE_HUD "a# #c# #E"

#define CSGO_HUDCOLOR_TIME "#99FF66"
#define CSGO_HUDCOLOR_SPEED "#FFFF99"
#define CSGO_HUDCOLOR_SPECS "#C291FF"

enum TimerMode
{
    Timer_Disabled,
    Timer_Stopped,
    Timer_Map,
    Timer_Bonus,
    Timer_Practice
};

enum HudElement
{
    HudElem_Time = 0,
    HudElem_TimeSimple,
    HudElem_Activity,
    HudElem_ActivitySimple,
    HudElem_Zone,
    HudElem_ZoneSimple,
    HudElem_CurrentMap,
    HudElem_XYVelocity,
    HudElem_XYVelocitySimple,
    HudElem_XYZVelocity,
    HudElem_XYZVelocitySimple,
    HudElem_RecordComparision,
    HudElem_RecordComparisionSimple,
    HudElem_RecordVelocityComparision,
    HudElem_PersonalComparision,
    HudElem_PersonalComparisionSimple,
    HudElem_PersonalVelocityComparision,
    HudElem_MapRecord,
    HudElem_PersonalRecord,
    HudElem_Character,
    HudElem_NewLine,
    HudElem_Total
}

forward OnPlayerMapStart(int client);
forward OnPlayerMapEnd(int client, bool isImprove, bool isRecord, float playerTime, float mapTime);
forward OnPlayerMapRanked(int client, int rank, int completions, int recordingID, int recordingRank);

forward OnPlayerStageStart(int client, int zone, bool inRun);
forward OnPlayerStageEnd(int client, int zone, bool isImprove, bool isRecord, float playerTime, float mapTime, bool inRun);
forward OnPlayerStageRanked(int client, int zone, int rank, int completions, int recordingID, int recordingRank);

forward OnPlayerBonusStart(int client, int zone);
forward OnPlayerBonusEnd(int client, int zone, bool isImprove, bool isRecord, float playerTime, float mapTime);
forward OnPlayerBonusRanked(int client, int zone, int rank, int completions, int recordingID, int recordingRank);
forward OnPlayerTimerLoad(int client, int playerID);

forward OnTimerToggle(int client, bool isNowEnabled);

forward OnServerIDLoaded(int serverID);

/**
 * Checks if timer is enabled.
 *
 * @param client    	The client to get the difficulty for.
 *
 * @return Timer enabled value.
 */

native IsTimerEnabled(client);

native GetServerID();

public
SharedPlugin __pl_timer_main =
    {
        name = "timer-main",
        file = "timer-main.smx",
#if defined REQUIRE_PLUGIN
        required = 1,
#else
        required = 0,
#endif
};

public __pl_timersurf_timer_SetNTVOptional()
{
    MarkNativeAsOptional("Timer_IsEnabled");
}
