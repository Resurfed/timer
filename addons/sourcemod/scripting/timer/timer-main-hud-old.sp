public Action HUDTimer(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        UpdateHUD(client)
    }

    return Plugin_Continue;
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

        if (!IsPlayerAlive(client))
        {

            int mode = GetEntProp(client, Prop_Send, "m_iObserverMode");

            if (mode == 4 || mode == 5)
            {

                int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

                if (isValidClient(target, true) && target >= 0 && target <= MaxClients)
                {
                    g_userSpecs[target]++;
                }
            }
        }
    }
}

void UpdateHUD(int client)
{

    if (!g_mapLoaded || !g_mapTimesLoaded)
    {
        return;
    }

    int target = client;

    if (IsClientObserver(client))
    {

        int observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

        if (observerMode == 4 || observerMode == 5 && !IsClientSourceTV(client) && !IsClientReplay(client))
        {

            target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        }
    }

    if (!isValidClient(target, true) || !isValidClient(client, false))
        return;

    if (!g_userLoaded[target])
    {
        PrintHintText(client, "[User Loading]");
        return;
    }

    char message[216];
    bool isTargetBot = IsFakeClient(target);

    if (g_userPanelEnabled[client] && g_engine != Engine_CSGO)
    {

        Hud_FormatTimeStats(target, message, sizeof message, isTargetBot);
        PrintKeyHintText(client, message);
    }

    if (isTargetBot)
    {
        return;
    }

    Format(message, sizeof message, "");

    if (g_userHudEnabled[client])
    {

        Hud_FormatCenterHud(target, g_hudConfigText[target], message, sizeof message);

        if (g_engine == Engine_CSGO)
        {
            Hud_AddFontTag(message, sizeof message, "");
        }

        PrintHintText(client, message);
    }
}

