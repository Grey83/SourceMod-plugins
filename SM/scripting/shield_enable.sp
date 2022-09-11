#pragma semicolon 1

#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_gamerules>

public Plugin myinfo =
{
	name		= "[CSGO] Shield enable",
	version		= "1.0.0_20.02.2022",
	description	= "Makes buying a shield available on any map",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnMapStart()
{
	GameRules_SetProp("m_bMapHasRescueZone", 1);

	float vec[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vec);
	int ent = CreateEntityByName("func_hostage_rescue");
	if(ent == -1) return;
	SetEntPropVector(ent, Prop_Data, "m_vecMaxs", NULL_VECTOR);
	SetEntPropVector(ent, Prop_Data, "m_vecMins", NULL_VECTOR);
	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Enable");
}