#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG false

Cookie CookieForceName;
Handle g_checkTimer[NEO_MAXPLAYERS+1];
char g_playerNames[NEO_MAXPLAYERS+1][32];
bool g_cookiesCached[NEO_MAXPLAYERS+1];
bool g_settingName[NEO_MAXPLAYERS+1];
bool g_nameChangeCooldown[NEO_MAXPLAYERS+1];
bool g_checkingTeam[NEO_MAXPLAYERS+1];
bool g_forceName[NEO_MAXPLAYERS+1];
bool g_lateLoad;

public Plugin myinfo = {
	name = "NT Force name",
	author = "bauxite, credits to Teamkiller324, Glubsy",
	description = "Force a clients name",
	version = "0.1.0",
	url = "",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()	
{
	LoadTranslations("common.phrases");
	CookieForceName = RegClientCookie("Force_Name_Force_Name", "Force Name", CookieAccess_Private);
	RegAdminCmd("sm_forcename", ForceName, ADMFLAG_GENERIC, "Force a clients name");
	AddCommandListener(Command_JoinTeam, "jointeam");
	HookEvent("player_changename", OnPlayerChangeName, EventHookMode_Pre);
	HookEvent("game_round_start", OnRoundStartPost, EventHookMode_Post);
	
	AutoExecConfig(true);
	
	if(g_lateLoad)
	{
		g_forceMode = NameForceBehaviour.IntValue;
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientCookiesCached(client);
			}
		}
	}
}

public Action OnPlayerChangeName(Event event, const char[] name, bool Dontbroadcast)
{
	#if DEBUG
	PrintToServer("[Force Name] Name Change event");
	#endif
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client <= 0 || !g_cookiesCached[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if(g_forceName[client])
	{
		SetEventBroadcast(event, true);
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public void OnRoundStartPost(Event event, const char[] name, bool dontBroadcast)
{
	if(g_forceName[client])
	{
		RequestFrame(CheckNameRoundStart, event.GetInt("userid"));
	}
}

void CheckNameRoundStart(int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || !g_cookiesCached[client] || !IsClientInGame(client))
	{
		return;
	}
	
	if(IsValidHandle(g_checkTimer[client]))
	{
		delete g_checkTimer[client];
	}
	
	g_checkTimer[client] = CreateTimer(2.0, CheckNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
	if(g_checkingTeam[client] || !g_forceName[client] || !IsClientInGame(client))
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
	
	if(client <= 0 || !g_forceName[client] || !IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
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
	PrintToServer("[Force Name] CheckNameTimer");
	#endif
	
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || !g_forceName[client] || !IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
		return Plugin_Stop;
	}
	
	if(g_nameChangeCooldown[client])
	{
		#if DEBUG
		PrintToServer("[Force Name] CheckNameTimer, already setting name, creating new timer");
		#endif
		
		if(IsValidHandle(g_checkTimer[client]))
		{
			g_checkTimer[client] = null;
		}
		
		g_checkTimer[client] = CreateTimer(5.0, CheckNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
		
		return Plugin_Stop;
	}
	
	g_nameChangeCooldown[client] = true;
	
	#if DEBUG
	char bufName[32];
	GetClientName(client, bufName, sizeof(bufName));
	PrintToServer("[Force Name] CheckNameTimer: %s : %s", bufName, g_playerNames[client]);
	#endif
	
	CreateTimer(3.0, SetNameTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action SetNameTimer(Handle timer, int userid)
{
	#if DEBUG
	PrintToServer("[Force Name] SetNameTimer");
	#endif
		
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || !g_forceName[client] || !IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
		return Plugin_Stop;
	}
	
	g_settingName[client] = true;
	SetClientName(client, g_playerNames[client]);
	CreateTimer(2.0, ResetNameChangeCooldown, userid, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.5, ResetNameBool, userid, TIMER_FLAG_NO_MAPCHANGE);
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

public Action ForceName(int client, int args)
{
	if(args != 2)
	{
		ReplyToCommand(client, "[Force Name] Usage: sm_forcename <target> <new name> to force a new name on a client");
		ReplyToCommand(client, "[Force Name] Usage: sm_forcename <target> <off | 0> - to disable force name on a client");
		return Plugin_Handled;
	}

	char argTwo[32];
	GetCmdArg(2, argTwo, sizeof(argTwo));
	
	char argTarget[32];
	GetCmdArg(1, argTarget, sizeof(argTarget));
	
	int target = FindTarget(client, argTarget, true, true);
	if(target == -1)
	{
		ReplyToCommand(client, "[Force Name] Target not found");
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(target) || !g_cookiesCached[target])
	{
		ReplyToCommand(client, "[Force Name] Target cookies are not cached or they are not in game, try again later");
		return Plugin_Handled;
	}

	if(StrEqual(argTwo, "0", false) || StrEqual(argTwo, "off", false))
	{
		SetClientCookie(target, CookieForceName, "");
		g_forceName[target] = false;
		return Plugin_Handled;
	}
	else 
	{
		SetClientCookie(target, CookieForceName, argNewName);
		strcopy(g_playerNames[target], sizeof(g_playerNames[]), argTwo);
		g_forceName[target] = true;
	}
	
	CreateTimer(2.0, CheckCookieTimer, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action CheckCookieTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0)
	{
		return Plugin_Stop;
	}
	
	RequestFrame(OnClientCookiesCached, client);
	return Plugin_Stop;
}

public void OnClientCookiesCached(int client)
{
	#if DEBUG
	PrintToServer("[Force Name] OnClientCookiesCached");
	#endif
	
	char forceName[32];
	
	GetClientCookie(client, CookieForceName, forceName, sizeof(forceName));
	
	if(forceName[0] == '\0')
	{
		g_forceName[client] = false;
	}
	else
	{
		strcopy(g_playerNames[client], sizeof(g_playerNames[]), forceName);
		g_forceName[client] = true;
	}
	
	g_cookiesCached[client] = true;
		
	if(!g_forceName[client])
	{
		return Plugin_Handled;
	}
	
	#if DEBUG
	PrintToServer("[Force Name] Cookies Timer");
	#endif
	
	CreateTimer(2.0, CheckNameTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientSettingsChanged(int client)	
{
	#if DEBUG
	PrintToServer("[Force Name] OnClientSettingsChanged");
	#endif
	
	if(!g_forceName[client] || !g_cookiesCached[client] || !IsClientInGame(client))
	{
		return;
	}
	
	if(g_settingName[client])
	{
		#if DEBUG
		PrintToServer("[Force Name] OnClientSettingsChanged, already setting name");
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
