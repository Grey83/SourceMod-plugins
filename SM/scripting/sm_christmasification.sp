#pragma semicolon 1
#pragma newdecls required

#include <sdktools_engine>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_trace>

#define MAX_ENTITIES (2048 - 128)	// 1920, fix for error "ED_Alloc: no free edicts"

static const char GLOW[] = "materials/sprites/glow04.vmt";	// "materials/sprites/greenglow1.vmt"

float
	startpoint[3],	// where to start drawing lights
	endpoint[3];	// where to stop drawing lights
Handle
	undo,			// undo props made
	g_hDatabase;	// sqlite database
char sMap[64];

public Plugin myinfo =
{
	name		= "Christmasification",
	author		= "MPQC",
	description	= "Adds some Christmas lights",
	version		= "1.1.0_09.11.2021 (rewritten by Grey83)",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_christmasification", Cmd_Christmasification, ADMFLAG_BAN, "Creates Christmas Lights");

	SQL_TConnect(OnDatabaseConnect, "christmasification");

	HookEvent("round_start", RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	GetCurrentMap(sMap, sizeof(sMap));
	ReplaceString(sMap, sizeof(sMap), "/", "_"); // fix for workshop

	PrecacheModel(GLOW);/*

	char buffer[36];
	FormatEx(buffer, sizeof(buffer), "materials/%s", GLOW);
	AddFileToDownloadsTable(buffer);

	pos = strlen(buffer) - 2;
	buffer[pos] = 't', buffer[pos+1] = 'f';	// vmt ==> vtf
	AddFileToDownloadsTable(buffer);// *.vtf, прекеш не нужен */
}

public void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_hDatabase)
		return;

	char query[128];
	FormatEx(query, sizeof(query), "SELECT * FROM christmasification WHERE mapname=\"%s\";", sMap); // get all lights in this map
	SQL_TQuery(g_hDatabase, SQL_PopulateMap, query);
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void OnMapEnd()
{
	if(!undo) undo = CreateStack(1);
	else while(!IsStackEmpty(undo)) PopStack(undo);	// if there's stuff within the stack, remove it all
}

public void SQL_PopulateMap(Handle owner, Handle hndl, const char[] error, any data)
{
	if(!hndl)
	{
		LogError("SQL Query Error: %s", error);
		SetFailState("Lost connection to database. Reconnecting on map change.");
	}

	float pos[3];
	while(SQL_MoreRows(hndl)) if(SQL_FetchRow(hndl))
	{
		// get the positions of the lights
		pos[0] = SQL_FetchFloat(hndl, 1);
		pos[1] = SQL_FetchFloat(hndl, 2);
		pos[2] = SQL_FetchFloat(hndl, 3);
		// grab the color of the lights.. we only care about the first color since we have either red or green
		CreateSprite(pos, SQL_FetchInt(hndl, 4) == 255, false);
	}
}

stock void Save(int client)
{
	if(IsStackEmpty(undo))
	{
		PrintToChat(client, "Round restarted or no lights made. Try again.");
		return;
	}

	int color, index;
	float position[3];
	char query[256];
	// keep popping from the stack until it's empty, and save the position/color of the light
	while(!IsStackEmpty(undo))
	{
		PopStackCell(undo, index);
		if(IsValidEdict(index))
		{
			GetEntPropVector(index, Prop_Send, "m_vecOrigin", position);
			color = GetEntProp(index, Prop_Send, "m_clrRender", 4, 0) & 0xFF;
			FormatEx(query, sizeof(query), "INSERT INTO christmasification(mapname, first, second, third, color) VALUES(\"%s\", \"%f\", \"%f\", \"%f\", %d);", sMap, position[0], position[1], position[2], color);
			SQL_TQuery(g_hDatabase, SQL_DoNothing, query);
		}
	}
}

stock void Undo(int client)
{
	if(IsStackEmpty(undo))
	{
		PrintToChat(client, "Round restarted or no lights made. Try again.");
		return;
	}

	int index;
	// empty the stack and delete all entities within it
	while(!IsStackEmpty(undo))
	{
		PopStackCell(undo, index);
		if(IsValidEdict(index)) AcceptEntityInput(index, "Kill");
	}
}

stock void ClearAllSQL(int client)
{
	char query[256];
	FormatEx(query, sizeof(query), "DELETE FROM christmasification WHERE mapname=\"%s\";", sMap);
	SQL_TQuery(g_hDatabase, SQL_DoNothing, query);
	PrintToChat(client, "[Christmasification] Cleared all lights.");
}


public void OnDatabaseConnect(Handle owner, Handle hndl, const char[] error, any data)
{
	if(!hndl || error[0])
	{
		PrintToServer("Error connecting to database: %s", error);
		SetFailState("Lost connection to database. Reconnecting on map change.");
	}

	g_hDatabase = hndl;

	SQL_TQuery(g_hDatabase, SQL_DoNothing, "CREATE TABLE IF NOT EXISTS christmasification(mapname VARCHAR(64), first REAL, second REAL, third REAL, color INTEGER);");
}

