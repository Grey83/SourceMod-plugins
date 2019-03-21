#pragma semicolon 1
#pragma newdecls required

#include <sdktools_engine>
#include <sdktools_functions>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>

static const int	BORDER_COLOR[]	= {127, 31, 0, 255},
					BEAM_COLOR[]	= {0, 255, 127, 255};

int iNumZones,
	hBeam;
float vCorners[4][8][3];
Handle hTimer[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegAdminCmd("sm_zones", Cmd_ShowZones, ADMFLAG_ROOT);
}

public Action Cmd_ShowZones(int client, int args)
{
	if(!client) return Plugin_Handled;

	if(hTimer[client] == null) hTimer[client] = CreateTimer(0.2, ShowZones, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	else
	{
		KillTimer(hTimer[client]);
		hTimer[client] = null;
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];
	Handle cfg = LoadGameConfigFile("funcommands.games");
	if(cfg == null) SetFailState("Unable to load game config 'funcommands.games'!");
	if(GameConfGetKeyValue(cfg, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0]) hBeam = PrecacheModel(buffer, true);
	CloseHandle(cfg);

	GetZonesParameters("func_buyzone");
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++) if(hTimer[i] != null) hTimer[i] = null;
}

stock void GetZonesParameters(const char[] name)
{
	iNumZones = 0;
	int i = -1;
	PrintToServer("\n");
	while((i = FindEntityByClassname(i, name)) != -1 && iNumZones < 4) SaveCorners(i);
	PrintToServer("Total zones: %i\n", iNumZones);
}

stock void SaveCorners(const int ent)
{
	float min[3], max[3], pos[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(ent, Prop_Data, "m_vecMins", min);
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", max);

	PrintToServer("%i) Zone parameters:\n   Pos: %.2f %.2f %.2f\n   Min: %.2f %.2f %.2f\n   Max: %.2f %.2f %.2f", iNumZones, pos[0], pos[1], pos[2], min[0], min[1], min[2], max[0], max[1], max[2]);
	AddVectors(pos, min, min);
	AddVectors(pos, max, max);

	vCorners[iNumZones][0][0] = min[0];
	vCorners[iNumZones][0][1] = min[1];
	vCorners[iNumZones][0][2] = min[2];

	vCorners[iNumZones][1][0] = max[0];
	vCorners[iNumZones][1][1] = min[1];
	vCorners[iNumZones][1][2] = min[2];

	vCorners[iNumZones][2][0] = max[0];
	vCorners[iNumZones][2][1] = max[1];
	vCorners[iNumZones][2][2] = min[2];

	vCorners[iNumZones][3][0] = min[0];
	vCorners[iNumZones][3][1] = max[1];
	vCorners[iNumZones][3][2] = min[2];

	vCorners[iNumZones][4][0] = min[0];
	vCorners[iNumZones][4][1] = min[1];
	vCorners[iNumZones][4][2] = max[2];

	vCorners[iNumZones][5][0] = max[0];
	vCorners[iNumZones][5][1] = min[1];
	vCorners[iNumZones][5][2] = max[2];

	vCorners[iNumZones][6][0] = max[0];
	vCorners[iNumZones][6][1] = max[1];
	vCorners[iNumZones][6][2] = max[2];

	vCorners[iNumZones][7][0] = min[0];
	vCorners[iNumZones][7][1] = max[1];
	vCorners[iNumZones][7][2] = max[2];

	iNumZones++;
}

public Action ShowZones(Handle timer, any client)
{
	static int i;
	static float dist[4];
	static char msg[256];
	msg[0] = 0;
	if(iNumZones) for(i = 0; i < iNumZones; i++)
	{
		dist[i] = Effect_DrawBeamBox(client, i);
		Format(msg, sizeof(msg), "%sДо зоны #%i: %.2f\n", msg, i, dist[i]); 
	}
	SetHudTextParams(0.01, 0.8, 0.21, 63, 127, 0, 255, 0, 0.0, 0.1, 0.1);
	ShowHudText(client, 6, msg);

	return Plugin_Continue;
}

stock float Effect_DrawBeamBox(const int client, const int zone)
{
	static int i, j;
	for(i = 0; i < 4; i++)
	{
		j = (i == 3 ? 0 : i+1);
		TE_SetupBeamPoints(vCorners[zone][i], vCorners[zone][j], hBeam, 0, 0, 0, 0.5, 3.0, 3.0, 1, 0.0, BORDER_COLOR, 0);
		TE_SendToClient(client);
	}

	for(i = 4; i < 8; i++)
	{
		j = (i == 7 ? 4 : i+1);
		TE_SetupBeamPoints(vCorners[zone][i], vCorners[zone][j], hBeam, 0, 0, 0, 0.5, 3.0, 3.0, 1, 0.0, BORDER_COLOR, 0);
		TE_SendToClient(client);
	}

	for(i = 0; i < 4; i++)
	{
		TE_SetupBeamPoints(vCorners[zone][i], vCorners[zone][i+4], hBeam, 0, 0, 0, 0.5, 3.0, 3.0, 1, 0.0, BORDER_COLOR, 0);
		TE_SendToClient(client);
	}

	static float pos[3], closest[3];
	GetClientEyePosition(client, pos);
	pos[2] -= 10;
	closest = pos;
	for(i = 0; i < 3; i++)
	{
		if(pos[i] < vCorners[zone][0][i])		closest[i] = vCorners[zone][0][i];
		else if(pos[i] > vCorners[zone][6][i])	closest[i] = vCorners[zone][6][i];
	}

	TE_SetupBeamPoints(pos, closest, hBeam, 0, 0, 0, 0.21, 3.0, 3.0, 1, 0.0, BEAM_COLOR, 0);
	TE_SendToAll();

	return GetVectorDistance(pos, closest);
}