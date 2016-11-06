// Старая версия
// последняя правка от 05.10.2016
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools> 

#define PLUGIN_VERSION	"1.0.0"
#define PLUGIN_NAME		"Prop control"
#define ENT_LIMIT			1024

Handle g_MoveMenu = INVALID_HANDLE;
Handle g_RotateMenu = INVALID_HANDLE;
Handle g_CopyMenu = INVALID_HANDLE;

int g_BeamSprite = -1;
char cAxis[3][1] = {"X", "Y", "Z"};
int iMAxis = 2;
char cDist[3][3] = {"3", "1", ".25"};
int iDist[3] = {"48", "16", "4"};
int iMDist = 0;
char cRelative[2][6] = {"world", "entity"};
int bWorld = 0;
bool bStored[MAXPLAYERS+1];
bool bIsAdmin[MAXPLAYERS+1];
char SID[MAXPLAYERS+1][18];
//int iPlayersEntities[MAXPLAYERS+1][ENT_LIMIT];
/*int iLimit[MAXPLAYERS+1];
int iTotalLimit;
int iCreated[MAXPLAYERS+1];*/
char cState[4][7] = {"closed", "opens", "opened", "closes"};

float bufferAng[MAXPLAYERS+1][3];
char bufferClass[MAXPLAYERS+1][64], bufferMdl[MAXPLAYERS+1][64];

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	author		= "Grey83",
	description	= "Rotate, move & copy props",
	version		= PLUGIN_VERSION,
	url			= ""
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	CreateConVar("sm_positionmenu_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegAdminCmd("sm_rotate", Cmd_Rotate, ADMFLAG_SLAY,"Rotate a prop");
	RegAdminCmd("sm_move", Cmd_Move, ADMFLAG_SLAY,"Move a prop");
	RegConsoleCmd("sm_copy", Cmd_Copy, "Copy a prop");
/*	RegAdminCmd("sm_delete", Cmd_Delete, ADMFLAG_SLAY,"Delete a prop");
	RegAdminCmd("sm_del", Cmd_Del, ADMFLAG_SLAY,"Delete aimed prop");*/
}

public void OnMapStart()
{
	g_RotateMenu = BuildRotateMenu();
	g_MoveMenu = BuildMoveMenu();
	g_CopyMenu = BuildCopyMenu();

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == INVALID_HANDLE)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}
	char sBeam[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", sBeam, sizeof(sBeam)) && sBeam[0]) g_BeamSprite = PrecacheModel(sBeam);
	CloseHandle(gameConfig);
}

public void OnClientPostAdminCheck(int client)
{
	if(1 <= client <= MaxClients)
	{
		bStored[client] = false;
		bIsAdmin[client] = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC);
		if(GetClientAuthId(client, AuthId_SteamID64, SID[client], 18)) PrintToServer("%s '%N' with SteamID '%s' connected", bIsAdmin[client] ? "Admin" : "Player", client, SID[client]);
		else PrintToServer("Can't get %N's SteamID", client);
	}
}
/*
public void OnClientDisconnect_Post(int client)
{
	amt[client] = 0;
}
*/
public void OnMapEnd()
{
	if(g_RotateMenu != INVALID_HANDLE)
	{
		CloseHandle(g_RotateMenu);
		g_RotateMenu = INVALID_HANDLE;
	}
	if(g_MoveMenu != INVALID_HANDLE)
	{
		CloseHandle(g_MoveMenu);
		g_MoveMenu = INVALID_HANDLE;
	}
	if(g_CopyMenu != INVALID_HANDLE)
	{
		CloseHandle(g_CopyMenu);
		g_CopyMenu = INVALID_HANDLE;
	}
}

//	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-
//	-	-	-	-	-	-	-	-	Меню поворота	-	-	-	-	-	-	-	-	-	-	-
//	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-

public Action Cmd_Rotate(int client, int args)
{
	if(0 < client <= MaxClients) DisplayMenu(g_RotateMenu, client, MENU_TIME_FOREVER);
	else ReplyToCommand(client, "[SM] %t", "Command is in-game only");

	return Plugin_Handled;
}

