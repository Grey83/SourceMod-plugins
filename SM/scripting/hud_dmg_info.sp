#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>

static const char
	PL_NAME[]	= "Damage Info",
	PL_VER[]	= "1.1.2",

	CHAT_TITLE[]= " \n\x04Top%i \x01by damage:",
	CHAT_ROW[]	= "\x01%2i) \x04%N\x01: \x04%i\x01dmg with \x04%i\x01kills";

static const int MAX_TOP = 10;

enum
{//	1+16 = On+Center+Spec
	enable,	// 0 (1)
	ff,		// 1 (2)
	self,	// 2 (4)
	spec,	// 3 (8)
	bots	// 4 (16)
};

Handle
	hCookies,
	hHUD;
bool
	bShow[MAXPLAYERS+1];
int
	iMode,
	iColor,
	iDmg[MAXPLAYERS+1],
	iKills[MAXPLAYERS+1];
float
	fPosX,
	fPosY,
	fTime;

public Plugin myinfo = 
{
	name	= PL_NAME,
	author	= "Grey83",
	version	= PL_VER,
	url		= "https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	CreateConVar("sm_dmg_info_version", PL_VER, PL_NAME, FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cvar;
	cvar = CreateConVar("sm_dmg_info_mode", "25", "Set Show damage functionality: 1 - enable plugin, 2 - show FF damage, 4 - show self damage, 8 - show info to the spectators, 16 - show bots in TOP", _, true, _, true, 31.0);
	cvar.AddChangeHook(CVarChanged_Mode);
	CVarChanged_Mode(cvar, NULL_STRING, NULL_STRING);

	cvar = CreateConVar("sm_dmg_info_color", "F80", "HUD info color. Set by HEX (RGB, RGBA, RRGGBB or RRGGBBAA, values 0 - F or 00 - FF, resp.). Wrong color code = white", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_Color);
	CVarChanged_Color(cvar, NULL_STRING, NULL_STRING);

	cvar = CreateConVar("sm_dmg_info_x", "-1.0", "HUD info position X (0.0 - 1.0 left to right or -1 for center)", _, true, -2.0, true, 1.0);
	cvar.AddChangeHook(CVarChanged_PosX);
	fPosX = cvar.FloatValue;

	cvar = CreateConVar("sm_dmg_info_y", "0.45", "HUD info position Y (0.0 - 1.0 top to bottom or -1 for center)", _, true, -2.0, true, 1.0);
	cvar.AddChangeHook(CVarChanged_PosY);
	fPosY = cvar.FloatValue;

	cvar = CreateConVar("sm_dmg_info_time", "1.0", "Information display time", _, true, _, true, 5.0);
	cvar.AddChangeHook(CVarChanged_Time);
	fTime = cvar.FloatValue;

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	hHUD = CreateHudSynchronizer();

	RegConsoleCmd("sm_top", Cmd_ShowDamage, "Shows top damagers");

	AutoExecConfig(true, "dmg_info");

	hCookies = RegClientCookie(PL_NAME, "Show damage caused", CookieAccess_Private);
	SetCookieMenuItem(Cookie_DamageInfo, 0, PL_NAME);
}

public void CVarChanged_Mode(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iMode = cvar.IntValue;
}

