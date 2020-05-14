#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <devzones>
#include <sdktools>
#include <colorlib>


#define VERSION "1.0.1"

#pragma newdecls required


//SQL Locking System

Database g_hDatabase;

//SQL Queries

char sql_createTables1[] = "CREATE TABLE IF NOT EXISTS `devzones_timerrank` ( \
  `ID` int(11) NOT NULL AUTO_INCREMENT, \
  `TimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, \
  `MapName` varchar(32) NOT NULL, \
  `ZoneName` varchar(32) NOT NULL, \
  `UserName` varchar(32) DEFAULT NULL, \
  `UserID` int(11) NOT NULL, \
  `Score` float NOT NULL, \
  PRIMARY KEY (`ID`) \
);";

//char sql_selectPlayerScore[] = "SELECT `TimeStamp`, `Score` FROM `devzones_timerrank` WHERE `UserID`='%d';"; // Arg: String:UserID
char sql_selectPlayerScoreByMap[] = "SELECT `TimeStamp`, `Score` FROM `devzones_timerrank` WHERE `UserID`='%d' AND `MapName`='%s' AND `ZoneName`='%s' ORDER BY `Score` ASC;"; // Arg: int32:UserID String:MapName(Must be escaped)
char sql_selectPersonalBestByMap[] = "SELECT `Score` FROM `devzones_timerrank` WHERE `UserID`='%d' AND `MapName`='%s' AND `ZoneName`='%s' ORDER BY `Score` ASC LIMIT 1;"; // Arg: int32:UserID String:MapName(Must be escaped)
char sql_selectScore[] = "SELECT `rankings1`.`ID`, `rankings2`.`UserID`, `rankings1`.`UserName`, `rankings2`.`MinScore` FROM ( SELECT `UserID`, Min(`Score`) as `MinScore` FROM `devzones_timerrank` WHERE `MapName`='%s' AND `ZoneName`='%s' GROUP BY `Score` ) as `rankings2` JOIN `devzones_timerrank` as `rankings1` ON `rankings1`.`Score` = `rankings2`.`MinScore` WHERE `MapName`='%s' AND `ZoneName`='%s' GROUP BY `Score`;"; // Arg: String:Map
char sql_selectScoreByID[] = "SELECT `UserName`, `UserID`, `MapName`, `Score`, `TimeStamp` FROM `devzones_timerrank` WHERE `ID`='%d' AND `ZoneName`='%s';"; // Arg int32:ID
char sql_insertScore[] = "INSERT INTO `devzones_timerrank` SET `MapName`='%s', `UserName`= '%s', `UserID`='%d', `Score`='%.3f', `ZoneName`= '%s';"; // Arg: int32:UserID, float32:Score


//Surf Timer Time ticking Process Variable

float g_surfPersonalBest[MAXPLAYERS + 1];
int g_surfPersonalBestMinute[MAXPLAYERS + 1];
float g_surfPersonalBestSecond[MAXPLAYERS + 1];
float g_surfTimerPoint[MAXPLAYERS + 1][2];
char g_surfTimerEnabled[MAXPLAYERS + 1] = { 0 }; // 0 on Surfing 1 on after reaching end zone 2 on being at start zone 3 on being at end zone


char g_surfZoneName[MAXPLAYERS + 1][128];
Handle g_Zones;

#include "surf-utilities/menu.sp"
#include "surf-utilities/hud.sp"

public Plugin myinfo =
{
	name = "Timer Utilities with DEV Zones",
	author = "Franc1sco Franug",
	description = "Timer with Custom Zones",
	version = VERSION,
	url = "http://steamcommunity.com/id/franug"
};

//Forwards