Handle BuildRotateMenu()
{
	Menu rotatemenu = new Menu(Menu_Rotate);

	rotatemenu.SetTitle("Select the direction to rotate:\n \nX (pitch)");

	rotatemenu.AddItem("0", "+45°");
	rotatemenu.AddItem("1", "-45°\n \nY (yaw)");
	rotatemenu.AddItem("2", "+45°");
	rotatemenu.AddItem("3", "-45°\n \nZ (roll)");
	rotatemenu.AddItem("4", "+45°");
	rotatemenu.AddItem("5", "-45°\n ");
	rotatemenu.AddItem("6", "Set all angles to 0°");

	SetMenuPagination(rotatemenu, MENU_NO_PAGINATION);
	SetMenuExitButton(rotatemenu, true);

	return rotatemenu;
}

public int Menu_Rotate(Menu rotatemenu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[2];
		float ang[3];
		rotatemenu.GetItem(param2, info, 2);

		int ent = GetClientAimTarget(client, false);
	
		if(ent > MaxClients && IsValidEntity(ent))
		{
			char ClassName[11];
			GetEdictClassname(ent, ClassName, 11);
			if(StrContains(ClassName, "npc_nmrih_", true) != 0)
			{
				if(StrContains(ClassName, "prop_door_rotating", true) == 0) GetEntPropVector(ent, Prop_Data, "m_angRotationClosed", ang);
				else GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
				switch(StringToInt(info))
				{
					case 0: ChangeAngle(ang, 0, true);
					case 1: ChangeAngle(ang, 0);
					case 2: ChangeAngle(ang, 1, true);
					case 3: ChangeAngle(ang, 1);
					case 4: ChangeAngle(ang, 2, true);
					case 5: ChangeAngle(ang, 2);
					case 6: for (int i; i < 3; i++) ang[i] = 0.0;
				}
				TeleportEntity(ent, NULL_VECTOR, ang, NULL_VECTOR);
				if(StrContains(ClassName, "prop_door_rotating", true) == 0) SetDoorProperties(ent, ang);
				SetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
			}
		}
		else PrintHintText(client, "Wrong entity");
		DisplayMenu(g_RotateMenu, client, MENU_TIME_FOREVER);
		return true;
	}
	return true;
}

void ChangeAngle(float angle[3], int axis, bool clockwise = false)
{
	if(clockwise) angle[axis] += 45.0;
	else angle[axis] -= 45.0;
	if(angle[axis] < -360 || angle[axis] > 360) angle[axis] = float(RoundFloat(angle[axis]) % 360);
	if(angle[axis] <= -180) angle[axis] += 360;
	else if(angle[axis] > 180) angle[axis] -= 360;
}

float ChangeOpenAngles(float angles[3], bool clockwise = false)
{
//	PrintToServer(" \nClockwise: %b\nOriginal angles\n	X: %4f\n	Y: %4f\n	Z: %4f", clockwise, angles[0], angles[1], angles[2]);
	float fwd[3], normal[3];
	GetAngleVectors(angles, fwd, NULL_VECTOR, normal);

	float normal_r[3];
	normal_r = normal;
	if(!clockwise) NegateVector(normal_r);
	float a = normal_r[0] ;
	float b = normal_r[1];
	float c = normal_r[2];
	float x = fwd[2] * b - fwd[1] * c;
	float y = fwd[0] * c - fwd[2] * a;
	float z = fwd[1] * a - fwd[0] * b;
	fwd[0] = x;
	fwd[1] = y;
	fwd[2] = z;
	
	GetVectorAngles(fwd, angles);

	float up[3];
	GetVectorVectors(fwd, NULL_VECTOR, up);

	int roll = RoundFloat(GetAngleBetweenVectors(up, normal, fwd));
//	PrintToServer("Roll = %i", roll);
	angles[2] += roll;
//	PrintToServer("New angles\n	X: %4f\n	Y: %4f\n	Z: %4f", angles[0], angles[1], angles[2]);

	for(int i; i < 3; i++)
	{
		if(angles[i] <= -180) angles[i] += 360;
		else if(angles[i] > 180) angles[i] -= 360;
	}
//	PrintToServer("Fixed angles\n	X: %4f\n	Y: %4f\n	Z: %4f", angles[0], angles[1], angles[2]);

	return angles;
}

