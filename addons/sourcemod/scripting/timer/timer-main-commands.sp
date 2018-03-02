//reset stage
public Action Command_Teleport(int client, int args)
{
	RestartUserStage(client);
	return Plugin_Handled;
}

void RestartUserStage(int client)
{
	int zone = g_userZone[client];
	TimerMode mode = g_userMode[client];

	if (mode == Timer_Bonus)
	{
		TeleportUserToZoneSafe(client, zone, 1);
		return;
	}

	if (!zone || !g_mapStaged)
	{
		zone = 1;
	}

	TeleportUserToZoneSafe(client, zone, 0);
}

public Action Command_Restart(int client, int args)
{

	if (!IsPlayerAlive(client))
	{
		PrintTimerMessage(client, "<warning>Error|<message> You must be alive for this command.");
		return Plugin_Handled;
	}

	TeleportUserToZoneSafe(client, 1, 0);
	return Plugin_Handled;
}

public Action Command_GoBack(int client, int args)
{
	int zone = g_userZone[client];
	TimerMode mode = g_userMode[client];

	if (!(mode == Timer_Map || mode == Timer_Practice))
	{
		return Plugin_Handled;
	}

	if (zone <= 1)
	{
		return Plugin_Handled;
	}

	TeleportUserToZoneSafe(client, zone - 1, 0);
	return Plugin_Handled;
}

public Action Command_ToStage(int client, int args)
{
	if (!IsPlayerAlive(client))
	{
		PrintTimerMessage(client, "<warning>Error |<message> You must be alive for this command.");
		return Plugin_Handled;
	}

	if (!g_mapStaged)
	{
		PrintTimerMessage(client, "<warning>Error |<message> Command unavaliable on linear maps.");
		return Plugin_Handled;
	}
	
	if (!args)
	{
		ShowZoneList(client, 0);
		return Plugin_Handled;
	}

	char cIndex[32];
	GetCmdArg(1, cIndex, sizeof cIndex);
	int index = StringToInt(cIndex);

	//on any-order staged maps, there is one last stage representing the hub
	if (g_mapAnyStaged)
	{
		if (index <= 0 || index > g_mapZones + 1)
		{
			PrintTimerMessage(client, "<warning>Error |<message> Stage %i does not exist.", index);
			return Plugin_Handled;
		}
	}
	else if (index <= 0 || index > g_mapZones)
	{
		PrintTimerMessage(client, "<warning>Error |<message> Stage %i does not exist.", index);
		return Plugin_Handled;
	}

	TeleportUserToZoneSafe(client, index, 0);
	return Plugin_Handled;
}

public Action Command_ToBonus(int client, int args)
{
	if (!IsPlayerAlive(client))
	{
		PrintTimerMessage(client, "<warning>Error |<message> You must be alive for this command.");
		return Plugin_Handled;
	}

	if (g_mapBonuses == 0)
	{
		PrintTimerMessage(client, "<warning>Error |<message> Bonus does not exist.");
		return Plugin_Handled;
	}

	if (!args)
	{
		if (g_mapBonuses == 1)
		{
			TeleportUserToZoneSafe(client, 1, 1);
		}
		else
		{
			ShowZoneList(client, 1);
		}

		return Plugin_Handled;
	}

	char cIndex[32];
	GetCmdArg(1, cIndex, sizeof cIndex);
	int index = StringToInt(cIndex);

	if (index > g_mapBonuses)
	{
		PrintTimerMessage(client, "<warning>Error |<message> Bonus %i does not exist.", index);
		return Plugin_Handled;
	}

	TeleportUserToZoneSafe(client, index, 1);
	return Plugin_Handled;
}