public void OnPluginStart()
{
	g_Zones = CreateArray(128);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_prestart", Event_Start);
	
	RegConsoleCmd("sm_mr", MenuMyRank, "A panel shows your record on this map.");
	RegConsoleCmd("sm_wr", MenuRank, "A panel shows server top record on this map.");
	RegConsoleCmd("sm_notimer", CloseC, "Close timer.");
	
	//AddCommandListener(Command_Cheat, "sm_slap");
	//AddCommandListener(Command_Cheat, "sm_teleport");
	
	if(SQL_CheckConfig("devzones_timer"))
	{
		Database.Connect(OnDatabaseConnect, "devzones_timer");
	} else {
		SetFailState("No found database entry devzones_timer on databases.cfg");
	}
}
/*
public Action Command_Cheat(int client, const char[] command,int args)
{
    if(g_surfTimerEnabled[client] == 0)
	{
		g_surfTimerEnabled[client] = 2;
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Cheat detected, admin abuse.");
	}
}
*/
public Action CloseC(int client, int args)
{
	if(g_surfTimerEnabled[client] == 0)
	{
		g_surfTimerEnabled[client] = 2;
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Stopped timer");
	}
	else
	{
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} No timer for stop");
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if(IsInvalidClient(client)) 
		return;
	
	g_surfPersonalBest[client] = 0.0;
	g_surfPersonalBestMinute[client] = 0;
	g_surfPersonalBestSecond[client] = 0.0;
	g_surfTimerEnabled[client] = 2;
	g_surfTimerPoint[client][0] = 0.0;
	g_surfTimerPoint[client][1] = 0.0;
	strcopy(g_surfZoneName[client], 128, "");

}

public void OnClientDisconnect(int client)
{
	delete g_surfTimerHandle[client];
}

/*
public void OnClientCookiesCached(int client)
{
	char buffer[5];
	GetClientCookie(client, g_cookieHintMode, buffer, sizeof(buffer));
	if(buffer[0] == '\0')
		g_cookieClientHintMode[client] = GetConVarInt(g_cvarMode);
}
*/

///////////////////
//  Event Hook Functions

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_surfTimerEnabled[client] = 2;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_surfTimerEnabled[client] = 2;
}

public void Zone_OnClientEntry(int client, const char[] zone)
{
	if(IsInvalidClient(client)) 
		return;
	
	if(StrContains(zone, "timer_start", true) == 0)
	{
		char zonename[128];
		strcopy(zonename, 128, zone);
		ReplaceString(zonename, 128, "timer_start_", "", false);
		if(!StrEqual(zonename, g_surfZoneName[client]))
			SurfGetPersonalBest(client, zonename);
		
		strcopy(g_surfZoneName[client], 128, zonename);
		g_surfTimerEnabled[client] = 2;
		delete g_surfTimerHandle[client];
		
		return;
	}
	else if(StrContains(zone, "timer_stop", true) == 0)
	{
		char zonename[128];
		strcopy(zonename, 128, zone);
		ReplaceString(zonename, 128, "timer_stop_", "", false);
		if(!StrEqual(zonename, g_surfZoneName[client]))
			return;
			
		if(g_surfTimerEnabled[client] == 0)
		{	
			g_surfTimerPoint[client][1] = GetGameTime();
			float scoredTime = g_surfTimerPoint[client][1] - g_surfTimerPoint[client][0];
			CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} You've reached to End Zone in %.3fs", scoredTime);
			
			strcopy(g_surfZoneName[client], 128, zonename);
			
			SurfSetRecord(client, scoredTime, zonename);
			SurfGetPersonalBest(client, zonename);
		}
		g_surfTimerEnabled[client] = 3;
		
		return;
	}
	else if(StrContains(zone, "timer_close", true) == 0)
	{
		if(g_surfTimerEnabled[client] == 0)
		{	
			CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} You exit from the game zone");
			g_surfTimerEnabled[client] = 2;
		}
		
		return;
	}
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if(IsInvalidClient(client)) 
		return;
	
	if(StrContains(zone, "timer_start", false) == 0)
	{
		/*
		if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
		{
			g_surfTimerEnabled[client] = 2;
			CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Noclip detected, admin abuse.");
			return;
		}*/
		g_surfTimerPoint[client][0] = GetGameTime();
		g_surfTimerEnabled[client] = 0;
		g_surfTimerHandle[client] = CreateTimer(0.1, SurfShowHint, client);
		
		char zonename[128];
		strcopy(zonename, 128, zone);
		ReplaceString(zonename, 128, "timer_start_", "", false);
		CPrintToChat(client, "{lighgreen}[Franug-Timer]{green} Started timer for game %s. Type !notimer for stop timer", zonename);
		
		return;
	}
	else if(StrContains(zone, "timer_stop", false) == 0)
	{
		char zonename[128];
		strcopy(zonename, 128, zone);
		ReplaceString(zonename, 128, "timer_stop_", "", false);
		if(!StrEqual(zonename, g_surfZoneName[client]))
			return;
			
		g_surfTimerEnabled[client] = 1;
		
		return;
	}
}