float GetAngleBetweenVectors(const float vector1[3], const float vector2[3], const float direction[3])
{
	float vector1_n[3], vector2_n[3], direction_n[3], cross[3];
	NormalizeVector(direction, direction_n);
	NormalizeVector(vector1, vector1_n);
	NormalizeVector(vector2, vector2_n);
	float degree = ArcCosine(GetVectorDotProduct(vector1_n, vector2_n)) * 57.29577951;   // 180/Pi
	GetVectorCrossProduct(vector1_n, vector2_n, cross);

	if(GetVectorDotProduct(cross, direction_n) < 0.0) degree *= -1.0;

	return degree;
}

//	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-
//	-	-	-	-	-	-	-	Меню перемещения	-	-	-	-	-	-	-	-	-	-	-
//	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-

public Action Cmd_Move(int client, int args)
{
	if(0 < client <= MaxClients) DisplayMenu(g_MoveMenu, client, MENU_TIME_FOREVER);
	else ReplyToCommand(client, "[SM] %t", "Command is in-game only");

	return Plugin_Handled;
}

Handle BuildMoveMenu()
{
	Menu movemenu = new Menu(Menu_Move, MENU_ACTIONS_ALL);

	char buffer[64];
	movemenu.SetTitle("[Prop control] Move\n     Direction:");
	movemenu.AddItem("0", "+\n     3");		// Направление
	movemenu.AddItem("1", "-\n \n     Distance:");
	movemenu.AddItem("2", "3");			// Расстояние
	movemenu.AddItem("3", "1");
	movemenu.AddItem("4", ".25\n \n     Axis:");
	movemenu.AddItem("5", "X");			// Ось
	movemenu.AddItem("6", "Y");
	movemenu.AddItem("7", "Z\n \n     Relative to:");
	movemenu.AddItem("8", "entity");
	SetMenuPagination(movemenu, 0);
	SetMenuExitButton(movemenu, true);

	return movemenu;
}

public int Menu_Move(Menu movemenu, MenuAction action, int client, int param)
{
	char buffer[64];
	switch(action)
	{
		case MenuAction_Display:
		{
			Format(buffer, sizeof(buffer), "[%s] Move\nAxis of %s: %s Dist.: %s)\n     Direction:", PLUGIN_NAME, cAxis[iMAxis], cRelative[iWorld], cDist[iMDist]);	// Сделать перевод Format(buffer, sizeof(buffer), "%T:\n %T '%s'\n ", "TitleMove", client, "Axis", client, cAxis[iMAxis]);
			movemenu.SetTitle(buffer);
		}
		case MenuAction_DisplayItem:
		{
			if(1 < param <= 8)
			{
				if(param < 5)
				{
					Format(buffer, sizeof(buffer), "%s %s", cDist[param - 2], (param - 2 == iMDist) ? "☑" : " ");
					if(param == 4) Format(buffer, sizeof(buffer), "%s\n \n     Axis:", buffer);
				}
				else if(param < 8)
				{
					Format(buffer, sizeof(buffer), "%s %s", cAxis[param - 5], (param - 5 == iMAxis) ? "☑" : " ");
					if(param == 7) Format(buffer, sizeof(buffer), "%s\n \n     Relative to:", buffer);
				}
				else Format(buffer, sizeof(buffer), "%s", cRelative[iWorld]);
				return RedrawMenuItem(buffer);
			}
		}
		case MenuAction_Select:		//переписать
		{
//			if(0 <= param < 2)
			if(param < 2)
			{
				float pos[3];
				int ent = GetClientAimTarget(client, false);
		
				if(ent > MaxClients && IsValidEntity(ent))
				{
					char ClassName[11];
					GetEdictClassname(ent, ClassName, 11);
					if(StrContains(ClassName, "npc_nmrih_", true) != 0)
					{
						GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
						SetNewPosition(ent, pos, param);
						TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
					}
				}
				else PrintHintText(client, "Wrong entity");
			}
			else if(1 < param < 5) iMAxis = param - 6;
			else if(4 < param < 8) iMAxis = param - 6;
			else if(param == 8) iWorld = (iWorld == 0) 1 : 0;
			movemenu.Display(client, MENU_TIME_FOREVER);
			return 0;
		}
	}
	return 0;
}