void ShowZoneList(int client, int type) 
{
	int zones = type ? g_mapBonuses : g_mapZones;

	if (!zones)
	{
		return;
	}

	Menu menu = new Menu(menuhandler_userZoneList);
	menu.SetTitle("Select a %s: \n \n", type ? "Bonus" : "Stage");
	char buffer[16], index[8];

	for (int i = 0; i < zones; i++)
	{

		Format(index, sizeof index, "%i", type);
		Format(buffer, sizeof buffer, "%s %i", type ? "Bonus" : "Stage", i + 1);
		menu.AddItem(index, buffer);
	}
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int menuhandler_userZoneList(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{

	case MenuAction_Select:
	{
		char index[3];
		menu.GetItem(choice, index, sizeof index);
		int type = StringToInt(index);
		TeleportUserToZoneSafe(client, choice + 1, type);
	}

	case MenuAction_End:
		delete menu;
	}
}

void TeleportUserToZoneSafe(int client, int zone, int type)
{

	TimerMode userMode = g_userMode[client];
	int userZone = g_userZone[client];
	//if it's to a bonus
	if (type == 1)
	{
		if (zone <= 0 || zone > g_mapBonuses)
		{
			return;
		}

		g_userZone[client] = zone;
		TeleportEntity(client, g_spawnBonusOrigin[zone - 1], g_spawnBonusAngles[zone - 1], g_spawnBonusVelocity[zone - 1]);
	}
	else
	{
		//if it goes to a stage that doesn't exist
		if (zone < 0 || zone > g_mapZones + (g_mapAnyStaged ? 1 : 0))
		{ //on any-order stage maps there's one more "fake" stage that is the hub
			return;
		}
		//if they're skipping forward in stages - ignore on any order staged maps
		if (!g_mapAnyStaged && userMode == Timer_Map && zone > userZone)
		{
			g_userMode[client] = Timer_Stopped;
		}
		//if it's on an any order staged map, you can do the stages in any order except stage 1
		else if (g_mapAnyStaged && userMode == Timer_Map && zone == 1)
		{
			g_userMode[client] = Timer_Stopped;
		}

		g_userZone[client] = zone;
		TeleportEntity(client, g_spawnStageOrigin[zone], g_spawnStageAngles[zone], g_spawnStageVelocity[zone]);
	}
}

void TeleportUserToZone(int client, int zone, int type)
{
	if (type == 1)
	{
		if (zone <= 0 || zone > g_mapBonuses)
		{
			return;
		}
		TeleportEntity(client, g_spawnBonusOrigin[zone - 1], g_spawnBonusAngles[zone - 1], g_spawnBonusVelocity[zone - 1]);
	}
	else
	{
		if (zone < 0 || zone > g_mapZones)
		{
			return;
		}
		TeleportEntity(client, g_spawnStageOrigin[zone], g_spawnStageAngles[zone], g_spawnStageVelocity[zone]);
	}
}

void TeleportEntityDelayVelocity(int client, const float origin[3], const float angle[3], const float velocity[3], float delay)
{
	TeleportEntity(client, origin, angle, ZERO_VECTOR);
	SetEntityMoveType(client, MOVETYPE_NONE);

	DataPack pack = new DataPack();
	pack.WriteCell(client);

	for (int i = 0; i < sizeof velocity; i++)
	{
		pack.WriteFloat(velocity[i]);
	}

	CreateTimer(delay, Timer_AddVelocity, pack);
}

public Action Timer_AddVelocity(Handle timer, Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);

	float velocity[3];

	for (int i = 0; i < sizeof velocity; i++)
		velocity[i] = ReadPackFloat(pack);

	SetEntityMoveType(client, MOVETYPE_WALK);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
	delete pack;
	return Plugin_Handled;
}

public Action Command_SetSpawn(int client, int args)
{
	if (!args)
	{
		PrintTimerMessage(client, "<warning>Error |<message> No value input. ");
		return Plugin_Handled;
	}

	char cIndex[32];
	GetCmdArg(1, cIndex, sizeof cIndex);
	int index = StringToInt(cIndex);
	SetSpawnPoint(client, index, 0);
	return Plugin_Handled;
}

