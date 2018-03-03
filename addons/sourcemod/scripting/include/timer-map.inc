#if defined _timer_map_included_
#endinput
#endif
#define _timer_map_included_

#define ORIGIN_BUFFER 100
#define DEFAULT_GRID_SNAP 32
#define MAX_SNAP_LIMIT 256
#define STATIC_ZONE_REFRESH 0.5

enum DrawMode 
{
	DrawMode_Stopped  = -1,
	DrawMode_Frozen,
	DrawMode_Active,
};

enum ZoneType 
{
	Zone_Unknown = -1,
	Zone_Start,
	Zone_End, 
	Zone_BStart,
	Zone_BEnd,
	Zone_Tele,
	Zone_NextStage,
	Zone_ToStage,
	Zone_ToBonus,
	Zone_Restart,
	Zone_MaxVelocity,
	Zone_MaxVelocitySoft,
	Zone_NoJump
};

char zone_type_names[13][] = 
{
    "Unknown", 
    "Zone Start", 
    "Zone End", 
    "Bonus Start", 
    "Bonus End", 
    "Restart Stage", 
    "To Next Stage", 
    "To Stage #", 
    "To Bonus #", 
    "Restart Map", 
    "Max Velocity", 
    "Max Velocity Soft", 
    "No Jump" 
};

enum VoteMenuChoice {
	MenuChoice_StartDraw = 0,
	MenuChoice_EndDraw,
	MenuChoice_Upload,
	MenuChoice_ToggleSnapping,
	MenuChoice_IncreaseGrid,
	MenuChoice_DecreaseGrid,
	MenuChoice_ZoneList,
	MenuChoice_Reset
}

/**
 * Called when a player enters zone.
 *
 * @param client		    Client Index of event activator.
 * @param zone_type		    Zone type [-1 - invalid, 0 - stage, 1 - bonus, 2 - extra].
 * @param zone_number		Zone number value.
 * @param max_velocity		Is max velocity enabled.
 * @noreturn
 */
 forward OnTimerZoneEnter(int client, ZoneType zone_type, int zone_number, bool max_velocity);

 /**
 * Called when a player leaves zone.
 *
 * @param client		    Client Index of event activator.
 * @param zone_type		    Zone type [-1: invalid, 0: stage, 1: bonus, 2: extra].
 * @param zone_number		Zone number value.
 * @param max_velocity		Is max velocity enabled.
 * @noreturn
 */
 forward OnTimerZoneExit(int client, ZoneType zone_type, int zone_number, bool max_velocity);

 /**
 * Called when map information is loaded/changed.
 *
 * @param map_id 		    Database mapid (-1: zone modification)
 * @param stages		    Amount of map stages.
 * @param bonuses           Amount of map bonuses.
 * @param map_type          Map type [0: staged, 1: linear].
 * @param tier			    Map difficulty [1-6].
 * @param prehop            Is there a jump limit.
 * @param active            Is the map active.
 */
forward OnTimerMapLoad(int map_id, int stages, int bonuses, int map_type, int tier, int prehop, bool active);

 /**
 * Get map information related to timer
 *
 * @param map_id            Database mapid
 * @param stages            Amount of map stages.
 * @param bonuses           Amount of map bonuses.
 * @param map_type          Map type [0: staged, 1: linear].
 * @param tier	            Map difficulty [1-6].
 * @param prehop            Is there a jump limit.
 */
native bool GetTimerMapInfo(int &map_id, int &stages, int &bonuses, int &map_type, int &tier, int &prehop);
