#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG true

Database hDB;

bool g_cookiesCached[NEO_MAXPLAYERS+1];
bool g_forceName[NEO_MAXPLAYERS+1];
char g_playerNames[NEO_MAXPLAYERS+1][32];

ConVar NameForceBehaviour;
Handle g_checkTimer[NEO_MAXPLAYERS+1];
bool g_settingName[NEO_MAXPLAYERS+1];
bool g_nameChangeCooldown[NEO_MAXPLAYERS+1];
bool g_checkingTeam[NEO_MAXPLAYERS+1];

bool g_listCooldown;
bool g_lateLoad;
int g_forceMode;

char g_tag[] = "[Name Manager]";

public Plugin myinfo = {
	name = "NT Name Manager",
	author = "bauxite, credits to Teamkiller324, Glubsy",
	description = "!storename, !forcename, !shownames, cvar sm_name_force 0/1/2",
	version = "0.6.0",
	url = "https://github.com/bauxiteDYS/SM-NT-Name-Manager",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()	
{
	LoadTranslations("common.phrases");
	NameForceBehaviour = CreateConVar("sm_name_force", "1", "0 - Off, 1 - Forced name for specific clients, 2 - Forced name for all clients", _, true, 0.0, true, 2.0);
	HookConVarChange(NameForceBehaviour, NameForceBehaviour_Changed);

	RegAdminCmd("sm_storename", StoreName, ADMFLAG_GENERIC, "Stores a clients name");
	RegAdminCmd("sm_forcename", StoreName, ADMFLAG_GENERIC, "Force a clients name");
	RegAdminCmd("sm_unforcename", StoreName, ADMFLAG_GENERIC, "Unforce a clients name");
	RegAdminCmd("sm_shownames", ShowName, ADMFLAG_GENERIC, "Show current and stored names in console");
	AddCommandListener(Command_JoinTeam, "jointeam");
	HookEvent("player_changename", OnPlayerChangeName, EventHookMode_Pre);
	HookEvent("game_round_start", OnRoundStartPost, EventHookMode_Post);
	
	AutoExecConfig(true);
	
	if(g_lateLoad)
	{
		g_forceMode = NameForceBehaviour.IntValue;
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsFakeClient(client))
			{
				continue;
			}
			
			if(IsClientInGame(client))
			{
				//OnClientCookiesCached(client);
				OnClientPutInServer(client);
			}
		}
	}
}

public void OnConfigsExecuted()
{
	g_forceMode = NameForceBehaviour.IntValue;
	
	DB_init();
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	
	int userid = GetClientUserId(client);
	
	if(userid <= 0)
	{
		return;
	}
	
	DB_retrieveCookie(userid);
}

void DB_init()
{
	char error[255];
	hDB = SQLite_UseDatabase("nt_name_manager", error, sizeof(error));

	if(hDB == INVALID_HANDLE)
	{
		SetFailState("%s SQL error: %s", g_tag, error);
	}
	
	Transaction txn;
	txn = SQL_CreateTransaction();
	
	char query[512];
	
	hDB.Format(query, sizeof(query), 
	"\
	CREATE TABLE IF NOT EXISTS nt_stored_names \
	(\
	steamID	TEXT NOT NULL, \
	forceName INTEGER NOT NULL DEFAULT 0, \
	storedName TEXT, \
	PRIMARY KEY(steamID) \
	);\
	");
	
	hDB.Query(DB_fast_callback, "VACUUM", _, DBPrio_High);
	
	txn.AddQuery(query);
	
	hDB.Execute(txn, TxnSuccess_Init, TxnFailure_Init);
}

void TxnSuccess_Init(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    PrintToServer("%s SQL Database init succesful", g_tag);
}

void TxnFailure_Init(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    SetFailState("%s SQL Error Database init failure: [%d] %s", g_tag, failIndex, error);
}

void DB_retrieveCookie(int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || client > MaxClients)
	{
		return;
	}
	
	char steamID[32];
	
	if(!GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		LogError("%s Error getting SteamID in RetrieveCookie", g_tag);
		return;
	}
	
	char query[256];
	
	hDB.Format(query, sizeof(query), 
	"\
	SELECT forceName, storedName \
	FROM nt_stored_names \
	WHERE steamID = '%s'; \
	",
	steamID);
	
	hDB.Query(DB_cookie_callback, query, userid, DBPrio_Normal);
}