public Action Command_SetBonusSpawn(int client, int args)
{
	if (!args)
	{
		PrintTimerMessage(client, "<warning>Error |<message> No value input. ");
		return Plugin_Handled;
	}

	char cIndex[32];
	GetCmdArg(1, cIndex, sizeof cIndex);
	int index = StringToInt(cIndex);
	SetSpawnPoint(client, index, 1);
	return Plugin_Handled;
}

void SetSpawnPoint(int client, int zone, int type)
{
	float origin[3], angle[3], velocity[3];

	GetClientAbsOrigin(client, origin);
	GetClientAbsAngles(client, angle);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

	if (!type)
	{
		g_spawnStageAngles[zone] = angle;
		g_spawnStageOrigin[zone] = origin;
		g_spawnStageVelocity[zone] = velocity;
	}

	else
	{
		g_spawnBonusAngles[zone - 1] = angle;
		g_spawnBonusOrigin[zone - 1] = origin;
		g_spawnBonusVelocity[zone - 1] = velocity;
	}

	PrintTimerMessage(client, "<info>Info |<message> %s %i set. ", type ? "Bonus spawn" : "Spawn", zone);

	char cOrigin[96], cAngle[96], cVel[96], query[756];

	VectorToString(cOrigin, sizeof cOrigin, origin, "|");
	VectorToString(cAngle, sizeof cAngle, angle, "|");
	VectorToString(cVel, sizeof cVel, velocity, "|");

	FormatEx(query, sizeof query, "INSERT INTO cs_spawns(mapid,zone,type,origin,angle,velocity) VALUES (%i,%i,%i,'%s','%s','%s') ON DUPLICATE KEY UPDATE origin=VALUES(origin), angle=VALUES(angle), velocity=VALUES(velocity)", g_mapID, zone, type, cOrigin, cAngle, cVel);
	g_database.Query(callback_SpawnInsert, query);
}

public void callback_SpawnInsert(Database db, DBResultSet results, char[] error, any data)
{

	if (results == null)
	{
		LogError("Spawn Insert Error : %s", error);
		return;
	}

	return;
}

public Action Command_ToggleTimer(int client, int args)
{
	g_userTimerEnabled[client] = !g_userTimerEnabled[client];

	if (g_userTimerEnabled[client])
	{
		TeleportUserToZoneSafe(client, 1, 0);

		if (IsPlayerAlive(client))
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}

		SendTimerToggleEvent(client, true);
		PrintTimerMessage(client, "<info>Info |<message> Timer Enabled.");

		if (g_userResumeAllowed[client])
		{
			PrintTimerMessage(client, "<info>Info |<message> Type <desc>!resume <message>to continue your run.");
		}
	}
	else
	{
		BackupUserResumeStats(client);
		StopUserTimer(client, true);
		SendTimerToggleEvent(client, false);
		PrintTimerMessage(client, "<info>Info |<message> Timer Disabled. Type !timer to enable.");
	}
	return Plugin_Handled;
}

public void SendTimerToggleEvent(int client, bool isNowEnabled)
{
	Call_StartForward(g_event_timerToggle);
	Call_PushCell(client);
	Call_PushCell(isNowEnabled);
	Call_Finish();
}

void StopUserTimer(int client, bool completeStop)
{
	SetClientMode(client, Timer_Stopped);
	g_userInRun[client] = false;

	if (completeStop)
	{
		g_userInZone[client] = false;
		g_userFixInZone[client] = false;
		g_userFixZone[client] = -1;
		g_userFixType[client] = -1;
	}
}

public Action Command_Options(int client, int args)
{
	ShowOptionsMenu(client);
	return Plugin_Handled;
}

