#include <sdktools>
#include <clientprefs>

Handle CookiePlayerName;
Handle CookieForceName;
ConVar NameForceBehaviour;
char g_playerNames[32+1][32];
char g_newNames[32+1][32];
bool g_cookiesCached[32+1];
bool g_gettingName[32+1];
bool g_settingName[32+1];
bool g_forceName[32+1];
int g_forceMode;

public Plugin myinfo = {
	name = "NT Name Manager",
	author = "bauxite, credits to Teamkiller324",
	description = "!forcename, !storename, !shownames, cvar sm_name_force 0/1/2",
	version = "0.3.3",
	url = "https://github.com/bauxiteDYS/SM-NT-Name-Manager",
};

public void OnPluginStart()	
{
	LoadTranslations("common.phrases");
	NameForceBehaviour = CreateConVar("sm_name_force", "1", "0 off, 1 for forced, 2 all clients", _, true, 0.0, true, 2.0);
	HookConVarChange(NameForceBehaviour, NameForceBehaviour_Changed);
	CookiePlayerName = RegClientCookie("Player_Name", "Stores Clients Name", CookieAccess_Private);
	CookieForceName = RegClientCookie("Force_Name", "Force Name", CookieAccess_Private);
	RegAdminCmd("sm_storename", StoreName, ADMFLAG_GENERIC, "Stores a clients name");
	RegAdminCmd("sm_forcename", ForceName, ADMFLAG_GENERIC, "Force a clients name");
	RegAdminCmd("sm_shownames", ShowName, ADMFLAG_GENERIC, "Show current and stored names in console");
	AddCommandListener(Command_JoinTeam, "jointeam");
	HookEvent("player_changename", OnPlayerChangeName, EventHookMode_Pre);
}

public Action OnPlayerChangeName(Event event, const char[] name, bool Dontbroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsClientInGame(client) || client <= 0)
	{
		return Plugin_Continue;
	}
		
	if(g_forceMode == 0)
	{
		return Plugin_Continue;
	}
	
	if(!g_cookiesCached[client])
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

public void OnConfigsExecuted()
{
	g_forceMode = NameForceBehaviour.IntValue;
}

