/*  SM Franug CSGO Sprays
 *
 *  Copyright(C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or(at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <clientprefs>
#include <sdktools_engine>
#include <sdktools_functions>
#include <sdktools_sound>
#include <sdktools_stringtables>
#include <sdktools_tempents>
#include <sdktools_trace>

static const
	String:PL_NAME[]= "SM Franug CSGO Sprays",
	String:PL_VER[]	= "1.4.6",

	String:SND[]	= "*items/spraycan_spray.wav";

#define MAX_SPRAYS 128
#define MAX_MAP_SPRAYS 200

new g_iLastSprayed[MAXPLAYERS + 1],
	g_sprayElegido[MAXPLAYERS + 1],

	g_time,
	g_distance,
	bool:g_use,
	g_maxMapSprays,
	g_resetTimeOnKill,
	g_showMsg,

	Handle:h_distance,
	Handle:h_time,
	Handle:h_use,
	Handle:h_maxMapSprays,
	Handle:h_resetTimeOnKill,
	Handle:h_showMsg,

	Handle:c_GameSprays;

enum Listado
{
	String:Nombre[32],
	index
}

new g_sprays[MAX_SPRAYS][Listado],
	g_sprayCount,

// Array to store previous sprays
	Float:g_spraysMapPos[MAX_MAP_SPRAYS][3],
	g_spraysMapId[MAX_MAP_SPRAYS],
// Running count of all sprays on the map
	g_sprayMapCount,
// Current index of the last spray in the array; this resets to 0 when g_maxMapSprays is reached(FIFO)
	g_sprayIndexLast;



public Plugin:myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Use sprays in CSGO",
	author		= "Franc1sco Steam: franug (rewritten by Grey83)",
	url			= "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO) SetFailState("Plugin for CS:GO only!");

	CreateConVar("sm_franugsprays_version", PL_VER, PL_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	h_time = CreateConVar("sm_csgosprays_time", "30", "Cooldown between sprays", _, true, 5.0);
	HookConVarChange(h_time, OnConVarChanged);
	g_time = GetConVarInt(h_time);

	h_distance = CreateConVar("sm_csgosprays_distance", "115", "How far the sprayer can reach", _, true, 64.0, true, 256.0);
	HookConVarChange(h_distance, OnConVarChanged);
	g_distance = GetConVarInt(h_distance);

	h_use = CreateConVar("sm_csgosprays_use", "1", "Spray when a player runs +use(Default: E)", _, true, _, true, 1.0);
	HookConVarChange(h_use, OnConVarChanged);
	g_use = GetConVarBool(h_use);

	h_maxMapSprays = CreateConVar("sm_csgosprays_mapmax", "25", "Maximum ammount of sprays on the map", _, true, 1.0, true, (MAX_MAP_SPRAYS + 0.0));
	HookConVarChange(h_maxMapSprays, OnConVarChanged);
	g_maxMapSprays = GetConVarInt(h_maxMapSprays);

	h_resetTimeOnKill = CreateConVar("sm_csgosprays_reset_time_on_kill", "1", "Reset the cooldown on a kill", _, true, _, true, 1.0);
	HookConVarChange(h_resetTimeOnKill, OnConVarChanged);
	g_resetTimeOnKill = GetConVarBool(h_resetTimeOnKill);

	h_showMsg = CreateConVar("sm_csgosprays_show_messages", "1", "Print messages of this plugin to the players", _, true, _, true, 1.0);
	HookConVarChange(h_showMsg, OnConVarChanged);
	g_showMsg = GetConVarBool(h_showMsg);

	RegConsoleCmd("sm_spray", MakeSpray);
	RegConsoleCmd("sm_sprays", GetSpray);

	HookEvent("round_start", roundStart);
	HookEvent("player_death", Event_PlayerDeath);

	c_GameSprays = RegClientCookie("Sprays", "Sprays", CookieAccess_Private);
	SetCookieMenuItem(SprayPrefSelected, 0, "Sprays");
	AutoExecConfig(true, "csgo_sprays");
}

public OnPluginEnd()
{
	for(new i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) OnClientDisconnect(i);
}

public OnClientCookiesCached(client)
{
	new String:SprayString[12];
	GetClientCookie(client, c_GameSprays, SprayString, sizeof(SprayString));
	g_sprayElegido[client] = StringToInt(SprayString);
}

public OnClientDisconnect(client)
{
	if(AreClientCookiesCached(client))
	{
		new String:SprayString[12];
		FormatEx(SprayString, sizeof(SprayString), "%i", g_sprayElegido[client]);
		SetClientCookie(client, c_GameSprays, SprayString);
	}
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == h_time)
		g_time = GetConVarInt(convar);
	else if(convar == h_distance)
		g_distance = GetConVarInt(convar);
	else if(convar == h_use)
		g_use = GetConVarBool(convar);
	else if(convar == h_maxMapSprays)
		g_maxMapSprays = GetConVarInt(convar);
	else if(convar == h_resetTimeOnKill)
		g_resetTimeOnKill = GetConVarBool(convar);
	else if(convar == h_showMsg)
		g_showMsg = GetConVarBool(convar);
}

public Action:roundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new i = 1;
	for(; i < GetMaxClients(); i++) if(IsClientInGame(i)) g_iLastSprayed[i] = false;

	if(g_sprayMapCount > g_maxMapSprays) g_sprayMapCount = g_maxMapSprays;

	for(i = 0; i < g_sprayMapCount; i++)
	{
		TE_SetupBSPDecal(g_spraysMapPos[i], g_spraysMapId[i]);
		TE_SendToAll();
	}

}

public OnClientPostAdminCheck(client)
{
	g_iLastSprayed[client] = false;
}

public OnMapStart()
{
	g_sprayMapCount = g_sprayIndexLast = 0;
	AddToStringTable(FindStringTable("soundprecache"), SND);

	decl String:path[PLATFORM_MAX_PATH];
	g_sprayCount = 1;
	FormatEx(g_sprays[0][Nombre], 32, "Случайный рисунок");

	new Handle:kv = CreateKeyValues("Sprays");
	BuildPath(Path_SM, path, sizeof(path), "configs/csgo_sprays.cfg");
	FileToKeyValues(kv, path);

	if(!KvGotoFirstSubKey(kv))
	{
		CloseHandle(kv);
		SetFailState("CFG File not found: %s", path);
	}

	decl String:buffer[PLATFORM_MAX_PATH], String:download[PLATFORM_MAX_PATH];
	new Handle:vtf;
	while(KvGotoNextKey(kv))
	{
		KvGetSectionName(kv, buffer, sizeof(buffer));
		FormatEx(g_sprays[g_sprayCount][Nombre], 32, buffer);
		KvGetString(kv, "path", buffer, sizeof(buffer));

		g_sprays[g_sprayCount][index] = PrecacheDecal(buffer, true);

		FormatEx(path, sizeof(path), buffer);
		FormatEx(download, sizeof(download), "materials/%s.vmt", buffer);
		AddFileToDownloadsTable(download);

		vtf = CreateKeyValues("LightmappedGeneric");
		FileToKeyValues(vtf, download);
		KvGetString(vtf, "$basetexture", buffer, sizeof(buffer), buffer);
		CloseHandle(vtf);
		FormatEx(download, sizeof(download), "materials/%s.vtf", buffer);
		AddFileToDownloadsTable(download);

		g_sprayCount++;
	}
	CloseHandle(kv);

	for(new i = g_sprayCount; i < MAX_SPRAYS; ++i) g_sprays[i][index] = 0;
}

public Action:MakeSpray(client, args)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	if(IsPlayerAlive(client)) PlaceSpray(client);
	else if(g_showMsg) PrintToChat(client, " \x0C● Граффити » \x01Вы \x07должны быть живы\x01, чтобы использовать эту команду!");

	return Plugin_Handled;
}

public Action:GetSpray(client, args)
{
	new Handle:menu = CreateMenu(DIDMenuHandler);
	SetMenuTitle(menu, "Выберите граффити (%d/%d):", g_sprayElegido[client], g_sprayCount-1);
	decl String:item[4];
	for(new i; i < g_sprayCount; ++i)
	{
		FormatEx(item, 4, "%d", i);
		AddMenuItem(menu, item, g_sprays[i][Nombre]);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 0);
}

public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	if(action == MenuAction_Select)
	{
		g_sprayElegido[client] = itemNum;
		if(g_showMsg) PrintToChat(client, " \x0C● Граффити » \x01Вы выбрали \x03%s", g_sprays[g_sprayElegido[client]][Nombre]);
	}
	else if(action == MenuAction_End) CloseHandle(menu);
}

stock GetPlayerEyeViewPoint(client, Float:fPosition[3], Float:fOrigin[3])
{
	decl Float:fAngles[3];
	GetClientEyeAngles(client, fAngles);
	new Handle:hTrace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(hTrace)) TR_GetEndPosition(fPosition, hTrace);
	CloseHandle(hTrace);
}

public bool:TraceEntityFilterPlayer(iEntity, iContentsMask)
{
	return iEntity > MaxClients;
}

TE_SetupBSPDecal(const Float:vecOrigin[3], id)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", id);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse)
{
	if(g_use && buttons & IN_USE && buttons & IN_DUCK && IsPlayerAlive(client)) PlaceSpray(client);
}

stock PlaceSpray(client)
{
	new iTime = GetTime(), diff = g_time + g_iLastSprayed[client] - iTime;
	if(diff > 0)
	{
		if(g_showMsg) PrintToChat(client, " \x0C● Граффити » \x01Вам нужно подождать \x07%i \x01секунд, чтобы снова использовать эту команду!", diff);
		return;
	}

	decl Float:fClientEyePosition[3], Float:fClientEyeViewPoint[3], Float:fVector[3];
	GetClientEyePosition(client, fClientEyePosition);
	GetPlayerEyeViewPoint(client, fClientEyeViewPoint, fClientEyePosition);
	MakeVectorFromPoints(fClientEyeViewPoint, fClientEyePosition, fVector);

	if(GetVectorLength(fVector) > g_distance)
	{
		if(g_showMsg) PrintToChat(client, " \x0C● Граффити » \x01Вы \x07слишком далеко \x01от стены, чтобы использовать эту команду!");
		return;
	}

	if(!g_sprayElegido[client]) TE_SetupBSPDecal(fClientEyeViewPoint, g_sprays[GetRandomInt(1, g_sprayCount-1)][index]);
	else
	{
		if(!g_sprays[g_sprayElegido[client]][index])
		{
			if(g_showMsg) PrintToChat(client, " \x0C● Граффити » \x01Ваш граффити \x07не работает\x01, выберите другой.");
			return;
		}
		TE_SetupBSPDecal(fClientEyeViewPoint, g_sprays[g_sprayElegido[client]][index]);

		// Save spray position and identifier
		if(g_sprayIndexLast == g_maxMapSprays) g_sprayIndexLast = 0;
		g_spraysMapPos[g_sprayIndexLast] = fClientEyeViewPoint;
		g_spraysMapId[g_sprayIndexLast] = g_sprays[g_sprayElegido[client]][index];
		g_sprayIndexLast++;
		if(g_sprayMapCount != g_maxMapSprays) g_sprayMapCount++;
	}
	TE_SendToAll();

	if(g_showMsg) PrintToChat(client, " \x0C● Граффити » \x01Вы использовали свой граффити.");
	EmitSoundToAll(SND, client, _, _, _, 0.6);

	g_iLastSprayed[client] = iTime;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_resetTimeOnKill)
	{
		new user = GetClientOfUserId(GetEventInt(event, "attacker"));
		if(user && user != GetClientOfUserId(GetEventInt(event, "userid")) && !IsFakeClient(user))
			g_iLastSprayed[user] = false;
	}
	return Plugin_Continue;
}

public SprayPrefSelected(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) 
{
	if(action == CookieMenuAction_SelectOption) GetSpray(client,0);
}
