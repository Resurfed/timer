//set custom trigger name
public Action Command_TriggerName(int client, int args) 
{
    if (!args)
    {
        PrintToChat(client, "%t", "No Argument");
        return;
    }

    char name[32];
    GetCmdArgString(name, sizeof(name));
    ZoneType type = ProcessLegacyZoneString(name, sizeof(name), g_draw_zone_value[client], g_draw_zone_maxvel[client]);
    
    if (type != Zone_Unknown)
    {
        g_draw_zone_type[client] = type;
        PrintToChat(client, "%t", "Zone Info Set");
        ShowZoneMenu(client);
    }
    else
    {
        PrintToChat(client, "%t", "Invalid Zone Name", name);
        return; 
    }
}

//set custom trigger filter
public Action Command_FilterName(int client, int args) 
{
    if (!args) 
    {
        Format(g_draw_zone_filter[client], sizeof(g_draw_zone_filter[]), "");
        PrintToChat(client, "%t", "Zone Cache Cleared");
        return;
    }
    
    GetCmdArgString(g_draw_zone_filter[client], sizeof(g_draw_zone_filter[]));
    PrintToChat(client, "%t", "Filter Name Set", g_draw_zone_filter[client]);
}

public Action Command_SetPrehopMode(int client, int args) 
{
	if (g_map_info == null) 
    {
		return;
	}

	if (!args) 
    {
		return;
	}
	
	char cmode[12];
	GetCmdArg(1, cmode, sizeof cmode);
	int mode = StringToInt(cmode);

	if (mode >= 0 && mode < sizeof(zone_type_names)) 
    {
		g_map_info.prevent_prehop = view_as<bool>(mode);
		char buffer[128];
		Format(buffer, sizeof buffer, "maps/%i/", g_map_info.id);
		http_client.Put(buffer, g_map_info, OnMapUpdate);		
	}
}

public Action Command_InsertMap(int client, int args)
{
    if (g_map_info == null) 
    {
        return;
    }

    if (args !=  6) 
    {
        PrintToChat(client, "%t", "Insert Map Help");
        return;
    }

    char author[32], difficulty[16], type[16], checkpoints[16], bonuses[16], baked_triggers[16];

    GetCmdArg(1, difficulty, sizeof difficulty);
    GetCmdArg(2, checkpoints, sizeof checkpoints);
    GetCmdArg(3, type, sizeof type);
    GetCmdArg(4, author, sizeof author);
    GetCmdArg(5, bonuses, sizeof bonuses);
    GetCmdArg(6, baked_triggers, sizeof baked_triggers);
    
    g_map_info.SetAuthor(author);
    g_map_info.difficulty = StringToInt(difficulty);
    g_map_info.type = view_as<MapType>(StringToInt(type));
    g_map_info.checkpoints = StringToInt(checkpoints);
    g_map_info.bonuses = StringToInt(bonuses);
    g_map_info.enable_baked_triggers = view_as<bool>(StringToInt(baked_triggers));
    g_map_info.active = true;

    char buffer[128];
    Format(buffer, sizeof buffer, "maps/%i/", g_map_info.id);
    http_client.Put(buffer, g_map_info, OnMapUpdate);
    CallMapLoadEvent();

    HookBakedTriggers(g_map_info.enable_baked_triggers);
}

public void OnMapUpdate(HTTPResponse response, any value) 
{
	if (response.Status != HTTPStatus_OK) 
    { 
		LogError("Invalid Response on Map Update");
		return; 
	} 
}

public Action Command_ZoneMenu(int client, int args) 
{
    ShowZoneMenu(client);
}

