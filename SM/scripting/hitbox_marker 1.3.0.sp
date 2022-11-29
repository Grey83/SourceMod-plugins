#pragma semicolon 1

#include <clientprefs>

enum
{
	HG_None = -1,
	HG_Health,	// урон по хп
	HG_Armor,	// урон по броне
	HG_Head,	// голова
	HG_Chest,	// грудь
	HG_Belly,	// живот
	HG_LArm,	// левая рука
	HG_RArm,	// правая рука
	HG_LLeg,	// левая нога
	HG_RLeg,	// правая нога
	HG_Neck,	// шея
	HG_Hits,	// общее кол-во попаданий

	HitData
};

static const char
	PL_NAME[]	= "[CS:GO] Hitbox marker",
	PL_VER[]	= "1.3.0",

	INFO_TYPE[][] =
{
	"{Health}",
	"{Armor}",
	"{Head}",
	"{Chest}",
	"{Belly}",
	"{LArm}",
	"{RArm}",
	"{LLeg}",
	"{RLeg}",
	"{Neck}",
	"{Hits}"
};

enum
{
	T_HUD,
	T_NoDmg,
	T_Dmg,

	T_Total
};

static const int COLOR[] = {0x00ff00, 0x00ff00, 0xff0000};

Handle
	hHUD,
	hTimer[MAXPLAYERS+1],
	hCookies;
Menu
	hMenu;
bool
	bLate,
	bOnDeath[MAXPLAYERS+1] = {true, ...},
	bHint[MAXPLAYERS+1],
	bCount[MAXPLAYERS+1] = {true, ...},
	bFull[MAXPLAYERS+1] = {true, ...},
	bShow[MAXPLAYERS+1] = {true, ...};
float
	fTime,
	fXpos,
	fYpos;
int
	iColor[T_Total];
	iInfo[MAXPLAYERS+1][MAXPLAYERS+1][HitData];

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= "1.3.0",
	author		= "Palonez, Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		FormatEx(error, err_max, "Plugin for CS:GO only!");
		return APLRes_Failure;
	}

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("hitbox_marker.phrases");

	hHUD = CreateHudSynchronizer();

	CreateConVar("sm_hitbox_marker_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar;
	cvar = CreateConVar("sm_hm_output_mode", "1", "Режим отображения [0 - после попадания | 1 - после смерти]", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChange_OnDeath);
	bOnDeath[0] = cvar.BoolValue;

	cvar = CreateConVar("sm_hm_method", "0", "Метод отображения [0 - HUD | 1 - Hint (сверху)]", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChange_Hint);
	bHint[0] = cvar.BoolValue;

	cvar = CreateConVar("sm_hm_count", "1", "Отображать ли в Hint количество попадений в хитбокс [0 - только красить | 1 - да]", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChange_Count);
	bCount[0] = cvar.BoolValue;

	cvar = CreateConVar("sm_hm_allinfo", "1", "Тип отображения [0 - выводить только попадания | 1 - выводить всю информацию]", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChange_Full);
	bFull[0] = cvar.BoolValue;

	cvar = CreateConVar("sm_hm_holdtime", "3.0", "Время отображения", _, true, 0.2, true, 5.0); // емнип, больше 5 секунд не работает
	cvar.AddChangeHook(CVarChange_Time);
	fTime = cvar.FloatValue;

	cvar = CreateConVar("sm_hm_hud_x", "0.05", "Позиция по X (слева направо, -1.0 - центр)", _, true, -2.0, true, 1.0);
	cvar.AddChangeHook(CVarChange_X);
	fXpos = cvar.FloatValue;

	cvar = CreateConVar("sm_hm_hud_y", "0.5", "Позиция по Y (сверху вниз, -1.0 - центр)", _, true, -2.0, true, 1.0);
	cvar.AddChangeHook(CVarChange_Y);
	fYpos = cvar.FloatValue;

	cvar = CreateConVar("sm_hm_hud_color", "00ff00", "Цвет текста в HUD в HEX виде (RGB или RRGGBB, значения 0 - F или 00 - FF, соответственно). Не валидное значение = зелёный", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_HUDColor);
	SetColor(cvar, T_HUD);

	cvar = CreateConVar("sm_hm_hud_color_nodmg", "00ff00", "Цвет в Hint зоны без попадений в HEX виде (RGB или RRGGBB, значения 0 - F или 00 - FF, соответственно). Не валидное значение = зелёный", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_HintNoDmg);
	SetColor(cvar, T_NoDmg);

	cvar = CreateConVar("sm_hm_hud_color_dmg", "00ff00", "Цвет в Hint зоны с попадениями в HEX виде (RGB или RRGGBB, значения 0 - F или 00 - FF, соответственно). Не валидное значение = красный", FCVAR_PRINTABLEONLY);
	cvar.AddChangeHook(CVarChanged_HintDmg);
	SetColor(cvar, T_Dmg);

	AutoExecConfig(true, "hitbox_marker");

	HookEvent("player_hurt",  Event_Hurt);
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death);
	HookEvent("round_start",  Event_Start, EventHookMode_PostNoCopy);

	hCookies = RegClientCookie("hitbox_marker", "Hitbox marker settings", CookieAccess_Private);
	SetCookieMenuItem(Cookie_Settings, 0, "Hitbox marker");

	RegConsoleCmd("sm_hm", Cmd_Menu, "Show Hitbox marker settings");

	if(!bLate) return;

	for(int i = 1; i <= MaxClients; i++)
	{
		ResetOptions(i);
		if(IsClientInGame(i) && !IsFakeClient(i)) ReadClientSettings(i);
	}
}