void Hud_FormatCenterHud(int client, char[] config, char[] message, int maxlength)
{

    int tempLength;
    char buffer[45];
    TimerMode mode = g_userMode[client];
    int zone = g_userZone[client];

    for (int i = 0; i < MAX_HUDCONFIG_LENGTH; i++)
    {

        //i hate this, but i cant really think of a better approach atm so fuck it yolo
        switch (config[i])
        {

        case 'A':
        {

            Hud_GetTime(client, buffer, sizeof buffer);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_TIME);
            }

            if (mode == Timer_Bonus)
            {
                tempLength += FormatEx(message[tempLength], maxlength - tempLength, "Bonus Time: %s ", buffer);
            }
            else if (mode == Timer_Practice && g_mapStaged)
            {
                tempLength += FormatEx(message[tempLength], maxlength - tempLength, "Stage Time: %s ", buffer);
            }
            else
            {
                tempLength += FormatEx(message[tempLength], maxlength - tempLength, "Time: %s ", buffer);
            }
        }

        case 'a':
        {
            Hud_GetTime(client, buffer, sizeof buffer);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_TIME);
            }

            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "%s ", buffer);
        }

        case 'B':
        {

            if ((!g_userInZone[client] && !g_mapStaged && mode == Timer_Map && zone > 1) || (g_mapStaged && !g_userInZone[client]))
            {

                tempLength += FormatEx(message[tempLength], maxlength - tempLength, "Surfing ");
                continue;
            }

            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "In Zone ");
        }
        case 'b':
        {

            if ((!g_userInZone[client] && !g_mapStaged && mode == Timer_Map && zone > 1) || (g_mapStaged && !g_userInZone[client]))
            {
                continue;
            }
            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "In Zone ");
        }

        case 'C':
        {

            Hud_GetZone(client, buffer, sizeof buffer, false);
            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "%s ", buffer);
        }
        case 'c':
        {
            Hud_GetZone(client, buffer, sizeof buffer, true);
            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "%s ", buffer);
        }
        case 'D':
        {
            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "%s ", g_currentMap);
        }

        case 'E':
        {

            Hud_GetVelocity(client, buffer, sizeof buffer, false);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_SPEED);
            }

            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "Speed: %s ", buffer);
        }
        case 'e':
        {
            Hud_GetVelocity(client, buffer, sizeof buffer, false);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_SPEED);
            }

            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "[%s u/s] ", buffer);
        }
        case 'F':
        {
            Hud_GetVelocity(client, buffer, sizeof buffer, true);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_SPEED);
            }

            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "Speed: %s ", buffer);
        }
        case 'f':
        {

            Hud_GetVelocity(client, buffer, sizeof buffer, true);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_SPEED);
            }

            tempLength += FormatEx(message[tempLength], maxlength - tempLength, "[%s u/s] ", buffer);
        }
        case 'G':
        {

            if (mode == Timer_Map && zone > 1)
            {

                float playerTime = g_userTempCPTimes[client][zone - 1];
                float mapBestTime = g_mapCPTimes[zone - 1];
                if (mapBestTime)
                {
                    FormatComparision(playerTime, mapBestTime, buffer, sizeof buffer);
                    tempLength += FormatEx(message[tempLength], maxlength - tempLength, "(Rec. %s) ", buffer);
                }
            }
        }

        case 'g':
        {

            if (mode == Timer_Map && zone > 1)
            {

                float playerTime = g_userTempCPTimes[client][zone - 1];
                float mapBestTime = g_mapCPTimes[zone - 1];

                if (mapBestTime)
                {
                    FormatComparision(playerTime, mapBestTime, buffer, sizeof buffer);
                    tempLength += FormatEx(message[tempLength], maxlength - tempLength, "\n(Rec. %s) ", buffer);
                }
            }
        }

        case 'H':
        {
            if (mode == Timer_Map && zone > 1)
            {

                float playerVelocity = g_userTempCPVelocity[client][zone - 1];
                float mapBestVelocity = g_mapCPVelocity[zone - 1];

                if (mapBestVelocity && !g_mapStaged)
                {

                    if (playerVelocity < mapBestVelocity)
                    {
                        tempLength += FormatEx(message[tempLength], maxlength - tempLength, "(Rec. %.1f u/s) ", playerVelocity - mapBestVelocity);
                    }
                    else
                    {
                        tempLength += FormatEx(message[tempLength], maxlength - tempLength, "(Rec. +%.1f u/s) ", playerVelocity - mapBestVelocity);
                    }
                }
            }
        }
        case 'h':
        {
        }
        case 'I':
        {

            if (mode == Timer_Map && zone > 1)
            {

                float playerTime = g_userTempCPTimes[client][zone - 1];
                float userBestTime = g_userCPTimes[client][zone - 1];

                if (userBestTime)
                {
                    FormatComparision(playerTime, userBestTime, buffer, sizeof buffer);
                    tempLength += FormatEx(message[tempLength], maxlength - tempLength, "(Per. %s) ", buffer);
                }
            }
        }

        case 'i':
        {

            if (mode == Timer_Map && zone > 1)
            {

                float playerTime = g_userTempCPTimes[client][zone - 1];
                float userBestTime = g_userCPTimes[client][zone - 1];

                if (userBestTime)
                {
                    FormatComparision(playerTime, userBestTime, buffer, sizeof buffer);
                    tempLength += FormatEx(message[tempLength], maxlength - tempLength, "\n(Per. %s) ", buffer);
                }
            }
        }
        case 'J':
        {

            if (mode == Timer_Map && zone > 1)
            {

                float playerVelocity = g_userTempCPVelocity[client][zone - 1];
                float userBestVelocity = g_userCPVelocity[client][zone - 1];

                if (userBestVelocity && !g_mapStaged)
                {
                    if (playerVelocity < userBestVelocity)
                    {
                        tempLength += FormatEx(message[tempLength], maxlength - tempLength, "(Per. %.1f u/s) ", playerVelocity - userBestVelocity);
                    }
                    else
                    {
                        tempLength += FormatEx(message[tempLength], maxlength - tempLength, "(Per. +%.1f u/s) ", playerVelocity - userBestVelocity);
                    }
                }
            }
        }

        case 'K':
        {
            FormatTimeFloat(g_mapStageTimes[0], buffer, sizeof buffer);
            tempLength += Format(message[tempLength], maxlength - tempLength, "WR %s ", buffer);
        }
        case 'L':
        {
            FormatTimeFloat(g_userStageTimes[client][0], buffer, sizeof buffer);
            tempLength += Format(message[tempLength], maxlength - tempLength, "PR %s ", buffer);
        }

        case 'M':
        {

            Format(buffer, sizeof buffer, "Specs: %i", g_userSpecs[client]);

            if (g_engine == Engine_CSGO)
            {
                Hud_AddColorTag(buffer, sizeof buffer, CSGO_HUDCOLOR_SPECS);
            }

            tempLength += Format(message[tempLength], maxlength - tempLength, "%s", buffer);
        }

        case '|':
        {
            tempLength += Format(message[tempLength], maxlength - tempLength, "| ");
        }
        case '#':
        {
            tempLength += Format(message[tempLength], maxlength - tempLength, " \n");
        }
        case ' ':
        {
            tempLength += Format(message[tempLength], maxlength - tempLength, " ");
        }
        case '\0':
        {
            break;
        }
        }
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
    else if (mode == Timer_Map && zone == 1 && g_userInZone[client])
    {
        Format(buffer, maxlength, "[Stopped]");
        return;
    }
    else if (g_userInZone[client] && (mode == Timer_Bonus || mode == Timer_Practice))
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

