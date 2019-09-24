#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools_functions>
//#include <sdktools_hooks>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>

static const char
	PL_NAME[]	= "[ BuyZone Protector ]",
	PL_VER[]	= "2.2.0";

Handle
	hTimer;

bool
	bLate,
	bCSGO,
	bShowBounds,
	bDontShoot,
	bColor,
	bMsg,
	bInBuyZone[MAXPLAYERS+1];

int
	iColor[4],
	g_BeamSprite;

float
	fBuyTime,
	fZoneBounds[2][5];

public Plugin myinfo = 
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "protects certain time players, which inside of their buy zone",
	author		= "Regent (rewritten by Grey83)"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	EngineVersion ev = GetEngineVersion();
	if(ev == Engine_CSGO) bCSGO = true;
	else if(ev != Engine_CSS) SetFailState("This plugin for CSS and CSGO only!");

	LoadTranslations("buyzone_protector.phrases.txt");

	CreateConVar("sm_bzp_version", PL_VER, PL_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	bool rus;
	char code[4];
	GetLanguageInfo(GetServerLanguage(), code, sizeof(code));
	rus = code[0] == 'r' && code[1] == 'u' && !code[2];

	ConVar cvar;
	cvar = CreateConVar("sm_bzp_drawzone", "1", rus ? "рисовать(1) или нет(0) зону защиты" : "draw(1) or not(0) zone of protection", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_ShowBounds);
	bShowBounds = cvar.BoolValue;

	cvar = CreateConVar("sm_bzp_color_tzone", "F00", rus ? "цвет зоны Т" : "color of lines t zone", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_TZoneColor);
	CVarChanged_TZoneColor(cvar, NULL_STRING, NULL_STRING);

	cvar = CreateConVar("sm_bzp_color_ctzone", "00F", rus ? "цвет зоны КТ" : "color of lines ct zone", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_CTZoneColor);
	CVarChanged_CTZoneColor(cvar, NULL_STRING, NULL_STRING);

	cvar = CreateConVar("sm_bzp_restrictshoot", "1", rus ? "разрешить(0) или нет(1) стрелять из своих зон или нет" : "allow(0) or not(1) shooting from their zone or not", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_DontShoot);
	bDontShoot = cvar.BoolValue;

	cvar = CreateConVar("sm_bzp_changecolor", "1", rus ? "изменять(0) или нет(1) цвет игроков в своих зонах" : "change(0) or not(1) player color in their zone", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Color);
	bColor = cvar.BoolValue;

	cvar = CreateConVar("sm_bzp_color_t", "F007", rus ? "цвет Т в своей зоне, пока защита активна" : "color of T in their zone while protect lasts", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_TColor);

	cvar = CreateConVar("sm_bzp_color_ct", "00F7", rus ? "цвет КТ в своей зоне, пока защита активна" : "color of CT in their zone while protect lasts", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_CTColor);

	cvar = CreateConVar("sm_bzp_notice", "1", rus ? "разрешить(0) или нет(1) плагину сообщать игрокам о входе/покидании зоны" : "allow(0) or not(1) sending messages about entering/leaving zones", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Msg);
	bMsg = cvar.BoolValue;

	if((cvar = FindConVar("mp_buytime")))
	{
		cvar.AddChangeHook(CVarChanged_BuyTime);
		CVarChanged_BuyTime(cvar, NULL_STRING, NULL_STRING);
	}
	else
	{
		cvar = CreateConVar("sm_bzp_prottime", "20", rus ? "как долго в секундах будет длится защита зон покупок" : "how long in seconds will lasts protection of buyzone", _, true);
		cvar.AddChangeHook(CVarChanged_ProtectionTime);
		fBuyTime = cvar.FloatValue;
	}

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "buyzone_protector");

	if(bLate) for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void CVarChanged_ShowBounds(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bShowBounds = cvar.BoolValue;
}

public void CVarChanged_TZoneColor(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iColor[0] = HEX2RGBA(cvar);
}

public void CVarChanged_CTZoneColor(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iColor[1] = HEX2RGBA(cvar);
}

public void CVarChanged_DontShoot(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bDontShoot = cvar.BoolValue;
}

public void CVarChanged_Color(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bColor = cvar.BoolValue;
}

public void CVarChanged_TColor(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iColor[2] = HEX2RGBA(cvar);
}

public void CVarChanged_CTColor(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iColor[3] = HEX2RGBA(cvar);
}

public void CVarChanged_Msg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bMsg = cvar.BoolValue;
}

public void CVarChanged_ProtectionTime(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fBuyTime = cvar.IntValue + 0.0;
}

public void CVarChanged_BuyTime(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(bCSGO) fBuyTime = cvar.IntValue + 0.0;
	else fBuyTime = 60 * cvar.FloatValue;
}

stock int HEX2RGBA(ConVar cvar)
{
	char clr[16];
	cvar.GetString(clr, sizeof(clr));
	clr[9] = 0;	// чтобы проверялось максимум 9 первых символов

	int i;
	while(clr[i])
	{
		if(!(clr[i] >= '0' && clr[i] <= '9') && !(clr[i] >= 'A' && clr[i] <= 'F') && !(clr[i] >= 'a' && clr[i] <= 'f'))
		{	// не HEX-число
			LogError("\nHEX color '%s' isn't valid!\nNew color is 0xffffffff (255 255 255 255)!\n", clr);
			return -1;
		}
		i++;
	}

	clr[8] = 0;
	if(i == 6)								// добавляем прозрачность
	{
		clr[6] = clr[7] = 'F';
		i = 8;
	}
	else if(i == 3 || i == 4)				// короткая форма => полная форма
	{
		if(i == 3) clr[6] = clr[7] = 'F';	// добавляем прозрачность
		else clr[6] = clr[7] = clr[3];
		clr[4] = clr[5] = clr[2];
		clr[2] = clr[3] = clr[1];
		clr[1] = clr[0];
		i = 8;
	}

	if(i != 8)
	{	// невалидный цвет => 0xFFFFFFFF
		LogError("\nHEX color '%s' isn't valid!\nNew color is 0xffffffff (255 255 255 255)!\n", clr);
		return -1;
	}
	StringToIntEx(clr, i, 16);
	return i;
}

