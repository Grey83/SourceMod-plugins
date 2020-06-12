#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_tempents>
#include <sdktools_sound>
#if SOURCEMOD_V_MINOR >= 9
	#include <sdktools_variant_t>
#endif

static const char
	PL_NAME[]	= "Revival",
	PL_VER[]	= "1.0.11",

	MARK_MDL1[]	= "hud/scoreboard_dead.vmt",	// for CSGO & CSS
	MARK_MDL2[]	= "sprites/glow.vmt",			// for CSSv34
	KEY_NAME[][]= {"Ctrl", "E", "Shift"},
	CLR[][][]	=
{//		name		CSGO		CSS			CSSv34
	{"{DEFAULT}",	"\x01",	"\x01",			"\x01"},
	{"{TEAM}",		"\x03",	"\x03",			"\x03"},
	{"{GREEN}",		"\x04",	"\x0700AD00",	"\x04"},
	{"{WHITE}",		"\x01",	"\x07FFFFFF",	""},
	{"{RED}",		"\x02",	"\x07FF0000",	""},
	{"{LIME}",		"\x05",	"\x0700FF00",	""},
	{"{LIGHTGREEN}","\x06",	"\x0799FF99",	""},
	{"{LIGHTRED}",	"\x07",	"\x07FF4040",	""},
	{"{GRAY}",		"\x08",	"\x07CCCCCC",	""},
	{"{LIGHTOLIVE}","\x09",	"\x07FFBD6B",	""},
	{"{OLIVE}",		"\x10",	"\x07FA8B00",	""},
	{"{BLUEGREY}",	"\x0A",	"\x076699CC",	""},
	{"{LIGHTBLUE}",	"\x0B",	"\x0799CCFF",	""},
	{"{BLUE}",		"\x0C",	"\x073D46FF",	""},
	{"{PURPLE}",	"\x0E",	"\x07FA00FA",	""},
	{"{LIGHTRED2}",	"\x0F",	"\x07FF8080",	""}
};

static const int
	COLOR[]		= {0xff3f1f, 0x1f3fff, 0x00bf00},	// T, CT, Any
	KEY_VAL[]	= {IN_DUCK, IN_USE, IN_SPEED};
static const float
	NULL_PERCENT[MAXPLAYERS+1]	= {0.0, ...},
	EFF_LIFE	= 1.0,	// частота обновления эффекта
	MARK_SIZE	= 0.3;	// размер меток

enum
{
	E_Unknown,
	E_CSGO,
	E_CSS,
	E_Old
};

bool
	bEnable,
	bTip,
	bMsg,
	bPos,
	bTeam,
	bEnemy,
	bBar,
	bPercent,
	bEffect,
	bDeath,
	bSprites,
	bHS;
float
	fRadius,
	fNoDmgTime;
int
	iKey,
	iClean,
	iTime,
	iCD,
	iTimes,
	iNoBlockTime,
	iHPCost,
	iHP,
	iFrag,
	iColorT,
	iColorCT,
	iColorAny;
char
	sCvarPath[PLATFORM_MAX_PATH],
	sSoundPath[PLATFORM_MAX_PATH];

bool
	bAllowed = true,
	bProto;
int
	iEngine,
	iOffsetGroup,
	hBeam = -1,
	hHalo = -1,
	iMarkRef[MAXPLAYERS+1] = {-1, ...},
	iTimesRevived[MAXPLAYERS+1],
	iTeam[MAXPLAYERS+1],
	iDeathTeam[MAXPLAYERS+1],
	iTarget[MAXPLAYERS+1],
	iReviver[MAXPLAYERS+1];
float
	fDeathPos[MAXPLAYERS+1][3],
	fDeathAng[MAXPLAYERS+1][3],
	fProgress[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PL_NAME,
	author		= "Grey83",
	description	= "Press and hold +USE above death place to respawn player",
	version		= PL_VER,
	url			= "https://steamcommunity.com/groups/grey83ds"
//	https://github.com/Grey83/SourceMod-plugins/blob/master/SM/scripting/sm_revival.sp
};

