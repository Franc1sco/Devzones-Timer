public Action MenuMyRank(int client, int args)
{
	if(IsInvalidClient(client)) 
		return Plugin_Handled;
		
	Menu menu = CreateMenu(Juegos1Handler);
	menu.SetTitle("Select the game from this map");
	char temp[128];
	for (int i = 0; i < GetArraySize(g_Zones); i++)
	{
		
		GetArrayString(g_Zones, i, temp, 128);
		menu.AddItem(temp, temp);
	}
	menu.ExitButton = true;
	menu.Display(client,MENU_TIME_FOREVER);	
	
	return Plugin_Handled;
}

public int Juegos1Handler(Menu menu, MenuAction action, int client, int itemNum) 
{
	if( action == MenuAction_Select ) 
	{
		char info[128];
		
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		strcopy(g_surfZoneName[client], 128, info);
		
		MenuMyRankContinue(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public int MenuMyRankHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action MenuMyRankContinue(int client)
{
	
	char query[255];
	char unescapedMap[32];
	char Map[65];
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	if(!SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map)))
	{
		LogError("Escape Error");
		return;
	}
	FormatEx(query, sizeof(query), sql_selectPlayerScoreByMap, GetSteamAccountID(client), Map, g_surfZoneName[client]);
	g_hDatabase.Query(T_MenuMyRankRetrive, query, GetClientSerial(client));
}

public void T_MenuMyRankRetrive(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	
	if ((client = GetClientFromSerial(data)) == 0)
		return;
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuMyRankHandler);
	
	char buffer[256];
	char TimeStamp[32];
	float Score;
	
	while(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		SQL_FetchString(results, 0, TimeStamp, sizeof(TimeStamp));
		Score = SQL_FetchFloat(results, 1);
		FormatEx(buffer, sizeof(buffer), "%s : %.3f sec", TimeStamp, Score);
		menu.AddItem(buffer, buffer);
	}
	
	menu.SetTitle("Your Record");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuRankHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char ID[16];
			menu.GetItem(param2, ID, sizeof(ID));
			MenuRankSubmenu(param1, StringToInt(ID)); // Param1 is client
		}
		case MenuAction_End:
		{
			delete menu;
		}
	} 
}


public Action MenuRank(int client, int args)
{
	if(IsInvalidClient(client)) 
		return Plugin_Handled;
		
	Menu menu = CreateMenu(Juegos2Handler);
	menu.SetTitle("Select the game from this map");
	char temp[128];
	for (int i = 0; i < GetArraySize(g_Zones); i++)
	{
		GetArrayString(g_Zones, i, temp, 128);
		menu.AddItem(temp, temp);
	}
	menu.ExitButton = true;
	menu.Display(client,MENU_TIME_FOREVER);	
	
	return Plugin_Handled;
}

public int Juegos2Handler(Menu menu, MenuAction action, int client, int itemNum) 
{
	if( action == MenuAction_Select ) 
	{
		char info[128];
		
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		strcopy(g_surfZoneName[client], 128, info);
		
		MenuRankContinue(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action MenuRankContinue(int client)
{
	DataPack pack = CreateDataPack();
	char query[1024];
	char unescapedMap[32];
	char Map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	if(!SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map)))
	{
		LogError("Escape Error");
		return;
	}
	FormatEx(query, sizeof(query), sql_selectScore, Map, g_surfZoneName[client], Map, g_surfZoneName[client]);
	pack.WriteCell(GetClientSerial(client));
	pack.WriteString(unescapedMap);
	g_hDatabase.Query(T_MenuRankRetrive, query, pack);

}

public void T_MenuRankRetrive(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	
	DataPack pack = view_as<DataPack>(data);
	
	pack.Reset();
	
	if ((client = GetClientFromSerial(pack.ReadCell())) == 0)
		return;
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuRankHandler);
	
	int count = 0;
	char buffer[256], Name[32], ID[16];
	char steam[32];
	float Score;
	int ScoreMinute;
	
	Handle dupli = CreateArray(16);
	while(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		SQL_FetchString(results, 1, steam, sizeof(steam));
		// aqui me salian duplicados con el iner join ese, asi que puse esto para no repetir steams para que no salgan varias veces en el !wr solo una
		if(FindStringInArray(dupli, steam) != -1) // si la steam ya esta en la array se ignora para evitar duplicados
		{
			continue;
		}
		SQL_FetchString(results, 2, Name, sizeof(Name));
		Score = SQL_FetchFloat(results, 3);
		SQL_FetchString(results, 0, ID, sizeof(ID));
		
		ScoreMinute = RoundToFloor(Score) / 60;
		FormatEx(buffer, sizeof(buffer), "#%d - %s - %02d:%06.3f", ++count, Name, ScoreMinute, Score - ScoreMinute * 60.0);
		
		menu.AddItem(ID, buffer);
		
		PushArrayString(dupli, steam); // añado al array para que si se vuelve a repetir, se ignore
	}
	
	delete dupli;
	
	//delete results;
	
	if(count == 0)
	{
		menu.AddItem("There is Nothing To Show :(", "There is Nothing To Show :(");
	}
	
	pack.ReadString(Name, sizeof(Name));
	menu.SetTitle("Records For %s:\n(%d records)", Name, count);
	
	CloseHandle(pack);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

void MenuRankSubmenu(int client, int ID)
{
	char query[256];
	FormatEx(query, sizeof(query), sql_selectScoreByID, ID, g_surfZoneName[client]);
	g_hDatabase.Query(T_MenuRankSubmenu, query, GetClientSerial(client));
}

public void T_MenuRankSubmenu(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	
	if(client == 0)
		return;
		
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuRankSubmenuHandler);
	
	char buffer[64];
	char UserName[32], MapName[32], TimeStamp[32];
	int UserID;
	float Time;
	
	int TimeMinute;
	if(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		SQL_FetchString(results, 0, UserName, sizeof(UserName));
		UserID = SQL_FetchInt(results, 1);
		SQL_FetchString(results, 2, MapName, sizeof(MapName));
		Time = SQL_FetchFloat(results, 3);
		SQL_FetchString(results, 4, TimeStamp, sizeof(TimeStamp));
	}
	
	menu.SetTitle("%s [U:1:%d]\n--- %s\nGame: %s:", UserName, UserID, MapName, g_surfZoneName[client]);
	
	TimeMinute = RoundToFloor(Time) / 60;
	
	FormatEx(buffer, sizeof(buffer), "Time: %02d:%06.3fs", TimeMinute, Time - TimeMinute * 60);
	menu.AddItem("1", buffer);
	FormatEx(buffer, sizeof(buffer), "Date: %s", TimeStamp);
	menu.AddItem("2", buffer);
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	//delete results;
}

public int MenuRankSubmenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}