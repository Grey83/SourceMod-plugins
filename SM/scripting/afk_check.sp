#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <sdktools_functions>
#include <sdktools_hooks>

static const char	PLUGIN_NAME[]		= "AFK check",
					PLUGIN_VERSION[]	= "1.0.0";

static const int check[] = {10, 20, 30};	// бездействие, сек. (предупреждение, в наблюдатели, кик)

bool bLate,
	bCS,
	bEnabled,
	bAFK[MAXPLAYERS+1],
	bNew[MAXPLAYERS+1],
	bAdmin[MAXPLAYERS+1];
int iTeams,
	iLastGood[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PLUGIN_NAME,
	author		= "Grey83",
	description	= "Check the player is AFK or not",
	version		= PLUGIN_VERSION,
	url			= "http://steamcommunity.com/groups/grey83ds"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("sm_afk_check", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	EngineVersion engine = GetEngineVersion();
	if(!(bCS = engine == Engine_CSGO || engine == Engine_CSS)) iTeams = GetTeamCount();

	HookEvent("round_start", Event_Start, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_End, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_Spawn);

	if(bLate)
	{
		bLate = false;
		bEnabled = true;
		for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
			bNew[i] = false;
		}
	}
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	bEnabled = true;
	for(int i = 1, time = GetTime(); i <= MaxClients; i++) if(IsClientInGame(i))
	{
		iLastGood[i] = time;
		bNew[i] = false;
	}
}

public void Event_End(Event event, const char[] name, bool dontBroadcast)
{
	bEnabled = false;
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	bNew[event.GetInt("userid")] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if(0 < client <= MaxClients && !IsFakeClient(client))
	{
		bAdmin[client] = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC);
		bNew[client] = true;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!bEnabled || bNew[client] || bAdmin[client] || IsFakeClient(client) || IsClientReplay(client) || IsClientSourceTV(client))
		return Plugin_Continue;

	static int old_buttons[MAXPLAYERS+1], time;
	time = GetTime();
	if(!(bAFK[client] = buttons == old_buttons[client])) iLastGood[client] = time;
	old_buttons[client] = buttons;

	if(time > iLastGood[client] + check[2])
		KickClient(client, "AFK больше %i секунд. Goodnight, sweet prince", check[2]);
	else if(time > iLastGood[client] + check[1])
	{
		PrintCenterText(client, "За пребывание AFK через %i секунд\nВы будете кикнуты с сервера!", check[2] - check[1]);
		if(bCS) CS_SwitchTeam(client, CS_TEAM_SPECTATOR);
		else if(iTeams > 3) ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		else ForcePlayerSuicide(client);
	}
	else if(time > iLastGood[client] + check[0])
		PrintCenterText(client, "За пребывание AFK через %i секунд\nВы будете перемещены в наблюдатели!", check[1] - check[0]);

	return Plugin_Continue;
}

public void OnClientDisconnect_Post(int client)
{
	bNew[client] = true;
}