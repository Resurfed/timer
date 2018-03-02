public int OnTimerZoneEnter(int client, ZoneType type, int value, bool maxVel)
{
    if (!g_mapLoaded || !g_mapTimesLoaded)
    {
        return 0;
    }

    if (!IsPlayerAlive(client) || !isValidClient(client) || !g_userLoaded[client])
    {
        return 0;
    }

    switch (type)
    {
        case Zone_Start:
        {
            StageZoneEnter(client, value, false, maxVel);
        }

        // adding one so end zone isn't mistaken for final stage start.
        //don't add one for maps whose stages can be beaten in arbitrary order
        case Zone_End:
        {
            StageZoneEnter(client, value + (g_mapAnyStaged ? 0 : 1), true, maxVel);
        }
        case Zone_BStart:
        {
            BonusZoneEnter(client, value, false, maxVel);
        }
        case Zone_BEnd:
        {
            BonusZoneEnter(client, value, true, maxVel);
        }
        case Zone_Tele:
        {
            RestartUserStage(client);
        }
        case Zone_ToStage:
        {
            TeleportUserToZone(client, value, 0);
        }
        case Zone_ToBonus:
        {
            TeleportUserToZoneSafe(client, value, 1);
        }
        case Zone_NextStage:
        {
            if (g_userMode[client] == Timer_Map || g_userMode[client] == Timer_Practice)
            {
                TeleportUserToZone(client, g_userZone[client] + 1, 0);
            }
        }

        case Zone_Restart:
        {
            TeleportUserToZoneSafe(client, 1, 0);
        }

        case Zone_MaxVelocity:
        {
            if (GetPlayerVelocity(client, false) > value)
            {
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
            }
        }
    }

    return 0;
}

public int OnTimerZoneExit(int client, ZoneType type, int value, bool maxVel)
{
    if (!g_mapLoaded || !g_mapTimesLoaded)
    {
        return 0;
    }

    if (!IsPlayerAlive(client) || !isValidClient(client))
    {
        return 0;
    }

    switch (type)
    {
        case Zone_Start:
        {
            StageZoneExit(client, value, false, maxVel);
        }

        case Zone_End:
        {
            StageZoneExit(client, value + 1, true, maxVel);
        }
        case Zone_BStart:
        {
            BonusZoneExit(client, value, false, maxVel);
        }
        case Zone_BEnd:
        {
            BonusZoneExit(client, value, true, maxVel);
        }
    }

    return 0;
}