void Hud_GetZone(int client, char[] buffer, int maxlength, bool checkInZone)
{
    TimerMode mode = g_userMode[client];
    int zone = g_userZone[client];

    if (mode == Timer_Stopped)
    {
        Format(buffer, maxlength, "Free Mode");
        return;
    }
    else if (mode == Timer_Bonus)
    {
        Format(buffer, maxlength, "Bonus %i", zone);
    }
    else if (mode == Timer_Map || mode == Timer_Practice)
    {
        //on any-order staged maps, the zone of mapZones + 1 is the hub.  Don't call it a stage
        if (g_mapAnyStaged && zone == g_mapZones + 1)
        {
            Format(buffer, maxlength, "Stage Hub");
        }
        else if (g_mapStaged)
        {
            Format(buffer, maxlength, "Stage %i", zone);
        }
        else
        {
            Format(buffer, maxlength, "Linear Map");
        }
    }

    if (!checkInZone || !g_userInZone[client])
    {
        return;
    }

    // Exclude linear map checkpoints
    if (!g_mapStaged && mode == Timer_Map && zone > 1)
    {
        return;
    }

    Format(buffer, maxlength, "%s Start", buffer);
}

void Hud_GetVelocity(int client, char[] buffer, int maxlength, bool includeVertical)
{

    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

    for (new i = 0; i <= 2; i++)
        velocity[i] *= velocity[i];

    int value;

    if (includeVertical)
    {
        value = RoundToFloor(SquareRoot(velocity[0] + velocity[1] + velocity[2]));
    }
    else
    {
        value = RoundToFloor(SquareRoot(velocity[0] + velocity[1]));
    }

    Format(buffer, maxlength, "%i", value);
}

stock void PrintKeyHintText(int client, char[] buffer)
{

    if (g_engine == Engine_CSGO)
    {
        return;
    }

    Handle hBuffer = StartMessageOne("KeyHintText", client);
    BfWriteByte(hBuffer, 1);
    BfWriteString(hBuffer, buffer);
    EndMessage();

    return;
}

void Hud_FormatTimeStats(int client, char[] buffer, int maxlength, bool isPlayerBot = false)
{

    Format(buffer, maxlength, "Spectators: %i\n \n", g_userSpecs[client]);

    if (isPlayerBot)
    {
        return;
    }

    TimerMode mode = g_userMode[client];
    int zone = g_userZone[client];

    float bestTime;
    float userTime;

    char formattedTime[32];
    char name[32], modeName[32];
    //show bonus times when on bonus
    if (mode == Timer_Bonus)
    {

        userTime = g_userBonusTimes[client][zone - 1];
        bestTime = g_mapBonusTimes[zone - 1];
        Format(name, sizeof name, "%s", g_mapBonusName[zone - 1]);
        Format(modeName, sizeof modeName, "Bonus");
    }
    //show map times when on linear, map start, timer stopped or in the hub of any-order staged map
    else if (!g_mapStaged || zone < 1 || mode == Timer_Stopped || (g_mapAnyStaged && (zone == g_mapZones + 1)))
    {

        userTime = g_userStageTimes[client][0];
        bestTime = g_mapStageTimes[0];
        Format(name, sizeof name, "%s", g_mapStageName[0]);
        Format(modeName, sizeof modeName, "Map");
    }
    else
    {

        userTime = g_userStageTimes[client][zone];
        bestTime = g_mapStageTimes[zone];
        Format(name, sizeof name, "%s", g_mapStageName[zone]);
        Format(modeName, sizeof modeName, "Stage");
    }

    Format(buffer, maxlength, "%sPersonal Record\n", buffer);
    FormatTimeFloat(userTime, formattedTime, sizeof formattedTime);

    if (userTime == 0)
    {
        Format(buffer, maxlength, "%sNone\n \n", buffer);
    }
    else
    {

        Format(buffer, maxlength, "%s%s", buffer, formattedTime);
        FormatComparision(userTime, bestTime, formattedTime, sizeof formattedTime);
        Format(buffer, maxlength, "%s (%s)\n \n", buffer, formattedTime);
    }

    Format(buffer, maxlength, "%s%s Record\n", buffer, modeName);

    if (bestTime == 0)
    {
        Format(buffer, maxlength, "%sNone", buffer);
    }
    else
    {
        FormatTimeFloat(bestTime, formattedTime, sizeof formattedTime);
        Format(buffer, maxlength, "%s%s (%s)", buffer, formattedTime, name);
    }

    return;
}

void Hud_AddColorTag(char[] buffer, int maxlength, char[] hexColor)
{

    Format(buffer, maxlength, "<font color='%s'>%s</font>", hexColor, buffer);
}

void Hud_AddFontTag(char[] buffer, int maxlength, char[] font)
{
    FormatHud(0);
    Format(buffer, maxlength, "<font face='%s'>%s</font>", font, buffer);
}

void FormatHud(int client)
{
    ArrayList hud_elements = new ArrayList(1, 16);
    hud_elements.PushString("FormatHudTime");
    hud_elements.PushString("FormatHudZone");
    hud_elements.PushString("FormatHudVelocity");

    char function_name[32];
    hud_elements.GetString(0, function_name, sizeof(function_name));
    Call_StartFunction(INVALID_HANDLE, GetFunctionByName(INVALID_HANDLE, function_name));
    Call_PushCell(client);
    Call_Finish();
}

void FormatHudTime(int client)
{

}

void FormatHudZone()
{

}

void FormatHudVelocity()
{

}