public void CVarChanged_Color(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	char clr[16];
	CVar.GetString(clr, sizeof(clr));
	clr[9] = 0;	// чтобы проверялось максимум 9 первых символов

	int i;
	while(clr[i])
	{
		if(!(clr[i] >= '0' && clr[i] <= '9') && !(clr[i] >= 'A' && clr[i] <= 'F') && !(clr[i] >= 'a' && clr[i] <= 'f'))
		{	// не HEX-число
			iColor = -1;
			LogError("\nHEX color '%s' isn't valid!\nHUD color is 0x%x (%d %d %d %d)!\n", clr, iColor, (iColor & 0xFF000000) >>> 24, (iColor & 0xFF0000) >> 16, (iColor & 0xFF00) >> 8, iColor & 0xFF);
			return;
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

	if(i != 8) iColor = -1;					// невалидный цвет => 0xFFFFFFFF
	else StringToIntEx(clr, iColor, 16);

	PrintToServer("\nHUD color is 0x%x (%d %d %d %d)!\n", iColor, (iColor & 0xFF000000) >>> 24, (iColor & 0xFF0000) >> 16, (iColor & 0xFF00) >> 8, iColor & 0xFF);
}

public void CVarChanged_PosX(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	fPosX = CVar.FloatValue;
}

public void CVarChanged_PosY(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	fPosY = CVar.FloatValue;
}

public void CVarChanged_Time(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	fTime = CVar.FloatValue;
}

public void Cookie_DamageInfo(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_DisplayOption)
		Format(buffer, maxlen, "%s: %s", PL_NAME, bShow[client] ? "☑" : "☐");
	else if(action == CookieMenuAction_SelectOption)
	{
		bShow[client] = !bShow[client];
		SetClientCookie(client, hCookies, bShow[client] ? "1" : "0");
		ShowCookieMenu(client);
	}
}

public void OnClientCookiesCached(int client)
{
	char buffer[4];
	GetClientCookie(client, hCookies, buffer, sizeof(buffer));
	bShow[client] = buffer[0] != '0';
}

public void OnClientPostAdminCheck(int client)
{
	iDmg[client] = iKills[client] = 0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++) iDmg[i] = iKills[i] = 0;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	static int victim, attacker, damage;
	if(!(victim = GetClientOfUserId(event.GetInt("userid")))
	|| !(attacker = GetClientOfUserId(event.GetInt("attacker")))
	|| (damage = event.GetInt("dmg_health")) < 1)
		return;

	if(victim == attacker)
	{
		if(!(iMode & (1 << self)))
			return;
	}
	else if(!(iMode & (1 << ff)) && GetClientTeam(victim) == GetClientTeam(attacker))
		return;

	if(victim != attacker) iDmg[attacker] += damage;

	if(!(iMode & (1 << enable)))
		return;

	SetHudTextParams(fPosX, fPosY, fTime + 0.1, (iColor & 0xFF000000) >>> 24, (iColor & 0xFF0000) >> 16, (iColor & 0xFF00) >> 8, iColor & 0xFF, _, 0.0, _, 0.1);
	if(!IsFakeClient(attacker) && bShow[attacker]) ShowSyncHudText(attacker, hHUD, "- %i HP", damage);

	if(iMode & (1 << spec)) for(int i = 1, mode; i <= MaxClients; i++)
		if(i != attacker && IsClientInGame(i) && IsClientObserver(i) && bShow[i]
		&& GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == attacker
		&& ((mode = GetEntProp(i, Prop_Send, "m_iObserverMode")) == 4 || mode == 5))
			ShowSyncHudText(i, hHUD, "- %i HP", damage);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int victim, attacker;
	if(!(victim = GetClientOfUserId(event.GetInt("userid")))
	|| !(attacker = GetClientOfUserId(event.GetInt("attacker"))))
		return;

	iKills[attacker]++;
	if(IsFakeClient(victim)) return;

	static char weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	PrintToChat(victim, "\x01\x04%N \x01killed You with \x04%s", attacker, weapon);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(iMode & (1 << enable)) ShowDamage();
}

public Action Cmd_ShowDamage(int client, int args)
{
	if(!(iMode & (1 << enable)))
		return Plugin_Handled;

	int num;
	if(args)
	{
		char buffer[4];
		GetCmdArg(1, buffer, sizeof(buffer));
		num = StringToInt(buffer);
	}
	ShowDamage(client, num);

	return Plugin_Handled;
}

stock void ShowDamage(int client = 0, int places = 0)
{
	if(places < 1 || places > MAX_TOP) places = MAX_TOP;
	static int i, j, num, max, lst, place, dmg, clients[MAXPLAYERS+1], list[MAXPLAYERS+1][2];
	max = lst = place = 0;

	for(i = 1, num = 0; i <= MaxClients; i++) if(IsClientInGame(i) && (iMode & (1 << bots) || !IsFakeClient(i)) && iDmg[i])
	{
		clients[num++] = i;
		if(max < iDmg[i])
		{
			lst	= i;
			max = iDmg[i];
		}
	}
	if(!num)
	{
		if(client) PrintToChat(client, "\x01No players in \x04TOP%i \x01yet", places);
		return;
	}

	// заполняем массив
	for(i = 0; i < num && place < places;)
	{
		// переходим к следующему месту
		place++;
		// находим первого игрока на месте place по дамагу
		if(place > 1) for(j = 0, dmg = 0; j < num; j++) if(iDmg[clients[j]] < max && iDmg[clients[j]] > dmg)
		{
			lst	= clients[j];
			dmg	= iDmg[clients[j]];
		}
		list[i][0] = place;	// место
		list[i][1] = lst;	// id
		max = iDmg[lst];	// запоминаем максимальный урон на этом месте
		i++;

		// находим всех игроков на этом же месте
		for(j = 0; j < num && i < num; j++) if(clients[j] != lst && iDmg[clients[j]] == max)
		{
			list[i][0] = place;
			list[i][1] = clients[j];
			i++;
		}
	}

	num = i;
	if(!client)
	{
		PrintToChatAll(CHAT_TITLE, places);
		for(i = 0; i < num; i++) PrintToChatAll(CHAT_ROW, list[i][0], list[i][1], iDmg[list[i][1]], iKills[list[i][1]]);
		PrintToChatAll(" \n");
		return;
	}
	PrintToChat(client, CHAT_TITLE, places);
	for(i = 0; i < num; i++) PrintToChat(client, CHAT_ROW, list[i][0], list[i][1], iDmg[list[i][1]], iKills[list[i][1]]);
	PrintToChat(client, " \n");
}