public void OnPluginEnd()
{
	if(hTimer) Timer_RemoveProtection(null);
}

public void OnMapStart()
{
	hTimer = null;

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if(gameConfig)
	{
		char beam[PLATFORM_MAX_PATH];
		if(GameConfGetKeyValue(gameConfig, "SpriteBeam", beam, sizeof(beam)) && beam[0])
			g_BeamSprite = PrecacheModel(beam);
	}
	else LogError("Unable to load game config 'funcommands.games'");
	CloseHandle(gameConfig);

	int ent = -1, team;
	float pos[3], min[3], max[3];
	while((ent = FindEntityByClassname(ent, "func_buyzone")) != -1)
	{
		if((team = GetEntProp(ent, Prop_Send, "m_iTeamNum")) < 2) continue;

		team -= 2;
		SDKHook(ent, SDKHook_StartTouch, team ? OnCTZoneTouch_Start : OnTZoneTouch_Start);
		SDKHook(ent, SDKHook_EndTouch,	OnZoneTouch_End);

		if(!g_BeamSprite) continue;

		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		GetEntPropVector(ent, Prop_Send, "m_vecMins", min);
		GetEntPropVector(ent, Prop_Send, "m_vecMaxs", max);

		fZoneBounds[team][0] = pos[0] + min[0];
		fZoneBounds[team][1] = pos[1] + min[1];

		fZoneBounds[team][2] = pos[0] + max[0];
		fZoneBounds[team][3] = pos[1] + max[1];

		fZoneBounds[team][4] = pos[2] + max[2];
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	bInBuyZone[client] = false;
}

public Action OnTakeDamage(int client, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if(hTimer && bInBuyZone[client] && GetClientTeam(client) > 1 && attacker > 0 && attacker <= MaxClients)
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(bShowBounds && g_BeamSprite)
	{
		DrawZoneBounds(0);
		DrawZoneBounds(1);
	}

	if(hTimer) KillTimer(hTimer);
	if(fBuyTime > 0) hTimer = CreateTimer(fBuyTime, Timer_RemoveProtection, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock void DrawZoneBounds(int ct)
{
	int color[4];
	color[0] = (iColor[ct] & 0xFF000000) >>> 24;
	color[1] = (iColor[ct] & 0xFF0000) >> 16;
	color[2] = (iColor[ct] & 0xFF00) >> 8;
	color[3] = iColor[ct] & 0xFF;

	float start[3], end[3];
	start[2] = end[2] = fZoneBounds[ct][4];

	start[0] = fZoneBounds[ct][0], end[0] = fZoneBounds[ct][0];
	start[1] = fZoneBounds[ct][1], end[1] = fZoneBounds[ct][3];
	DrawBeam(start, end, color);

	start[0] = fZoneBounds[ct][0], end[0] = fZoneBounds[ct][2];
	start[1] = fZoneBounds[ct][3], end[1] = fZoneBounds[ct][3];
	DrawBeam(start, end, color);

	start[0] = fZoneBounds[ct][2], end[0] = fZoneBounds[ct][2];
	start[1] = fZoneBounds[ct][3], end[1] = fZoneBounds[ct][1];
	DrawBeam(start, end, color);

	start[0] = fZoneBounds[ct][2], end[0] = fZoneBounds[ct][0];
	start[1] = fZoneBounds[ct][1], end[1] = fZoneBounds[ct][1];
	DrawBeam(start, end, color);
}

stock void DrawBeam(const float start[3], const float end[3], const int color[4])
{
	TE_SetupBeamPoints(start, end, g_BeamSprite, 0, 0, 0, fBuyTime, 20.0, 20.0, 0, 0.0, color, 0);
	TE_SendToAll();
}

public Action Timer_RemoveProtection(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) StopProtect(i);

	hTimer = null;
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int& buttons)
{
	if(bDontShoot && buttons & IN_ATTACK && hTimer && bInBuyZone[client])
	{
		buttons &= ~IN_ATTACK;
		PrintCenterText(client, "%t", "shoot blocked");
	}
}

public Action OnTZoneTouch_Start(int ent, int client)
{
	if(hTimer && 0 < client <= MaxClients) StartProtect(client, 2);
}

public Action OnCTZoneTouch_Start(int ent, int client)
{
	if(hTimer && 0 < client <= MaxClients) StartProtect(client, 3);
}

stock void StartProtect(int client, int team)
{
	if(GetClientTeam(client) != team) return;

	bInBuyZone[client] = true;
	if(bMsg) PrintToChat(client, "%t", "entered");
	if(bColor)
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, (iColor[team] & 0xFF000000) >>> 24, (iColor[team] & 0xFF0000) >> 16, (iColor[team] & 0xFF00) >> 8, iColor[team] & 0xFF);
	}
}

public Action OnZoneTouch_End(int ent, int client)
{
	if(hTimer && 0 < client <= MaxClients) StopProtect(client, true);
}

stock void StopProtect(int client, bool leave = false)
{
	if(!bInBuyZone[client] || !IsPlayerAlive(client)) return;

	bInBuyZone[client] = false;
	if(bMsg) PrintToChat(client, "%t", leave ? "leaved" : "ended");
	if(bColor)
	{
		SetEntityRenderColor(client);
		SetEntityRenderMode(client, RENDER_NORMAL);
	}
}