void StageZoneEnter(int client, int zone, bool endZone, bool maxVel)
{
    //call a different function for any-order stage maps because the logic is really different
    if (g_mapAnyStaged)
    {
        StageZoneEnterAny(client, zone, endZone, maxVel);
        return;
    }
    if (!g_userLoaded[client] || !g_userTimerEnabled[client])
    {
        return;
    }

    if (zone > MAX_STAGES)
    {
        return;
    }

    SetClientInZone(client, true, 0, zone);

    if (maxVel)
    {
        LimitUserVelocity(client, false);
    }

    // On run start
    if (zone <= 1)
    {

        ClearTempCache(client);
        SetClientMode(client, Timer_Map);
        g_userZone[client] = 1;

        return;
    }

    else if (g_userMode[client] == Timer_Map && g_userZone[client] > zone)
    {
        g_userZone[client] = zone;
    }

    else if (zone <= g_mapZones)
    {

        if (g_userMode[client] == Timer_Stopped || g_userMode[client] == Timer_Bonus)
        {

            SetClientMode(client, Timer_Practice);
            g_userZone[client] = zone;
        }
    }
    //if they came from the previous stage, then they must have beaten the previous stage
    if (g_userZone[client] != zone - 1)
    {
        return;
    }

    g_userZone[client]++;
    endZone = (endZone && zone > g_mapZones);

    float currentTime = GetGameTime();

    float playerTime,
        playerBestTime,
        mapBestTime;

    bool isImprove, isRecord;

    // Stage completion logic
    playerTime = currentTime - g_userSTempTime[client];

    playerBestTime = g_userStageTimes[client][zone - 1];
    mapBestTime = g_mapStageTimes[zone - 1];

    g_userTempSCPTimes[client][zone - 1] = playerTime;

    if (g_mapStaged)
    {

        isImprove = (playerTime < playerBestTime || playerBestTime == 0);
        isRecord = (playerTime < mapBestTime || mapBestTime == 0);

        if (isImprove)
        {

            g_userStageTimes[client][zone - 1] = playerTime;
            StoreTime(client, zone - 1, 0, playerTime);
        }

        if (isRecord)
        {

            g_mapStageTimes[zone - 1] = playerTime;
            GetClientName(client, g_mapStageName[zone - 1], sizeof g_mapStageName);
            g_mapStageUserID[zone - 1] = g_userID[client];
        }

        SendCompletionMessage(client, 0, zone - 1, playerTime, playerBestTime, mapBestTime);

        bool inRun = (g_userMode[client] == Timer_Map);
        CallStageEndEvent(client, zone - 1, isImprove, isRecord, playerTime, mapBestTime, inRun);

        if (endZone && g_userMode[client] == Timer_Practice)
        {
            SetClientMode(client, Timer_Stopped);
            return;
        }
    }

    // Checkpoint Logic
    if (g_userMode[client] != Timer_Map)
    {
        return;
    }

    playerTime = currentTime - g_userTempTime[client];
    playerBestTime = g_userCPTimes[client][zone - 1];
    mapBestTime = g_mapCPTimes[zone - 1];

    g_userTempCPTimes[client][zone - 1] = playerTime;
    g_userTempCPVelocity[client][zone - 1] = GetPlayerVelocity(client, false);

    if (!endZone)
    {
        SendCheckpointMessage(client, zone - 1, playerTime, playerBestTime, mapBestTime);
        return;
    }

    //Map Completion Logic
    playerBestTime = g_userStageTimes[client][0];
    mapBestTime = g_mapStageTimes[0];

    isImprove = (playerTime < playerBestTime || playerBestTime == 0);
    isRecord = (playerTime < mapBestTime || mapBestTime == 0);

    if (isImprove)
    {

        g_userStageTimes[client][0] = playerTime;

        for (int i = 0; i < MAX_STAGES + 1; i++)
        {
            g_userCPTimes[client][i] = g_userTempCPTimes[client][i];
            g_userSCPTimes[client][i] = g_userTempSCPTimes[client][i];

            g_userCPVelocity[client][i] = g_userTempCPVelocity[client][i];
        }

        StoreCPTime(client);
        StoreTime(client, 0, 0, playerTime);
    }

    //Map Record
    if (isRecord)
    {
        g_mapStageTimes[0] = playerTime;
        for (int i = 0; i < MAX_STAGES + 1; i++)
        {

            g_mapCPTimes[i] = g_userTempCPTimes[client][i];
            g_mapSCPTimes[i] = g_userTempSCPTimes[client][i];
            g_mapCPVelocity[i] = g_userTempCPVelocity[client][i];
        }

        GetClientName(client, g_mapStageName[0], sizeof g_mapStageName);
        g_mapStageUserID[0] = g_userID[client];
    }

    CallMapEndEvent(client, isImprove, isRecord, playerTime, mapBestTime);
    SendCompletionMessage(client, 0, 0, playerTime, playerBestTime, mapBestTime);

    PushToLeaderboard(client, playerTime);

    g_userInRun[client] = false;
    SetClientMode(client, Timer_Stopped);
    ClearTempCache(client);
}