void ShowZoneMenu(int client)
{
    Menu menu = new Menu(MenuHandler_ZoneMenu);
    char title[128];
    Format(title, sizeof(title), "<Draw Zone Menu>\n \n");
    Format(title, sizeof(title), "%sType: %s \n \n", title, zone_type_names[view_as<int>(g_draw_zone_type[client]) + 1]);
    Format(title, sizeof(title), "%sValue: %i \n \n", title, g_draw_zone_value[client]);
    Format(title, sizeof(title), "%sFilter: %s \n \n", title, g_draw_zone_filter[client]);
    Format(title, sizeof(title), "%sVelocity Limit: %s \n \n", title, g_draw_zone_maxvel[client] ? "True" : "False");
    Format(title, sizeof(title), "%sSnapping: %i \n \n", title, g_grid_size[client]);

    menu.SetTitle(title);
    menu.AddItem("", "[Start Draw]");
    menu.AddItem("", "[End Draw]");
    menu.AddItem("", "[Upload] \n \n");
    
    if (g_grid_snapping[client]) 
    {
        menu.AddItem("", "Toggle Snapping\n Enabled\n ");
        menu.AddItem("", "Increase Grid");
        menu.AddItem("", "Decrease Grid\n ");
    }
    else 
    {
        menu.AddItem("", "Toggle Snapping\n Disabled\n ");
        menu.AddItem("", "Increase Grid", ITEMDRAW_DISABLED);
        menu.AddItem("", "Decrease Grid\n ", ITEMDRAW_DISABLED);
    }
    
    menu.AddItem("", "Zone List\n ");
    menu.AddItem("", "Reset\n ");
    menu.AddItem("", "Close");
    menu.Pagination = MENU_NO_PAGINATION;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneMenu(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        switch (view_as<ZoneMenuChoice>(choice))
        {
            case MenuChoice_StartDraw:
            {
                StartZoneDraw(client);
                ShowZoneMenu(client);
            }
            case MenuChoice_EndDraw:
            {
                EndZoneDraw(client);
                ShowZoneMenu(client);
            }            
            case MenuChoice_Upload:
            {
                SaveZone(client);
                ShowZoneMenu(client);
            }            
            case MenuChoice_ToggleSnapping:
            {
                g_grid_snapping[client] = !g_grid_snapping[client];
                ShowZoneMenu(client);
            }            
            case MenuChoice_IncreaseGrid:
            {
                g_grid_size[client] = g_grid_size[client] < MAX_SNAP_LIMIT ? g_grid_size[client] * 2 : MAX_SNAP_LIMIT;
                ShowZoneMenu(client);
            }
            case MenuChoice_DecreaseGrid:
            {
                g_grid_size[client] = RoundToCeil(g_grid_size[client] / 2.0);
                ShowZoneMenu(client);   
            }
            case MenuChoice_ZoneList:
            {
                ShowZoneList(client); 
            }
            case MenuChoice_Reset:
            {
                g_draw_zone_mode[client] = DrawMode_Stopped;
                ShowZoneMenu(client);
            }
        }
    }

    else if (action == MenuAction_End) 
    {
        delete menu;
    }

    return 0;
}

void StartZoneDraw(int client) 
{
    if (g_draw_zone_mode[client] != DrawMode_Active) 
    {
        CreateTimer(0.1, DrawDevZone, client, TIMER_REPEAT);
        g_draw_zone_mode[client] = DrawMode_Active;
    }
    
    if (g_grid_snapping[client])
    {
        GetClientSnappedOrigin(client, g_draw_zone_start[client], g_grid_size[client], true);
    }
    else
    {
        GetClientAbsOrigin(client, g_draw_zone_start[client]);
    }

    ShowZoneMenu(client);
}

void EndZoneDraw(int client) 
{    
    g_draw_zone_mode[client] = DrawMode_Frozen;

    if (g_grid_snapping[client])
    {
        GetClientSnappedOrigin(client, g_draw_zone_end[client], g_grid_size[client], true);
    }
    else 
    {
        GetClientAbsOrigin(client, g_draw_zone_end[client]);
    }

    ShowZoneMenu(client);
}

void SaveZone(int client) 
{   
    g_draw_zone_mode[client] = DrawMode_Stopped;
    
    Zone zone = new Zone();
    zone.value = g_draw_zone_value[client];
    zone.type = g_draw_zone_type[client];
    zone.velocity = g_draw_zone_maxvel[client];
    zone.map = g_map_info.id;
    zone.SetFilterName(g_draw_zone_filter[client]);
    zone.SetStartCoordinates(g_draw_zone_start[client]);
    zone.SetEndCoordinates(g_draw_zone_end[client]);
    
    int index = AddZoneToCache(zone);
    StoreZone(client, zone, index);
    DeployZone(index);
    PrintToChat(client, "%t", "Zone Created");
}

void StoreZone(int client, Zone zone, int index) 
{
    http_client.Post("maps/zones/", zone, OnZoneInserted, index);
}

public void OnZoneInserted(HTTPResponse response, any value) 
{
    ResponseInfo response_info;
    JSONObject json_object = GetPostResponseObject(response, response_info, "zone");
    
    if (response_info != Request_Success) 
    {
        return;
    }

    Zone zone = view_as<Zone>(json_object);
    Zone active_zone = view_as<Zone>(g_zones.Get(value));
    
    PrintToChatAll("%t", "Zone Inserted", zone.id);

    active_zone.id = zone.id;
    delete zone;
}

void DeleteZone(int client, int zoneID) 
{
	//Mark as deleted
	for (int i = 0; i < g_zones.Length; i++) 
    {
		Zone zone = view_as<Zone>(g_zones.Get(i));
		if (zone.id == zoneID) 
        {
			zone.id = -1;
			break;	
		}	
	}

	//Send request
	char buffer[128];
	Format(buffer, sizeof buffer, "zones/%i", zoneID);
	http_client.Delete(buffer, OnZoneDelete, client);
}