public void OnPluginStart()
{
	bProto = GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;

	switch(GetEngineVersion())
	{
		case Engine_CSGO:
			iEngine = E_CSGO;
		case Engine_CSS, Engine_HL2DM, Engine_DODS:
			iEngine = E_CSS;
		case Engine_SourceSDK2006:
			iEngine = E_Old;
	}

	iOffsetGroup	= FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	CreateConVar("sm_revival_version", PL_VER, PL_NAME, FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

	ConVar cvar;
	cvar = CreateConVar("sm_revival_enabled", "1", "Enable/disable plugin", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enable);
	bEnable = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_tip", "1", "Enable/disable key tip at the beginning of the round", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Tip);
	bTip = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_msg", "1", "Enable/disable chat messages", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Msg);
	bMsg = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_key", "1", "Key for reviving (0 - 'duck', 1 - 'use', 2 - 'walk')", _, true, _, true, 2.0);
	cvar.AddChangeHook(CVarChanged_Key);
	iKey = cvar.IntValue;

	cvar = CreateConVar("sm_revival_pos", "1", "Spawn player at: 0 - position of reviver, 1 - his death position", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Pos);
	bPos = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_clean", "2", "Remove body x sec after the death (-1 - don't remove)", FCVAR_NOTIFY, true, -1.0);
	cvar.AddChangeHook(CVarChanged_Clean);
	iClean = cvar.IntValue;

	cvar = CreateConVar("sm_revival_teamchange", "1", "Can a player be revived after a team change", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Team);
	bTeam = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_enemy", "0", "Can a player revive the enemy (the revived player will change the team)", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enemy);
	bEnemy = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_bar", "1", "Enable/disable progressbar for reviving", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Bar);
	bBar = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_percent", "1", "Enable/disable save the percentage of reviving", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Percent);
	bPercent = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_effect", "1", "Enable/disable effect around to place of death", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Effect);
	bEffect = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_radius", "200.0", "Radius to respawn death player", FCVAR_NOTIFY, true);
	cvar.AddChangeHook(CVarChanged_Radius);
	fRadius = cvar.FloatValue;

	cvar = CreateConVar("sm_revival_time", "0", "The time after the death of the player, during which the revive is possible", FCVAR_NOTIFY, true);
	cvar.AddChangeHook(CVarChanged_Time);
	iTime = cvar.IntValue;

	cvar = CreateConVar("sm_revival_countdown", "3.0", "Time for respawn in seconds", FCVAR_NOTIFY, true);
	cvar.AddChangeHook(CVarChanged_CD);
	iCD = cvar.IntValue;

	cvar = CreateConVar("sm_revival_times", "0", "How many times can a player revive other players during the round (0 - unlimited)", FCVAR_NOTIFY, true);
	cvar.AddChangeHook(CVarChanged_Times);
	iTimes = cvar.IntValue;

	cvar = CreateConVar("sm_revival_noblock_time", "2", "Noblocking time after respawn(set at 0 if you have any noblock plugin)", _, true);
	cvar.AddChangeHook(CVarChanged_NoBlockTime);
	iNoBlockTime = cvar.IntValue;

	cvar = CreateConVar("sm_revival_health_cost", "25", "Need's health to respawn others", FCVAR_NOTIFY, true);
	cvar.AddChangeHook(CVarChanged_HPCost);
	iHPCost = cvar.IntValue;

	cvar = CreateConVar("sm_revival_death", "1", "Can a player revive others if he have less HP than needed for reviving", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Death);
	bDeath = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_health", "100", "How many HP will get revived player", FCVAR_NOTIFY, true, 25.0);
	cvar.AddChangeHook(CVarChanged_HP);
	iHP = cvar.IntValue;

	cvar = CreateConVar("sm_revival_frag", "1", "Give x frags to the player for revived teammate", FCVAR_NOTIFY, true);
	cvar.AddChangeHook(CVarChanged_Frag);
	iFrag = cvar.IntValue;

	cvar = CreateConVar("sm_revival_hs_rip", "0", "Disallow the revival of the players killed in the head", FCVAR_NOTIFY, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_HS);
	bHS = cvar.BoolValue;

	cvar = CreateConVar("sm_revival_soundpath", "ui/achievement_earned.wav", "This sound playing after reviving (empty string = disabled)", FCVAR_PRINTABLEONLY, true);
	cvar.AddChangeHook(CVarChanged_Sound);
	cvar.GetString(sCvarPath, sizeof(sCvarPath));

	cvar = CreateConVar("sm_revival_nodmg_time", "2.0", "No damage recive time after respawn (set at 0.0 if you have any spawn protect plugin)", _, true, _, true, 5.0);
	cvar.AddChangeHook(CVarChanged_NoDmgTime);
	fNoDmgTime = cvar.FloatValue;

	cvar = CreateConVar("sm_revival_color_t", "ff3f1f", "T death mark color. Set by HEX (RGB or RRGGBB, values 0 - F or 00 - FF, resp.). Wrong color code = red", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_ColorT);
	SetColor(cvar, iColorT, COLOR[0]);

	cvar = CreateConVar("sm_revival_color_ct", "1f3fff", "CT death mark color. Set by HEX (RGB or RRGGBB, values 0 - F or 00 - FF, resp.). Wrong color code = blue", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_ColorCT);
	SetColor(cvar, iColorCT, COLOR[1]);

	cvar = CreateConVar("sm_revival_color_any", "00bf00", "Any death team mark color. Set by HEX (RGB or RRGGBB, values 0 - F or 00 - FF, resp.). Wrong color code = green", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_ColorAny);
	SetColor(cvar, iColorAny, COLOR[2]);

	HookEvent("player_team", Event_Team);
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	LoadTranslations("revival.phrases");

	AutoExecConfig(true, "revival");
}

public void OnPluginEnd()
{
	for(int i = 1, ent; i <= MaxClients; i++) if((ent = GetMarkId(i)) != -1) AcceptEntityInput(ent, "Kill");
}

public void CVarChanged_Enable(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bEnable = cvar.BoolValue;
	PrintToChatAllClr("%t%t", "ChatTag", bEnable ? "Enabled" : "Disabled");
}

public void CVarChanged_Tip(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bTip = cvar.BoolValue;
}

public void CVarChanged_Msg(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bMsg = cvar.BoolValue;
}

public void CVarChanged_Key(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iKey = cvar.IntValue;
	PrintToChatAllClr("%T%T", "ChatTag", LANG_SERVER, "KeyTip", LANG_SERVER, KEY_NAME[iKey]);
}

public void CVarChanged_Pos(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bPos = cvar.BoolValue;
}

public void CVarChanged_Clean(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iClean = cvar.IntValue;
}

public void CVarChanged_Team(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bTeam = cvar.BoolValue;
}

public void CVarChanged_Enemy(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bEnemy = cvar.BoolValue;

	for(int i; i <= MaxClients; i++) if(iDeathTeam[i] && iMarkRef[i] == -1) SetMarkColor(i);
}

public void CVarChanged_Bar(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bBar = cvar.BoolValue;
}

public void CVarChanged_Percent(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bPercent = cvar.BoolValue;
}

public void CVarChanged_Effect(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bEffect = cvar.BoolValue;
}

public void CVarChanged_Radius(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	fRadius = cvar.FloatValue;
}

public void CVarChanged_Time(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iTime = cvar.IntValue;
}

public void CVarChanged_CD(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iCD = cvar.IntValue;
}

public void CVarChanged_Times(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iTimes = cvar.IntValue;
}

public void CVarChanged_NoBlockTime(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iNoBlockTime = cvar.IntValue;
}

public void CVarChanged_HPCost(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iHPCost = cvar.IntValue;
}

public void CVarChanged_Death(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bDeath = cvar.BoolValue;
}

public void CVarChanged_HP(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iHP = cvar.IntValue;
}

public void CVarChanged_Frag(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	iFrag = cvar.IntValue;
}

public void CVarChanged_Sound(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	cvar.GetString(sCvarPath, sizeof(sCvarPath));
}

public void CVarChanged_HS(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	bHS = cvar.BoolValue;
}

public void CVarChanged_NoDmgTime(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	fNoDmgTime = cvar.FloatValue;
}

public void CVarChanged_ColorT(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetColor(cvar, iColorT, COLOR[0]);
	if(!bEnemy) for(int i = 1; i <= MaxClients; i++) if(IsMarkExist(i) && GetClientTeam(i) == 2) SetMarkColor(i);
}

public void CVarChanged_ColorCT(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetColor(cvar, iColorCT, COLOR[1]);
	if(!bEnemy) for(int i = 1; i <= MaxClients; i++) if(IsMarkExist(i) && GetClientTeam(i) == 3) SetMarkColor(i);
}

public void CVarChanged_ColorAny(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetColor(cvar, iColorAny, COLOR[2]);
	if(bEnemy) for(int i = 1; i <= MaxClients; i++) if(IsMarkExist(i) && GetClientTeam(i) > 1) SetMarkColor(i);
}

stock void SetColor(ConVar cvar, int& color, int def_clr)
{
	char clr[8];
	cvar.GetString(clr, sizeof(clr));
	clr[7] = 0;	// чтобы проверялось максимум 7 первых символов

	int i;
	while(clr[i])
	{
		if(!(clr[i] >= '0' && clr[i] <= '9') && !(clr[i] >= 'A' && clr[i] <= 'F') && !(clr[i] >= 'a' && clr[i] <= 'f'))
		{	// не HEX-число
			color = def_clr;
			LogError("HEX color '%s' isn't valid!\nHUD color is 0x%x (%d %d %d)!\n", clr, color, (color & 0xFF0000) >> 16, (color & 0xFF00) >> 8, color & 0xFF);
			return;
		}
		i++;
	}

	clr[6] = 0;
	if(i == 3)	// короткая форма => полная форма
	{
		clr[4] = clr[5] = clr[2];
		clr[2] = clr[3] = clr[1];
		clr[1] = clr[0];
		i = 6;
	}

	if(i != 6) color = def_clr;	// невалидный цвет
	else StringToIntEx(clr, color , 16);
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
	AddFileToDownloadsTable(sSoundPath);

	if(iEngine == E_CSGO)
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
	iTimesRevived[client] = iTarget[client] = iReviver[client] = 0;
	for(int i = 1; i <= MaxClients; i++) if(IsClientValid(i) && iTarget[client] == i) iTarget[client] = 0;
}

public void OnClientDisconnect(int client)
{
	RemoveMark(client);
	iTeam[client] = 0;
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if(!bAllowed || !(client = GetClientOfUserId(event.GetInt("userid")))) return;

	if(((iTeam[client] = event.GetInt("team")) < 2) || (!bTeam && iTeam[client] != iDeathTeam[client]))
	{
		ResetRespawnData(client);
		iDeathTeam[client] = 0;
		ResetPercents(client);
	}
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if(!bEnable || !bAllowed || bHS && event.GetBool("headshot") || !(client = GetClientOfUserId(event.GetInt("userid")))
	|| (iDeathTeam[client] = GetClientTeam(client)) < 2)
		return;

	CreateMark(client);

	if(iTime) CreateTimer(iTime+0.0, Timer_DisableReviving, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	if(iClean < 0) return;
	static int iOffsetRagdoll = -1;
	if((iOffsetRagdoll != -1 || (iOffsetRagdoll = FindSendPropInfo("CCSPlayer", "m_hRagdoll")) != -1)
	&& (client = GetEntDataEnt2(client, iOffsetRagdoll)) != -1 && IsValidEntity(client))
		CreateTimer(iClean+0.0, Timer_RemoveBody, EntIndexToEntRef(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RemoveBody(Handle timer, any ent)
{
	if((ent = EntRefToEntIndex(ent)) != -1) AcceptEntityInput(ent, "Kill");
}

public Action Timer_DisableReviving(Handle timer, any client)
{
	if(!(client = GetClientOfUserId(client)))
		return;

	RemoveMark(client);
	ResetPercents(client);
	iDeathTeam[client] = 0;
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if(!bEnable || !bAllowed || !(client = GetClientOfUserId(event.GetInt("userid")))) return;

	RemoveMark(client);
	ResetPercents(client);
	iDeathTeam[client] = iTarget[client] = iReviver[client] = 0;
	iTeam[client] = GetClientTeam(client);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	bAllowed = true;
	if(bEnable && bTip) PrintToChatAllClr("%t%t", "ChatTag", "KeyTip", KEY_NAME[iKey]);
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason)
{
	bAllowed = false;
	for(int i = 1; i <= MaxClients; i++) ResetRespawnData(i);
	return Plugin_Continue;
}

stock void SendWarnNotEnough(int client, bool &val)
{
	if(!bMsg || val) return;

	val = true;
	PrintToChatClr(client, "%t%t", "ChatTag", "NotEnoughHP");
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	static bool reset[MAXPLAYERS+1], cant, prev[MAXPLAYERS+1];
	static int old_target[MAXPLAYERS+1], diff, target[MAXPLAYERS+1], old_buttons[MAXPLAYERS+1], iOffsetVel_0 = -1, iOffsetVel_1 = -1, iOffsetVel_2 = -1;
	static float start[MAXPLAYERS+1], time, effect_time[MAXPLAYERS+1], pos[3];
	static char name[MAX_NAME_LENGTH];

	if(!bEnable || !bAllowed || IsFakeClient(client) || (iTimes && iTimesRevived[client] >= iTimes))
		return Plugin_Continue;

	if(!reset[client] && (!IsPlayerAlive(client) || GetClientTeam(client) < 2))
	{
		reset[client] = true;
		fProgress[client] = NULL_PERCENT;
		SendProgressBar(client, old_target[client]);
		if(old_target[client]) old_target[client] = 0;
		return Plugin_Continue;
	}

	cant = iHPCost && (diff = GetClientHealth(client) - iHPCost) < 1 && !bDeath;
	if(buttons & KEY_VAL[iKey] && !(old_buttons[client] & KEY_VAL[iKey]) && cant && !old_target[client])
	{
		SendWarnNotEnough(client, prev[client]);
		old_buttons[client] = buttons;
		return Plugin_Continue;
	}

	if(old_target[client] && (!IsClientInGame(old_target[client]) || IsPlayerAlive(old_target[client]) || cant))
	{
		fProgress[client][old_target[client]] = 0.0;
		old_target[client] = 0;
		SendProgressBar(client);
		if(cant)
		{
			SendWarnNotEnough(client, prev[client]);
			return Plugin_Continue;
		}
	}
	prev[client] = cant;

	time = GetGameTime();
	if(buttons & KEY_VAL[iKey] && GetEntityFlags(client) & FL_ONGROUND)
	{
		if(!old_target[client] || !iDeathTeam[old_target[client]])
			target[client] = GetNearestTarget(client);
		else if((iOffsetVel_0 != -1 || (iOffsetVel_0 = FindSendPropInfo("CCSPlayer", "m_vecVelocity[0]")) != -1)
		&& GetEntDataFloat(client, iOffsetVel_0)
		|| (iOffsetVel_1 != -1 || (iOffsetVel_1	= FindSendPropInfo("CCSPlayer", "m_vecVelocity[1]")) != -1)
		&& GetEntDataFloat(client, iOffsetVel_1)
		|| (iOffsetVel_2 != -1 || (iOffsetVel_2	= FindSendPropInfo("CCSPlayer", "m_vecVelocity[2]")) != -1)
		&& GetEntDataFloat(client, iOffsetVel_2))
		{
			GetClientAbsOrigin(client, pos);
			if(FloatCompare(fRadius, GetVectorDistance(pos, fDeathPos[old_target[client]])) == -1)
				target[client] = GetNearestTarget(client);
		}
		else target[client] = old_target[client];

		if(FloatCompare(FloatSub(time, effect_time[client]), EFF_LIFE) != -1 || target[client] != old_target[client])
		{
			effect_time[client] = time;
			CreateEffect(client, target[client]);
		}

		if(target[client] && IsClientConnected(target[client]))
		{
			reset[client] = false;
			if(target[client] != old_target[client])
			{
				SaveProgress(client, old_target[client], FloatSub(time, start[client]));
				start[client] = FloatSub(time, fProgress[client][target[client]]);
				old_target[client] = target[client];

				SendProgressBar(client, target[client], start[client]);

				if(bMsg)
				{
					if(iTarget[client] != target[client])
					{
						GetClientName(target[client], name, sizeof(name));
						PrintToChatClr(client, "%t%t", "ChatTag", "YouReviving", name);
						if(iReviver[target[client]] != client)
						{
							GetClientName(client, name, sizeof(name));
							PrintToChatClr(target[client], "%t%t", "ChatTag", "YouRevivingBy", name);
						}
					}

					if(iHPCost)
					{
						if(diff < 1) PrintToChatClr(client, "%t", "ReviveCostDeath");
						else PrintToChatClr(client, "%t", "ReviveCostHealth", diff);
					}
				}
				iReviver[target[client]] = client;
				iTarget[client] = target[client];
			}
			if(FloatSub(time, start[client])/iCD >= 1) InitRespawn(client, target[client], diff);
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
		if(bMsg)
		{
			GetClientName(old_target[client], name, sizeof(name));
			PrintToChatClr(client, "%t%t", "ChatTag", "RevivingStopped", name, RoundToNearest((FloatSub(time, start[client])/iCD)*100));
		}
		old_target[client] = 0;
	}
	old_buttons[client] = buttons;
	return Plugin_Continue;
}

stock void CreateMark(int client)
{
//	if(hHalo == -1) return;
	iTeam[client] = GetClientTeam(client);

	GetClientAbsOrigin(client, fDeathPos[client]);
	fDeathPos[client][2] -= 40;
	GetClientAbsAngles(client, fDeathAng[client]);

	static int ent;
	if((ent = GetMarkId(client)) != -1) AcceptEntityInput(ent, "Kill");

	if((ent = CreateEntityByName("env_sprite")) == -1) return;

	DispatchKeyValue(ent, "model", iEngine == E_Old ? MARK_MDL2 : MARK_MDL1);
	DispatchKeyValue(ent, "classname", "death_mark");
	DispatchKeyValue(ent, "spawnflags", "1");
	DispatchKeyValueFloat(ent, "scale", MARK_SIZE);
	DispatchKeyValue(ent, "rendermode", "5");
	DispatchSpawn(ent);

	iMarkRef[client] = EntIndexToEntRef(ent);
	SetMarkColor(client);
	TeleportEntity(ent, fDeathPos[client], NULL_VECTOR, NULL_VECTOR);
}

stock void SetMarkColor(const int client)
{
	static int clr;
	clr = bEnemy ? iColorAny : iTeam[client] == 2 ? iColorT : iColorCT;

	SetVariantInt(((clr & 0xFF0000) >> 16));
	AcceptEntityInput(iMarkRef[client], "ColorRedValue");
	SetVariantInt(((clr & 0xFF00) >> 8));
	AcceptEntityInput(iMarkRef[client], "ColorGreenValue");
	SetVariantInt((clr & 0xFF));
	AcceptEntityInput(iMarkRef[client], "ColorBlueValue");
}

stock void ResetRespawnData(int client)
{
	SendProgressBar(client);
	fProgress[client] = NULL_PERCENT;
	iTimesRevived[client] = iDeathTeam[client] = iTarget[client] = iReviver[client] = 0;
	RemoveMark(client);
}

static void RemoveMark(int client)
{
	static int ent;
	if((ent = GetMarkId(client)) != -1) AcceptEntityInput(ent, "Kill");
	iMarkRef[client] = -1;
}

stock void ResetPercents(int client)
{
	static int i;
	for(i = 1; i <= MaxClients; i++) fProgress[i][client] = 0.0;
}

stock int GetNearestTarget(int client)
{
	if(!IsPlayerAlive(client)) return 0;

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

stock Action InitRespawn(int client, int target, int hp)
{
	if(!IsPlayerAlive(client) || !IsClientValid(target, true))	// не факт что необходима
		return Plugin_Handled;

	RemoveMark(client);
	ResetPercents(client);
	SendProgressBar(client, target);
	iTarget[client] = iReviver[target] = 0;

	static int buffer;
	if(bEnemy && (buffer = GetClientTeam(client)) != iDeathTeam[target]) CS_SwitchTeam(target, buffer);
	CS_RespawnPlayer(target);
	if(!bPos) GetClientAbsOrigin(client, fDeathPos[target]);
	TeleportEntity(target, fDeathPos[target], fDeathAng[target], NULL_VECTOR);
	SetEntityHealth(target, iHP);

	static char name[MAX_NAME_LENGTH];
	if((buffer = GetEntProp(target, Prop_Data, "m_iDeaths")) > 0) SetEntProp(target, Prop_Data, "m_iDeaths", buffer-1);
	if(iFrag) SetEntProp(client, Prop_Data, "m_iFrags", GetEntProp(client, Prop_Data, "m_iFrags")+iFrag);
	if(bMsg)
	{
		GetClientName(target, name, sizeof(name));
		PrintToChatClr(client, "%t%t", "ChatTag", iFrag ? "TargetRevivedFrag" : "TargetRevived", name);
		GetClientName(client, name, sizeof(name));
		PrintToChatClr(target, "%t%t", "ChatTag", "YouRevived", target, name);
	}
	if(sSoundPath[0]) EmitAmbientSound(sSoundPath, fDeathPos[target]);

	if(iHPCost)
	{
		if(hp > 0) SetEntityHealth(client, hp);
		else ForcePlayerSuicide(client);
	}

	if(iNoBlockTime && iOffsetGroup != -1)
	{
		SetEntData(client, iOffsetGroup, 17, 4, true);
		CreateTimer(iNoBlockTime+0.0, Timer_EnableCollision, GetClientUserId(target), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	if(fNoDmgTime > 0.01)
	{
		SetEntProp(target, Prop_Data, "m_takedamage", 0, 1);
		SetClientColor(target, RENDERFX_HOLOGRAM, RENDER_TRANSCOLOR, 63, 255, 63 , 63);
		CreateTimer(fNoDmgTime, Timer_EnableDmg, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
	}

	if(!iTimes) return Plugin_Handled;

	iTimesRevived[client]++;
	if(!bMsg) return Plugin_Handled;

	if(iTimesRevived[client] >= iTimes) PrintToChatClr(client, "%t%t", "ChatTag", "RevivalsNotAvailable");
	else PrintToChatClr(client, "%t%t", "ChatTag", "RevivalsAvailable", iTimes - iTimesRevived[client]);

	return Plugin_Handled;
}

public Action Timer_EnableDmg(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		SetClientColor(client);
	}
}

stock void SetClientColor(int client, RenderFx fx = RENDERFX_NONE, RenderMode mode = RENDER_NORMAL, int r = 255, int g = 255, int b = 255, int a = 255)
{
	SetEntityRenderFx(client, fx);
	SetEntityRenderMode(client, mode);
	SetEntityRenderColor(client, r, g, b, a);
}

public Action Timer_EnableCollision(Handle timer, any client)
{
	if((client = GetClientOfUserId(client))) SetEntData(client, iOffsetGroup, 5, 4, true);
}

stock void SendProgressBar(const int client, const int target = 0, const float time = 0.0)
{
	if(iEngine == E_CSGO || !bBar || !IsClientValid(client)) return;

	static int iOffsetStart = -1, iOffsetDuration = -1;
	if(iOffsetStart == -1 && (iOffsetStart = FindSendPropInfo("CCSPlayer", "m_flProgressBarStartTime")) == -1)
		return;
	if(iOffsetDuration == -1 && (iOffsetDuration = FindSendPropInfo("CCSPlayer", "m_iProgressBarDuration")) == -1)
		return;

	static int duration;
	duration = time ? iCD : 0;

	SetEntDataFloat(client, iOffsetStart, time, true);
	SetEntData(client, iOffsetDuration, duration, true);

	if(!IsClientValid(target)) return;
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
			if(IsClientValid(i) && (bEnemy || team == GetClientTeam(i))) clients[num++] = i;
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
	static int clr;
	clr = bEnemy ? iColorAny : team == 2 ? iColorT : iColorCT;
	TE_WriteNum("r", ((clr & 0xFF0000) >> 16));
	TE_WriteNum("g", ((clr & 0xFF00) >> 8));
	TE_WriteNum("b", (clr & 0xFF));
	TE_WriteNum("a", 191);
	TE_WriteNum("m_nSpeed", 1);
	TE_WriteNum("m_nFlags", 0);
	TE_WriteNum("m_nFadeLength", 0);
}

stock void PrintToChatAllClr(const char[] msg, any ...)
{
	static char buffer[PLATFORM_MAX_PATH];
	for(int i = 1; i <= MaxClients; i++) if(IsClientValid(i))
	{
		VFormat(buffer, sizeof(buffer), msg, 2);
		PrintToChatClr(i, "%s", buffer);
	}
}

stock void PrintToChatClr(int client, const char[] msg, any ...)
{
	if(!IsClientValid(client)) return;

	Handle hBuffer = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	if(!hBuffer) return;

	SetGlobalTransTarget(client);
	static char buffer[PLATFORM_MAX_PATH], new_msg[PLATFORM_MAX_PATH];
	if(iEngine != E_Unknown) FormatEx(buffer, sizeof(buffer), "%s\x01%s", iEngine == E_CSGO ? " " : "", msg);
	VFormat(new_msg, sizeof(new_msg), buffer, 3);

	if(iEngine) for(int i; i < 16; i++) ReplaceString(new_msg, sizeof(new_msg), CLR[i][0], CLR[i][iEngine]);
	else for(int i; i < 16; i++) ReplaceString(new_msg, sizeof(new_msg), CLR[i][0], "");

	if(bProto)
	{
		PbSetInt(hBuffer, "ent_idx", 0);
		PbSetBool(hBuffer, "chat", true);
		PbSetString(hBuffer, "msg_name", new_msg);
		PbAddString(hBuffer, "params", "");
		PbAddString(hBuffer, "params", "");
		PbAddString(hBuffer, "params", "");
		PbAddString(hBuffer, "params", "");
	}
	else
	{
		BfWriteByte(hBuffer, 0);
		BfWriteByte(hBuffer, true);
		BfWriteString(hBuffer, new_msg);
	}
	EndMessage();
}

stock bool IsClientValid(int client, bool allow_bots = false)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && (allow_bots || !IsFakeClient(client));
}

stock bool IsMarkExist(int client)
{
	return iMarkRef[client] != -1 && GetMarkId(client) != -1;
}

stock int GetMarkId(int client)
{
	return EntRefToEntIndex(iMarkRef[client]);
}
