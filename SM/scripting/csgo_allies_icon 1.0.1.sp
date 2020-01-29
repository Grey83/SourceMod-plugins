#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_engine>
#if SOURCEMOD_V_MINOR >= 9
	#include <sdktools_variant_t>
#endif

static const char PATH[] = "materials/vgui/hud/icon_arrow_down.vmt";	// путь файлу vmt, отвечающему за иконку

bool
	bLate;
int
	iTeam[MAXPLAYERS+1],
	iIcon[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= "[CSGO] Allies icon",
	version		= "1.0.1",
	description	= "Shows the icon above the allies",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_team", Event_Team);
	HookEvent("player_death", Event_State);
	HookEvent("player_spawn", Event_State);

	if(bLate) for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && (iTeam[i] = GetClientTeam(i))) CreateIcon(i);
}

public void OnMapStart()
{
	PrecacheModel(PATH, true);
// раскомментировать код ниже, если текстура отсутствует в ресурсах игры
/*	AddFileToDownloadsTable(PATH);

	char buffer[64];
	Handle vtf = CreateKeyValues("UnlitGeneric");
	FileToKeyValues(vtf, PATH);
	KvGetString(vtf, "$basetexture", buffer, sizeof(buffer), buffer);
	CloseHandle(vtf);
	Format(buffer, sizeof(buffer), "materials/%s.vtf", buffer);
	AddFileToDownloadsTable(buffer);*/
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client) return;

	iTeam[client] = event.GetInt("team");
	CreateIcon(client);
}

public void Event_State(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client) CreateIcon(client);
}

public void OnClientDisconnect(int client)
{
	ClearIcon(client);
	iTeam[client] = 0;
}

stock bool CreateIcon(int client)
{
	ClearIcon(client);
	if(iTeam[client] < 2 || !IsPlayerAlive(client)) return false;

	static int ent;
	if(!(ent = CreateEntityByName("env_sprite"))) return false;

	DispatchKeyValue(ent, "model", PATH);
	DispatchKeyValue(ent, "classname", "allies_icon");
	DispatchKeyValue(ent, "spawnflags", "1");
	DispatchKeyValue(ent, "scale", "0.08");
//	https://developer.valvesoftware.com/wiki/Render_Modes
//	Normal (0), Color (1), Texture (2), Glow (3), Solid (4), Additive (5), Additive Fractional Frame (7), Alpha Add (8), World Space Glow (9), Don't Render (10)
	DispatchKeyValue(ent, "rendermode", "5");
	DispatchKeyValue(ent, "rendercolor", "255 255 255");
	if(!DispatchSpawn(ent)) return false;

	iIcon[client] = EntIndexToEntRef(ent);

	static float pos[3], max[3];
	GetClientAbsOrigin(client, pos);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", max);
	pos[2] += max[2] + 10.0;
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);

	static char buffer[16];
	Format(buffer, sizeof(buffer), "client%d", client);
	DispatchKeyValue(client, "targetname", buffer);
	SetVariantString(buffer);
	AcceptEntityInput(ent, "SetParent", ent, ent, 0);
	SDKHook(ent, SDKHook_SetTransmit, iTeam[client] == 2 ? ShouldHideMark_T : ShouldHideMark_Ct);
	return true;
}

stock void ClearIcon(int client)
{
	if(!iIcon[client])) return;

	if(EntRefToEntIndex(iIcon[client]) != INVALID_ENT_REFERENCE) AcceptEntityInput(iIcon[client], "Kill");
	iIcon[client] = 0;
}

public Action ShouldHideMark_T(int ent, int client)
{
	return iTeam[client] == 2 ? Plugin_Continue : Plugin_Handled;
}

public Action ShouldHideMark_Ct(int ent, int client)
{
	return iTeam[client] == 3 ? Plugin_Continue : Plugin_Handled;
}