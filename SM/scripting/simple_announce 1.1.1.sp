#pragma semicolon 1
#pragma newdecls required

static const char
	CLR[][][]	=
{//		name		CSGO		CSS			CSSv34
	{"{DEFAULT}",	"\x01",	"\x01",			"\x01"},
	{"{TEAM}",		"\x03",	"\x03",			"\x03"},
	{"{GREEN}",		"\x04",	"\x0700AD00",	"\x04"},
	{"{WHITE}",		"\x01",	"\x07FFFFFF",	"\x01"},
	{"{RED}",		"\x02",	"\x07FF0000",	""},
	{"{LIME}",		"\x05",	"\x0700FF00",	"\x04"},
	{"{LIGHTGREEN}","\x06",	"\x0799FF99",	"\x04"},
	{"{LIGHTRED}",	"\x07",	"\x07FF4040",	""},
	{"{GRAY}",		"\x08",	"\x07CCCCCC",	""},
	{"{LIGHTOLIVE}","\x09",	"\x07FFBD6B",	""},
	{"{OLIVE}",		"\x10",	"\x07FA8B00",	""},
	{"{BLUEGREY}",	"\x0A",	"\x076699CC",	""},
	{"{LIGHTBLUE}",	"\x0B",	"\x0799CCFF",	""},
	{"{BLUE}",		"\x0C",	"\x073D46FF",	""},
	{"{PURPLE}",	"\x0E",	"\x07FA00FA",	""},
	{"{LIGHTRED2}",	"\x0F",	"\x07FF8080",	""}
},
	TYPE[][]	=
{
	"Бот",
	"Replay",
	"SourceTV",
	"Игрок",
	"Админ"
};

enum
{
	E_Unknown,
	E_CSGO,
	E_CSS,
	E_Old
};

enum
{
	T_Bot,
	T_Replay,
	T_STV,
	T_Player,
	T_Admin
};

bool bProto;
int iEngine,
	iMode,
	iType[MAXPLAYERS+1];

public Plugin myinfo =
{
	name	= "Simple announce",
	author	= "Grey83",
	version	= "1.0.0",
	url		= "https://steamcommunity.com/groups/grey83ds"
}

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

	ConVar cvar;
	(cvar = CreateConVar("sm_announce_admin", "3", "Add info: 0 - Nothing, 1 - SteamID, 2 - IP, 3 - SteamID & IP", _, true, 0.0, true, 3.0)).AddChangeHook(CVarChanged_Mode);
	iMode = cvar.IntValue;

	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_team", Event_Team, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
}

public void CVarChanged_Mode(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iMode = cvar.IntValue;
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client))
		iType[client] = GetUserAdmin(client) == INVALID_ADMIN_ID ? T_Player : T_Admin;
	else if(IsClientSourceTV(client)) iType[client] = T_STV;
	else if(IsClientReplay(client)) iType[client] = T_Replay;
	else iType[client] = T_Bot;
}

public Action Event_Disconnect(Event event, const char[] name, bool dontBroadcast)
{
	if(!dontBroadcast) event.BroadcastDisabled = true;
	return Plugin_Continue;
}

public Action Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && !dontBroadcast)
	{
		event.BroadcastDisabled = true;
		if(event.GetBool("disconnect")) PrintConnect(client);
		else if(!event.GetInt("oldteam")) PrintConnect(client, true);
		else switch(event.GetInt("team"))
		{
			case 1: PrintToChatAllClr("Игрок {GREEN}%N {WHITE}перешёл в {GRAY}Наблюдение", client);
			case 2: PrintToChatAllClr("Игрок {GREEN}%N {WHITE}зашёл за {LIGHTRED}Террористов", client);
			case 3: PrintToChatAllClr("Игрок {GREEN}%N {WHITE}зашёл за {LIGHTBLUE}Спецназ", client);
		}
	}
	return Plugin_Continue;
}

stock void PrintConnect(int client, bool connect = false)
{
	static char msg[PLATFORM_MAX_PATH], amsg[PLATFORM_MAX_PATH], buffer[32];
	FormatEx(msg, sizeof(msg), "Игрок {GREEN}%N %s{WHITE}.", client, connect ? "{LIGHTGREEN}подключился к серверу" : "{LIGHTRED2}покидает игру");

	FormatEx(amsg, sizeof(amsg), "%s {GREEN}%N{WHITE}", TYPE[iType[client]], client);
	if(iType[client])
	{
		if(iMode & 1)
		{
			GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
			Format(amsg, sizeof(amsg), "%s [{OLIVE}%s{WHITE}]", amsg, buffer);
		}
		if(iMode & 2)
		{
			GetClientIP(client, buffer, sizeof(buffer));
			Format(amsg, sizeof(amsg), "%s [{OLIVE}%s{WHITE}]", amsg, buffer);
		}
	}
	Format(amsg, sizeof(amsg), "%s %s.", amsg, connect ? "{LIGHTGREEN}подключился к серверу" : "{LIGHTRED2}покидает игру");

	for(int i = 1; i <= MaxClients; i++) if(IsClientValid(i)) PrintToChatClr(i, iType[i] == T_Admin ? amsg : msg);
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

stock bool IsClientValid(int client)
{
	return IsClientInGame(client) && iType[client];
}