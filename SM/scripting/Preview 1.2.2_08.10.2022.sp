#pragma newdecls required
#pragma semicolon 1

#include <cstrike>
#include <sdkhooks>
#include <sdktools_engine>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include <sdktools_trace>

static const char
	PL_NAME[]	= "Preview",
	PL_VER[]	= "1.2.2_08.10.2022",

	SCFG[]		= "configs/preview/settings.ini",
	DCFG[]		= "configs/preview/download.ini",

	PRE_CSS[]	= "\x07FF0000",
	PRE_CSGO[]	= " \x07";

Menu
	hList,
	hPreview;
bool
	bCSGO;
int
	iItem[MAXPLAYERS+1],
	iRef[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= PL_NAME,
	author		= "Drumanid, Grey83",
	description	= "Preview of available player models",
	version		= PL_VER,
	url			= "http://vk.com/drumanid https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	CreateConVar("sm_preview_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	bCSGO = GetEngineVersion() == Engine_CSGO;

	RegConsoleCmd("sm_pre", Cmd_Preview);
	RegConsoleCmd("sm_preview", Cmd_Preview);

	RegAdminCmd("sm_preview_reload", Cmd_Reload, ADMFLAG_CONFIG, "Reload \"Preview\" plugin configurations");

	hList = new Menu(Menu_List);
	hList.ExitButton = true;

	hPreview = new Menu(Menu_Preview, MenuAction_DisplayItem);
	hPreview.SetTitle("Демонстрация модели\nПревью появится на позиции вашего прицела!\n ");
	hPreview.AddItem("", "Превью");
	hPreview.ExitBackButton = true;
	hPreview.ExitButton = true;
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		iItem[i] = 0;
		OnClientDisconnect(i);
	}
	hList.RemoveAllItems();

	char buffer[PLATFORM_MAX_PATH];
	KeyValues kv = new KeyValues("Preview");
	BuildPath(Path_SM, buffer, sizeof(buffer), SCFG);
	if(!kv.ImportFromFile(buffer)) SetFailState("No found: %s", buffer);

	kv.Rewind();
	if(kv.GotoFirstSubKey())
	{
		int val;
		char name[64], model[128];
		do
		{
			kv.GetSectionName(name, sizeof(name));
			kv.GetString("model", model, sizeof(model));
			if((val = strlen(model) - 4) < 1 || strcmp(model[val], ".mdl", true))
				LogError("Wrong '%s' model path: '%s'", name, model);
			else hList.AddItem(model, name);
		} while(kv.GotoNextKey());
	}

	iItem[0] = hList.ItemCount;
	hList.SetTitle("Скины (%i):\n ", iItem[0]);
	if(!iItem[0])
	{
		hList.AddItem(NULL_STRING, "Нет скинов для просмотра", ITEMDRAW_DISABLED);
		LogError("Empty or invalid config '%s'", buffer);
		return;
	}

	BuildPath(Path_SM, buffer, sizeof(buffer), DCFG);
	File file = OpenFile(buffer, "r");
	if(!file) SetFailState("No found: %s", buffer);

	while(file.ReadLine(buffer, sizeof(buffer)))
	{
		TrimString(buffer);
		if(IsCharAlpha(buffer[0]) && StrContains(buffer, "//") == -1 && FileExists(buffer))
		{
			AddFileToDownloadsTable(buffer);
			PrecacheModel(buffer, true);
		}
	}

	delete file;
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason)
{
	for(int i = 1; i <= MaxClients; i++) iRef[i] = -1;
	return Plugin_Continue;
}

public Action Cmd_Reload(int client, int args)
{
	OnMapStart();
	ReplyToCommand(client, "Added models to preview menu: %i", iItem[0]);

	return Plugin_Handled;
}

public Action Cmd_Preview(int client, int args)
{
	if(client) hList.DisplayAt(client, ((iItem[client] & 0xfff000) >> 12), MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	RemoveMdl(client);
	iItem[client] = 0;
}

public int Menu_List(Menu menu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		iItem[client] = option | (hList.Selection << 12);
		hPreview.Display(client, MENU_TIME_FOREVER);
	}
	return 0;
}

public int Menu_Preview(Menu menu, MenuAction action, int client, int param)
{
	static char buffer[128];
	switch(action)
	{
		case MenuAction_DisplayItem:
		{
			hList.GetItem((iItem[client]&0xfff), "", 0, _, buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "%s модель\n    %s", iRef[client] != -1 ? "Скрыть" : "Показать", buffer);
			return RedrawMenuItem(buffer);
		}
		case MenuAction_Select:
		{
			if(iRef[client] == -1)
				ShowModel(client);
			else RemoveMdl(client);
			hPreview.Display(client, MENU_TIME_FOREVER);
		}
		case MenuAction_Cancel:
			if(param == MenuCancel_ExitBack) hList.DisplayAt(client, ((iItem[client] & 0xfff000) >> 12), MENU_TIME_FOREVER);
	}
	return 0;
}

stock void ShowModel(int client)
{
	RemoveMdl(client);

	char mdl[128];
	hList.GetItem((iItem[client]&0xfff), mdl, sizeof(mdl));

	if(!IsModelPrecached(mdl))
	{
		LogError("Model '%s' not cached.", mdl);
		PrintToChat(client, "%sК сожалению сервер не может показать вам эту модель!", bCSGO ? PRE_CSGO : PRE_CSS);
		return;
	}

	int ent = CreateEntityByName("prop_physics_override");
	if(ent == -1)
	{
		LogError("Failed to create entity 'prop_physics_override'.");
		return;
	}

	DispatchKeyValue(ent, "model", mdl);
	DispatchKeyValue(ent, "physicsmode", "2");
	DispatchKeyValue(ent, "massScale", "1.0");
	DispatchKeyValue(ent, "spawnflags", "0");
	DispatchKeyValue(ent, "CollisionGroup", "1");

	float fPos[3], fAng[3];
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAng);
	TR_TraceRayFilter(fPos, fAng, MASK_SOLID, RayType_Infinite, Filter, client);
	TR_GetEndPosition(fPos);
	GetClientAbsAngles(client, fAng); fAng[1] -= 180.0;
	TeleportEntity(ent, fPos, fAng, NULL_VECTOR);

	if(!DispatchSpawn(ent))
	{
		LogError("Failed to spawn entity 'prop_physics_override'.");
		return;
	}

	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
	SetEntityMoveType(ent, MOVETYPE_NONE);

	SDKHook(ent, SDKHook_SetTransmit, SetTransmit);

	iRef[client] = EntIndexToEntRef(ent);
}

stock void RemoveMdl(int client)
{
	if(IsMdlExist(client)) AcceptEntityInput(iRef[client], "Kill");
	iRef[client] = -1;
}

public bool Filter(int ent, int mask, any entity)
{
	return ent != entity;
}

public Action SetTransmit(int entity, int client)
{
	return iRef[client] != -1 && EntRefToEntIndex(iRef[client]) == entity ? Plugin_Continue : Plugin_Handled;
}

stock bool IsMdlExist(int client)
{
	return iRef[client] != -1 && GetMdlId(client) != -1;
}

stock int GetMdlId(int client)
{
	return EntRefToEntIndex(iRef[client]);
}