float void SetNewPosition(int entity, float origin[3], int direction)
{
	dist = iDist[iMDist] * (-1*direction);
	pos[iMAxis] += iDist[iMDist];

	float pos[3], ang[3], dest[3];

	dest[axis] = size[axis];
	Math_RotateVector(dest, ang, dest);
	if(dir) AddVectors(pos, dest, dest);
	else SubtractVectors(pos, dest, dest);

	return pos;
}

//	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-
//	-	-	-	-	-	-	-	Меню копирования	-	-	-	-	-	-	-	-	-	-	-
//	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-	-

public Action Cmd_Copy(int client, int args)
{
	if(0 < client <= MaxClients) DisplayMenu(g_CopyMenu, client, MENU_TIME_FOREVER);
	else ReplyToCommand(client, "[SM] %t", "Command is in-game only");

	return Plugin_Handled;
}

Handle BuildCopyMenu()
{
	Menu copymenu = new Menu(Menu_Copy, MENU_ACTIONS_ALL);

	copymenu.SetTitle("Copy/Paste props:");

	copymenu.AddItem("0", "Copy");
	copymenu.AddItem("1", "Paste\n \nCreate a copy of the object\nwith an offset in the axis");
	copymenu.AddItem("2", "+\n     Z");
	copymenu.AddItem("3", "-\n ");
	copymenu.AddItem("4", "+\n     X");
	copymenu.AddItem("5", "-\n ");
	copymenu.AddItem("6", "+\n     Y");
	copymenu.AddItem("7", "-");

	SetMenuPagination(copymenu, 0);
	SetMenuExitButton(copymenu, true);

	return copymenu;
}

public int Menu_Copy(Menu copymenu, MenuAction action, int client, int param2)
{
	switch(action)
	{
/*		case MenuAction_Display:
		{
			char buffer[64];
			Format(buffer, sizeof(buffer), "Distance for move:\nAxis '%s'\n ", cAxis[iMAxis]);	// Сделать перевод Format(buffer, sizeof(buffer), "%T:\n %T '%s'\n ", "TitleMove", client, "Axis", client, cAxis[iMAxis]);
			copymenu.SetTitle(buffer);
		}*/
		case MenuAction_DisplayItem:
		{
			if(param2 == 0)
			{
				char buffer[64];
				Format(buffer, sizeof(buffer), "Copy\n     %s", bufferClass[client]);
				return RedrawMenuItem(buffer);
			}
		}
		case MenuAction_Select:
		{
			if(param2 == 1)
			{
				float pos[3];
				if(bStored[client] && GetPlayerEye(client, pos)) CreateEntity(client, pos, bufferAng[client], bufferClass[client], bufferMdl[client]);
				else PrintHintText(client, "You have not saved any prop");
//				SetEntPropEnt(beament, Prop_Data, "m_hOwnerEntity", client);
//				SetEntPropString(beament, Prop_Data, "m_iName", name);
			}
			else
			{
				int ent = GetClientAimTarget(client, false);
			
				if(ent > MaxClients && IsValidEntity(ent))
				{
					char ClassName[64];
					GetEdictClassname(ent, ClassName, 64);
					if(StrContains(ClassName, "npc_nmrih_", true) != 0)
					{
						switch(param2)
						{
							case 0: CopyEntityProperties(client, ent);
							case 2: CopyEntity(client, ent, 2, true);
							case 3: CopyEntity(client, ent, 2);
							case 4: CopyEntity(client, ent, 1, true);
							case 5: CopyEntity(client, ent, 1);
							case 6: CopyEntity(client, ent, 0, true);
							case 7: CopyEntity(client, ent, 0);
						}
					}
					char buffer[74];
					Format(buffer, 74, "Copied: '%s'", ClassName);
					PrintHintText(client, buffer);
				}
				else PrintHintText(client, "Wrong entity");
			}
			copymenu.Display(client, MENU_TIME_FOREVER);
			return 0;
		}
	}
	return 0;
}

