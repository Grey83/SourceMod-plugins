#pragma semicolon 1

#include <sourcemod>
//#include <smlib/entities>
#include <sdktools_functions>

#define PLUGIN_VERSION		"1.0.0"
#define PLUGIN_NAME		"[NMRiH] Codes"

public Plugin:myinfo =
{
	name =		PLUGIN_NAME,
	author =		"Grey83",
	description =	"",
	version =	PLUGIN_VERSION,
	url =		""
};

public OnPluginStart()
{
	LoadTranslations("nmrih_keycodes.phrases");
	RegAdminCmd("sm_codes", Cmd_GetCodes, ADMFLAG_SLAY, "Show KeyPad codes in the chat");
	HookEvent("keycode_enter", Event_KeycodeEnter, EventHookMode_Pre);
}

public Action:Cmd_GetCodes(client, args)
{
	new entity = -1, num;
	while((entity = FindEntityByClassname(entity, "trigger_keypad")) != INVALID_ENT_REFERENCE){
		num++;
		new String:sCode[16];
		GetEntPropString(entity, Prop_Data, "m_pszCode", sCode, sizeof(sCode));
		if(!client) PrintToServer("The keypad #%d code is: %s", num, sCode);
		else PrintToChat(client, "\x03%T \x04%s", "KeyPadCode", client, num, sCode);
	}
	if (!num)
	{
		if(!client) PrintToServer("None of the keyboard was not found");
		else PrintToChat(client, "\x03%T", "NoKeypads", client);
	}
	return Plugin_Handled;
}

public Event_KeycodeEnter(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:sCode[16],String:sKeyPadCode[16];
	new client = GetEventInt(event, "player");
	new KeyPad = GetEventInt(event, "keypad_idx");
	GetEventString(event, "code", sCode, sizeof(sCode));
	new iCode = StringToInt(sCode);
	GetEntPropString(KeyPad, Prop_Data, "m_pszCode", sKeyPadCode, sizeof(sKeyPadCode), 0);
	new iKeyPadCode = StringToInt(sKeyPadCode);
	
	if(iCode == iKeyPadCode && iKeyPadCode != 0) PrintToChatAll("\x04%N \x03%T \x01%s", client, "CorrectCode", client, sKeyPadCode);
	else PrintToChatAll("\x04%N \x03%T \x01%s", client, "IncorrectCode", client, sCode);
}