void DB_cookie_callback(Database db, DBResultSet results, const char[] error, int userid)
{
	if (!db || !results || error[0])
	{
		LogError("%s SQL Error: %s", g_tag, error);
		return;
	}

	if (SQL_GetRowCount(results) == 0 || !SQL_FetchRow(results))
	{
		return;
	}
	
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || client > MaxClients)
	{
		return;
	}
	
	int forceBool = SQL_FetchInt(results, 0);
	
	g_forceName[client] = !!forceBool;
	
	SQL_FetchString(results, 1, g_playerNames[client], sizeof(g_playerNames[]));
	
	char bufName[32];
	char steamID[32];
	
	if(g_playerNames[client][0] == '\0')
	{
		GetClientName(client, bufName, sizeof(bufName));
		strcopy(g_playerNames[client], sizeof(g_playerNames[]), bufName);
		
		if(!GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID)))
		{
			LogError("%s Error getting SteamID in RetrieveCookieSetnewcookie", g_tag);
			return;
		}
		
		DB_insertName(steamID, g_forceName[client], g_playerNames[client]);
	}
	
	g_cookiesCached[client] = true;
	
	#if DEBUG
	PrintToServer("F:%d N:%s", g_forceName[client], g_playerNames[client]);
	#endif
	
	if(g_forceMode == 0)
	{
		#if DEBUG
		PrintToServer("[Name Manager] db retrieve callback");
		#endif
		
		return;
	}
	
	#if DEBUG
	PrintToServer("[Name Manager] Cookies Timer");
	#endif
	
	CreateTimer(2.0, CheckNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckCookieTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0)
	{
		return Plugin_Stop;
	}
	
	RequestFrame(CheckClientCookie, client);
	return Plugin_Stop;
}

