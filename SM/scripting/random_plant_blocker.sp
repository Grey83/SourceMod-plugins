#pragma semicolon 1
#pragma newdecls required

#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_gamerules>

static const char
	PL_NAME[]	= "Random plant blocker",
	PL_VER[]	= "1.0.1_29.12.2021";

enum
{
	H_Team,
	H_Start,
	H_End,
	H_Begin,
	H_Abort,

	H_Total
};

Handle
	hHUD;
bool
	bHook[H_Total],
	bCheck,
	bBlock,
	bPlanting;
int
	iPlant,
	iPlayers,
	iBlockedPlant,
	iFuncBombTarget = -1;

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Blocks a random plant if the players in teams are less than the set value",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	EngineVersion ev = GetEngineVersion();
	if(ev == Engine_CSS || ev == Engine_CSGO) hHUD = CreateHudSynchronizer();

	LoadTranslations("random_plant_blocker.phrases");

	CreateConVar("sm_rpb_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar;
	cvar = CreateConVar("sm_rpb_plant", "1", "Block plant: -1 - random, 0 - 'A', 1 - 'B'", FCVAR_NONE, true, -1.0, true, 1.0);
	cvar.AddChangeHook(CVarChange_Plant);
	iPlant = cvar.IntValue;

	cvar = CreateConVar("sm_rpb_players", "6", "Minimum players to unlock all sites", FCVAR_NONE, true, _, true, MaxClients - 1.0);
	cvar.AddChangeHook(CVarChange_Players);
	iPlayers = cvar.IntValue;

	AutoExecConfig(true, "random_plant_blocker");
}

public void OnPluginEnd()
{
	if(bBlock) TriggerFuncBombTarget(false);
}

public void CVarChange_Plant(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iPlant = cvar.IntValue;
}

public void CVarChange_Players(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iPlayers = cvar.IntValue;
}

public void OnMapStart()
{
	iFuncBombTarget = -1;
	bBlock = bPlanting = bCheck = false;
	if(GameRules_GetProp("m_bMapHasBombTarget"))
		CreateEventHooks();
	else DeleteEventHooks();
}

stock void CreateEventHooks()
{
	if(!bHook[H_Team])	bHook[H_Team]	= HookEventEx("player_team",		Event_Team, EventHookMode_PostNoCopy);
	if(!bHook[H_Start])	bHook[H_Start]	= HookEventEx("round_freeze_end",	Event_Round, EventHookMode_PostNoCopy);
	if(!bHook[H_End])	bHook[H_End]	= HookEventEx("round_end",			Event_Round, EventHookMode_PostNoCopy);
	if(!bHook[H_Begin])	bHook[H_Begin]	= HookEventEx("bomb_beginplant",	Event_Bomb, EventHookMode_PostNoCopy);
	if(!bHook[H_Abort])	bHook[H_Abort]	= HookEventEx("bomb_abortplant",	Event_Bomb, EventHookMode_PostNoCopy);
}

stock void DeleteEventHooks()
{
	if(bHook[H_Team])
	{
		UnhookEvent("player_team",		Event_Team, EventHookMode_PostNoCopy);
		bHook[H_Team] = false;
	}
	if(bHook[H_Start])
	{
		UnhookEvent("round_freeze_end",	Event_Round, EventHookMode_PostNoCopy);
		bHook[H_Start] = false;
	}
	if(bHook[H_End])
	{
		UnhookEvent("round_end",		Event_Round, EventHookMode_PostNoCopy);
		bHook[H_End] = false;
	}
	if(bHook[H_Begin])
	{
		UnhookEvent("bomb_beginplant",	Event_Bomb, EventHookMode_PostNoCopy);
		bHook[H_Begin] = false;
	}
	if(bHook[H_Abort])
	{
		UnhookEvent("bomb_abortplant",	Event_Bomb, EventHookMode_PostNoCopy);
		bHook[H_Abort] = false;
	}
}

public void OnClientDisconnect(int client)
{
	if(bCheck) GetOnlinePlayers();
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	if(bCheck) GetOnlinePlayers();
}

public void Event_Round(Event event, const char[] name, bool dontBroadcast)
{
	if(bBlock) TriggerFuncBombTarget(false);
	bPlanting = bBlock = false;
	if(!(bCheck = name[6] == 'f'))
		return;

	iFuncBombTarget = -1;

	if(iPlant < 0) iBlockedPlant = GetRandomInt(0, 99) % 2;	// выбираем случайный плент для блокировки
	else iBlockedPlant = iPlant;

	int ent = -1;
	if((ent = FindEntityByClassname(ent, "func_bomb_target")) != -1)
	{
		iFuncBombTarget = EntIndexToEntRef(ent);
		if(iBlockedPlant)
		{
			if((ent = FindEntityByClassname(ent, "func_bomb_target")) != -1)
			iFuncBombTarget = EntIndexToEntRef(ent);
		}
		GetOnlinePlayers();
	}
}

public void Event_Bomb(Event event, const char[] name, bool dontBroadcast)
{
	if(!(bPlanting = name[5] == 'b')) GetOnlinePlayers();
}

stock void GetOnlinePlayers()
{
	if(bPlanting || !IsFuncBombTargetValid()) return;

	int num;
	for(int i = 1; i <= MaxClients && num <= iPlayers; i++) if(IsClientInGame(i) && GetClientTeam(i) > 1) num++;

	static bool blocked;
	blocked = bBlock;
	bBlock = num < iPlayers;
	if(blocked == bBlock) return;

	TriggerFuncBombTarget(bBlock);

	char txt[PLATFORM_MAX_PATH];
	if(hHUD) SetHudTextParams(-1.0, -1.0, 3.0, 256, 128, 0, 255, 0, 0.0, 0.0, 0.5);

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && (!IsFakeClient(i) || IsClientSourceTV(i) || IsClientReplay(i)))
		{
			PrintToChat(i, "%t", "PlantStateChanged", iBlockedPlant ? 'B' : 'A', bBlock ? "Disabled" : "Enabled");
			if(bBlock) PrintToChat(i, "%t", "NumberNotify", iPlayers - num);
			if(!hHUD) continue;

			FormatEx(txt, sizeof(txt), "%T", "HUD_PlantStateChanged", i, iBlockedPlant ? 'B' : 'A', bBlock ? "HUD_Disabled" : "HUD_Enabled");
			if(!bBlock) Format(txt, sizeof(txt), "%s\n%T", txt, "HUD_NumberNotify", i, iPlayers - num);
			ShowSyncHudText(i, hHUD, txt);
		}
}

stock void TriggerFuncBombTarget(bool disable)
{
	if(IsFuncBombTargetValid()) AcceptEntityInput(iFuncBombTarget, disable ? "Disable" : "Enable");	// DisableAndEndTouch
}

stock bool IsFuncBombTargetValid()
{
	return iFuncBombTarget != -1 && EntRefToEntIndex(iFuncBombTarget) != INVALID_ENT_REFERENCE;
}