public void OnZoneDelete(HTTPResponse response, any data)
{
	if (response.Status != HTTPStatus_OK) 
    { 
		LogError("Invalid Response on zone deletion");
		return; 
	}
	
	if ( data > -1 ) 
    {
		PrintToChat(data, "<info>Info |<message> Zone deleted. Changes will take effect on next map load.");
	}
}

void ShowZoneList(int client) 
{    
    Menu menu = new Menu(MenuHandler_ZoneList);
    menu.SetTitle("<Loaded Zone List>\n ");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    
    if (!g_total_zones) 
    {
        menu.AddItem("", "[No Custom Triggers]", ITEMDRAW_DISABLED);
        menu.Display(client, MENU_TIME_FOREVER);
        return;
    }
    
    char buffer[128], cindex[10];
    
    for (int i = 0; i < g_total_zones; i++) 
    {
        Zone zone = view_as<Zone>(g_zones.Get(i));  
        IntToString(i, cindex, sizeof(cindex));
        FormatEx(buffer, sizeof buffer, "#%i | %s %i", i + 1, zone_type_names[view_as<int>(zone.type) + 1], zone.value);
        menu.AddItem(cindex, buffer);
    }
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneList(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        char cindex[10];
        menu.GetItem(choice, cindex, sizeof cindex);
        int index = StringToInt(cindex);
        ShowZoneInfo(client, index);
    }

    else if (action == MenuAction_Cancel)
    {
        if (choice == MenuCancel_ExitBack) 
        {
            ShowZoneMenu(client);
        }
    }

    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowZoneInfo(int client, int index) 
{    
    float start[3], end[3];
    char filter[32], zone_id[10], buffer[384];
    
    Zone zone = g_zones.Get(index);
    zone.GetStartCoordinates(start);
    zone.GetEndCoordinates(end);
    zone.GetFilterName(filter, sizeof filter);
    
    FormatEx(zone_id, sizeof zone_id, "%i", zone.id);
    Format(buffer, sizeof(buffer), "<Custom Zone>\n \n");
    Format(buffer, sizeof(buffer), "%sZone ID: %i\n \n", buffer, zone.id);
    Format(buffer, sizeof(buffer), "%sFilter: %s\n \n", buffer, filter);
    Format(buffer, sizeof(buffer), "%sStart: %.1f %.1f %.1f\n \n", buffer, start[0], start[1], start[2]);
    Format(buffer, sizeof(buffer), "%sEnd: %.1f %.1f %.1f\n \n", buffer, end[0], end[1], end[2]);

    Menu menu = new Menu(MenuHandler_ZoneInfo);
    menu.SetTitle(buffer);
    menu.AddItem(zone_id, "Delete Trigger", (zone.id == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneInfo(Menu menu, MenuAction action, int client, int choice) 
{
    if (action == MenuAction_Select)
    {
        if (!choice)
        {
            char cindex[16];
            menu.GetItem(choice, cindex, sizeof(cindex));
            int index = StringToInt(cindex);
            DeleteZone(client, index);
            ShowZoneList(client);
        }
    }

    else if (action == MenuAction_Cancel)
    {
        if (choice == MenuCancel_ExitBack)
        {
            ShowZoneList(client);
        }
    }

    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public Action DrawDevZone(Handle Timer, any data) 
{
    switch (g_draw_zone_mode[data]) 
    {
        case DrawMode_Stopped:
        {
            return Plugin_Stop;
        }
        case DrawMode_Active:  
        {
            float temp_zone_max[3];

            if (g_grid_snapping[data]) 
                GetClientSnappedOrigin(data, temp_zone_max, g_grid_size[data], true);
            else 
                GetClientAbsOrigin(data, temp_zone_max);
                
            DrawLaserBox(g_draw_zone_start[data], temp_zone_max, {255, 255, 255, 255}, 0.1, true);
        }
        case DrawMode_Frozen:  
        {
            DrawLaserBox(g_draw_zone_start[data], g_draw_zone_end[data], {120, 80, 30, 255}, 0.1, true);
        }
    }

    return Plugin_Continue;
}

public Action DrawZone(Handle Timer) 
{
    if (!g_zones_loaded || !g_round_started) 
    {
        return Plugin_Continue;
    }
    
    for (int i = 0; i < g_total_zones; i++) 
    {	
        float start[3], end[3];
        Zone zone = g_zones.Get(i);
        zone.GetStartCoordinates(start);
        zone.GetEndCoordinates(start);

        DrawLaserBox(start, end, {0, 128, 192, 255}, 1.0, false);
    }
    
    return Plugin_Continue;
}