public void SQL_DoNothing(Handle owner, Handle hndl, const char[] error, any data)
{
	if(!hndl || error[0])
	{
		LogError("SQL query errors: %s", error);
		SetFailState("Lost connection to database. Reconnecting on map change.");
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////		 MENU			///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

public Action Cmd_Christmasification(int client, int args)
{
	MainMenu(client);
	return Plugin_Handled;
}

stock void MainMenu(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(MainMenuHandler);
	SetMenuTitle(menu, "Christmas Menu");
	AddMenuItem(menu, "", "Add Lights");
	AddMenuItem(menu, "", "Clear All Lights");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		if(!param)
			ChooseLightTypeMenu(client);
		else ClearAll(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock void ClearAll(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(ClearAllMenuHandler);
	SetMenuTitle(menu, "Are you sure you want to erase all lights?");
	AddMenuItem(menu, "", "Yes");
	AddMenuItem(menu, "", "No");
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int ClearAllMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		if(!param) ClearAllSQL(client);
		MainMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack) MainMenu(client);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

stock void ChooseLightTypeMenu(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(ChooseLightTypeMenuHandler);
	SetMenuTitle(menu, "Choose Light Type");
	AddMenuItem(menu, "", "Row of Lights");
	AddMenuItem(menu, "", "Individual light");
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int ChooseLightTypeMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		if(!param)
			AddLightsMenu(client);
		else AddIndividualLightMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack) MainMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock void AddIndividualLightMenu(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(AddIndividualLightMenuHandler);
	SetMenuTitle(menu, "Add Lights Menu\n    Look where you want the light to be created");
	AddMenuItem(menu, "", "Red");
	AddMenuItem(menu, "", "Green");
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int AddIndividualLightMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		OnMapEnd();
		float position[3];
		TraceEye(client, position);
		CreateSprite(position, !param);
		DecideLightsMenuEnd(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack) ChooseLightTypeMenu(client);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

stock void AddLightsMenu(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(AddLightsMenuHandler);
	SetMenuTitle(menu, "Add Lights Menu\n    Look at where you want to begin adding lights then push 2");
	AddMenuItem(menu, "", "Begin");
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int AddLightsMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		TraceEye(client, startpoint);
		AddLightsMenuEnd(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack) ChooseLightTypeMenu(client);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

stock void AddLightsMenuEnd(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(AddLightsMenuEndHandler);
	SetMenuTitle(menu, "Add Lights Menu\n    Look at where you want to end adding the lights then push 2");
	AddMenuItem(menu, "", "End");
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int AddLightsMenuEndHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		TraceEye(client, endpoint);
		DrawLights();
		DecideLightsMenuEnd(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack) AddLightsMenu(client);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
	
}

stock void DecideLightsMenuEnd(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	Handle menu = CreateMenu(DecideLightsMenuHandler);
	SetMenuTitle(menu, "Decide Lights Menu");
	AddMenuItem(menu, "", "Save");
	AddMenuItem(menu, "", "Undo");
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 60);
}

public int DecideLightsMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		if(!param)
			Save(client);
		else Undo(client);
		MainMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack)
		{
			Undo(client);
			AddLightsMenuEnd(client);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// This function is taken from Mitchell's LASERRRRRRRRSSSS plugin. All credits to him for it.
stock void TraceEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(null)) TR_GetEndPosition(pos, null);
}

// This function is taken from Mitchell's LASERRRRRRRRSSSS plugin. All credits to him for it.
public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return(entity > MaxClients || !entity);
}

stock void DrawLights()
{
	float direction[3], starting[3];
	starting = startpoint;

	SubtractVectors(endpoint, startpoint, direction);
	NormalizeVector(direction, direction);
	ScaleVector(direction, 75.0);

	OnMapEnd();

	int i;
	while(++i)
	{
		CreateSprite(starting, !(i % 2));
		if(GetVectorDistance(endpoint, starting) < 75.0)
			break;

		AddVectors(starting, direction, starting);
	}
}

stock void CreateSprite(const float position[3], bool red, const bool pushstack = true)
{
	int sprite = CreateEntityByName("env_sprite");
	if(sprite != -1)
	{
		if(sprite > MAX_ENTITIES)
		{
			AcceptEntityInput(sprite, "Kill");
			ThrowError("Too much entities on map");
		}

		DispatchKeyValueVector(sprite, "Origin", position);
		DispatchKeyValue(sprite, "model", GLOW);
		DispatchKeyValue(sprite, "spawnflags", "1");
		DispatchKeyValue(sprite, "scale", "0.5");
		DispatchKeyValue(sprite, "rendermode", "9");
		DispatchKeyValue(sprite, "rendercolor", red ? "255 0 0" : "0 255 0");
		DispatchSpawn(sprite);

		if(pushstack) PushStackCell(undo, sprite);
	}
}