void CopyEntityProperties(int client, int entity)
{
	if(entity > MaxClients && IsValidEntity(entity))
	{
		float pos[3], min[3], max[3], size[3];
		int color[4], owner, color_offset = -1;
		char name[64];

		GetProperties(entity, pos, bufferAng[client], min, max, size, bufferClass[client], bufferMdl[client]);
		PrintToChat(client, "\x01Position:	\x03X: \x04%f\x03, Y: \x04%f\x03, Z: \x04%f", pos[0], pos[1], pos[2]);
		PrintToChat(client, "\x01Angles:	\x03X: \x04%f\x03, Y: \x04%f\x03, Z: \x04%f", bufferAng[client][0], bufferAng[client][1], bufferAng[client][2]);
		PrintToChat(client, "\x01Size:	\x03X: \x04%f\x03, Y: \x04%f\x03, Z: \x04%f", size[0], size[1], size[2]);
		Effect_DrawAxisOfRotation(client, pos, bufferAng[client], max, g_BeamSprite, 0, 0, 10.0, 1.0, 1.0, 0, 0.0, 0);
		Effect_DrawBeamBoxRotatable(client, pos, min, max, bufferAng[client], g_BeamSprite, 0, 0, 10.0, 1.0, 1.0, 0, 0.0, {0, 255, 127, 255}, 0);
		color_offset = GetEntSendPropOffs(entity, "m_clrRender", false);
		if(color_offset != -1)
		{
			GetEntDataArray(entity, color_offset, color, 4, 1);
			PrintToChat(client, "\x01Color:	\x03R: \x04%i\x03, G: \x04%i\x03, B: \x04%i\x03, A: \x04%i", color[0], color[1], color[2], color[3]);
		}
		else PrintToChat(client, "\x01Color:	\x04NaN");
		owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if(owner >= 0) PrintToChat(client, "\x01Owner:	\x03'\x04%N\x03' (\x04%i\x03)", owner, owner);
		else PrintToChat(client, "\x01Owner:	\x04NaN");
		if(strlen(bufferClass[client]) > 0) PrintToChat(client, "\x01Class:	'\x04%s\x03'", bufferClass[client]);
		else PrintToChat(client, "\x01Class:	\x04NaN");
		GetEntPropString(entity, Prop_Data, "m_iName", name, 64);
		if(strlen(name) > 0) PrintToChat(client, "\x01Name:	'\x04%s\x03'", name);
		else PrintToChat(client, "\x01Name:	\x04NaN");

		if(StrContains(bufferClass[client], "prop_door_rotating", true) == 0)
		{
			int state = GetEntProp(entity, Prop_Data, "m_eDoorState");	// 0 - закрыто, 1 - открывается/закрывается, 2 - открыто
			PrintToChat(client, "\x01State:	\x04%s \x03(\x04%d\x03)", cState[state], state);
			PrintToChat(client, "\x01Delay:	\x04%.2f \x03sec", GetEntPropFloat(entity, Prop_Data, "m_flAutoReturnDelay"));
			
		}
		bStored[client] = true;
	}
}

void CopyEntity(int client, int entity, int axis, bool dir = false)
{
	float pos[3], ang[3], min[3], max[3], size[3], dest[3];
	char class[64], mdl[64];

	GetProperties(entity, pos, ang, min, max, size, class, mdl);

	dest[axis] = size[axis];
	Math_RotateVector(dest, ang, dest);
	if(dir) AddVectors(pos, dest, dest);
	else SubtractVectors(pos, dest, dest);

	CreateEntity(client, dest, ang, class, mdl);
}

