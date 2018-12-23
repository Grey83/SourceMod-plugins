#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_tempents>
#include <sdktools_sound>
//#include <sdktools_variant_t>	// only for SM1.9

static const char	PLUGIN_NAME[]		= "Revival",
					PLUGIN_VERSION[]	= "1.0.4",

					MARK_MDL[]			= "hud/scoreboard_dead.vmt",
					KEY_NAME[][]		= {"Ctrl", "E", "Shift"};
static const int	COLOR[][]	= {{255, 63, 31, 191}, {31, 63, 255, 191}, {0, 191, 0, 191}},	// T, CT, Any
					KEY_VAL[]	= {IN_DUCK, IN_USE, IN_SPEED};
static const float	NULL_PERCENT[MAXPLAYERS+1]	= {0.0, ...},
					EFF_LIFE	= 1.0,	// частота обновления эффекта
					MARK_SIZE	= 0.3;	// размер меток

bool bEnable,
	bTeam,
	bEnemy,
	bPercent,
	bEffect,
	bFrag,
	bSprites;
float fRadius;
int iKey,
	iClean,
	iTime,
	iCD,
	iTimes,
	iNoBlockTime,
	iHPCost,
	iHP;
char sCvarPath[PLATFORM_MAX_PATH],
	sSoundPath[PLATFORM_MAX_PATH];

bool bAllowed = true,
	bCSGO;
int iOffsetGroup,
	hBeam = -1,
	hHalo = -1,
	iMarkRef[MAXPLAYERS+1] = {-1, ...},
	iTimesRevived[MAXPLAYERS+1],
	iDeathTeam[MAXPLAYERS+1];
float fDeathPos[MAXPLAYERS+1][3],
	fProgress[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PLUGIN_NAME,
	author		= "Grey83",
	description	= "Press and hold +USE above death place to respawn player",
	version		= PLUGIN_VERSION,
	url			= "https://steamcommunity.com/groups/grey83ds"
//	https://github.com/Grey83/SourceMod-plugins/blob/master/SM/scripting/sm_revival.sp
};