void ShowOptionsMenu(int client)
{
	Menu menu = CreateMenu(menuhandler_showOptionsMenu);
	menu.SetTitle("<Player Preferences> \n ");
	menu.AddItem("", "General Settings");

	if (g_array_schemeNames == null)
	{
		menu.AddItem("", "Chat Settings", ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("", "Chat Settings");
	}

	menu.AddItem("", "Hud Settings\n ");

	if (g_userUnsavedChanged[client])
	{
		menu.AddItem("", "Save and Exit");
		menu.ExitButton = true;
	}
	else
	{
		menu.AddItem("", "Exit");
		menu.ExitButton = false;
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int menuhandler_showOptionsMenu(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		switch (choice)
		{
			case 0:
			{
				ShowOptionsMenuGeneral(client);
			}
			case 1:
			{
				ShowOptionsMenuChat(client);
			}
			case 2:
			{
				ShowOptionsMenuHud(client);
			}
			case 3:
			{

				if (g_userUnsavedChanged[client])
				{
					SavePlayerSettings(client, false);
				}
			}
		}
	}

	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void ShowOptionsMenuGeneral(int client)
{
	Menu menu = CreateMenu(menuhandler_showOptionsMenuGeneral);
	menu.SetTitle("<General Preferences> \n ");

	if (g_userSoundsEnabled[client])
	{
		menu.AddItem("", "Toggle Sounds\nEnabled");
	}
	else
	{
		menu.AddItem("", "Toggle Sounds\nDisabled");
	}

	if (g_userTelehopEnabled[client])
	{
		menu.AddItem("", "Toggle Spawn Velocity\nEnabled");
	}
	else
	{
		menu.AddItem("", "Toggle Spawn Velocity\nDisabled");
	}

	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int menuhandler_showOptionsMenuGeneral(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		switch (choice)
		{

		case 0:
		{
			g_userSoundsEnabled[client] = !g_userSoundsEnabled[client];
		}
		case 1:
		{
			g_userTelehopEnabled[client] = !g_userTelehopEnabled[client];
		}
		}

		ShowOptionsMenuGeneral(client);

		if (!g_userUnsavedChanged[client])
		{
			g_userUnsavedChanged[client] = true;
		}
	}

	else if (action == MenuAction_Cancel)
	{
		if (choice == MenuCancel_ExitBack)
		{
			ShowOptionsMenu(client);
		}
	}

	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void ShowOptionsMenuChat(int client)
{
	Menu menu = CreateMenu(menuhandler_showOptionsMenuChat);
	menu.SetTitle("<Chat Preferences> \n ");

	char scheme[32], buffer[64];
	g_array_schemeNames.GetString(g_userChatColorScheme[client], scheme, sizeof scheme);

	FormatEx(buffer, sizeof buffer, "Change Color Scheme \n%s", scheme);
	menu.AddItem("", buffer);
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

public int menuhandler_showOptionsMenuChat(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		if (choice == 0)
		{
			g_userChatColorScheme[client]++;
			if (g_loadedColorSchemes == g_userChatColorScheme[client])
			{
				g_userChatColorScheme[client] = 0;
			}
			SetUserColorScheme(client, g_userChatColorScheme[client]);
			ShowOptionsMenuChat(client);
		}

		if (!g_userUnsavedChanged[client])
		{
			g_userUnsavedChanged[client] = true;
		}
	}

	else if (action == MenuAction_Cancel)
	{
		if (choice == MenuCancel_ExitBack)
		{
			ShowOptionsMenu(client);
		}
	}

	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void ShowOptionsMenuHud(client)
{
	Menu menu = CreateMenu(menuhandler_showOptionsHud);
	menu.SetTitle("<Hud Preferences> \n ");

	if (g_userPanelEnabled[client])
	{
		menu.AddItem("", "Toggle Side Panel\nEnabled");
	}
	else
	{
		menu.AddItem("", "Toggle Side Panel\nDisabled");
	}

	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int menuhandler_showOptionsHud(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{

		if (choice == 0)
		{
			g_userPanelEnabled[client] = !g_userPanelEnabled[client];
		}

		ShowOptionsMenuHud(client);

		if (!g_userUnsavedChanged[client])
		{
			g_userUnsavedChanged[client] = true;
		}
	}
	else if (action == MenuAction_Cancel)
	{

		if (choice == MenuCancel_ExitBack)
		{
			ShowOptionsMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int OnColorSchemesLoaded(ArrayList schemes, int size)
{
	if (g_array_schemeNames != null)
	{
		delete g_array_schemeNames;
		g_array_schemeNames = null;
	}

	g_array_schemeNames = schemes.Clone();
	g_loadedColorSchemes = size;
	return 0;
}

public Action Command_ResumeRun(int client, int args)
{
	if (g_mapAnyStaged)
	{
		//make sure to re-enable if you cache targetname with the run resuming
		PrintTimerMessage(client, "<warning>Error|<message> Command unavailable on this map.");
		return Plugin_Handled;
	}
	if (!g_mapStaged)
	{
		PrintTimerMessage(client, "<warning>Error|<message> Command unavaliable on linear maps.");
		return Plugin_Handled;
	}

	if (!g_userResumeAllowed[client])
	{
		PrintTimerMessage(client, "<info>Info |<message> No run to resume.");
		return Plugin_Handled;
	}
	//If the client is still spectating return error.
	if (GetClientTeam(client) == 1)
	{
		PrintTimerMessage(client, "<info>Info |<message> Please join a team before resuming your run.");
		return Plugin_Handled;
	}

	g_userResumeAllowed[client] = false;
	TeleportUserToZoneSafe(client, g_userResumeZone[client], 0);
	CreateTimer(0.1, timer_DelayResumeValues, client);

	return Plugin_Handled;
}

public Action timer_DelayResumeValues(Handle Timer, any client)
{
	g_userZone[client] = g_userResumeZone[client];
	g_userMode[client] = Timer_Map;
	g_userTempTime[client] = g_userResumeTempTime[client];
	g_userCPTimes[client] = g_userResumeTempCPTimes[client];
	g_userSCPTimes[client] = g_userResumeTempSCPTime[client];
	g_userCPVelocity[client] = g_userResumeTempVelocity[client];

	return Plugin_Handled;
}

public Action Command_StopTimer(int client, int args)
{
	return Plugin_Handled;
}

public Action Command_SpecInfo(int client, int args)
{
	char name[32];
	int target;

	if (args)
	{
		GetCmdArgString(name, sizeof(name));
		target = ClientFromName(name);

		if (target == -1 || !isValidClient(target, true))
		{
			PrintTimerMessage(client, "%t", "No User Search Results", name);
			return Plugin_Handled;
		}
	}
	else if (!GetClientSpecTarget(client, target))
	{
		target = client;
	}

	GetClientName(target, name, sizeof name);

	if (!IsPlayerAlive(target))
	{
		int spec;
		char specName[32];

		if (GetClientSpecTarget(target, spec) && !g_userHiddenSpec[client])
		{
			GetClientName(spec, specName, sizeof specName);
			PrintTimerMessage(client, "<info>Info | <name>%s <message>is spectating <name>%s. ", name, specName);
		}
		else
		{
			PrintTimerMessage(client, "<info>Info | <name>%s <message>is not spectating anyone. ", name, specName);
		}

		return Plugin_Handled;
	}

	char buffer[256];
	bool hasSpecs;

	for (int spec = 1; spec <= MaxClients; spec++)
	{

		if (!IsClientInGame(spec) || IsFakeClient(spec) || IsPlayerAlive(spec) || g_userHiddenSpec[spec])
		{
			continue;
		}

		int specTarget;

		if (GetClientSpecTarget(spec, specTarget) && (specTarget == target))
		{
			GetClientName(spec, name, sizeof name);
			Format(buffer, sizeof buffer, "%s%s %s", buffer, !hasSpecs ? "" : ",", name);

			if (!hasSpecs)
			{
				hasSpecs = true;
			}
		}
	}

	if (hasSpecs)
	{
		PrintTimerMessage(client, "<info>Info | <message>Spectators: <desc>%s.", buffer);
	}
	else
	{
		PrintTimerMessage(client, "<info>Info | <message>Spectators: <desc>None.");
	}

	return Plugin_Handled;
}

bool GetClientSpecTarget(int client, int &target)
{
	if (!IsPlayerAlive(client))
	{
		int mode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if (mode == 4 || mode == 5)
		{
			target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (isValidClient(target, true))
			{
				return true;
			}
		}
	}

	target = -1;
	return false;
}

public Action Command_HideSpec(int client, int args)
{
	g_userHiddenSpec[client] = !g_userHiddenSpec[client];
	PrintTimerMessage(client, "<info>Info | <message>You are now %s the spectator list.", g_userHiddenSpec[client] ? "hidden from" : "visible on");
	return Plugin_Handled;
}

public Action Command_SetHudConfig(int client, int args)
{
	if (!args)
	{
		PrintTimerMessage(client, "<info>Info |<message> Check console for information.");
		PrintToConsole(client, "Current Hud Config: %s ", g_hudConfigText[client]);
		PrintToConsole(client, "%t", "Hud Options Description");
		return Plugin_Handled;
	}

	char buffer[32];
	GetCmdArg(1, buffer, sizeof buffer);
	if (buffer[0] == '0')
	{
		if (g_engine == Engine_CSGO)
		{
			Format(buffer, sizeof buffer, DEFAULT_CSGO_HUD);
		}
		else
		{
			Format(buffer, sizeof buffer, DEFAULT_SOURCE_HUD);
		}
	}

	Format(g_hudConfigText[client], sizeof g_hudConfigText[], "%s", buffer);
	SavePlayerSettings(client, true);
	return Plugin_Handled;
}

public Action Command_ShowCheckpoint(int client, int args)
{
	char name[32];
	int target = client;

	if (args)
	{
		GetCmdArg(1, name, sizeof name);
		target = ClientFromName(name);

		if (target == -1)
		{
			PrintTimerMessage(client, "%t", "No User Search Results", name);
			return Plugin_Handled;
		}
	}

	GetClientName(target, name, sizeof name);
	char message[256];
	Format(message, sizeof message, "<info>Info | <message>Player: <name>%s <message>- Current Activity: ", name);

	if (!IsPlayerAlive(target))
	{
		Format(message, sizeof message, "%s<desc>Spectate Mode", message);
		PrintTimerMessage(client, message);
		return Plugin_Handled;
	}

	char buffer[32];
	Hud_GetZone(target, buffer, sizeof(buffer), true);
	Format(message, sizeof message, "%s<desc>%s<message>, ", message, buffer);
	Hud_GetTime(target, buffer, sizeof(buffer));
	TimerMode mode = g_userMode[target];

	if (mode == Timer_Bonus)
	{
		Format(message, sizeof(message), "%sBonus Time: <time>%s ", message, buffer);
	}
	else if (mode == Timer_Practice && g_mapStaged)
	{
		Format(message, sizeof(message), "%sStage Time: <time>%s ", message, buffer);
	}
	else
	{
		Format(message, sizeof(message), "%sTime: <time>%s ", message, buffer);
	}

	PrintTimerMessage(client, message);
	return Plugin_Handled;
}

public Action Command_HideHud(int client, int args)
{
	g_userHudEnabled[client] = !g_userHudEnabled[client];
	PrintTimerMessage(client, "<info>Info | <message>Hud ", g_userHudEnabled[client] ? "Enabled." : "Disabled");
	return Plugin_Handled;
}

public Action Command_SetPrehopMode(int client, int args)
{
	if (!args)
	{
		return Plugin_Handled;
	}

	char cMode[12];
	GetCmdArg(1, cMode, sizeof cMode);
	int mode = StringToInt(cMode);

	if (mode >= 0 && mode < sizeof(zone_type_names))
	{
		PrintTimerMessage(client, "<info>Info | <message>Prehop set to '<name>%s<message>'.", jumpLimitNames[mode]);
	}
	return Plugin_Handled;
}
