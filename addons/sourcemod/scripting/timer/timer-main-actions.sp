public Action OnPlayerRunCmd(int client, int &buttons, &impulse, float vel[3], float angles[3], &weapon)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
    {
        return Plugin_Continue;
    }

    if (g_mapPrehopMode == JumpLimit_Disabled)
    {
        return Plugin_Continue;
    }
    int flags = GetEntityFlags(client);

    if (buttons & IN_JUMP)
    {

        if (flags & FL_ONGROUND)
        {
            HandlePlayerJump(client);
        }
    }
    else
    {
        if (flags & FL_ONGROUND)
        {
            if (g_userPrehopLimiter[client] < 5)
                g_userPrehopLimiter[client]++;

            else if (g_userPrehops[client] != 0)
            {
                g_userPrehops[client] = 0;
            }
        }
    }

    return Plugin_Continue;
}

void HandlePlayerJump(int client)
{
    //Dont prevent prehops on linear checkpoints.
    if (!g_mapStaged && (g_userMode[client] == Timer_Map && g_userZone[client] > 1))
    {
        return;
    }

    if (g_userInZone[client] && (g_userMode[client] != Timer_Stopped) || g_mapPrehopMode == JumpLimit_Everywhere)
    {

        g_userPrehopLimiter[client] = 0;
        g_userPrehops[client]++;

        if (g_userPrehops[client] >= DEFAULT_MAX_PREHOPS)
        {

            g_userPrehops[client] = 0;
            StopPlayerPrehop(client);
        }
    }
}

void StopPlayerPrehop(int client)
{
    PrintTimerMessage(client, "<warning>Warning | <message>Prehop limit reached!");
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
}

public Action PrehopTimer(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
        {
            continue;
        }

        if (g_userPrehopLimiter[client] > 0)
        {
            g_userPrehopLimiter[client] -= 1;
        }
    }
}

public void ConVarChanged_VelocityLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{

    g_mapVelocityLimit = convar.IntValue;
    return;
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetClientMode(client, Timer_Stopped);

    if (g_userResumeAllowed[client])
    {
        PrintTimerMessage(client, "<info>Info |<message> Type <desc>!resume <message>to continue your run.");
    }
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{

    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    BackupUserResumeStats(client);
    SetClientMode(client, Timer_Stopped);
}

stock void PrePrintTimerMessage(int client, const char[] message, any...)
{

    char buffer[256];
    VFormat(buffer, sizeof buffer, message, true);

    if (g_pluginChatLoaded)
    {
        PrintTimerMessage(client, buffer);
    }
    else
    {
        PrintToChat(client, buffer);
    }
}
stock void PrePrintTimerMessageAll(int client, const char[] message, any...)
{

    char buffer[256];
    VFormat(buffer, sizeof buffer, message, true);

    if (g_pluginChatLoaded)
    {
        PrintTimerMessageAll(client, buffer);
    }
    else
    {
        PrintToChatAll(buffer);
    }
}

stock void PrePrintTimerMessageSpecs(int client, const char[] message, any...)
{
    char buffer[256];
    VFormat(buffer, sizeof buffer, message, true);

    if (g_pluginChatLoaded)
    {
        PrintTimerMessageSpecs(client, buffer);
    }
    else
    {
        PrintToChat(client, buffer);
    }
}

bool BackupUserResumeStats(int client)
{
    if (!g_mapStaged || !(g_userMode[client] == Timer_Map && g_userZone[client] > 1))
    {
        return false;
    }

    g_userResumeAllowed[client] = true;
    g_userResumeZone[client] = g_userZone[client];
    g_userResumeTempTime[client] = g_userTempTime[client];
    g_userResumeTempCPTimes[client] = g_userCPTimes[client];
    g_userResumeTempSCPTime[client] = g_userSCPTimes[client];
    g_userResumeTempVelocity[client] = g_userCPVelocity[client];

    return true;
}

stock void EmitSoundToAllowed(char[] sound)
{
    for (int client = 1; client <= MaxClients; client++)
    {

        if (!IsClientInGame(client))
        {
            continue;
        }

        if (g_userSoundsEnabled[client])
        {
            EmitSoundToClient(client, sound);
        }
    }
}

bool GetEventSound(bool isRecord, int stage, int type, char[] sound, int maxlength)
{
    if (isRecord)
    {
        if (stage == 0)
        {
            Format(sound, maxlength, "%s", g_soundMapRecord);
            return true;
        }

        else if (type == 1)
        {

            Format(sound, maxlength, "%s", g_soundBonusRecord);
            return true;
        }

        else
        {
            Format(sound, maxlength, "%s", g_soundStageRecord);
            return true;
        }
    }
    else
    {
        if (stage == 0)
        {
            Format(sound, maxlength, "%s", g_soundMapComp);
            return true;
        }

        else if (type == 1)
        {
            Format(sound, maxlength, "%s", g_soundBonusComp);
        }
    }

    return false;
}
