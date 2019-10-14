#pragma semicolon 1
#pragma newdecls required

#include <sdktools_functions>

static const char
	PL_VER[]	= "1.1.0",
	PL_NAME[]	= "[CS:GO] Player Hint Info",

	TEAM[][]	= {"Enemy", "Ally", "Terrorist", "Counter-Terrorist"};

Handle
	hTimer;
int
	iShow,
	iHP,
	iTeam[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Shows information about the target player in the HUD in CS:GO",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO) SetFailState("This plugin for CSGO only!");

	CreateConVar("csgo_hint_info_version", PL_VER, PL_NAME, FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cvar;	//
	cvar = CreateConVar("sm_hint_info_show", "27", "Show info to the: 0 - nobody, 1 - spectators, 2 - allies, 4 - enemies, 8 - alive, 16 - dead", _, true, _, true, 31.0);
	cvar.AddChangeHook(CVarChanged_Show);
	CVarChanged_Show(cvar, NULL_STRING, NULL_STRING);

	cvar = CreateConVar("sm_hint_info_hp", "26", "Show health to the: 0 - nobody, 1 - spectators, 2 - allies, 4 - enemies, 8 - alive, 16 - dead", _, true, _, true, 31.0);
	cvar.AddChangeHook(CVarChanged_Health);
	iHP = cvar.IntValue;

	HookEvent("player_team", Event_Team);

	LoadTranslations("csgo_hint_info.phrases");

	AutoExecConfig(true, "csgo_hint_info");
}

public void CVarChanged_Show(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iShow = cvar.IntValue;
	if(!iShow == !hTimer) return;

	if(!hTimer) NewTimer();
	else delete hTimer;
}

public void CVarChanged_Health(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iHP = cvar.IntValue;
}

public void OnMapStart()
{
	if(iShow && !hTimer) NewTimer();
}

public void OnMapEnd()
{
	if(hTimer) delete hTimer;
}

stock void NewTimer()
{
	hTimer = CreateTimer(0.5, Timer_Hint, _, TIMER_REPEAT);
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if((client = GetClientOfUserId(event.GetInt("userid")))) iTeam[client] = event.GetInt("team");
}

public Action Timer_Hint(Handle timer)
{
	static int i, j, target;
	static bool spec, alive, ally, hp;
	static char name[MAX_NAME_LENGTH];
	for(i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && iTeam[i])
	{
		if((spec = iTeam[i] == 1) && !(iShow & 1)
		|| !spec && (((alive = !spec && IsPlayerAlive(i)) && !(iShow & 8)) || (!alive && !(iShow & 16)))
		|| (target = GetClientAimTarget(i, false)) < 1 || target > MaxClients || !IsClientInGame(target)
		|| iTeam[target] < 2 || !IsPlayerAlive(target)
		|| !spec && (((ally = iTeam[i] == iTeam[target]) && !(iShow & 2)) || (!ally && !(iShow & 4))))
			continue;

		hp = spec && iHP & 1 || !spec && (ally && iHP & 2 || !ally && iHP & 4) && (alive && iHP & 8 || !alive && iHP & 16);
		GetClientName(target, name, sizeof(name));
		j = spec ? iTeam[target] : (ally ? 1 : 0);
		if(hp)	PrintHintText(i, "%t", "InfoHealht", name, GetClientHealth(target), TEAM[j]);
		else	PrintHintText(i, "%t", "InfoNoHealht", name, TEAM[j]);
	}
}