void CreateEntity(int client, const float origin[3], const float angles[3], const char class[64], const char mdl[64])
{
	int ent = CreateEntityByName(class);
	if(ent > MaxClients)
	{
		SetEntityModel(ent, mdl);
		DispatchSpawn(ent);
		AcceptEntityInput(ent, "DisableMotion");
		TeleportEntity(ent, origin, angles, NULL_VECTOR);
		if(StrContains(class, "prop_door_rotating", true) == 0) SetDoorProperties(ent, angles);
//		SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
//		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 5);
		SetEntPropString(ent, Prop_Data, "m_iName", SID[client]);
	}
}

void GetProperties(int ent, float origin[3], float angles[3], float min[3], float max[3], float size[3], char class[64], char mdl[64])
{
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
	GetEdictClassname(ent, class, 64);
	if(StrContains(class, "prop_door_rotating", true) == 0) SetEntPropVector(ent, Prop_Data, "m_angRotationClosed", angles);
	else GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
	GetEntPropVector(ent, Prop_Data, "m_vecMins", min);
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", max);
	SubtractVectors(max, min, size);
	GetEntPropString(ent, Prop_Data, "m_ModelName", mdl, 64);
}

void SetDoorProperties(int entity, const float angles[3])
{
	float AngF[3], AngB[3];
	AngF = angles;
	AngB = angles;
	SetEntPropVector(entity, Prop_Data, "m_angRotationClosed", angles);
	SetEntPropVector(entity, Prop_Data, "m_angRotationOpenForward", ChangeOpenAngles(AngF, true));
	SetEntPropVector(entity, Prop_Data, "m_angRotationOpenBack", ChangeOpenAngles(AngB));
	SetEntProp(entity, Prop_Data, "m_eDoorState", 0);
	if(GetEntPropFloat(entity, Prop_Data, "m_flAutoReturnDelay") < 1) SetEntPropFloat(entity, Prop_Data, "m_flAutoReturnDelay", 5.0);
}

/*
stock DeleteEntity(int ent)
{
	char sTargetname[256];
	Format(sTargetname, sizeof(sTargetname), "dissolve%N%f", GetOwner(iEntity), GetRandomFloat());
	DispatchKeyValue(iEntity, "targetname", sTargetname);
	char sDissolve = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(sDissolve, "dissolvetype", "3");
	DispatchKeyValue(sDissolve, "target", sTargetname);
	AcceptEntityInput(sDissolve, "dissolve");
	RemoveNumberFromPropCount(iEntity);
	AcceptEntityInput(sDissolve, "kill");
}
*/
stock void Effect_DrawAxisOfRotation(int client, const float origin[3], const float angles[3], const float length[3], int modelIndex, int startFrame=0, int frameRate=30, float life=5.0, float width=5.0, float endWidth=5.0, int fadeLength=2, float amplitude=1.0, int speed=0)
{
	// Create the additional corners of the box
	float xAxis[3], yAxis[3], zAxis[3];
	xAxis[0] = length[0] + 5.0;
	yAxis[1] = length[1] + 5.0;
	zAxis[2] = length[2] + 5.0;

	// Rotate all edges
	Math_RotateVector(xAxis, angles, xAxis);
	Math_RotateVector(yAxis, angles, yAxis);
	Math_RotateVector(zAxis, angles, zAxis);

	// Apply world offset (after rotation)
	AddVectors(origin, xAxis, xAxis);
	AddVectors(origin, yAxis, yAxis);
	AddVectors(origin, zAxis, zAxis);

	// Draw all
	TE_SetupBeamPoints(origin, xAxis, modelIndex, 0, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, {255, 0, 0, 255}, speed);
	TE_SendToClient(client);

	TE_SetupBeamPoints(origin, yAxis, modelIndex, 0, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, {0, 255, 0, 255}, speed);
	TE_SendToClient(client);

	TE_SetupBeamPoints(origin, zAxis, modelIndex, 0, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, {0, 0, 255, 255}, speed);
	TE_SendToClient(client);
}

