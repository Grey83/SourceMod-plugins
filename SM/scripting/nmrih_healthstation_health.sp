#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new iHSHealthOffset;

new g_BeamSprite = -1;
new g_HaloSprite = -1;
new aHealthStationLoc[10],
	aHealthStation[10];
new iNumHealthStations;

new bool:g_bLateLoaded = false;

public Plugin:myinfo =
{
	name = "[NMRiH] HealthStation Health",
	author = "Grey83",
	description = "",
	version = "1.0",
	url = ""
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
  g_bLateLoaded = late;
  return APLRes_Success;
}

public OnPluginStart()
{
	decl String:game[16];
	GetGameFolderName(game, sizeof(game));
	if(strcmp(game, "nmrih", false) != 0)
	{
		SetFailState("Unsupported game!");
	}

	RegAdminCmd("sm_hsh", Cmd_HSHealth, ADMFLAG_SLAY);
	RegAdminCmd("sm_hst", Cmd_HSTele, ADMFLAG_SLAY);
	iHSHealthOffset = FindSendPropInfo("CNMRiH_HealthStationLocation", "_health");

	HookEvent("state_change", Event_SC);

	if (g_bLateLoaded) FindHealthStations();
}

public OnMapStart()
{
	g_BeamSprite = PrecacheModel("materials/sprites/purplelaser1.vmt", true);
	g_HaloSprite = PrecacheModel("materials/sprites/laser/laser_dot_g.vmt", true);
}

public Event_SC(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iState = GetEventInt(event, "state");
	new iGameType = GetEventInt(event, "game_type");
	if (iState == 3 && iGameType == 1) FindHealthStations();
}

public FindHealthStations()
{
	new String:classname[30];
	new numLoc = 0, numSt = 0;
	for(new i = MaxClients; i < GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			if(strcmp(classname, "nmrih_health_station_location")==0)
			{
				aHealthStationLoc[numLoc] = i;
				numLoc++;
			}
			else if(strcmp(classname, "nmrih_health_station")==0)
			{
				aHealthStation[numSt] = i;
				numSt++;
			}
		}
	}
	iNumHealthStations = numLoc;
}

public Action:Cmd_HSHealth(client, args)
{
	new Float:fNewValue, Float:fValue;
	if(args > 0)
	{
		new String:szBuffer[10];
		GetCmdArg(1, szBuffer, sizeof( szBuffer ) );
		fNewValue = StringToFloat(szBuffer);
	}
	for(new i = 0; i < iNumHealthStations; i++)
	{
		new color[4], Float:fStart, Float:fEnd;
		fValue = GetEntDataFloat(aHealthStationLoc[i], iHSHealthOffset);
		if(!args) PrintToChat(client, "\x01HealthStation %d health: \x04%.2f\x01HP", i, fValue);
		else if(args > 0)
		{
			if(fValue < fNewValue)
			{
//				color[0] = 0;
				color[1] = 255;
//				color[2] = 0;
				color[3] = 255;
				fStart = 10.0;
				fEnd = 400.0;
			}
			else if(fValue > fNewValue)
			{
				color[0] = 255;
//				color[1] = 0;
//				color[2] = 0;
				color[3] = 255;
				fStart = 400.0;
				fEnd = 10.0;
			}
			else
			{
				color[0] = 127;
				color[1] = 127;
				color[2] = 127;
				color[3] = 127;
				fStart = 200.0;
				fEnd = 201.0;
			}
			new Float:Pos[3];
			GetEntPropVector(aHealthStationLoc[i], Prop_Send, "m_vecOrigin", Pos);
			SetEntDataFloat(aHealthStationLoc[i], iHSHealthOffset, fNewValue, true);
			TE_SetupBeamRingPoint(Pos, fStart, fEnd, g_BeamSprite, g_HaloSprite, 0, 15, 3.0, 5.0, 0.0, color, 10, 0);
			TE_SendToClient(client);
		}
	}
	return Plugin_Handled;
}

public Action:Cmd_HSTele(client, args)
{
	for(new i = 0; i < iNumHealthStations; i++)
	{
		new Float:Pos[3];
		GetEntPropVector(aHealthStationLoc[i], Prop_Send, "m_vecOrigin", Pos);
		TeleportEntity(aHealthStation[i], Pos, NULL_VECTOR, NULL_VECTOR);
//		SetEntPropVector(aHealthStation[i], Prop_Send, "m_vecOrigin", Pos);
	}
	return Plugin_Handled;
}