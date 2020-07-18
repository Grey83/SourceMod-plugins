#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>

enum
{
	Slot_Primary = 0,
	Slot_Secondary,
	Slot_Knife,
	Slot_Grenade,
	Slot_C4,
	Slot_None
};

Handle
	hCookies;
bool
	bLate,
	bGive[MAXPLAYERS+1] = {true, ...};
int
	iWpnChoice[3][MAXPLAYERS+1],
	iMenuSize[3];
Menu
	hPrimaryMenu,
	hSecondaryMenu,
	hGrenadesMenu;

static const char
	PL_NAME[]	= "[CSS] Gun Menu",
	PL_VER[]	= "1.1.0",

	sPrimaryWeapons[][][] =
{
	{"",					"Random\n  Sniper rifles:"},
	{"weapon_awp",			"Arctic Warfare Magnum"},
	{"weapon_sg550",		"SIG SG 550"},
	{"weapon_g3sg1",		"H&K G3/SG1"},
	{"weapon_scout",		"Steyr Scout\n  Assault rifles:"},
	{"weapon_ak47",			"AK"},
	{"weapon_m4a1",			"Colt M4A1"},
	{"weapon_sg552",		"SIG SG 552"},
	{"weapon_aug",			"Steyr AUG"},
	{"weapon_galil",		"IMI Galil AR"},
	{"weapon_famas",		"FAMAS\n  Submachine guns:"},
	{"weapon_mac10",		"Ingram MAC-10"},
	{"weapon_mp5navy",		"H&K MP5 Navy"},
	{"weapon_tmp",			"Steyr TMP"},
	{"weapon_ump45",		"H&K UMP 45"},
	{"weapon_p90",			"FN P90\n  Shotguns:"},
	{"weapon_m3",			"Benelli M3 Super 90"},
	{"weapon_xm1014",		"Benelli М4 Super 90\n  Machinegun:"},
	{"weapon_m249",			"M249"}
},
	sSecondaryWeapons[][][] =
{
	{"",					"Random\n "},
	{"weapon_glock",		"Glock-18"},
	{"weapon_usp",			"H&K USP"},
	{"weapon_p228",			"SIG Sauer P228"},
	{"weapon_deagle",		"IMI Desert Eagle"},
	{"weapon_fiveseven",	"FN Five-SeveN USG"},
	{"weapon_elite",		"Dual Beretta 92"}
},
	sGrenades[][][] =
{
	{"",					"Random\n "},
	{"weapon_hegrenade",	"M26 HE grenade "},
	{"weapon_flashbang",	"M84 Stun grenade"},
	{"weapon_smokegrenade",	"M18 Smoke grenade"}
};

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Gun Menu for gamemodes such as Retake, Deathmatch etc.",
	author		= "Grey83",
	url			= "https://forums.alliedmods.net/showthread.php?t=294225"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	iMenuSize[0] = sizeof(sPrimaryWeapons) - 1;
	iMenuSize[1] = sizeof(sSecondaryWeapons) - 1;
	iMenuSize[2] = sizeof(sGrenades) - 1;

	hPrimaryMenu = new Menu(Handler_PrimaryMenu);
	hPrimaryMenu.SetTitle("Primary weapon (%i):", iMenuSize[0]);
	for(int i; i <= iMenuSize[0]; i++)	hPrimaryMenu.AddItem(sPrimaryWeapons[i][0], sPrimaryWeapons[i][1]);

	hSecondaryMenu = new Menu(Handler_SecondaryMenu);
	hSecondaryMenu.SetTitle("Secondary weapon (%i):", iMenuSize[1]);
	for(int i; i <= iMenuSize[1]; i++)	hSecondaryMenu.AddItem(sSecondaryWeapons[i][0], sSecondaryWeapons[i][1]);

	hGrenadesMenu = new Menu(Handler_GrenadesMenu);
	hGrenadesMenu.SetTitle("Grenades (%i):", iMenuSize[2]);
	for(int i; i <= iMenuSize[2]; i++)	hGrenadesMenu.AddItem(sGrenades[i][0], sGrenades[i][1]);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn",Event_Spawn);

	ToggleBuyZones();

	AddCommandListener(Cmd_Buy, "autobuy");
	AddCommandListener(Cmd_Buy, "rebuy");
	AddCommandListener(Cmd_Buy, "buy");

//	AddCommandListener(Cmd_BuyGrenades, "buyequip");

	hCookies = RegClientCookie(PL_NAME, "Selected weapon", CookieAccess_Private);
	if(!bLate) return;

	bLate = false;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i))
	{
		if(IsFakeClient(i)) iWpnChoice[0][i] = iWpnChoice[1][i] = iWpnChoice[2][i] = -1;
		else if(AreClientCookiesCached(i)) OnClientCookiesCached(i);
	}
}

public void OnPluginEnd()
{
	ToggleBuyZones(true);
}

