#pragma semicolon 1
#include <sourcemod>
#define PLUGIN_VERSION	"1.0"
#define CONSOLE_PREFIX	"[NPCs HP]"

new Handle:hEnabled, bool:bEnabled,
	Handle:hNHP, iNHP;

public Plugin:myinfo = 
{
//	name = "[NMRiH] NPCs HP",
	name = " ",
	author = "Grey83",
	description = "",
	version	= PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
//	CreateConVar("nmrih_npcs_hp_version", PLUGIN_VERSION, "[NMRiH] NPCs HP version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	hEnabled = CreateConVar("sm_npcs_hp_enable", "0", "1/0 - On/Off plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	hNHP = CreateConVar("sm_npcs_hp", "1", "The maximum number zombie's HP", FCVAR_NONE, true, 0.0);

	bEnabled = GetConVarBool(hEnabled);
	iNHP = GetConVarInt(hNHP);

	HookConVarChange(hEnabled, OnConVarChange);
	HookConVarChange(hNHP, OnConVarChange);

	PrintToServer("[NMRiH] NPCs HP v.%s has been successfully loaded!", PLUGIN_VERSION);

	if (bEnabled) LateLoad();
}

public OnConVarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	if (hCvar == hEnabled)
	{
		bEnabled = bool:StringToInt(newValue);
		if (bEnabled) LateLoad();
	}
	else if (hCvar == hNHP)
	{
		iNHP = StringToInt(newValue);
		if (bEnabled) LateLoad();
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if (bEnabled)
	{
		if (StrContains(classname, "npc_nmrih_", true) == 0)
		{
			CreateTimer(0.1, SetHP, entity);
		}
	}
}

public Action:SetHP(Handle:timer, any:entity)
{
	if (IsValidEntity(entity))
	{
		new iCurrentHP;
		iCurrentHP = GetEntProp(entity, Prop_Data, "m_iHealth");
		if (iCurrentHP > iNHP)
		{
			SetEntProp(entity, Prop_Data, "m_iHealth", iNHP);
		}
	}
}

public Action:LateLoad()
{
	new maxent = GetMaxEntities(), String:entity[64];
	for (new i = GetMaxClients(); i < maxent; i++)
	{
		if ( IsValidEdict(i) && IsValidEntity(i) )
		{
			GetEdictClassname(i, entity, sizeof(entity));
			if (StrContains(entity, "npc_nmrih_", true) == 0)
			{
				new iCurrentHP;
				iCurrentHP = GetEntProp(i, Prop_Data, "m_iHealth");
				if (iCurrentHP > iNHP)
				{
					SetEntProp(i, Prop_Data, "m_iHealth", iNHP);
				}
			}
		}
	}
}