public void CVarChange_OnDeath(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bOnDeath[0] = cvar.BoolValue;
}

public void CVarChange_Hint(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bHint[0] = cvar.BoolValue;
}

public void CVarChange_Count(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bCount[0] = cvar.BoolValue;
}

public void CVarChange_Full(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bFull[0] = cvar.BoolValue;
}

public void CVarChange_Time(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fTime = cvar.FloatValue;
}

public void CVarChange_X(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fXpos = cvar.FloatValue;
}

public void CVarChange_Y(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fYpos = cvar.FloatValue;
}

public void CVarChanged_HUDColor(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetColor(cvar, T_HUD);
}

public void CVarChanged_HintNoDmg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetColor(cvar, T_NoDmg);
}

public void CVarChanged_HintDmg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetColor(cvar, T_Dmg);
}

stock void SetColor(ConVar cvar, int type)
{
	char clr[8];
	cvar.GetString(clr, sizeof(clr));
	clr[7] = 0;	// чтобы проверялось максимум 7 первых символов

	int i;
	while(clr[i])
	{
		if(!(clr[i] >= '0' && clr[i] <= '9') && !(clr[i] >= 'A' && clr[i] <= 'F') && !(clr[i] >= 'a' && clr[i] <= 'f'))
		{	// не HEX-число
			iColor[type] = COLOR[type];
			LogError("HEX color '%s' isn't valid!\nHUD color is 0x%x (%d %d %d)!\n", clr, iColor[type], (iColor[type] & 0xFF0000) >> 16, (iColor[type] & 0xFF00) >> 8, iColor[type] & 0xFF);
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

	if(i != 6) iColor[type] = COLOR[type];	// невалидный цвет
	else StringToIntEx(clr, iColor[type] , 16);
}

public void Cookie_Settings(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_DisplayOption)
		FormatEx(buffer, maxlen, "%T", "Menu_Title", client);
	else if(action == CookieMenuAction_SelectOption)
		SendMenu(client);
}

public Action Cmd_Menu(int client, int args)
{
	if(IsPlayerValid(client)) SendMenu(client);
	return Plugin_Handled;
}

stock void SendMenu(int client)
{
	if(!IsPlayerValid(client))
		return;

	if(!hMenu)
	{
		hMenu = new Menu(Menu_Settings, MENU_ACTIONS_ALL);
		hMenu.SetTitle("Hitbox marker\n \n    Show:");
		hMenu.AddItem("", "Full");
		hMenu.AddItem("", "Hits");
		hMenu.AddItem("", "Disable\n \n    Show info in the:");
		hMenu.AddItem("", "HUD");
		hMenu.AddItem("", "Hint (hits)");
		hMenu.AddItem("", "Hint (no hits)\n \n    Show after");
		hMenu.AddItem("", "Death");
		hMenu.AddItem("", "Hit\n ");
		hMenu.ExitBackButton = true;
	}
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Settings(Menu menu, MenuAction action, int client, int param)
{
	static char txt[128];
	SetGlobalTransTarget(client);
	switch(action)
	{
		case MenuAction_Display:
			menu.SetTitle("%t\n \n    %t:", "Menu_Title", "Menu_Show");
		case MenuAction_DisplayItem:
		{
			switch(param)
			{
				case 0: FormatEx(txt, sizeof(txt), "%t%s", "Menu_InfoFull", IsActiveOption(client, param) ? " ☑" : "");
				case 1: FormatEx(txt, sizeof(txt), "%t%s", "Menu_InfoHits", IsActiveOption(client, param) ? " ☑" : "");
				case 2: FormatEx(txt, sizeof(txt), "%t%s\n \n    %t:", "Menu_Disable", IsActiveOption(client, param) ? " ☑" : "", "Menu_Place");
				case 3: FormatEx(txt, sizeof(txt), "%t%s", "Menu_HUD", IsActiveOption(client, param) ? " ☑" : "");
				case 4: FormatEx(txt, sizeof(txt), "%t%s", "Menu_HintHits", IsActiveOption(client, param) ? " ☑" : "");
				case 5: FormatEx(txt, sizeof(txt), "%t%s\n \n    %t:", "Menu_HintNoHits", IsActiveOption(client, param) ? " ☑" : "", "Menu_After");
				case 6: FormatEx(txt, sizeof(txt), "%t%s ", "Menu_Death", IsActiveOption(client, param) ? " ☑" : "");
				case 7: FormatEx(txt, sizeof(txt), "%t%s\n ", "Menu_Hit", IsActiveOption(client, param) ? " ☑" : "");
			}
			return RedrawMenuItem(txt);
		}
		case MenuAction_DrawItem:
			return IsActiveOption(client, param) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
		case MenuAction_Select:
		{
			switch(param)
			{
				case 0:
					bShow[client] = bFull[client] = true;
				case 1:
				{
					bShow[client] = true;
					bFull[client] = false;
				}
				case 2:
					bShow[client] = false;
				case 3:
					bHint[client] = false;
				case 4:
				{
					bHint[client] = true;
					bCount[client] = true;
				}
				case 5:
				{
					bHint[client] = true;
					bCount[client] = false;
				}
				case 6:
					bOnDeath[client] = true;
				case 7:
					bOnDeath[client] = false;
			}

			FormatEx(txt, sizeof(txt), "0x%02x", (view_as<int>(bShow[client]) | (view_as<int>(bFull[client])<<1) | (view_as<int>(bHint[client])<<2) | (view_as<int>(bCount[client])<<3) | (view_as<int>(bOnDeath[client])<<4)));
			SetClientCookie(client, hCookies, txt);

			SendMenu(client);
		}
		case MenuAction_Cancel: if(param == MenuCancel_ExitBack) ShowCookieMenu(client);
	}
	return 0;
}

stock bool IsActiveOption(int client, int option)
{
	bool active;
	switch(option)
	{
		case 0: active = bShow[client] && bFull[client];
		case 1: active = bShow[client] && !bFull[client];
		case 2: active = !bShow[client];
		case 3: active = !bHint[client];
		case 4: active = bHint[client] && bCount[client];
		case 5: active = bHint[client] && !bCount[client];
		case 6: active = bOnDeath[client];
		case 7: active = !bOnDeath[client];
	}
	return active;
}

public void OnClientCookiesCached(int client)
{
	if(client && !IsFakeClient(client)) ReadClientSettings(client);
}

stock void ReadClientSettings(int client)
{
	char buffer[8];
	GetClientCookie(client, hCookies, buffer, sizeof(buffer));
	if(buffer[0] != '0' || buffer[1] != 'x' || strlen(buffer) != 4)
	{
		if(buffer[0]) SetClientCookie(client, hCookies, "");
		return;
	}

	int val = StringToInt(buffer, 0x10);
	bShow[client]	= view_as<bool>(val & 0x01);
	bFull[client]	= view_as<bool>(val & 0x02);
	bHint[client]	= view_as<bool>(val & 0x04);
	bCount[client]	= view_as<bool>(val & 0x08);
	bOnDeath[client]= view_as<bool>(val & 0x10);
}

public void OnClientDisconnect(int client)
{
	ResetStats(client);
	ResetOptions(client);
}

stock void ResetOptions(int client)
{
	bShow[client]	= true;
	bFull[client]	= bFull[0];
	bHint[client]	= bHint[0];
	bCount[client]	= bCount[0];
	bOnDeath[client]= bOnDeath[0];
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	ResetStats(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsClienValid(attacker))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	iInfo[attacker][client][HG_Health] += event.GetInt("dmg_health");
	iInfo[attacker][client][HG_Armor] += event.GetInt("dmg_armor");
	int hb = event.GetInt("hitgroup") + 1;
	if(HG_Armor < hb && hb < HitData)
	{
		iInfo[attacker][client][hb]++;
		iInfo[attacker][client][HG_Hits]++;
	}

	if(!bOnDeath[attacker]) ShowHits(attacker, client);
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsClienValid(client) && !bOnDeath[client]) ShowHits(client, GetClientOfUserId(event.GetInt("attacker")));
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++) DeleteTimer(i);
}

