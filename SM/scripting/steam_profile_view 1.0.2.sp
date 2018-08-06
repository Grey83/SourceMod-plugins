#pragma semicolon 1
#pragma newdecls required

static const char	PLUGIN_NAME[]		= "Steam Profile View",
					PLUGIN_VERSION[]	= "1.0.2";

bool bEnable,
	bSelf,
	bMotDOff[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	author		= "Grey83",
	description	= "Show Players Steam Profile in MotD Window",
	version		= PLUGIN_VERSION,
	url			= "http://steamcommunity.com/groups/grey83ds"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	CreateConVar("sm_spview_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar CVar;
	(CVar = CreateConVar("sm_spview_enable", "1", "1/0 - Enable/Disable Plugin", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_Enable);
	bEnable = CVar.BoolValue;

	(CVar = CreateConVar("sm_spview_self", "1", "1/0 - Enable/Disable show player his own profile", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_Self);
	bSelf = CVar.BoolValue;

	RegConsoleCmd("sm_profile", Cmd_SPView, "Show Players Steam Profile in MotD Window");

	AutoExecConfig(true, "spview");
}

public void CVarChanged_Enable(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	bEnable = newValue[0] == '1';
}

public void CVarChanged_Self(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	bSelf = newValue[0] == '1';
}

public Action Cmd_SPView(int client, int args)
{
	if(!bEnable || !client)
		return Plugin_Handled;

	QueryClientConVar(client, "cl_disablehtmlmotd", CheckMotD);
	if(bMotDOff[client]) PrintToChat(client, "You need to set 'cl_disablehtmlmotd' to '0' to be able to use this command.");
	else
	{
		int num;
		char name[64], SID[18];
		Menu menu = new Menu(Handler_SPView);
		for(int i = 1; i <= MaxClients; i++)
			if((client != i || bSelf) && IsClientInGame(i) && !IsFakeClient(i)
			&& GetClientAuthId(i, AuthId_SteamID64, SID, sizeof(SID)))
			{
				num++;
				GetClientName(i, name, sizeof(name));
				menu.AddItem(SID, name);
			}
		if(num > 0)
		{
			menu.SetTitle("Show Steam profile:");
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else ReplyToCommand(client, "[SM] %t", "No matching clients");
	}

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
		char link[53], title[128];
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
	else if(action == MenuAction_End) delete menu;
}