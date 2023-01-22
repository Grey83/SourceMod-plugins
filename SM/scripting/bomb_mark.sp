#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include <sdktools_gamerules>
#tryinclude <sdktools_variant_t>

static const char
	MARK[]	= "materials/sprites/bomb_mark.vmt";
static const float
	SIZE	= 0.3;	// размер меток

bool
	bShow[MAXPLAYERS+1];
int
	iMarkRef = -1;

public Plugin myinfo =
{
	name		= "Bomb mark",
	version		= "1.0.1_22.01.2023",
	description	= "Creates a mark on the bomb that only the terrorist team can see.",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnMapStart()
{
	iMarkRef = -1;
	if(!ManageHooks()) return;

	char vtf[sizeof(MARK)];
	vtf = MARK;
	int pos = strlen(MARK) - 2;
	vtf[pos] = 't', vtf[pos+1] = 'f';
	AddFileToDownloadsTable(vtf);
	AddFileToDownloadsTable(MARK);
	PrecacheModel(MARK, true);
}

stock bool ManageHooks()
{
	static bool hooked;
	if(!GameRules_GetProp("m_bMapHasBombTarget") == !hooked)
		return hooked;

	if((hooked ^= true))
	{
		HookEvent("bomb_defused",		Event_Bomb, EventHookMode_PostNoCopy);
		HookEvent("bomb_exploded",		Event_Bomb, EventHookMode_PostNoCopy);
		HookEvent("player_spawn",		Event_Player);
		HookEvent("player_death",		Event_Player);
	}
	else
	{
		UnhookEvent("bomb_defused",		Event_Bomb, EventHookMode_PostNoCopy);
		UnhookEvent("bomb_exploded",	Event_Bomb, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",		Event_Player);
		UnhookEvent("player_death",		Event_Player);
	}
	return hooked;
}

public void Event_Bomb(Event event, const char[] name, bool dontBroadcast)
{
	RemoveMark();
}

public void Event_Player(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if((client = GetClientOfUserId(event.GetInt("userid"))) && !IsFakeClient(client))
		bShow[client] = GetClientTeam(client) == 2 && name[7] == 's';
}

public void OnClientConnected(int client)
{
	bShow[client] = false;
}

public void OnEntityCreated(int ent, const char[] cls)
{
	if(ent > MaxClients && (!strcmp(cls, "weapon_c4", false) || !strcmp(cls, "planted_c4", false)))
		RequestFrame(cls[0] == 'p' ? Frame_Planted : Frame_Weapon, EntIndexToEntRef(ent));
}

public void Frame_Weapon(int bomb)
{
	MarkSpawn(bomb, 0x7f);
}

public void Frame_Planted(int bomb)
{
	MarkSpawn(bomb, 0x1f);
}

stock void MarkSpawn(int bomb, const int green)
{
	if((bomb = EntRefToEntIndex(bomb)) == INVALID_ENT_REFERENCE)
		return;

	RemoveMark();

	int mark;
	if((mark = CreateEntityByName("env_sprite")) == -1)
		return;

	iMarkRef = EntIndexToEntRef(mark);

	float pos[3];
	GetEntPropVector(bomb, Prop_Data, "m_vecAbsOrigin", pos);
	pos[2] += 4;
	DispatchKeyValueVector(mark, "origin", pos);
	DispatchKeyValue(mark, "model", MARK);
	DispatchKeyValue(mark, "classname", "bomb_mark");
	DispatchKeyValue(mark, "spawnflags", "1");
	DispatchKeyValueFloat(mark, "scale", SIZE);
	SetVariantInt(0xff);
	AcceptEntityInput(mark, "ColorRedValue");
	SetVariantInt(green);
	AcceptEntityInput(mark, "ColorGreenValue");
	SetVariantInt(0x1f);
	AcceptEntityInput(mark, "ColorBlueValue");
	DispatchKeyValue(mark, "rendermode", "5");
	SetVariantString("!activator");
	AcceptEntityInput(mark, "SetParent", bomb, mark, 0);
	if(DispatchSpawn(mark)) SDKHook(mark, SDKHook_SetTransmit, Hook_Transmit);
}

public Action Hook_Transmit(int mark, int client)
{
	return bShow[client] ? Plugin_Continue : Plugin_Handled;
}

stock void RemoveMark()
{
	if(iMarkRef != -1 && (iMarkRef = EntRefToEntIndex(iMarkRef)) != -1)
#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR < 10
		AcceptEntityInput(iMarkRef, "Kill");
#else
		RemoveEntity(iMarkRef);
#endif
	iMarkRef = -1;
}

public void OnPluginEnd()
{
	RemoveMark();
}
