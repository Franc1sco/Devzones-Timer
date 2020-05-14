Handle g_surfTimerHandle[MAXPLAYERS + 1];

public Action SurfShowHint(Handle timer, int client)
{
	g_surfTimerHandle[client] = null;
	int minute;
	float second;
	char buffer[64];
	
	if(client == 0)
	{
		return;
	}
	
	if(g_surfTimerEnabled[client] != 0)
	{
		return;
	}
	/*
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		g_surfTimerEnabled[client] = 2;
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Noclip detected, admin abuse.");
		return;
	}*/
	
	GetClientName(client, buffer, sizeof(buffer));
	GetCurrentElapsedTime(client, minute, second);
	
	if (g_surfPersonalBest[client] != 0.0)
	{
		PrintHintText(client, "Time: %02d:%06.3fs\nPB: %02d:%06.3fs\nGame: %s", minute, second, g_surfPersonalBestMinute[client], g_surfPersonalBestSecond[client], g_surfZoneName[client]);
	}
	else
	{
		PrintHintText(client, "Time: %02d:%06.3fs\nGame: %s", minute, second, g_surfZoneName[client]);
	}
	
	g_surfTimerHandle[client] = CreateTimer(0.1, SurfShowHint, client);
}