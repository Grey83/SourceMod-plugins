#pragma semicolon 1

#include <sdktools_gamerules>

#define VERSION "1.5.3 no_warmup"

new RenderOffs;

new bool:bEnabled,
	Float:fTime,
	bool:bNotify,
	iColor[2][4];

new TeamSpec,
	TeamFist,
	bool:NoTeams,
	bActive[MAXPLAYERS+1],
	bool:bCSGO;

public Plugin:myinfo = 
{
	name		= "Spawn Protection",
	author		= "Fredd (optimized by Grey83)",
	description	= "Adds spawn protection",
	version		= VERSION,
	url			= "www.sourcemod.net"
}

public OnPluginStart()
{
	decl String:buffer[16];
	GetGameFolderName(buffer, sizeof(buffer));
	if(StrEqual(buffer, "cstrike", false) || StrEqual(buffer, "dod", false) || StrEqual(buffer, "csgo", false) || StrEqual(buffer, "tf", false))
	{
		TeamSpec = 1;
		TeamFist = 2;
		bCSGO = buffer[2] == 'g';
	}
	else if(StrEqual(buffer, "Insurgency", false))
	{
		TeamSpec = 3;
		TeamFist = 1;
	}
	else if(StrEqual(buffer, "hl2mp", false))
		NoTeams = true;
	else SetFailState("%s is an unsupported mod", buffer);

	CreateConVar("spawnprotection_version", VERSION, "Spawn Protection Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	new Handle:CVar;
	CVar = CreateConVar("sp_on", "1", _, _, true, _, true, 1.0);
	HookConVarChange(CVar, CVarChanged_Enabled);
	bEnabled = GetConVarBool(CVar);

	CVar = CreateConVar("sp_time", "5", _, _, true, 1.0);
	HookConVarChange(CVar, CVarChanged_Time);
	fTime = GetConVarFloat(CVar);

	CVar = CreateConVar("sp_notify", "1", _, _, true, _, true, 1.0);
	HookConVarChange(CVar, CVarChanged_Notify);
	bNotify = GetConVarBool(CVar);

	CVar = CreateConVar(NoTeams ? "sp_color" : "sp_color_first", "255 31 0 120", _, FCVAR_PRINTABLEONLY);
	HookConVarChange(CVar, CVarChanged_ColorFirst);
	GetColor(CVar);

	if(!NoTeams)
	{
		CVar = CreateConVar("sp_color_second", "0 31 255 120", _, FCVAR_PRINTABLEONLY);
		HookConVarChange(CVar, CVarChanged_ColorSecond);
		GetColor(CVar, 1);
	}

	AutoExecConfig(true, "spawn_protection");

	RenderOffs = FindSendPropInfo("CBasePlayer", "m_clrRender");

	HookEvent("player_spawn", OnPlayerSpawn);
}

public CVarChanged_Enabled(Handle:CVar, const String:oldValue[], const String:newValue[])
{
	bEnabled = GetConVarBool(CVar);
}

public CVarChanged_Time(Handle:CVar, const String:oldValue[], const String:newValue[])
{
	fTime = GetConVarFloat(CVar);
}

public CVarChanged_Notify(Handle:CVar, const String:oldValue[], const String:newValue[])
{
	bNotify = GetConVarBool(CVar);
}

public CVarChanged_ColorFirst(Handle:CVar, const String:oldValue[], const String:newValue[])
{
	GetColor(CVar);
}

public CVarChanged_ColorSecond(Handle:CVar, const String:oldValue[], const String:newValue[])
{
	GetColor(CVar, 1);
}

GetColor(Handle:CVar, pos = 0)
{
	new String:buffer[16], String:s_color[4][4];
	GetConVarString(CVar, buffer, sizeof(buffer));
	ExplodeString(buffer, " ", s_color, 4, 4);
	for(new i, color; i < 4; i++)
	{
		color = StringToInt(s_color[i]);
		if(color < 1) iColor[pos][i] = 0;
		else if(color > 254) iColor[pos][i] = 255;
		else iColor[pos][i] = color;
	}
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(bEnabled)
	{
		if(bCSGO && GameRules_GetProp("m_bWarmupPeriod"))
			return Plugin_Continue;

		new client	= GetClientOfUserId(GetEventInt(event, "userid"));
		if(!IsPlayerAlive(client))
			return Plugin_Continue;

		new team;
		if(!NoTeams)
		{
			if(!(team = GetClientTeam(client)) || team == TeamSpec)
				return Plugin_Continue;
			team -= TeamFist;
		}

		bActive[client] = true;
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		CreateTimer(fTime, Timer_RemoveProtection, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		set_rendering(client, RENDERFX_DISTORT, iColor[team][0], iColor[team][1], iColor[team][2], RENDER_TRANSADD, iColor[team][3]);
		if(bNotify) PrintToChat(client, "\x04[SpawnProtection] \x01Spawn protection \x04enabled \x01for \x04%i \x01seconds", RoundFloat(fTime)); 
	}
	return Plugin_Continue;
}

public Action:Timer_RemoveProtection(Handle:timer, any:client)
{
	if((client = GetClientOfUserId(client)) && bActive[client]) RemoveProtection(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:velocity[3], Float:angles[3], &weapon, &weaponSub, &command, &tick, &randomSeed, mouseDir[2])
{
	if(bActive[client] && IsPlayerAlive(client) && buttons & IN_ATTACK) RemoveProtection(client);
	return Plugin_Continue;
}

RemoveProtection(client)
{
	bActive[client] = false;
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	set_rendering(client);
	if(bNotify) PrintToChat(client, "\x04[SpawnProtection] \x01Spawn protection is now \x04disabled");
}

stock set_rendering(client, RenderFx:fx=RENDERFX_NONE, r=255, g=255, b=255, RenderMode:render=RENDER_NORMAL, amount=255)
{
	if(RenderOffs == -1) return;

	SetEntProp(client, Prop_Send, "m_nRenderFX", fx, 1);
	SetEntProp(client, Prop_Send, "m_nRenderMode", render, 1);
	SetEntData(client, RenderOffs, r, 1, true);
	SetEntData(client, RenderOffs + 1, g, 1, true);
	SetEntData(client, RenderOffs + 2, b, 1, true);
	SetEntData(client, RenderOffs + 3, amount, 1, true);
}