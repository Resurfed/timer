public Action HUDTimer(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
        {
            continue;
        }
        UpdateHUD(client)
    }

    return Plugin_Continue;
}

void UpdateHud(int client)
{
    if (!g_mapLoaded || !g_mapTimesLoaded)
    {
        return;
    }

    if (!IsValidClient(client))
    {
        return;
    }

    int target = client;
    int observer_mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
    
    if (observer_mode == OBS_MODE_IN_EYE || observer_mode == OBS_MODE_CHASE)
    {
        target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
    }

    if (!IsValidClient(target))
    {
        return;
    }

    if (!g_userLoaded[target])
    {
        PrintHintText(client, "[User Loading]");
        return;
    }

    if (!g_userHudEnabled[target])
    {
        return;
    }

    char message[256];
    FormatCenterHud(target, message, sizeof(message));
    PrintHintText(client, message);
}

void FormatCenterHud(int client, char message, int maxlength)
{
    int written = 0;
    int length = strlen(g_hudConfigText[target]);
    for (int i = 0; i < length; i++)
    {
        int ielement = g_hudConfigText[target][i];
        if (ielement >= 0 && element < HudElement.total)
        {
            HudElement element = view_as<HudElement>(ielement);
            Call_StartFunction(INVALID_HANDLE, GetHudFormatter(element));
            Call_PassCell(client);
            Call_PassCell(element);
            Call_PushString(message[written]);
            Call_PushCell(maxlength - written);
            written += Call_Finish();
        }
    }
}

function GetHudFormatter(HudElement elemenet)
{
    switch (element)
    {
        case HudElem_Time: return Hud_AppendTime;
        case HudElem_TimeSimple: return Hud_AppendTime;
        case HudElem_Activity: return Hud_AppendActivity;
        case HudElem_ActivitySimple: return Hud_AppendActivity;
        case HudElem_Zone: return Hud_AppendZone;
        case HudElem_ZoneSimple: return Hud_AppendZone;
        case HudElem_CurrentMap: return Hud_AppendCurrentMap;
        case HudElem_XYVelocity: return Hud_AppendVelocity;
        case HudElem_XYVelocitySimple: return Hud_AppendVelocity;
        case HudElem_XYZVelocity: return Hud_AppendVelocity;
        case HudElem_XYZVelocitySimple: return Hud_AppendVelocity;
        case HudElem_RecordComparision: return Hud_AppendCompareRecord;
        case HudElem_RecordComparisionSimple: return Hud_AppendCompareRecord;
        case HudElem_RecordVelocityComparision: return Hud_AppendCompareVelocity;
        case HudElem_PersonalComparision: return Hud_AppendCompareRecord;
        case HudElem_PersonalComparisionSimple: return Hud_AppendCompareRecord;
        case HudElem_PersonalVelocityComparision: return Hud_AppendCompareVelocity;
        case HudElem_MapRecord: return Hud_AppendMapRecord;
        case HudElem_PersonalRecord: return Hud_AppendPersonalRecord;
        case HudElem_Character: return Hud_AppendPipe;
        case HudElem_NewLine: return Hud_AppendLine;
    }
    
    return HudAppendNull;
}

int Hud_AppendTime(int client, HudElement element, char[] message, int maxlength)
{
    Hud_GetTime(client, message, maxlength);

    if (element == Time)
    {
        if (mode == Timer_Bonus)
        {
            return Format(message, maxlength, "Bonus Time: %s ", message);
        }
        else if (mode == Timer_Practice && g_mapStaged)
        {
            return Format(message, maxlength, "Stage Time: %s ", message);
        }
        else
        {
            return Format(message, maxlength, "Time: %s ", message);
        }
    }
    else if (element == TimeSimple)
    {
        return Format(message, maxlength, "%s ", message);
    }
}

void Hud_GetTime(int client, char[] buffer, int maxlength)
{

    if (!g_userTimerEnabled[client])
    {
        Format(buffer, maxlength, "[Disabled]");
        return;
    }

    TimerMode mode = g_userMode[client];
    int zone = g_userZone[client];

    if (mode == Timer_Stopped)
    {
        Format(buffer, maxlength, "[Stopped]");
        return;
    }
    else if (mode == Timer_Map && g_userInZone[client] && zone == 1)
    {
        Format(buffer, maxlength, "[Stopped]");
        return;
    }
    else if ((mode == Timer_Bonus || mode == Timer_Practice) && g_userInZone[client])
    {
        Format(buffer, maxlength, "[Stopped]");
        return;
    }

    char formattedTime[15];
    float currentTime = GetGameTime();
    float playerTime;

    if (mode == Timer_Practice)
    {
        playerTime = currentTime - g_userSTempTime[client];
    }
    else
    {
        playerTime = currentTime - g_userTempTime[client];
    }

    FormatTimeFloat(playerTime, formattedTime, sizeof formattedTime);
    Format(buffer, maxlength, "%s", formattedTime);
}

