#if defined _timer_included_
#endinput
#endif
#define _timer_included_

#define PLUGIN_AUTHOR "malt / TheDeathly"
#define PLUGIN_VERSION "2.04"

#define DEFAULT_DB_CONFIG ""

#define MAX_STAGES 32
#define MAX_BONUSES 10
#define MAX_TOPTIMES 10
#define DEFAULT_PRECISION 3

#define UPDATE_URL    "http://resurfed.com/updater/timer/updatefile.txt"
stock float ZERO_VECTOR[3];

enum TimeType {
	TimeType_Map,
	TimeType_Stage,
	TimeType_Bonus
}

enum JumpLimit {
	JumpLimit_Disabled, 
	JumpLimit_Spawns,
	JumpLimit_Everywhere
}

stock char jumpLimitNames[3][] = { "JumpLimit_Disabled", "JumpLimit_Spawns", "JumpLimit_Everywhere" };

//FormatStandardTime
stock void FormatTimeFloat(float time, char[] buffer, int maxlength) 
{
    int hours;
    int minutes;

    if (time >= 3600.0)
    {
        hours = RoundToFloor(time / 3600.0);
        Format(buffer, maxlength, "%02i:", hours);
        time -= hours * 3600.0;
    }

    if (time >= 60.0)
    {
        minutes = RoundToFloor(time / 60.0);
    }

    Format(buffer, maxlength, "%s%02i:", buffer, minutes);
    Format(buffer, maxlength, "%s%05.2f", buffer, time);
}

stock void FormatComparision(float time, float compare_time, char[] buffer, maxlength) 
{
    char time_buffer[16];
    FormatTimeFloat(FloatAbs(compare_time - time), time_buffer, sizeof(time_buffer));
    Format(buffer, maxlength, "%s%s", time < compare_time ? "-" : "+", time_buffer);
}

stock void AbsVector(float vector[3]) 
{
    for (int i = 0; i < 3; i ++) 
    {
        vector[i] = FloatAbs(vector[i]);
    }
}

stock void GetClientSnappedOrigin(int client, float vector[3], int grid, bool ignore_height) 
{
    GetClientAbsOrigin(client, vector);    
    int size = ignore_height ? sizeof(vector) : sizeof(vector) - 1;
   
    for (int i = 0; i < size; i++) 
    {
        vector[i] = RoundToNearest(vector[i] / float(grid)) * float(grid);
    }
}

stock bool IsValidClient(int client, bool bots_valid = false) 
{
	if (client <= 0 
		|| client > MaxClients 
		|| !IsValidEntity(client)
		|| !IsClientConnected(client) 
		||  ( !bots_valid && IsFakeClient(client))
		|| !IsClientInGame(client)) {
			return false;  
		}

	return true;  
}

stock void StringToVector(float vector[3], char[] coordinateString, char[] delimiter) 
{
	char cords[3][56];

	ExplodeString(coordinateString, delimiter, cords, sizeof cords, sizeof cords[]);
	for (int i = 0; i < 3; i++) 
    {
		vector[i] = StringToFloat(cords[i]);
	}

	return;
}

stock void VectorToString(char[] buffer, int maxlength, float vector[3], char[] delimiter) 
{
	Format(buffer, maxlength, "%f%s%f%s%f", vector[0], delimiter, vector[1], delimiter, vector[2]);
	return;
}

stock int ClientFromName(char[] search_name, bool skipBots=true) 
{
	char name[32];

	for (int i = 1; i <= MaxClients; i++)
    {
		if (!IsClientConnected(i)) 
        {
			continue;
		}
		
		if (skipBots && IsFakeClient(i)) 
        {
			continue;
		}		

		GetClientName(i, name, sizeof name);
		if ( StrContains(name, search_name, false) != -1) 
        {
			return i;
		}
	}
	return -1;
}

stock void URLEncode(char[] buffer, char[] url, int maxlength)
{
	char letter;
	int i = 0, url_index = 0;

	while ((letter = buffer[i++]))
	{
		if ((letter >= '0' && letter <= '9') 
		|| (letter >= 'A' && letter <= 'Z') 
		|| (letter >= 'a' && letter <= 'z') 
		|| letter == '~' || letter == '_' || letter == '-' || letter == '.') 
		{
			if (url_index + 1 >= maxlength)
			{
				break;
			}

			url[url_index] = letter;
			url_index++;
			continue;
		}

		if (url_index + 3 >= maxlength) {
			break;
		}

		url[url_index] = '%';
		url_index++;

		/* Encode hex digit as url */
		url[url_index] = GetBase16Character((letter >> 4) & 0xF);
		url_index++;

		url[url_index] = GetBase16Character(letter & 0xF);
		url_index++;
	}
	url[url_index] = 0;
}

char GetBase16Character(int num)
{
	const char[] hex = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

	if (num >= 0 && num < 16)
	{
		return hex[num];
	}

	return 0;
}