public Action Cmd_Buy(int client, const char[] cmd, int argc)
{
	if(client && IsClientInGame(client) && GetClientTeam(client)) hPrimaryMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
/*
public Action Cmd_BuyGrenades(int client, const char[] cmd, int argc)
{
	if(client && IsClientInGame(client)) hGrenadesMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
*/
public Action Menu_PrimaryWeapon(int client, int args)
{
	if(client) hPrimaryMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Handler_PrimaryMenu(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		iWpnChoice[0][client] = param ? param : -1;
		SaveChoiceToCookies(client);
		hSecondaryMenu.Display(client, MENU_TIME_FOREVER);
	}
	return 0;
}

public int Handler_SecondaryMenu(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		iWpnChoice[1][client] = param ? param : -1;
		SaveChoiceToCookies(client);
		hGrenadesMenu.Display(client, MENU_TIME_FOREVER);
	}
	return 0;
}

public int Handler_GrenadesMenu(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		iWpnChoice[2][client] = param ? param : -1;
		SaveChoiceToCookies(client);
		if(bGive[client]) RequestFrame_Callback(GetClientUserId(client));
	}
	return 0;
}

stock void SaveChoiceToCookies(int client)
{
	int value;
	if(iWpnChoice[0][client] != -1) value  = iWpnChoice[0][client] << 16;
	else value  = 1 << 24;
	if(iWpnChoice[1][client] != -1) value |= iWpnChoice[1][client] << 8;
	else value |= 2 << 24;
	if(iWpnChoice[2][client] != -1) value |= iWpnChoice[2][client];
	else value |= 4 << 24;

	static char buffer[12];
	FormatEx(buffer, sizeof(buffer), "0x%08x", value);
	PrintToServer("\n%N's choice: %s\n", client, buffer);
	SetClientCookie(client, hCookies, buffer);
}
/*
	Grey83's choice: 0x00010000
	Grey83's choice: 0x00010400
	Grey83's choice: 0x00010402

	Grey83's settings: 0x00010402
*/

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client)) return;

	char buffer[12];
	GetClientCookie(client, hCookies, buffer, sizeof(buffer));
	PrintToServer("\n%N's settings: %s\n", client, buffer);
	if(buffer[0] != '0' || buffer[1] != 'x' || strlen(buffer) < 8 || strlen(buffer) > 10) return;

	int value = StringToInt(buffer, 0x10), rnd = (value & 0xFF000000) >>> 24;
	iWpnChoice[0][client] = rnd & 1 ? -1 : (value & 0xFF0000) >> 16;
	iWpnChoice[1][client] = rnd & 2 ? -1 : (value & 0xFF00) >> 8;
	iWpnChoice[2][client] = rnd & 4 ? -1 :  value & 0xFF;
}

public void OnClientDisconnect(int client)
{
	iWpnChoice[0][client] = iWpnChoice[1][client] = iWpnChoice[2][client] = 0;
	bGive[client] = true;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ToggleBuyZones();
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if(!(client = GetClientOfUserId(event.GetInt("userid"))) || GetClientTeam(client) < 2) return;

	if(!iWpnChoice[0][client])
		hPrimaryMenu.Display(client, MENU_TIME_FOREVER);
	else if(!iWpnChoice[1][client])
		hSecondaryMenu.Display(client, MENU_TIME_FOREVER);
	else if(!iWpnChoice[2][client])
		hGrenadesMenu.Display(client, MENU_TIME_FOREVER);
	else RequestFrame(RequestFrame_Callback, GetClientUserId(client));
}

public void RequestFrame_Callback(int client)
{
	static int wpn, team, defuser;
	if(!(client = GetClientOfUserId(client)) || (team = GetClientTeam(client) - 2) < 0) return;
	bGive[client] = false;

	StripWeapons(client);

	GivePlayerItem(client, "item_assaultsuit");

	if((wpn = iWpnChoice[0][client]) == -1) wpn = GetRandomInt(1, iMenuSize[0]);
	GivePlayerItem(client, sPrimaryWeapons[wpn][0]);

	static bool bot;
	bot = IsFakeClient(client);
	wpn = iWpnChoice[1][client];
	if(wpn == -1) wpn = GetRandomInt(bot ? 4 : 1, iMenuSize[1]);
	GivePlayerItem(client, sSecondaryWeapons[wpn][0]);

	if((defuser > 0 || (defuser = FindSendPropInfo("CCSPlayer", "m_bHasDefuser")) > 0) && team)
		SetEntData(client, defuser, 1, 1, true);

	wpn = iWpnChoice[2][client];
	if(wpn == -1) wpn = GetRandomInt(1, iMenuSize[2]);
	GivePlayerItem(client, sGrenades[bot ? 1 : wpn][0]);
}

stock void StripWeapons(int client)
{
	RemoveWeaponBySlot(client, Slot_Primary);
	RemoveWeaponBySlot(client, Slot_Secondary);
	while(RemoveWeaponBySlot(client)) {}
}

stock bool RemoveWeaponBySlot(int client, int slot = Slot_Grenade)
{
	int ent = GetPlayerWeaponSlot(client, slot);
	return ent > MaxClients && RemovePlayerItem(client, ent) && AcceptEntityInput(ent, "Kill");
}

stock void ToggleBuyZones(bool enable = false)
{
	char state[8];
	state = enable ? "Enable" : "Disable";
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "func_buyzone")) != -1)
		AcceptEntityInput(entity, state);
}