void StageZoneEnterAny(int client, int zone, bool endZone, bool maxVel)
{

    //this function is meant to replace StageZoneEnter for maps that let you beat stages in any order, after stage 1 (e.g. surf_christmas2)
    //instead of having a stage start for every stage and a stage end for the last stage, every stage has a start and an end
    //additionally, there is one more start/end pair, whose indices are one mroe than the amount of stages
    //the start represents the "hub" for the map, the end represents the end zone for the map

    //as for structure, this function is divided into 3 parts - one for start zones, one for stage ends, and one for the map end
    //most of it is just copied from StageZoneEnter

    //I don't think StageZoneExit needs any changes, funnily enough

    //kept from stagezoneenter
    if (!g_userLoaded[client] || !g_userTimerEnabled[client])
    {
        return;
    }

    if (zone > MAX_STAGES)
    {
        return;
    }

    SetClientInZone(client, true, 0, zone);

    if (maxVel)
    {
        LimitUserVelocity(client, false);
    }
    if (!endZone)
    {
        // When they enter the startzone
        if (zone <= 1)
        {

            ClearTempCache(client);
            SetClientMode(client, Timer_Map);
            g_userZone[client] = 1;
        }
        //if they are going to a different stage, just set their zone.
        else if (g_userMode[client] == Timer_Map)
        {
            g_userZone[client] = zone;
        }
        //if they're entering a different stage while not in a run
        else if (g_userMode[client] == Timer_Stopped || g_userMode[client] == Timer_Bonus || g_userMode[client] == Timer_Practice)
        {
            //put them in practice mode if they're not entering the hub
            if (zone != g_mapZones + 1)
            {
                SetClientMode(client, Timer_Practice);
            }
            g_userZone[client] = zone;
        }
        return;
    }
    else
    {
        //if they aren't ending the stage they're in, ignore it
        if (g_userZone[client] != zone)
        {
            return;
        }
    }
    bool mapEndZone = zone > g_mapZones;

    float currentTime = GetGameTime();

    float playerTime,
        playerBestTime,
        mapBestTime;

    bool isImprove, isRecord;

    playerTime = currentTime - g_userSTempTime[client];
    playerBestTime = g_userStageTimes[client][zone];
    mapBestTime = g_mapStageTimes[zone];
    isImprove = (playerTime < playerBestTime || playerBestTime == 0);
    isRecord = (playerTime < mapBestTime || mapBestTime == 0);

    // Stage completion logic
    if (!mapEndZone)
    {
        //set !ccp?
        g_userTempSCPTimes[client][zone] = playerTime;

        if (isImprove)
        {

            g_userStageTimes[client][zone] = playerTime;
            StoreTime(client, zone, 0, playerTime);
        }

        if (isRecord)
        {

            g_mapStageTimes[zone] = playerTime;
            GetClientName(client, g_mapStageName[zone], sizeof g_mapStageName);
            g_mapStageUserID[zone] = g_userID[client];
        }

        SendCompletionMessage(client, 0, zone, playerTime, playerBestTime, mapBestTime);

        bool inRun = (g_userMode[client] == Timer_Map);
        CallStageEndEvent(client, zone, isImprove, isRecord, playerTime, mapBestTime, inRun);

        g_userZone[client] = g_mapZones + 1; //after beating a stage, put the client in the hub

        // Checkpoint Logic
        if (!inRun)
        {
            g_userMode[client] = Timer_Stopped;
            return;
        }
        playerTime = currentTime - g_userTempTime[client]; 
        playerBestTime = g_userCPTimes[client][zone];
        mapBestTime = g_mapCPTimes[zone];

        g_userTempCPTimes[client][zone] = playerTime;
        g_userTempCPVelocity[client][zone] = GetPlayerVelocity(client, false);
        SendCheckpointMessage(client, zone, playerTime, playerBestTime, mapBestTime);
        return;
    }

    if (g_userMode[client] != Timer_Map)
    {
        g_userInRun[client] = false;
        SetClientMode(client, Timer_Stopped);
        ClearTempCache(client);
        return;
    }
    //Map Completion Logic
    playerTime = currentTime - g_userTempTime[client];
    playerBestTime = g_userStageTimes[client][0];
    mapBestTime = g_mapStageTimes[0];

    isImprove = (playerTime < playerBestTime || playerBestTime == 0);
    isRecord = (playerTime < mapBestTime || mapBestTime == 0);

    if (isImprove)
    {

        g_userStageTimes[client][0] = playerTime;

        for (int i = 0; i < MAX_STAGES + 1; i++)
        {
            g_userCPTimes[client][i] = g_userTempCPTimes[client][i];
            g_userSCPTimes[client][i] = g_userTempSCPTimes[client][i];

            g_userCPVelocity[client][i] = g_userTempCPVelocity[client][i];
        }

        StoreCPTime(client);
        StoreTime(client, 0, 0, playerTime);
    }

    //Map Record
    if (isRecord)
    {

        g_mapStageTimes[0] = playerTime;
        for (int i = 0; i < MAX_STAGES + 1; i++)
        {

            g_mapCPTimes[i] = g_userTempCPTimes[client][i];
            g_mapSCPTimes[i] = g_userTempSCPTimes[client][i];
            g_mapCPVelocity[i] = g_userTempCPVelocity[client][i];
        }

        GetClientName(client, g_mapStageName[0], sizeof g_mapStageName);
        g_mapStageUserID[0] = g_userID[client];
    }

    CallMapEndEvent(client, isImprove, isRecord, playerTime, mapBestTime);
    SendCompletionMessage(client, 0, 0, playerTime, playerBestTime, mapBestTime);

    PushToLeaderboard(client, playerTime);

    g_userInRun[client] = false;
    SetClientMode(client, Timer_Stopped);
    ClearTempCache(client);
}