public Action StoreName(int client, int args)
{
	char cmdName[4 + 1];
	GetCmdArg(0, cmdName, sizeof(cmdName));
	char cmdChar = CharToLower(cmdName[3]);
	bool storeName = cmdChar == 's' ? true : false;
	bool forceName = cmdChar == 'f' ? true : false;
	bool unforce = cmdChar == 'u' ? true : false;
	
	if(forceName && (args != 2 && args != 1))
	{
		ReplyToCommand(client, "[Name Manager] Usage: sm_forcename <target> <new name> to force a new name on a client");
		ReplyToCommand(client, "[Name Manager] Usage: sm_forcename <target> to enable forced name on a client");
		return Plugin_Handled;
	}
	
	if(storeName && args != 2)
	{
		ReplyToCommand(client, "[Name Manager] Usage: sm_storename <target> <newname>");
		return Plugin_Handled;
	}
	
	if(unforce && args != 1)
	{
		ReplyToCommand(client, "[Name Manager] Usage: sm_unforcename <target>");
		return Plugin_Handled;
	}

	char argTwo[32];
	if(args == 2)
	{
		GetCmdArg(2, argTwo, sizeof(argTwo));
	}
	
	char argTarget[32];
	GetCmdArg(1, argTarget, sizeof(argTarget));
	
	int target = FindTarget(client, argTarget, true, true);
	if(target == -1)
	{
		ReplyToCommand(client, "[Name Manager] Target not found");
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(target) || !g_cookiesCached[target])
	{
		ReplyToCommand(client, "[Name Manager] Target cookies are not cached or they are not in game, try again later");
		return Plugin_Handled;
	}
	
	char steamID[32];
	
	if(!GetClientAuthId(target, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		PrintToChat(client, "%s Error getting SteamID, try again later", g_tag);
		return Plugin_Handled;
	}
	
	if(unforce)
	{
		DB_clearForce(steamID, 0);
		g_forceName[target] = false;
		return Plugin_Handled;
	}
	
	if(forceName)
	{
		if(args == 1)
		{
			SetClientCookie(target, CookieForceName, "1");
		}
		else
		{
			SetClientCookie(target, CookiePlayerName, argTwo);
			SetClientCookie(target, CookieForceName, "1");
			strcopy(g_playerNames[target], sizeof(g_playerNames[]), argTwo);
		}
	}
	
	if(storeName)
	{
		SetClientCookie(target, CookiePlayerName, argTwo);
		strcopy(g_playerNames[target], sizeof(g_playerNames[]), argTwo);
	}
	
	if(g_forceMode == 0)
	{
		return Plugin_Handled;
	}
	
	CreateTimer(2.0, CheckCookieTimer, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

void DB_insertForce(const char[] steamID, int forceBool)
{	
	char query[512];
	
	char ogQuery[] = 	
	"\
	INSERT INTO nt_stored_names(steamID, forceBool) \
	VALUES ('%s', %d) \
	ON CONFLICT(steamID) \
	DO UPDATE SET \
	nt_stored_names.forceBool = excluded.forceBool; \
	";
	
	hDB.Format(query, sizeof(query), ogQuery, steamID, forceBool);
	
	hDB.Query(DB_fast_callback, query, _, DBPrio_Normal);
}

void DB_insertAll(const char[] steamID, int forceBool, const char[] newName)
{	
	char query[512];
	
	char ogQuery[] = 	
	"\
	INSERT INTO nt_stored_names(steamID, forceBool, newName) \
	VALUES ('%s', %d, '%s') \
	ON CONFLICT(steamID) \
	DO UPDATE SET \
	nt_stored_names.forceBool = excluded.forceBool, \
	nt_stored_names.newName = excluded.newName; \
	";
	
	hDB.Format(query, sizeof(query), ogQuery, steamID, forceBool, newName);
	
	hDB.Query(DB_fast_callback, query, _, DBPrio_Normal);
}

void DB_fast_callback(Database db, DBResultSet results, const char[] error, any data)
{
    if (!db || !results || error[0])
    {
        LogError("%s SQL Error: %s", g_tag, error);
        return;
    }
	else
	{
		PrintToServer("%s Some SQL thing was succesful", g_tag);
	}
}

public Action OnPlayerChangeName(Event event, const char[] name, bool Dontbroadcast)
{
	#if DEBUG
	PrintToServer("[Name Manager] Name Change event");
	#endif
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client <= 0 || g_forceMode == 0  || !g_cookiesCached[client] || !IsClientInGame(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}
	
	if(g_forceMode == 2 || (g_forceMode == 1 && g_forceName[client]))
	{
		SetEventBroadcast(event, true);
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public void OnRoundStartPost(Event event, const char[] name, bool dontBroadcast)
{
	RequestFrame(CheckNameRoundStart, event.GetInt("userid"));
}

void CheckNameRoundStart(int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || g_forceMode == 0  || !g_cookiesCached[client] || !IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	if(g_forceMode == 2 || (g_forceMode == 1 && g_forceName[client]))
	{
		if(IsValidHandle(g_checkTimer[client]))
		{
			delete g_checkTimer[client];
		}
	
		g_checkTimer[client] = CreateTimer(2.0, CheckNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void NameForceBehaviour_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_forceMode = convar.IntValue;
	
	if(g_forceMode == 2)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || GetClientTeam(i) <= 0 || IsFakeClient(i))
			{
				continue;
			}
			
			if(IsValidHandle(g_checkTimer[i]))
			{
				delete g_checkTimer[i];
			}
			
			g_checkTimer[i] = CreateTimer(1.0, CheckNameTimer, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
	if(g_forceMode == 0 || g_checkingTeam[client] || !IsClientInGame(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}
	
	g_checkingTeam[client] = true;
	CreateTimer(1.0, CheckTeam, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action CheckTeam(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || !IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	
	if(GetClientTeam(client) <= 0)
	{
		g_checkingTeam[client] = false;
		return Plugin_Stop;
	}
	
	if(IsValidHandle(g_checkTimer[client]))
	{
		delete g_checkTimer[client];
	}
	
	g_checkTimer[client] = CreateTimer(2.0, CheckNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
	g_checkingTeam[client] = false;
	
	return Plugin_Stop;
}

public Action CheckNameTimer(Handle timer, int userid)
{
	#if DEBUG
	PrintToServer("[Name Manager] CheckNameTimer");
	#endif
	
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || g_forceMode == 0 || !IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
		return Plugin_Stop;
	}
	
	if(GetClientTeam(client) <= 0 || (g_forceMode == 1 && !g_forceName[client]))
	{
		g_settingName[client] = false;
		g_nameChangeCooldown[client] = false;
		return Plugin_Stop;
	}
	
	if(g_nameChangeCooldown[client])
	{
		#if DEBUG
		PrintToServer("[Name Manager] CheckNameTimer, already setting name, creating new timer");
		#endif
		
		if(IsValidHandle(g_checkTimer[client]))
		{
			g_checkTimer[client] = null;
		}
		
		g_checkTimer[client] = CreateTimer(5.0, CheckNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
		
		return Plugin_Stop;
	}
	
	#if DEBUG
	char bufName[32];
	GetClientName(client, bufName, sizeof(bufName));
	PrintToServer("[Name Manager] CheckNameTimer: %s : %s", bufName, g_playerNames[client]);
	#endif
	
	g_nameChangeCooldown[client] = true;
	CreateTimer(3.0, SetNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action SetNameTimer(Handle timer, int userid)
{
	#if DEBUG
	PrintToServer("[Name Manager] SetNameTimer");
	#endif
		
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || !IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	
	if(GetClientTeam(client) <= 0 || (g_forceMode == 1 && !g_forceName[client]))
	{
		g_settingName[client] = false;
		g_nameChangeCooldown[client] = false;
		return Plugin_Stop;
	}
	
	g_settingName[client] = true;
	SetClientName(client, g_playerNames[client]);
	CreateTimer(0.5, ResetNameBool, userid, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, ResetNameChangeCooldown, userid, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}
public Action ResetNameBool(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0)
	{
		return Plugin_Stop;
	}
	
	g_settingName[client] = false;
	return Plugin_Stop;
}

public Action ResetNameChangeCooldown(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0)
	{
		return Plugin_Stop;
	}
	
	g_nameChangeCooldown[client] = false;
	return Plugin_Stop;
}

public Action ShowName(int client, int args)
{
	/*
	if(client <= 0)
	{
		return Plugin_Handled;
	}
	*/
	
	RequestFrame(PrintNamesInConsole, client);
	return Plugin_Handled;
}

void PrintNamesInConsole(int client)
{
	if(client <= 0 || !IsClientInGame(client))
	{
		return;
	}
	
	if(g_listCooldown)
	{
		ReplyToCommand(client, "[Name Manager] Cooldown, try again in 5s");
		return;
	}
	
	g_listCooldown = true;
	
	char buf[32+1];
	
	PrintToConsole(client, "============ Player Names ============");
	PrintToConsole(client, "Current ::: Stored");
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		
		GetClientName(i, buf, sizeof(buf));	
		PrintToConsole(client, "%s ::: %s", buf, g_playerNames[i]);
	}
	
	PrintToConsole(client, "======================================");
	
	CreateTimer(5.0, ResetListCooldown, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResetListCooldown(Handle timer)
{
	g_listCooldown = false;
	return Plugin_Stop;
}

public void OnClientSettingsChanged(int client)	
{
	#if DEBUG
	PrintToServer("[Name Manager] OnClientSettingsChanged");
	#endif
	
	if(g_forceMode == 0 || !g_cookiesCached[client] || !IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	if(g_forceMode == 1 && !g_forceName[client])
	{
		return;
	}
	
	if(g_settingName[client])
	{
		#if DEBUG
		PrintToServer("[Name Manager] OnClientSettingsChanged, already setting name");
		#endif
		
		return;
	}
	
	if(!IsValidHandle(g_checkTimer[client]))
	{
		g_checkTimer[client] = CreateTimer(3.0, CheckNameTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientDisconnect_Post(int client)
{
	ResetClientVariables(client);
}

public void OnMapEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		ResetClientVariables(client);
	}
	
	g_listCooldown = false;
}

void ResetClientVariables(int client)
{
	g_playerNames[client][0] = '\0';
	g_cookiesCached[client] = false;
	g_nameChangeCooldown[client] = false;
	g_settingName[client] = false;
	g_checkingTeam[client] = false;
	g_forceName[client] = false;
	
	// Some reason there's an error if we don't check if the timer is valid before deleting when that shouldn't be the case?
	// probably because it's not initialized as null???
	
	if(IsValidHandle(g_checkTimer[client]))
	{
		delete g_checkTimer[client];
	}
}