int Hud_AppendActivity(int client, HudElement element, char[] message, int maxlength)
{

    if ((!g_userInZone[client] && !g_mapStaged && mode == Timer_Map && zone > 1) || (g_mapStaged && !g_userInZone[client]))
    {
        if (element == Activity) 
        {
            return Format(message, maxlength, "Surfing ");
        }
        else 
        {
            return 0;
        }
    }
    return Format(message, maxlength, "In Zone ");
}

int Hud_AppendZone(int client, HudElement element, char[] message, int maxlength)
{
    TimerMode mode = g_userMode[client];
    int zone = g_userZone[client];
    int written = 0;

    if (mode == Timer_Stopped)
    {
        return Format(message, maxlength, "Free Mode");
    }

    else if (mode == Timer_Bonus)
    {
        written += Format(message, maxlength, "Bonus %i", zone);
    }
    
    else if (mode == Timer_Map || mode == Timer_Practice)
    {
        //on any-order staged maps, the zone of mapZones + 1 is the hub.  Don't call it a stage
        if (g_mapAnyStaged && zone == g_mapZones + 1)
        {
            written += Format(message, maxlength, "Stage Hub");
        }
        else if (g_mapStaged)
        {
            written += Format(message, maxlength, "Stage %i", zone);
        }
        else
        {
            written += Format(message, maxlength, "Linear Map");
        }
    }

    if (element == ZoneSimple || !g_userInZone[client])
    {
        return written;
    }

    // Exclude linear map checkpoints
    if (!g_mapStaged && mode == Timer_Map && zone > 1)
    {
        return written;
    }

    written += Format(buffer, maxlength, "%s Start", buffer);
    return written;
}

int Hud_AppendCurrentMap(int client, HudElement element, char[] message, int maxlength)
{
    return Format(message, maxlength, "%s ", g_currentMap);
}

int Hud_AppendVelocity(int client, HudElement element, char[] message, int maxlength)
{
    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

    if (element == XYVelocity || element == XYVelocitySimple)
    {
        velocity[2] = 0;
    }

    int speed = VectorLength(velocity);

    if (element == XYVelocity || element == XYZVelocity)
    {
        return Format(message, maxlength, "Speed: %i ", speed);
    }
    else 
    {
        return Format(message, maxlength, "[%i u/s] ", speed);
    }
}

int Hud_AppendCompareRecord(int client, HudElement element, char[] message, int maxlength)
{
    return 0;
}

int Hud_AppendCompareVelocity(int client, HudElement element, char[] message, int maxlength)
{
    return 0;
}

int Hud_AppendMapRecord(int client, HudElement element, char[] message, int maxlength)
{
    return 0;
}

int Hud_AppendPersonalRecord(int client, HudElement element, char[] message, int maxlength)
{
    return 0;
}

int Hud_AppendPipe(int client, HudElement element, char[] message, int maxlength)
{
    return Format(message, maxlength, "| ");
}

int Hud_AppendLine(int client, HudElement element, char[] message, int maxlength)
{
    return Format(message, maxlength, " \n");
}

int HudAppendNull(int client, HudElement element, char[] message, int maxlength)
{
    return 0;
}

public Action TrackerTimer(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        g_userSpecs[client] = 0;
    }

    for (int client = 1; client <= MaxClients; client++)
    {

        if (!IsClientInGame(client) || IsFakeClient(client) || g_userHiddenSpec[client])
        {
            continue;
        }

        if (IsPlayerAlive(client))
        {
            continue;
        }

        int observer_mode = GetEntProp(client, Prop_Send, "m_iObserverMode");

        if (observer_mode == OBS_MODE_IN_EYE || observer_mode == OBS_MODE_CHASE)
        {
            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

            if (isValidClient(target, true) && target >= 0 && target <= MaxClients)
            {
                g_userSpecs[target]++;
            }
        }
    }
}