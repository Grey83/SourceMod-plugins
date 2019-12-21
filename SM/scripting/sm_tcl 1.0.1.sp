#pragma semicolon 1
#pragma newdecls required

#include <cstrike>

static const char
	PL_NAME[]	= "Team change limit",
	PL_VER[]	= "1.0.1";

int
	iChanges[MAXPLAYERS+1],
	iTeam[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Limits the number of team changes per round",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	CreateConVar("sm_tcl_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY);

	ConVar cvar;
	cvar = CreateConVar("sm_tcl", "3", "Team changes per round", _, true);
	cvar.AddChangeHook(CVarChanged);
	iChanges[0] = cvar.IntValue;

	HookEvent("player_team", Event_Team);

	RegConsoleCmd("sm_spec", Cmd_Spec, "Join spectators team");

	AddCommandListener(Cmd_JoinTeam, "jointeam");
	AddCommandListener(Cmd_TeamMenu, "teammenu");

	AutoExecConfig(true, "team_change_limit");
}

public void CVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iChanges[0] = cvar.IntValue;
}

public void OnClientDisconnect_Post(int client)
{
	iChanges[client] = iTeam[client] = 0;
}

public Action CS_OnTerminateRound()
{
	for(int i = 1; i <= MaxClients; i++) iChanges[i] = 0;
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	static int client, t;
	if(!event.GetInt("disconnect") && (client = GetClientOfUserId(event.GetInt("userid"))) && !IsFakeClient(client)
	&& !event.GetInt("autoteam") && event.GetInt("oldteam") > 1 && (t = event.GetInt("team")) > 1 && iTeam[client] != t)
	{
		iTeam[client] = t;
		iChanges[client]++;
		PrintToChat(client, "Осталось %i попыток сменить команду", iChanges[0] - iChanges[client]);
	}
}

public Action Cmd_Spec(int client, int args)
{
	if(client) CS_SwitchTeam(client, 1);
	return Plugin_Handled;
}

public Action Cmd_JoinTeam(int client, const char[] cmd, int argc)
{
	if(!client || !iTeam[client])
		return Plugin_Continue;

	static char arg[8];
	if(!argc || GetCmdArg(1, arg, 8) > 1 || arg[0] < '1' || arg[0] > '3')
		return Plugin_Handled;

	if(arg[0] == '1' || arg[0] - '0' == iTeam[client] || iChanges[client] < iChanges[0])
		return Plugin_Continue;

	PrintToChat(client, "Вы исчерпали лимит переходов между командами за этот раунд.");
	return Plugin_Handled;
}

public Action Cmd_TeamMenu(int client, const char[] cmd, int argc)
{
	if(!client || iChanges[client] < iChanges[0])
		return Plugin_Continue;

	PrintToChat(client, "Вы исчерпали лимит переходов между командами за этот раунд.\nПерейти за наблюдателей - !spec");
	return Plugin_Handled;
}