#if defined _timer_map_methodmaps_included
 #endinput
#endif
#define _timer_map_methodmaps_included

#include <timer>
#include <ripext>

enum MapType {
	Map_Type_Staged = 0,
	Map_Type_Linear = 1
}
enum TimerMode {

}

methodmap MapInfo < JSONObject 
{
	public MapInfo()
	{
		JSONObject obj = new JSONObject();
		return view_as<MapInfo>(obj);
	}

	property int id
	{
		public get()
		{
			return this.GetInt("id");
		}
		public set(int value)
		{
			this.SetInt("id", value);
		}
	}
	
	property int difficulty
	{
		public get()
		{
			return this.GetInt("difficulty");
		}
		public set(int value)
		{
			this.SetInt("difficulty", value);
		}
	}
	
	property int checkpoints
	{
		public get()
		{
			return this.GetInt("checkpoints");
		}
		public set(int value)
		{
			this.SetInt("checkpoints", value);
		}
	}
	
	property MapType type
	{
		public get()
		{
			return view_as<MapType>(this.GetInt("type"));
		}
		public set(MapType value)
		{
			this.SetInt("type", view_as<int>(value));
		}
	}
	
	property int bonuses
	{
		public get()
		{
			return this.GetInt("bonuses");
		}
		public set(int value)
		{
			this.SetInt("bonuses", value);
		}
	}
	
	property bool active
	{
		public get()
		{
			return view_as<bool>(this.GetInt("active"));
		}
		public set(bool value)
		{
			this.SetInt("active", value);
		}
	}
	
	property bool prevent_prehop 
	{
		public get()
		{
			return view_as<bool>(this.GetInt("prevent_prehop"));
		}
		public set(bool value)
		{
			this.SetInt("prevent_prehop", value);
		}
	}
	
	property bool enable_baked_triggers
	{
		public get()
		{
			return view_as<bool>(this.GetInt("enable_baked_triggers"));
		}
		public set(bool value)
		{
			this.SetInt("enable_baked_triggers", value);
		}
	}
	
	public void GetName(char[] buffer, int size) 
	{
		this.GetString("name", buffer, size);
	}
	
	public void SetName(char[] map_name) 
	{
		this.SetString("name", map_name);
	}
	
	public void GetAuthor(char[] buffer, int size) 
	{
		this.GetString("author", buffer, size);
	}
	
	public void SetAuthor(char[] author) 
	{
		this.SetString("author", author);
	}
}

methodmap Zone < JSONObject 
{
	public Zone()
	{
		JSONObject obj = new JSONObject();
		return view_as<Zone>(obj);	
	}
	
	property int id 
	{
		public get()
		{
			return this.GetInt("id");
		}
		public set(int value)
		{
			this.SetInt("id", value);
		}
	}

	property int value 
	{
		public get()
		{
			return this.GetInt("value");
		}
		public set(int value)
		{
			this.SetInt("value", value);
		}
	}

	property ZoneType type 
	{
		public get()
		{
			return view_as<ZoneType>(this.GetInt("type"));
		}
		public set(ZoneType value)
		{
			this.SetInt("type", view_as<int>(value));
		}
	}

	property int velocity 
	{
		public get()
		{
			return this.GetInt("limit_speed");
		}
		public set(int value)
		{
			this.SetInt("limit_speed", value);
		}
	}
	
	property int map 
	{
		public get()
		{
			return this.GetInt("map");
		}
		public set(int value)
		{
			this.SetInt("map", value);
		}
	}
	
	public void GetTargetName(char[] buffer, int size) 
	{
		this.GetString("target_name", buffer, size);
	}
	
	public void SetTargetName(char[] target_name) 
	{
		this.SetString("target_name", target_name);
	}
	
	public void GetFilterName(char[] buffer, int size) 
	{
		this.GetString("filter_name", buffer, size);
	}
	
	public void SetFilterName(char[] filter_name) 
	{
		this.SetString("filter_name", filter_name);
	}
	
	public void GetStartCoordinates(float vector[3]) 
	{
		char buffer[75];
		this.GetString("start", buffer, sizeof buffer);
		StringToVector(vector, buffer, "|");
	}
	
	public void SetStartCoordinates(float vector[3]) 
	{	
		char buffer[75];
		VectorToString(buffer, sizeof buffer, vector, "|")
		this.SetString("start", buffer);
	}

	public void GetEndCoordinates(float vector[3]) 
	{
		char buffer[75];
		this.GetString("end", buffer, sizeof buffer);
		StringToVector(vector, buffer, "|");
	}
	
	public void SetEndCoordinates(float vector[3]) 
	{
		char buffer[75];
		VectorToString(buffer, sizeof buffer, vector, "|")
		this.SetString("end", buffer);
	}
}

/*
	Methodmap for user timer information.
*/
methodmap Player < JSONObject
{
	public Player()
	{
		JSONObject obj = new JSONObject();
		return view_as<Player>(obj);
	}
	
	property int id 
	{
		public get()
		{
			return this.GetInt("id");
		}
		public set(int value)
		{
			this.SetInt("id", value);
		}
	}
		
	property int zone 
	{
		public get()
		{
			return this.GetBool("zone");
		}
		public set(int value)
		{
			this.SetInt("zone", value);
		}
	}	
	
	property bool in_run 
	{
		public get()
		{
			return this.GetBool("in_run");
		}
		public set(bool value)
		{
			this.SetBool("in_run", value);
		}
	}	
	
	property bool in_zone
	{
		public get()
		{
			return this.GetBool("in_zone");
		}
		public set(bool value)
		{
			this.SetBool("in_zone", value);
		}
	}

	property TimerMode active_mode 
	{
		public get()
		{
			return view_as<TimerMode>(this.GetInt("active_mode"));
		}
		public set(TimerMode value)
		{
			this.SetInt("active_mode", view_as<int>(value));
		}
	}	
	
	public float GetStageTime(int stage)
	{
		char key[16];
		FormatEx(key, sizeof key, "stage_time:%i", stage);
		return this.GetFloat(key);
	}
	
	public void SetStageTime(int stage, float time)
	{
		char key[16];
		FormatEx(key, sizeof key, "stage_time:%i", stage);
		this.SetFloat(key, time);
	}	
	
	public float GetBonusTime(int stage)
	{
		char key[16];
		FormatEx(key, sizeof key, "bonus_time:%i", stage);
		return this.GetFloat(key);	
	}

	public void SetBonusTime(int stage, float time)
	{
		char key[16];
		FormatEx(key, sizeof key, "bonus_time:%i", stage);
		this.SetFloat(key, time);
	}
	
	public float GetCheckpointTime(int checkpoint) {
		char key[16];
		FormatEx(key, sizeof key, "cp_time:%i", checkpoint);
		return this.GetFloat(key);
	}
	
	public void SetCheckpointTime(int checkpoint, float time)
	{
		char key[16];
		FormatEx(key, sizeof key, "cp_time:%i", checkpoint);
		this.SetFloat(key, time);
	}
 
 	public float GetRunStageTime(int stage) {
		char key[16];
		FormatEx(key, sizeof key, "scp_time:%i", stage);
		return this.GetFloat(key);
	}
	
	public void SetRunStageTime(int stage, float time)
	{
		char key[16];
		FormatEx(key, sizeof key, "scp_time:%i", stage);
		this.SetFloat(key, time);
	}
	
	public float GetMapTime()
	{
		return this.GetFloat("map_time");		
	}
	
	public float SetMapTime(float time)
	{
		this.SetFloat("map_time", time);		
	}
}