stock void ShowHits(int client, int attacker)
{
	if(!bShow[client] || IsFakeClient(client) || !IsClienValid(attacker))
		return;

	if(bHint[client])
	{
		Event event = CreateEvent("cs_win_panel_round");
		event.SetString("funfact_token", FormatHintInfo(client, attacker));
		event.FireToClient(client);
		event.Cancel();

		DeleteTimer(client);
		hTimer[client] = CreateTimer(fTime, Timer_CloseHint, client);
	}
	else
	{
		SetHudTextParams(fXpos, fYpos, fTime, 0 , ((iColor[T_HUD] & 0xFF0000) >> 16), ((iColor[T_HUD] & 0xFF00) >> 8), (iColor[T_HUD] & 0xFF), 2, 0.0 , 0.0, 0.0);
		ShowSyncHudText(client, hHUD, FormatHUDInfo(client, attacker));
	}
}

stock char[] FormatHintInfo(int client, int attacker)
{
	static char num[40], buffer[512];
	if(bCount[client])
	{
		FormatEx(buffer, sizeof(buffer), "%T", bFull[client] ? "Hint_FullInfo" : "Hint_HitsInfo", client);
		for(int i; i < HitData; i++)
		{
			if(i > HG_Armor && i < HG_Hits)
				FormatEx(num, sizeof(num), "<font color=\"#%06x\">%i</font>", iInfo[client][attacker][i] > 0 ? iColor[T_Dmg] : iColor[T_NoDmg], iInfo[client][attacker][i]);
			else FormatEx(num, sizeof(num), "%i", iInfo[client][attacker][i]);
			ReplaceString(buffer, sizeof(buffer), INFO_TYPE[i], num);
		}
	}
	else
	{
		FormatEx(buffer, sizeof(buffer), "%T", bFull[client] ? "NoCount_FullInfo" : "NoCount_HitsInfo", client);
		for(int i; i < HitData; i++)
		{
			if(i > HG_Armor && i < HG_Hits)
				FormatEx(num, sizeof(num), "<font color=\"#%06x\">", iInfo[client][attacker][i] > 0 ? iColor[T_Dmg] : iColor[T_NoDmg]);
			else FormatEx(num, sizeof(num), "%i", iInfo[client][attacker][i]);
			ReplaceString(buffer, sizeof(buffer), INFO_TYPE[i], num);
		}
		ReplaceString(buffer, sizeof(buffer), "{/Clr}", "</font>");
	}
	ReplaceString(buffer, sizeof(buffer), "{NL}", "<br>");

	return buffer;
}

