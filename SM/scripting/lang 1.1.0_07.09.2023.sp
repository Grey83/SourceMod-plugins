#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>

static const char
	PL_NAME[]	= "Language",
	PL_VER[]	= "1.1.0_07.09.2023";

ArrayList
	hName,
	hCode;
Menu
	hMenu;
Handle
	hCookies;
bool
	bLate;
int
	iLang[MAXPLAYERS+1] = {-1, ...};
char
	sCode[4],
	sBuffer[64];

public Plugin myinfo = 
{
	name		= PL_NAME,
	author		= "Grey83",
	description	= "Set & Save client language",
	version		= PL_VER,
	url			= "https://forums.alliedmods.net/showthread.php?p=2444363"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("sm_lang_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_lang", Cmd_Lang, "Show/set own client language setting\n'sm_lang' - shows current client language\n'sm_lang <code>' - set own client language");

	hCookies = RegClientCookie("client_lang", "Saved client language", CookieAccess_Private);
	SetCookieMenuItem(LangMenu, 0, "Language");

	int num = GetLanguageCount();
	if(num > 0)
		return;

	hCode = new ArrayList(ByteCountToCells(4));
	hName = new ArrayList(ByteCountToCells(64));

	hMenu = CreateMenu(LangMenuHandler, MenuAction_Display|MenuAction_DrawItem|MenuAction_DisplayItem);
	hMenu.SetTitle("Language:");
	for(int i; i < num; i++)
	{
		GetLanguageInfo(i, sCode, sizeof(sCode), sBuffer, sizeof(sBuffer));

		hCode.PushString(sCode);
		hName.PushString(sBuffer);

		hMenu.AddItem("", sBuffer);
	}
	if(num < 10) hMenu.Pagination = 0;
	hMenu.ExitBackButton = true;

	if(!bLate)
		return;

	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && AreClientCookiesCached(i)) OnClientPostAdminCheck(i);
}

public void OnClientPostAdminCheck(int client)
{
	if(iLang[client] == -1) OnClientCookiesCached(client);
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
		return;

	GetClientCookie(client, hCookies, sCode, sizeof(sCode));
	iLang[client] = GetLanguageByCode(sCode);
	if(iLang[client] != -1) SetClientLanguage(client, iLang[client]);
}

public void OnClientDisconnect(int client)
{
	iLang[client] = -1;
}

public Action Cmd_Lang(int client, int args)
{
	if(client)
	{
		if(!args)
		{
			int lang = iLang[client] == -1 ? GetClientLanguage(client) : iLang[client];
			if(lang != -1 && lang < GetLanguageCount())
			{
				hCode.GetString(lang, sCode, sizeof(sCode));
				hName.GetString(lang, sBuffer, sizeof(sBuffer));
				PrintToChat(client, "Your client language is '%s' ('%s', %d)", sBuffer, sCode, lang);
			}
			else PrintToChat(client, "Your client language is unknown!");
		}
		else
		{
			GetCmdArg(1, sCode, sizeof(sCode));
			ChangeLanuage(client, GetLanguageByCode(sCode));
		}
	}
	else ReplyToCommand(client, "[SM] %t", "Command is in-game only");

	return Plugin_Handled;
}

public void LangMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_DisplayOption)
	{
		int lang = GetClientLanguage(client);
		if(lang != -1)
		{
			hName.GetString(lang, sBuffer, sizeof(sBuffer));
			FormatEx(buffer, maxlen, "Language: %s", sBuffer);
		}
		else FormatEx(buffer, maxlen, "Language");
	}
	else if(action == CookieMenuAction_SelectOption)	if(hMenu) hMenu.Display(client, MENU_TIME_FOREVER);
}

public int LangMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Display:
		{
			if(iLang[client] != -1)
			{
				hName.GetString(iLang[client], sBuffer, sizeof(sBuffer));
				menu.SetTitle("Language:\n    %s", sBuffer);
			}
			else menu.SetTitle("Language:");
		}
		case MenuAction_DisplayItem:
		{
			hCode.GetString(item, sCode, sizeof(sCode));
			hName.GetString(item, sBuffer, sizeof(sBuffer));
			Format(sBuffer, sizeof(sBuffer), "%s%s", sBuffer, item == iLang[client] ? " ☑" : "");
			return RedrawMenuItem(sBuffer);
		}
		case MenuAction_DrawItem:	return item == iLang[client] ?  ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
		case MenuAction_Select:
		{
			int pos = GetMenuSelectionPosition();
			ChangeLanuage(client, item);
			hMenu.DisplayAt(client, pos, MENU_TIME_FOREVER);
		}
		case MenuAction_Cancel:		if(item == MenuCancel_ExitBack) ShowCookieMenu(client);
	}

	return 0;
}

void ChangeLanuage(int client, const int lang)
{
	if(lang != -1)
	{
		hCode.GetString(lang, sCode, sizeof(sCode));
		hName.GetString(lang, sBuffer, sizeof(sBuffer));

		iLang[client] = lang;
		SetClientLanguage(client, lang);
		SetClientCookie(client, hCookies, sCode);
		PrintToChat(client, "Your client language changed to '%s' (%s, %d)", sBuffer, sCode, lang);
	}
	else PrintToChat(client, "Wrong lanuage code!");
}