void NameForceBehaviour_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_forceMode = convar.IntValue;
	
	if(g_forceMode == 2)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || GetClientTeam(i) <= 0)
			{
				continue;
			}
			
			CreateTimer(1.0, CheckNameTimer, i, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
	if(g_forceMode != 0)
	{
		return Plugin_Continue;
	}
	
	if(!IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	CreateTimer(1.0, CheckTeam, client, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action CheckTeam(Handle timer, int client)
{
	if(!IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
		return Plugin_Stop;
	}
	
	CreateTimer(1.0, CheckNameTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Stop;
}

public Action CheckNameTimer(Handle timer, int client)
{
	if(g_forceMode == 0)
	{
		return Plugin_Stop;
	}
	
	if(g_forceMode == 1 && !g_forceName[client])
	{
		return Plugin_Stop;
	}
	
	if(!IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
		return Plugin_Stop;
	}
	
	if(g_settingName[client])
	{
		return Plugin_Stop;
	}
	
	g_settingName[client] = true;
		
	char bufName[32];
	GetClientName(client, bufName, sizeof(bufName));
	if(!StrEqual(bufName, g_playerNames[client]))
	{
		CreateTimer(3.0, SetNameTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		g_settingName[client] = false;
	}
	
	return Plugin_Stop;
}

public Action SetNameTimer(Handle timer, int client)
{
	if(!IsClientInGame(client) || GetClientTeam(client) <= 0)
	{
		return Plugin_Stop;
	}
	
	SetClientName(client, g_playerNames[client]);
	CreateTimer(1.0, ResetNameBool, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action ResetNameBool(Handle timer, int client)
{
	g_settingName[client] = false;
	return Plugin_Stop;
}

public Action ShowName(int client, int args)
{
	if(client <= 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	PrintToConsole(client, "============ Player Names ============");
	PrintToConsole(client, "Current ::: Stored");
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
			
		PrintToConsole(client, "%s ::: %s", g_newNames[i], g_playerNames[i]);
	}
	
	PrintToConsole(client, "======================================");
	
	return Plugin_Continue;
}

public Action ForceName(int client, int args)
{
	if(args == 0)
	{
		return Plugin_Handled;
	}
	
	char arg1Target[32];
	GetCmdArg(1, arg1Target, sizeof(arg1Target));
	
	int target = FindTarget(client, arg1Target, true, true);
	if(target == -1)
	{
		ReplyToCommand(client, "target not found");
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(target) || !g_cookiesCached[target])
	{
		ReplyToCommand(client, "Target cookies are not cached or they are not in game, try again later");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		SetClientCookie(target, CookieForceName, "0");
		g_forceName[target] = false;
		return Plugin_Handled;
	}
	
	SetClientCookie(target, CookieForceName, "1");
	
	char arg2ForceName[32];
	GetCmdArg(2, arg2ForceName, sizeof(arg2ForceName));

	if(g_settingName[target])
	{
		ReplyToCommand(client, "Already setting name, try again later");
		return Plugin_Handled;
	}
	
	SetClientCookie(target, CookiePlayerName, arg2ForceName);
	strcopy(g_playerNames[target], sizeof(g_playerNames[]), arg2ForceName);
	
	if(g_forceMode == 0)
	{
		return Plugin_Handled;
	}
	
	CreateTimer(1.0, CheckCookieTimer, target, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action StoreName(int client, int args)
{
	if(args != 2)
	{
		return Plugin_Handled;
	}
	
	char arg2ForceName[32];
	GetCmdArg(2, arg2ForceName, sizeof(arg2ForceName));
	
	char arg1Target[32];
	GetCmdArg(1, arg1Target, sizeof(arg1Target));
	
	int target = FindTarget(client, arg1Target, true, true);
	if(target == -1)
	{
		ReplyToCommand(client, "target not found");
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(target) || !g_cookiesCached[target])
	{
		ReplyToCommand(client, "Target cookies are not cached or they are not in game, try again later");
		return Plugin_Handled;
	}
	
	if(g_settingName[target])
	{
		ReplyToCommand(client, "Already setting name, try again later");
		return Plugin_Handled;
	}
	
	SetClientCookie(target, CookiePlayerName, arg2ForceName);
	strcopy(g_playerNames[target], sizeof(g_playerNames[]), arg2ForceName);
	
	if(g_forceMode == 0)
	{
		return Plugin_Handled;
	}
	
	CreateTimer(1.0, CheckCookieTimer, target, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action CheckCookieTimer(Handle timer, int client)
{
	RequestFrame(OnClientCookiesCached, client);
	return Plugin_Stop;
}

public void OnClientCookiesCached(int client)
{
	char bufName[32];
	char forceName[2];
	
	GetClientCookie(client, CookiePlayerName, g_playerNames[client], sizeof(g_playerNames[]));
	GetClientCookie(client, CookieForceName, forceName, sizeof(forceName));
	
	if(forceName[0] == '1')
	{
		g_forceName[client] = true;
	}
	
	if(g_playerNames[client][0] == '\0')
	{
		GetClientName(client, bufName, sizeof(bufName));
		SetClientCookie(client, CookiePlayerName, bufName);
		strcopy(g_playerNames[client], sizeof(g_playerNames[]), bufName);
	}
	
	g_cookiesCached[client] = true;
	
	if(g_forceMode == 0)
	{
		return;
	}
	
	if(g_settingName[client])
	{
		return;
	}
	
	CreateTimer(1.0, CheckNameTimer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientSettingsChanged(int client)	
{
	if(!IsClientInGame(client))
	{
		return;
	}
	
	if(!g_gettingName[client])
	{
		g_gettingName[client] = true;
		CreateTimer(1.0, GetNewName, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	if(g_forceMode == 0)
	{
		return;
	}
	
	if(!g_cookiesCached[client])
	{
		return;
	}
	
	if(g_settingName[client])
	{
		return;
	}
	
	if(g_forceMode == 1 && !g_forceName[client])
	{
		return;
	}
	
	CreateTimer(3.0, CheckNameTimer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action GetNewName(Handle Timer, int client)
{
	if(!IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	
	GetClientName(client, g_newNames[client], sizeof(g_newNames));
	CreateTimer(1.0, ResetNewNameBool, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action ResetNewNameBool(Handle Timer, int client)
{
	g_gettingName[client] = false;
	return Plugin_Stop;
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
	g_newNames[client][0] = '\0';
	g_cookiesCached[client] = false;
	g_gettingName[client] = false;
	g_settingName[client] = false;
	g_forceName[client] = false;
	PrintToServer("reset player variables");
}