void StageZoneExit(int client, int zone, bool endZone, bool maxVel)
{

    if (!g_userLoaded[client] || !g_userTimerEnabled[client])
    {
        return;
    }

    if (zone > MAX_STAGES)
    {
        return;
    }

    SetClientInZone(client, false, 0, zone);

    if (endZone)
    {
        return;
    }

    if (maxVel)
    {
        LimitUserVelocity(client, true);
    }

    float currentTime = GetGameTime();

    g_userSTempTime[client] = currentTime;
    bool inRun = (g_userMode[client] == Timer_Map);
    CallStageStartEvent(client, zone, inRun);

    if (zone == 1)
    {
        g_userTempTime[client] = currentTime;
        g_userInRun = true;
        CallMapStartEvent(client);
    }
}

void BonusZoneEnter(int client, int zone, bool endZone, bool maxVel)
{

    if (!g_userLoaded[client] || !g_userTimerEnabled[client])
    {
        return;
    }

    if (zone <= 0 || zone > MAX_BONUSES)
    {
        return;
    }

    SetClientInZone(client, true, 1, zone);

    if (!endZone)
    {

        SetClientMode(client, Timer_Bonus);
        g_userZone[client] = zone;

        if (maxVel)
        {
            LimitUserVelocity(client, false);
        }
        return;
    }

    if (g_userMode[client] == Timer_Bonus &&
        g_userZone[client] == zone)
    {

        float currentTime = GetGameTime();

        float playerTime,
            playerBestTime,
            mapBestTime;

        bool isImprove, isRecord;

        playerTime = currentTime - g_userTempTime[client];
        playerBestTime = g_userBonusTimes[client][zone - 1];
        mapBestTime = g_mapBonusTimes[zone - 1];

        isImprove = (playerTime < playerBestTime || playerBestTime == 0);
        isRecord = (playerTime < mapBestTime || mapBestTime == 0);

        if (isImprove)
        {

            g_userBonusTimes[client][zone - 1] = playerTime;
            StoreTime(client, zone, 1, playerTime);
        }

        if (isRecord)
        {
            g_mapBonusTimes[zone - 1] = playerTime;
            GetClientName(client, g_mapBonusName[zone - 1], sizeof g_mapBonusName);
        }

        SendCompletionMessage(client, 1, zone, playerTime, playerBestTime, mapBestTime);
        CallBonusEndEvent(client, zone, isImprove, isRecord, playerTime, mapBestTime);

        SetClientMode(client, Timer_Stopped);
    }
}

void BonusZoneExit(int client, int zone, bool endZone, bool maxVel)
{

    if (!g_userLoaded[client] || !g_userTimerEnabled[client])
    {
        return;
    }

    if (zone <= 0 || zone > MAX_BONUSES)
    {
        return;
    }

    SetClientInZone(client, false, 1, zone);

    if (!endZone)
    {
        g_userTempTime[client] = GetGameTime();
        CallBonusStartEvent(client, zone);

        if (maxVel)
        {
            LimitUserVelocity(client, true);
        }
    }
}

void SetClientInZone(int client, bool isEnter, int type, int zone)
{
    bool isSameZone = (g_userFixZone[client] == zone && g_userFixType[client] == type);

    if (isEnter)
    {
        if (g_userInZone[client] && !isSameZone)
        {
            g_userFixInZone[client] = true;
        }

        g_userInZone[client] = true;
    }
    else
    {
        if (g_userFixInZone[client])
        {
            g_userFixInZone[client] = false;
        }
        else
        {
            g_userInZone[client] = false;
        }
    }

    g_userFixZone[client] = zone;
    g_userFixType[client] = type;
}

void SetClientMode(int client, TimerMode mode)
{
    if (mode == Timer_Stopped)
    {
        g_userZone[client] = 1;

        if (g_userInRun[client])
        {
            g_userInRun[client] = false;
        }
    }

    g_userMode[client] = mode;
}

