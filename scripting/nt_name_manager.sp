#include <sdktools>
#include <clientprefs>

Handle CookiePlayerName;
ConVar NameForceBehaviour;
char g_playerNames[32+1][32];
char g_newNames[32+1][32];
bool g_cookiesCached[32+1];
bool g_gettingName[32+1];
bool g_settingName[32+1];
bool g_enabled;

public Plugin myinfo = {
	name		=	"Name Manager",
	author		=	"bauxite, credits to Teamkiller324",
	description	=	"!forcename (store a name), !shownames, sm_name_force 0/1 (cvar to enable automatic name change)",
	version		=	"0.3.0",
	url			=	"",
};

public void OnPluginStart()	
{
	LoadTranslations("common.phrases");
	NameForceBehaviour = CreateConVar("sm_name_force", "0", "0 off - 1 on", _, true, 0.0, true, 1.0);
	HookConVarChange(NameForceBehaviour, NameForceBehaviour_Changed);
	CookiePlayerName = RegClientCookie("Player_Name", "Stores Clients Name", CookieAccess_Private);
	RegAdminCmd("sm_forcename", ForceName, ADMFLAG_GENERIC, "Force store a clients name");
	RegAdminCmd("sm_shownames", ShowName, ADMFLAG_GENERIC, "Revert all names to stored ones");
	AddCommandListener(Command_JoinTeam, "jointeam");
}

public void OnConfigsExecuted()
{
	g_enabled = NameForceBehaviour.BoolValue;
}

void NameForceBehaviour_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_enabled = NameForceBehaviour.BoolValue;
	
	if(g_enabled)
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
	if(!g_enabled)
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
	if(!g_enabled)
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
	
	if(!g_enabled)
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
	
	GetClientCookie(client, CookiePlayerName, g_playerNames[client], sizeof(g_playerNames[]));
	
	if(g_playerNames[client][0] == '\0')
	{
		GetClientName(client, bufName, sizeof(bufName));
		SetClientCookie(client, CookiePlayerName, bufName);
		strcopy(g_playerNames[client], sizeof(g_playerNames[]), bufName);
	}
	
	g_cookiesCached[client] = true;
	
	if(!g_enabled)
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
	
	if(!g_enabled)
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
	
	CreateTimer(2.0, CheckNameTimer, client, TIMER_FLAG_NO_MAPCHANGE);
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
	g_playerNames[client][0] = '\0';
	g_newNames[client][0] = '\0';
	g_cookiesCached[client] = false;
	g_gettingName[client] = false;
	g_settingName[client] = false;
}

public void OnMapEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_playerNames[client][0] = '\0';
		g_newNames[client][0] = '\0';
		g_cookiesCached[client] = false;
		g_gettingName[client] = false;
		g_settingName[client] = false;
	}
}