///////////////////////
// Own Functions

bool IsInvalidClient(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) 
		return true;
	else 
		return false;
}

void GetCurrentElapsedTime(int client, int &minute, float &second)
{
	if(g_surfTimerEnabled[client] != 0)
	{
		minute = 0;
		second = 0.0;
		
		return;
	}
	float delta = GetGameTime() - g_surfTimerPoint[client][0];
	
	GetSecondToMinute(delta, minute, second);
	
	return;
}

void GetSecondToMinute(float input, int &minute, float &second)
{	
	minute = RoundToFloor(input) / 60;
	second = input - minute * 60.0;
	
	return;
}

public void OnDatabaseConnect(Database db, const char[] error, any data)
{
	/**
	 * See if the connection is valid.  If not, don't un-mark the caches
	 * as needing rebuilding, in case the next connection request works.
	 */
	if(db == null)
	{
		LogError("Database failure: %s", error);
	}
	else 
	{
		g_hDatabase = db;
	}
	db.Query(T_CreateTable, sql_createTables1, _, DBPrio_High);
	
	return;
}

public void T_CreateTable(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
}

void SurfSetRecord(int client, float timeScored, char[] zonename)
{
	char query[255];
	char unescapedMap[32];
	char Map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	
	char Name[MAX_NAME_LENGTH+1];
	char SafeName[(sizeof(Name)*2)+1];
	if(!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(g_hDatabase, Name, SafeName, sizeof(SafeName));
	}
	
	if(!(SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map))))
	{
		LogError("Escape Error");
		return;
	}
	
	FormatEx(query, sizeof(query), sql_insertScore, Map, SafeName, GetSteamAccountID(client), timeScored, zonename);
	g_hDatabase.Query(T_SurfSetRecord, query, GetClientSerial(client));
	
	return;
}

public void T_SurfSetRecord(Database db, DBResultSet results, const char[] error, any data)
{
	if(GetClientFromSerial(data) == 0)
		return;
	
	if(db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
}

void SurfGetPersonalBest(int client, char[] zone)
{
	char query[255];
	char unescapedMap[32], Map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	
	if(!(SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map))))
	{
		LogError("Escape Error");
		return;
	}
	
	FormatEx(query, sizeof(query), sql_selectPersonalBestByMap, GetSteamAccountID(client), Map, zone);
	g_hDatabase.Query(T_SurfGetPersonalBest, query, GetClientSerial(client));
	
	return;
}

public void T_SurfGetPersonalBest(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	g_surfPersonalBest[client] = 0.0;
	
	if(db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	if(SQL_HasResultSet(results) && SQL_FetchRow(results))
	{
		g_surfPersonalBest[client] = SQL_FetchFloat(results, 0);
		GetSecondToMinute(g_surfPersonalBest[client], g_surfPersonalBestMinute[client], g_surfPersonalBestSecond[client]);
	}
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	ClearArray(g_Zones);
}

public void Zone_OnCreated(const char [] zone)
{
	if(StrContains(zone, "timer_start", true) == 0)
	{
		char zonename[128];
		strcopy(zonename, 128, zone);
		ReplaceString(zonename, 128, "timer_start_", "", false);
		
		if(FindStringInArray(g_Zones, zonename) == -1)
			PushArrayString(g_Zones, zonename);
	}
}