void ClearTempCache(int client)
{
    for (int i = 0; i < MAX_STAGES + 1; i++)
    {
        g_userTempCPTimes[client][i] = 0.0;
        g_userTempSCPTimes[client][i] = 0.0;
    }
}

public float GetPlayerVelocity(int client, bool includeVertical)
{

    float velVec[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velVec);

    if (includeVertical)
    {
        return SquareRoot(Pow(velVec[0], 2.0) + Pow(velVec[1], 2.0) + Pow(velVec[2], 2.0));
    }

    return SquareRoot(Pow(velVec[0], 2.0) + Pow(velVec[1], 2.0));
}

void LimitUserVelocity(int client, bool printMsg)
{
    float userVelocity[3], altClientVel, scale;
    float maxvel = float(g_mapVelocityLimit);

    GetEntPropVector(client, Prop_Data, "m_vecVelocity", userVelocity);
    altClientVel = SquareRoot(Pow(userVelocity[0], 2.0) + Pow(userVelocity[1], 2.0));
    scale = FloatDiv(maxvel, altClientVel);

    if (scale < 1.0)
    {
        userVelocity[0] = FloatMul(userVelocity[0], scale / 2);
        userVelocity[1] = FloatMul(userVelocity[1], scale / 2);

        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, userVelocity);

        if (printMsg)
        {
            PrintTimerMessage(client, "<warning>Warning | <message>Max velocity exceeded.")
        }
    }
}

void CallMapStartEvent(int client)
{
    Call_StartForward(g_event_mapStart);
    Call_PushCell(client);
    Call_Finish();
}

void CallMapEndEvent(int client, bool isImprove, bool isRecord, float playerTime, float mapTime)
{
    Call_StartForward(g_event_mapEnd);
    Call_PushCell(client);
    Call_PushCell(isImprove);
    Call_PushCell(isRecord);
    Call_PushFloat(playerTime);
    Call_PushFloat(mapTime);
    Call_Finish();
}

void CallMapRankedEvent(int client, int rank, int completions, int recordingID, int recordingRank)
{
    Call_StartForward(g_event_mapRanked);
    Call_PushCell(client);
    Call_PushCell(rank);
    Call_PushCell(completions);
    Call_PushCell(recordingID);
    Call_PushCell(recordingRank);
    Call_Finish();

    if (rank == 1)
    {
        SendCrossServerRecordNotification(client, 0, 0);
    }
}

void CallStageStartEvent(int client, int zone, bool inRun)
{
    Call_StartForward(g_event_stageStart);
    Call_PushCell(client);
    Call_PushCell(zone);
    Call_PushCell(inRun);
    Call_Finish();
}

void CallStageEndEvent(int client, int zone, bool isImprove, bool isRecord, float playerTime, float mapTime, bool inRun)
{
    Call_StartForward(g_event_stageEnd);
    Call_PushCell(client);
    Call_PushCell(zone);
    Call_PushCell(isImprove);
    Call_PushCell(isRecord);
    Call_PushFloat(playerTime);
    Call_PushFloat(mapTime);
    Call_PushCell(inRun);
    Call_Finish();
}

void CallStageRankedEvent(int client, int zone, int rank, int completions, int recordingID, int recordingRank)
{
    Call_StartForward(g_event_stageRanked);
    Call_PushCell(client);
    Call_PushCell(zone);
    Call_PushCell(rank);
    Call_PushCell(completions);
    Call_PushCell(recordingID);
    Call_PushCell(recordingRank);
    Call_Finish();
}

void CallBonusStartEvent(int client, int zone)
{
    Call_StartForward(g_event_bonusStart);
    Call_PushCell(client);
    Call_PushCell(zone);
    Call_Finish();
}

void CallBonusEndEvent(int client, int zone, bool isImprove, bool isRecord, float playerTime, float mapTime)
{
    Call_StartForward(g_event_bonusEnd);
    Call_PushCell(client);
    Call_PushCell(zone);
    Call_PushCell(isImprove);
    Call_PushCell(isRecord);
    Call_PushFloat(playerTime);
    Call_PushFloat(mapTime);
    Call_Finish();
}

