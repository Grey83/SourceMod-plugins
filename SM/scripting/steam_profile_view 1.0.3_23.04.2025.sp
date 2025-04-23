#pragma semicolon 1
#pragma newdecls required

static const char
	PL_NAME[]	= "Steam Profile View",
	PL_VER[]	= "1.0.3_23.04.2025";

bool
	bEnable,
	bSelf,
	bMotDOff[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Show Players Steam Profile in MotD Window",
	author		= "Grey83",
	url			= "http://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	CreateConVar("sm_spview_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar;
	cvar = CreateConVar("sm_spview_enable", "1", "1/0 - Enable/Disable Plugin", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enable);
	bEnable = cvar.BoolValue;

	cvar = CreateConVar("sm_spview_self", "1", "1/0 - Enable/Disable show player his own profile", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Self);
	bSelf = cvar.BoolValue;

	AutoExecConfig(true, "spview");

	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_profile", Cmd_SPView, "Show Players Steam Profile in MotD Window");
}

public void CVarChanged_Enable(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bEnable = cvar.BoolValue;
}

public void CVarChanged_Self(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bSelf = cvar.BoolValue;
}

public Action Cmd_SPView(int client, int args)
{
	if(!bEnable || !client)
		return Plugin_Handled;

	QueryClientConVar(client, "cl_disablehtmlmotd", CheckMotD);

	if(!bMotDOff[client])
	{
		char name[MAX_NAME_LENGTH], SID[20];
		Menu menu = new Menu(Handler_SPView);
		for(int i; ++i <= MaxClients;)
			if((client != i || bSelf) && IsClientInGame(i) && !IsFakeClient(i)
			&& GetClientAuthId(i, AuthId_SteamID64, SID, sizeof(SID)))
			{
				GetClientName(i, name, sizeof(name));
				menu.AddItem(SID, name);
			}

		if(menu.ItemCount > 0)
		{
			menu.SetTitle("Show Steam profile:");
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			CloseHandle(menu);
			ReplyToCommand(client, "[SM] %t", "No matching clients");
		}
	}
	else PrintToChat(client, "You need to set 'cl_disablehtmlmotd' to '0' to be able to use this command.");

	return Plugin_Handled;
}

public void CheckMotD(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	bMotDOff[client] = result == ConVarQuery_Okay && StringToInt(cvarValue) > 0;
}

public int Handler_SPView(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		char link[56], title[MAX_NAME_LENGTH+16];
		menu.GetItem(param, link, sizeof(link), _, title, sizeof(title));

		KeyValues kv = new KeyValues("data");
		Format(title, sizeof(title), "%s's Steam Profile", title);
		kv.SetString("title", title);
		kv.SetString("type", "2");
		Format(link, sizeof(link), "http://steamcommunity.com/profiles/%s", link);
		kv.SetString("msg", link);
		ShowVGUIPanel(client, "info", kv);
		delete kv;

		menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
	}
	else if(action == MenuAction_End) CloseHandle(menu);

	return 0;
}