public Action Timer_CloseHint(Handle timer, int client)
{
	Event event = CreateEvent("round_start");
	event.FireToClient(client);
	event.Cancel();

	hTimer[client] = null;
	return Plugin_Stop;
}

stock char[] FormatHUDInfo(int client, int attacker)
{
	static char num[12], buffer[512];
	FormatEx(buffer, sizeof(buffer), "%T", bFull[client] ? "HUD_FullInfo" : "HUD_HitsInfo", client);
	ReplaceString(buffer, sizeof(buffer), "{NL}", "\n");
	for(int i; i < HitData; i++)
	{
		FormatEx(num, sizeof(num), "%i", iInfo[client][attacker][i]);
		ReplaceString(buffer, sizeof(buffer), INFO_TYPE[i], num);
	}
	return buffer;
}

stock bool IsClienValid(int client)
{
	return client && IsClientInGame(client);
}

stock bool IsPlayerValid(int client)
{
	return client && IsClientInGame(client) && !IsFakeClient(client);
}

stock void ResetStats(int client)
{
	DeleteTimer(client);

	for(int i, k; i < HitData; i++) for(k = 0; k <= MaxClients; k++) iInfo[client][k][i] = 0;
}

stock void DeleteTimer(int client)
{
	if(hTimer[client])
	{
		CloseHandle(hTimer[client]);
		hTimer[client] = null;
	}
}