stock void Effect_DrawBeamBoxRotatable(int client, const float origin[3], const float mins[3], const float maxs[3], const float angles[3], int modelIndex, int startFrame=0, int frameRate=30, float life=5.0, float width=5.0, float endWidth=5.0, int fadeLength=2, float amplitude=1.0, const int color[4]={ 255, 0, 0, 255 }, int speed=0)
{
	// Create the additional corners of the box
	float corners[8][3];
	for (int i=0; i < 3; i++)
	{
		corners[0][i] = mins[i];
	}
	corners[1][0] = maxs[0];
	corners[1][1] = mins[1];
	corners[1][2] = mins[2];

	corners[2][0] = maxs[0];
	corners[2][1] = maxs[1];
	corners[2][2] = mins[2];

	corners[3][0] = mins[0];
	corners[3][1] = maxs[1];
	corners[3][2] = mins[2];

	corners[4][0] = mins[0];
	corners[4][1] = mins[1];
	corners[4][2] = maxs[2];

	corners[5][0] = maxs[0];
	corners[5][1] = mins[1];
	corners[5][2] = maxs[2];

	for (int i=0; i < 3; i++)
	{
		corners[6][i] = maxs[i];
	}

	corners[7][0] = mins[0];
	corners[7][1] = maxs[1];
	corners[7][2] = maxs[2];

	// Rotate all edges
	for (int i=0; i < sizeof(corners); i++)
	{
		Math_RotateVector(corners[i], angles, corners[i]);
	}

	// Apply world offset (after rotation)
	for (int i=0; i < sizeof(corners); i++)
	{
		AddVectors(origin, corners[i], corners[i]);
	}

    // Draw all the edges
	// Horizontal Lines
	// Bottom
	for (int i=0; i < 4; i++)
	{
		int j = ( i == 3 ? 0 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, 0, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_SendToClient(client);
	}

	// Top
	for (int i=4; i < 8; i++)
	{
		int j = ( i == 7 ? 4 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, 0, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_SendToClient(client);
	}

	// All Vertical Lines
	for (int i=0; i < 4; i++)
	{
		TE_SetupBeamPoints(corners[i], corners[i+4], modelIndex, 0, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_SendToClient(client);
	}
}

stock void Math_RotateVector(const float vec[3], const float angles[3], float result[3])
{
	// First the angle/radiant calculations
	float rad[3];
	// I don't really know why, but the alpha, beta, gamma order of the angles are messed up...
	// 2 = xAxis
	// 0 = yAxis
	// 1 = zAxis
	rad[0] = DegToRad(angles[2]);
	rad[1] = DegToRad(angles[0]);
	rad[2] = DegToRad(angles[1]);

	// Pre-calc function calls
	float cosAlpha = Cosine(rad[0]);
	float sinAlpha = Sine(rad[0]);
	float cosBeta = Cosine(rad[1]);
	float sinBeta = Sine(rad[1]);
	float cosGamma = Cosine(rad[2]);
	float sinGamma = Sine(rad[2]);

	// 3D rotation matrix for more information: http://en.wikipedia.org/wiki/Rotation_matrix#In_three_dimensions
	float x = vec[0], y = vec[1], z = vec[2];
	float newX, newY, newZ;
	newY = cosAlpha*y - sinAlpha*z;
	newZ = cosAlpha*z + sinAlpha*y;
	y = newY;
	z = newZ;

	newX = cosBeta*x + sinBeta*z;
	newZ = cosBeta*z - sinBeta*x;
	x = newX;
	z = newZ;

	newX = cosGamma*x - sinGamma*y;
	newY = cosGamma*y + sinGamma*x;
	x = newX;
	y = newY;
	
	// Store everything...
	result[0] = x;
	result[1] = y;
	result[2] = z;
}

stock bool GetPlayerEye(int client, float pos[3])
{
	float angles[3], origin[3];

	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	bool result = TR_DidHit(trace);
	if(result) TR_GetEndPosition(pos, trace);
	else PrintToChat(client, "Can't create entity");

	CloseHandle(trace);
	return result;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > GetMaxClients() || entity == 0;
} 