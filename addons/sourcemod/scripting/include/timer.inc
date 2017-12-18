#if defined _timer_included_
#endinput
#endif
#define _timer_included_

#define PLUGIN_AUTHOR "malt / TheDeathly"
#define PLUGIN_VERSION 2.04

stock float ZERO_VECTOR[3];

stock void FormatTime(float time, char[] buffer, int maxlength) 
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

stock void FormatTimeComparision(float time, float compare_time, char[] buffer, maxlength) 
{
    char time_buffer[16];
    FormatTime(FloatAbs(compare_time - time), time_buffer, sizeof(time_buffer));
    Format(buffer, maxlength, "%s%s", time < compare_time ? "-" : "+", time_buffer);
}

stock void AbsVector(float vector[3]) 
{
    for (int i = 0; i < 3; i ++) 
    {
        vector[i] = FloatAbs(vector[i]);
    }
}

stock void GetClientSnappedOrigin(int client, float vector[3], int grid_size, bool ignore_height) 
{
    GetClientAbsOrigin(client, vector);    
    int size = ignore_height ? sizeof(vector) : sizeof(vector) - 1;
   
    for (int i = 0; i < size; i++) 
    {
        vector[i] = RoundToNearest(vector[i] / grid_size) * grid_size;
    }
}