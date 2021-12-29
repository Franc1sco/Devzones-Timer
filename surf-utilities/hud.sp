Handle g_surfTimerHandle[MAXPLAYERS + 1];

public Action SurfShowHint(Handle timer, int client)
{
	g_surfTimerHandle[client] = null;
	int minute;
	float second;
	char buffer[64];
	
	if(client == 0 || !IsClientInGame(client))
	{
		return;
	}
	
	if(g_surfTimerEnabled[client] != 0)
	{
		return;
	}
	if(!IsPlayerAlive(client))
	{
		g_surfTimerEnabled[client] = 2;
		return;
	}
	
	MoveType movimiento = GetEntityMoveType(client);
	
	if(movimiento != MOVETYPE_WALK && movimiento != MOVETYPE_LADDER)
	{
		g_surfTimerEnabled[client] = 2;
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Cheat detected, timer stopped.");
		return;
	}
	
	if(movimiento != MOVETYPE_LADDER)
	{
		if(GetEntityGravity(client) != 1.0)
			SetEntityGravity(client, 1.0);
			
		if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0)
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
			
	}
	
	if(gp_bHosties && IsClientInLastRequest(client))
	{
		g_surfTimerEnabled[client] = 2;
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Dont use timer on last request, timer stopped.");
		return;
	}
	
	GetClientName(client, buffer, sizeof(buffer));
	GetCurrentElapsedTime(client, minute, second);
	
	SetHudTextParams(0.0, 0.3, 0.5, 255, 255, 255, 100, 0, 0.0, 0.0, 0.0);
	if (g_surfPersonalBest[client] != 0.0)
	{
		ShowHudText(client, 3, "Time: %02d:%06.3fs\nPB: %02d:%06.3fs\nGame: %s", minute, second, g_surfPersonalBestMinute[client], g_surfPersonalBestSecond[client], g_surfZoneName[client]);
		//PrintCenterText(client, "Time: %02d:%06.3fs\nPB: %02d:%06.3fs\nGame: %s", minute, second, g_surfPersonalBestMinute[client], g_surfPersonalBestSecond[client], g_surfZoneName[client]);
	}
	else
	{
		ShowHudText(client, 3, "Time: %02d:%06.3fs\nGame: %s", minute, second, g_surfZoneName[client]);
		//PrintCenterText(client, "Time: %02d:%06.3fs\nGame: %s", minute, second, g_surfZoneName[client]);
	}
	
	g_surfTimerHandle[client] = CreateTimer(0.1, SurfShowHint, client);
}