void CallBonusRankedEvent(int client, int zone, int rank, int completions, int recordingID, int recordingRank)
{
    Call_StartForward(g_event_bonusRanked);
    Call_PushCell(client);
    Call_PushCell(zone);
    Call_PushCell(rank);
    Call_PushCell(completions);
    Call_PushCell(recordingID);
    Call_PushCell(recordingRank);
    Call_Finish();
}

void CallUserLoadEvent(int client, int userID)
{

    Call_StartForward(g_event_playerLoad);
    Call_PushCell(client);
    Call_PushCell(userID);
    Call_Finish();
}

public int Native_GetEnabledValue(Handle plugin, int params)
{
    int client = GetNativeCell(1);
    return g_userTimerEnabled[client];
}

public int Native_GetServerID(Handle plugin, int params)
{
    return g_serverID;
}

void SendCompletionMessage(int client, int type, int stage, float time, float oldTime, float recordTime)
{
    char message[512],
        name[32],
        formattedTime[15],
        comparedOld[15],
        comparedRecord[15];

    bool isImprove = (time < oldTime || oldTime == 0.0);
    bool isRecord = (time < recordTime || recordTime == 0.0);

    GetClientName(client, name, sizeof name);
    FormatTimeFloat(time, formattedTime, sizeof formattedTime);
    FormatComparision(time, oldTime, comparedOld, sizeof comparedOld);
    FormatComparision(time, recordTime, comparedRecord, sizeof comparedRecord);

    if (isRecord || stage == 0 || type == 1)
    {
        Format(message, sizeof message, "<name>%s ", name);
    }

    Format(message, sizeof message, "%s<timemsg>", message);

    if (!isRecord)
    {
        if (stage == 0)
        {
            Format(message, sizeof message, "%sFinished the Map ", message);
        }
        else
        {
            Format(message, sizeof message, "%sFinished %s %i ", message, (type) ? "Bonus" : "Stage", stage);
        }
    }
    else
    {
        if (stage == 0)
        {
            Format(message, sizeof message, "%sBroke the Map Record ", message);
        }
        else
        {
            Format(message, sizeof message, "%sBroke %s %i Record ", message, (type) ? "Bonus" : "Stage", stage);
        }
    }

    Format(message, sizeof message, "%s<time>%s ", message, formattedTime);

    if (recordTime > 0.0)
    {
        Format(message, sizeof message, "%s<desc>Rec. <%s>%s ", message, isRecord ? "neg" : "pos", comparedRecord);
    }
    if (oldTime > 0.0)
    {
        Format(message, sizeof message, "%s<desc>Per. <%s>%s ", message, isImprove ? "neg" : "pos", comparedOld);
    }

    char sound[64];

    if (GetEventSound(isRecord, stage, type, sound, sizeof sound))
    {
        EmitSoundToAllowed(sound);
    }

    if (isRecord || stage == 0 || type == 1)
    {
        PrePrintTimerMessageAll(client, message);
    }
    else
    {
        PrePrintTimerMessageSpecs(client, message);
    }
}

void SendCheckpointMessage(int client, int stage, float time, float oldTime, float recordTime)
{
    char message[512],
        formattedTime[15],
        comparedOld[15],
        comparedRecord[15];

    bool isImprove = (time < oldTime || oldTime == 0.0);
    bool isRecord = (time < recordTime || recordTime == 0.0);

    FormatTimeFloat(time, formattedTime, sizeof formattedTime);
    FormatComparision(time, oldTime, comparedOld, sizeof comparedOld);
    FormatComparision(time, recordTime, comparedRecord, sizeof comparedRecord);
    Format(message, sizeof message, "%s<timemsg>", message);
    
    // Checkpoints
    if (!g_mapStaged)
    {
        Format(message, sizeof message, "%sCheckpoint %i <time>%s ", message, stage, formattedTime);
    }
    else
    {
        Format(message, sizeof message, "%sCurrent Time <time>%s ", message, formattedTime);
    }

    if (recordTime != 0)
    {
        Format(message, sizeof message, "%s<desc>Rec. <%s>%s ", message, isRecord ? "neg" : "pos", comparedRecord);
    }

    if (oldTime != 0)
    {
        Format(message, sizeof message, "%s<desc>Per. <%s>%s ", message, isImprove ? "neg" : "pos", comparedOld);
    }

    PrintTimerMessageSpecs(client, "%s", message);
}