public void OnPluginStart()
{
	EngineVersion EV = GetEngineVersion();
	if(EV == Engine_CSGO) bCSGO = true;
	else if(EV != Engine_CSS) SetFailState("Plugin for CSS and CSGO only!");

	iOffsetGroup	= FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	CreateConVar("sm_revival_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

	ConVar CVar;
	(CVar = CreateConVar("sm_revival_enabled", "1", "Enable/disable plugin", FCVAR_NOTIFY, true, _, true, 1.0)).AddChangeHook(CVarChanged_Enable);
	bEnable = CVar.BoolValue;

	(CVar = CreateConVar("sm_revival_key", "1", "Key for reviving (0 - 'duck', 1 - 'use', 2 - 'walk')", _, true, _, true, 2.0)).AddChangeHook(CVarChanged_Key);
	iKey = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_clean", "2", "Remove body x sec after the death (-1 - don't remove)", FCVAR_NOTIFY, true, -1.0)).AddChangeHook(CVarChanged_Clean);
	iClean = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_teamchange", "1", "Can a player be revived after a team change", FCVAR_NOTIFY, true, _, true, 1.0)).AddChangeHook(CVarChanged_Team);
	bTeam = CVar.BoolValue;

	(CVar = CreateConVar("sm_revival_enemy", "0", "Can a player revive the enemy (the revived player will change the team)", FCVAR_NOTIFY, true, _, true, 1.0)).AddChangeHook(CVarChanged_Enemy);
	bEnemy = CVar.BoolValue;

	(CVar = CreateConVar("sm_revival_percent", "1", "Enable/disable save the percentage of reviving", FCVAR_NOTIFY, true, _, true, 1.0)).AddChangeHook(CVarChanged_Percent);
	bPercent = CVar.BoolValue;

	(CVar = CreateConVar("sm_revival_effect", "1", "Enable/disable effect around to place of death", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_Enable);
	bEffect = CVar.BoolValue;

	(CVar = CreateConVar("sm_revival_radius", "200.0", "Radius to respawn death player", FCVAR_NOTIFY, true)).AddChangeHook(CVarChanged_Radius);
	fRadius = CVar.FloatValue;

	(CVar = CreateConVar("sm_revival_time", "0", "The time after the death of the player, during which the revive is possible", FCVAR_NOTIFY, true)).AddChangeHook(CVarChanged_Time);
	iTime = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_countdown", "3.0", "Time for respawn in seconds", FCVAR_NOTIFY, true)).AddChangeHook(CVarChanged_CD);
	iCD = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_times", "0", "How many times can a player revive other players during the round (0 - unlimited)", FCVAR_NOTIFY, true)).AddChangeHook(CVarChanged_Times);
	iTimes = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_noblock_time", "2", "Noblocking time after respawn(set at 0 if you have any noblock plugin)", _, true)).AddChangeHook(CVarChanged_NoBlockTime);
	iNoBlockTime = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_health_cost", "25", "Need's health to respawn", FCVAR_NOTIFY, true)).AddChangeHook(CVarChanged_HPCost);
	iHPCost = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_health", "100", "How many HP will get revived player", FCVAR_NOTIFY, true, 25.0)).AddChangeHook(CVarChanged_HP);
	iHP = CVar.IntValue;

	(CVar = CreateConVar("sm_revival_frag", "1", "Enable/disable give frag to the player for revived teammate", FCVAR_NOTIFY, true, _, true, 1.0)).AddChangeHook(CVarChanged_Frag);
	bFrag = CVar.BoolValue;

	(CVar = CreateConVar("sm_revival_soundpath", "ui/achievement_earned.wav", "This sound playing after reviving (empty string = disabled)", FCVAR_PRINTABLEONLY, true)).AddChangeHook(CVarChanged_Sound);
	CVar.GetString(sCvarPath, sizeof(sCvarPath));

	HookEvent("player_team", Event_Team);
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	LoadTranslations("revival.phrases");

	AutoExecConfig(true, "revival");
}

public void OnPluginEnd()
{
	for(int i = 1, ent; i <= MaxClients; i++) if(iMarkRef[i] != -1 && (ent = EntRefToEntIndex(iMarkRef[i])) != -1) AcceptEntityInput(ent, "Kill");
}

public void CVarChanged_Enable(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bEnable = CVar.BoolValue;
	PrintToChatAll("%T%T", "ChatTag", LANG_SERVER, bEnable ? "Enabled" : "Disabled", LANG_SERVER);
}

public void CVarChanged_Key(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iKey = CVar.IntValue;
	PrintToChatAll("%T%T", "ChatTag", LANG_SERVER, "KeyTip", LANG_SERVER, KEY_NAME[iKey]);
}

public void CVarChanged_Clean(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iClean = CVar.IntValue;
}

public void CVarChanged_Team(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bTeam = CVar.BoolValue;
}

public void CVarChanged_Enemy(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bEnemy = CVar.BoolValue;
	for(int i, team; i <= MaxClients; i++) if(iDeathTeam[i] && iMarkRef[i] != -1)
	{
		team = bEnemy ? 2 : iDeathTeam[i] - 2;
		SetMarkColor(EntRefToEntIndex(iMarkRef[i]), team);
	}
}

public void CVarChanged_Percent(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bPercent = CVar.BoolValue;
}

public void CVarChanged_Effect(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bEffect = CVar.BoolValue;
}

public void CVarChanged_Radius(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	fRadius = CVar.FloatValue;
}

public void CVarChanged_Time(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iTime = CVar.IntValue;
}

public void CVarChanged_CD(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iCD = CVar.IntValue;
}

public void CVarChanged_Times(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iTimes = CVar.IntValue;
}

public void CVarChanged_NoBlockTime(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iNoBlockTime = CVar.IntValue;
}

public void CVarChanged_HPCost(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iHPCost = CVar.IntValue;
}

public void CVarChanged_HP(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iHP = CVar.IntValue;
}

public void CVarChanged_Frag(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bFrag = CVar.BoolValue;
}

public void CVarChanged_Sound(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	CVar.GetString(sCvarPath, sizeof(sCvarPath));
}

public void OnMapStart()
{
	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if(gameConfig == null) LogError("Unable to load game config funcommands.games");
	else
	{
		char buffer[PLATFORM_MAX_PATH];
		if(GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
			hBeam = PrecacheModel(buffer);
		if(GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
			hHalo = PrecacheModel(buffer);

		bSprites = hBeam != -1 && hHalo != -1;
		if(!bSprites)
			LogError("Can't find config for %s%s%s!", hBeam == -1 ? "SpriteBeam" : "", hBeam == hHalo ? " and " : "", hHalo == -1 ? "SpriteHalo" : "");
	}
	CloseHandle(gameConfig);

	if(!sCvarPath[0]) return;
	FormatEx(sSoundPath, sizeof(sSoundPath), "sound/%s", sCvarPath);
	if(FileExists(sSoundPath)) AddFileToDownloadsTable(sSoundPath);
	else
	{
		sSoundPath[0] = 0;
		return;
	}

	if(bCSGO)
	{
		FormatEx(sSoundPath, sizeof(sSoundPath), "*%s", sCvarPath);
		AddToStringTable(FindStringTable("soundprecache"), sSoundPath);
		return;
	}

	FormatEx(sSoundPath, sizeof(sSoundPath), "%s", sCvarPath);
	PrecacheSound(sSoundPath, true);
}

public void OnClientConnected(int client)
{
	iTimesRevived[client] = 0;
}

public void OnClientDisconnect(int client)
{
	RemoveMark(client);
}

public Action Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	if(!bAllowed) return Plugin_Continue;

	static int client, team;
	if((client = GetClientOfUserId(event.GetInt("userid"))))
	{
		if(((team = event.GetInt("team")) < 2) || (!bTeam && team != iDeathTeam[client]))
		{
			ResetRespawnData(client);
			iDeathTeam[client] = 0;
			ResetPercents(client);
		}
	}

	return Plugin_Continue;
}

public Action Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	if(!bAllowed) return Plugin_Continue;

	static int client;
	if(!(client = GetClientOfUserId(event.GetInt("userid"))) || (iDeathTeam[client] = GetClientTeam(client)) < 2
	|| !bEnable)
		return Plugin_Continue;

	CreateMark(client);

	if(iTime) CreateTimer(iTime+0.0, Timer_DisableReviving, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	if(iClean < 0) return Plugin_Continue;
	static int iOffsetRagdoll = -1;
	if((iOffsetRagdoll != -1 || (iOffsetRagdoll = FindSendPropInfo("CCSPlayer", "m_hRagdoll")) != -1)
	&& (client = GetEntDataEnt2(client, iOffsetRagdoll)) != -1 && IsValidEntity(client))
		CreateTimer(iClean+0.0, Timer_RemoveBody, EntIndexToEntRef(client), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action Timer_RemoveBody(Handle timer, any ent)
{
	if((ent = EntRefToEntIndex(ent)) != -1) AcceptEntityInput(ent, "Kill");
}

public Action Timer_DisableReviving(Handle timer, any client)
{
	if((client = GetClientOfUserId(client))) HideMark(client);
	ResetPercents(client);
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!bAllowed) return Plugin_Continue;

	static int client;
	if(bEnable && (client = GetClientOfUserId(event.GetInt("userid")))) HideMark(client);
	ResetPercents(client);

	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	bAllowed = true;
	if(bEnable) PrintToChatAll("%t%t", "ChatTag", "KeyTip", KEY_NAME[iKey]);

	return Plugin_Continue;
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason)
{
	bAllowed = false;
	for(int i = 1; i <= MaxClients; i++) ResetRespawnData(i);
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(!bEnable || !bAllowed || IsFakeClient(client) || (iTimes && iTimesRevived[client] >= iTimes))
		return Plugin_Continue;

	static bool reset[MAXPLAYERS+1];
	static int old_target[MAXPLAYERS+1];
	if(!reset[client] && (!IsPlayerAlive(client) || GetClientTeam(client) < 2))
	{
		reset[client] = true;
		fProgress[client] = NULL_PERCENT;
		SendProgressBar(client, old_target[client]);
		if(old_target[client]) old_target[client] = 0;
		return Plugin_Continue;
	}

	if(old_target[client] && (!IsClientInGame(old_target[client]) || IsPlayerAlive(old_target[client])))
	{
		fProgress[client][old_target[client]] = 0.0;
		old_target[client] = 0;
		SendProgressBar(client);
	}

	static int target, old_buttons[MAXPLAYERS+1];
	static float start[MAXPLAYERS+1], time, effect_time[MAXPLAYERS+1];
	static char name[MAX_NAME_LENGTH];
	time = GetGameTime();
	if(buttons & KEY_VAL[iKey] && GetEntityFlags(client) & FL_ONGROUND)
	{
		static int iOffsetVel_0 = -1, iOffsetVel_1 = -1, iOffsetVel_2 = -1;
		if(!old_target[client] || !iDeathTeam[old_target[client]])
			target = GetNearestTarget(client);
		else if((iOffsetVel_0 != -1 || (iOffsetVel_0 = FindSendPropInfo("CCSPlayer", "m_vecVelocity[0]")) != -1)
		&& GetEntDataFloat(client, iOffsetVel_0)
		|| (iOffsetVel_1 != -1 || (iOffsetVel_1	= FindSendPropInfo("CCSPlayer", "m_vecVelocity[1]")) != -1)
		&& GetEntDataFloat(client, iOffsetVel_1)
		|| (iOffsetVel_2 != -1 || (iOffsetVel_2	= FindSendPropInfo("CCSPlayer", "m_vecVelocity[2]")) != -1)
		&& GetEntDataFloat(client, iOffsetVel_2))
		{
			static float pos[3];
			GetClientAbsOrigin(client, pos);
			if(FloatCompare(fRadius, GetVectorDistance(pos, fDeathPos[old_target[client]])) == -1)
				target = GetNearestTarget(client);
		}
		else target = old_target[client];

		if(FloatCompare(FloatSub(time, effect_time[client]), EFF_LIFE) != -1 || target != old_target[client])
		{
			effect_time[client] = time;
			CreateEffect(client, target);
		}

		if(target)
		{
			reset[client] = false;
			if(target != old_target[client])
			{
				SaveProgress(client, old_target[client], FloatSub(time, start[client]));
				start[client] = FloatSub(time, fProgress[client][target]);
				old_target[client] = target;

				SendProgressBar(client, target, start[client]);

				GetClientName(target, name, sizeof(name));
				PrintToChat(client, "%t%t", "ChatTag", "YouReviving", name);
				if(iHPCost)
				{
					static int newHP;
					if((newHP = GetClientHealth(client) - iHPCost) < 1)
						PrintToChat(client, "%t", "ReviveCostDeath");
					else PrintToChat(client, "%t", "ReviveCostHealth", newHP);
				}

				GetClientName(client, name, sizeof(name));
				PrintToChat(target, "%t%t", "ChatTag", "YouRevivingBy", name);
			}
			if(FloatSub(time, start[client])/iCD >= 1) InitRespawn(client, target);
		}
		else
		{
			if(old_target[client])
			{
				SaveProgress(client, old_target[client], FloatSub(time, start[client]));
				SendProgressBar(client, old_target[client]);
				old_target[client] = 0;
			}
		}
	}
	else if(old_buttons[client] & KEY_VAL[iKey] && old_target[client])
	{
		reset[client] = true;
		SaveProgress(client, old_target[client], FloatSub(time, start[client]));
		SendProgressBar(client, old_target[client]);
		GetClientName(old_target[client], name, sizeof(name));
		PrintToChat(client, "%t%t", "ChatTag", "RevivingStopped", name, RoundToNearest((FloatSub(time, start[client])/iCD)*100));
		old_target[client] = 0;		// 
	}
	old_buttons[client] = buttons;
	return Plugin_Continue;
}

public Action Timer_EnableCollision(Handle timer, any client)
{
	if((client = GetClientOfUserId(client))) SetEntData(client, iOffsetGroup, 5, 4, true);
}

stock void CreateMark(int client)
{
	static int team, ent, old_team[MAXPLAYERS+1];
	if(hHalo == -1 || (team = GetClientTeam(client) - 2) < 0) return;
	if(bEnemy) team = 2;

	GetClientAbsOrigin(client, fDeathPos[client]);
	fDeathPos[client][2] -= 40;
	if(iMarkRef[client] != -1 && (ent = EntRefToEntIndex(iMarkRef[client])) != -1)
	{
		if(old_team[client] != team) SetMarkColor(ent, team);
		AcceptEntityInput(ent, "ShowSprite");
	}
	else if((ent = CreateEntityByName("env_sprite")) != -1)
	{
		DispatchKeyValue(ent, "model", MARK_MDL);
		DispatchKeyValue(ent, "classname", "death_mark");
		DispatchKeyValue(ent, "spawnflags", "1");
		DispatchKeyValueFloat(ent, "scale", MARK_SIZE);
		DispatchKeyValue(ent, "rendermode", "5");
		DispatchSpawn(ent);

		iMarkRef[client] = EntIndexToEntRef(ent);
		SetMarkColor(ent, team);
		old_team[client] = team;
	}
	else return;
	old_team[client] = team;
	TeleportEntity(ent, fDeathPos[client], NULL_VECTOR, NULL_VECTOR);
}

stock void SetMarkColor(int ent, int team)
{
	SetVariantInt(COLOR[team][0]);
	AcceptEntityInput(ent, "ColorRedValue");
	SetVariantInt(COLOR[team][1]);
	AcceptEntityInput(ent, "ColorGreenValue");
	SetVariantInt(COLOR[team][2]);
	AcceptEntityInput(ent, "ColorBlueValue");
}

stock void ResetRespawnData(int client)
{
	SendProgressBar(client);
	fProgress[client] = NULL_PERCENT;
	iTimesRevived[client] = iDeathTeam[client] = 0;
	HideMark(client);
}

static void RemoveMark(int client)
{
	static int ent;
	if(iMarkRef[client] != -1 && (ent = EntRefToEntIndex(iMarkRef[client])) != -1) AcceptEntityInput(ent, "Kill");
	iMarkRef[client] = -1;
}

stock void HideMark(const int client)
{
	static int ent;
	if(iMarkRef[client] != -1 && (ent = EntRefToEntIndex(iMarkRef[client])) != -1) AcceptEntityInput(ent, "HideSprite");
	iDeathTeam[client] = 0;
}

stock void ResetPercents(int client)
{
	static int i;
	for(i = 1; i <= MaxClients; i++) fProgress[i][client] = 0.0;
}

stock int GetNearestTarget(int client)
{
	static int i, team, target;
	static float pos[3], dist[MAXPLAYERS], min_dist;
	if(!bEnemy) team = GetClientTeam(client);
	GetClientAbsOrigin(client, pos);

	for(i = 1, target = 0, min_dist = fRadius; i < MaxClients; i++)
		if(i != client && iDeathTeam[i] > 1 && (bEnemy || team == iDeathTeam[i])
		&& FloatCompare(min_dist, (dist[i] = GetVectorDistance(pos, fDeathPos[i]))) == 1)
		{
			min_dist = dist[i];
			target = i;
		}

	return target;
}

stock void SaveProgress(const int client, const int target, const float value)
{
	if(!target) return;
	if(bPercent) fProgress[client][target] = value;
	else fProgress[client][target] = 0.0;
}

stock Action InitRespawn(int client, int target)
{
	if(!IsPlayerAlive(client) || !target || !IsClientInGame(target) || IsPlayerAlive(target))	// не факт что необходима
		return Plugin_Handled;

	HideMark(client);
	ResetPercents(client);

	static int buffer;
	if(bEnemy && (buffer = GetClientTeam(client)) != iDeathTeam[target]) CS_SwitchTeam(target, buffer);
	CS_RespawnPlayer(target);
	TeleportEntity(target, fDeathPos[target], NULL_VECTOR, NULL_VECTOR);
	SetEntityHealth(target, iHP);

	static char name[MAX_NAME_LENGTH];
	if((buffer = GetEntProp(target, Prop_Data, "m_iDeaths")) > 0) SetEntProp(target, Prop_Data, "m_iDeaths", buffer-1);
	if(bFrag) SetEntProp(client, Prop_Data, "m_iFrags", GetEntProp(client, Prop_Data, "m_iFrags")+1);
	GetClientName(target, name, sizeof(name));
	PrintToChat(client, "%t%t", "ChatTag", bFrag ? "TargetRevivedFrag" : "TargetRevived", name);
	GetClientName(client, name, sizeof(name));
	PrintToChat(target, "%t%t", "ChatTag", "YouRevived", target, name);
	if(sSoundPath[0]) EmitAmbientSound(sSoundPath, fDeathPos[target]);

	if((buffer = GetClientHealth(client) - iHPCost) > 0) SetEntityHealth(client, buffer);
	else ForcePlayerSuicide(client);

	if(iNoBlockTime && iOffsetGroup != -1)
	{
		SetEntData(client, iOffsetGroup, 17, 4, true);
		CreateTimer(iNoBlockTime+0.0, Timer_EnableCollision, GetClientUserId(target), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	if(!iTimes) return Plugin_Handled;

	iTimesRevived[client]++;
	if(iTimesRevived[client] >= iTimes) PrintToChat(client, "%t%t", "ChatTag", "RevivalsNotAvailable");
	else PrintToChat(client, "%t%t", "ChatTag", "RevivalsAvailable", iTimes - iTimesRevived[client]);

	return Plugin_Handled;
}

stock void SendProgressBar(const int client, const int target = 0, const float time = 0.0)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) return;

	static int iOffsetStart = -1, iOffsetDuration = -1;
	if(iOffsetStart == -1 && (iOffsetStart = FindSendPropInfo("CCSPlayer", "m_flProgressBarStartTime")) == -1)
		return;
	if(iOffsetDuration == -1 && (iOffsetDuration = FindSendPropInfo("CCSPlayer", "m_iProgressBarDuration")) == -1)
		return;

	static int duration;
	duration = time ? iCD : 0;

	SetEntDataFloat(client, iOffsetStart, time, true);
	SetEntData(client, iOffsetDuration, duration, true);

	if(!target || !IsClientInGame(target) || IsFakeClient(target)) return;
	SetEntDataFloat(target, iOffsetStart, time, true);
	SetEntData(target, iOffsetDuration, duration, true);
}

stock void CreateEffect(const int client, const int target)
{
	if(!bEffect || !bSprites) return;

	static int i, team, clients[MAXPLAYERS+1], num;
	team = GetClientTeam(client);
	if(target)
	{
		for(i = 1, num = 0; i <= MaxClients; i++)
			if(IsClientInGame(i) && !IsFakeClient(i) && (bEnemy || team == GetClientTeam(i))) clients[num++] = i;
		TE_SetupBeamRingTarget(target, team);
		TE_Send(clients, num);
	}
	else for(i = 1, num = 0; i <= MaxClients; i++) if(iDeathTeam[i] && (bEnemy || iDeathTeam[i] == team))
	{
		TE_SetupBeamRingTarget(i, team);
		TE_SendToClient(client);
		num++;
	}
}

stock void TE_SetupBeamRingTarget(const int target, int team)
{
	TE_Start("BeamRingPoint");
	TE_WriteVector("m_vecCenter", fDeathPos[target]);
	TE_WriteFloat("m_flStartRadius", fRadius);
	TE_WriteFloat("m_flEndRadius", fRadius+0.1);
	TE_WriteNum("m_nModelIndex", hBeam);
	TE_WriteNum("m_nHaloIndex", hHalo);
	TE_WriteNum("m_nStartFrame", 0);
	TE_WriteNum("m_nFrameRate", 15);
	TE_WriteFloat("m_fLife", EFF_LIFE);
	TE_WriteFloat("m_fWidth", 3.0);
	TE_WriteFloat("m_fEndWidth", 3.0);
	TE_WriteFloat("m_fAmplitude", 0.0);
	team = bEnemy ? 2 : team - 2;
	TE_WriteNum("r", COLOR[team][0]);
	TE_WriteNum("g", COLOR[team][1]);
	TE_WriteNum("b", COLOR[team][2]);
	TE_WriteNum("a", COLOR[team][3]);
	TE_WriteNum("m_nSpeed", 1);
	TE_WriteNum("m_nFlags", 0);
	TE_WriteNum("m_nFadeLength", 0);
}
