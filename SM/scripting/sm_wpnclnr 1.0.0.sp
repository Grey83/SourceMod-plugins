#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#if SOURCEMOD_V_MINOR >= 9
	#include <sdktools_variant_t>
#endif

#if SOURCEMOD_V_MINOR > 10
	#define PL_NAME	"Weapon cleaner"
	#define PL_VER	"1.0.0"
#endif

#if SOURCEMOD_V_MINOR < 11
static const char
	PL_NAME[]	= "Weapon cleaner",
	PL_VER[]	= "1.0.0";
#endif

Handle
	hDropped[2048];
float
	fClear;


public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Clears map from dropped weapons",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	CreateConVar("sm_wpnclnr_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar = CreateConVar("sm_wpnclnr_time", "10", "Time after which the dropped weapon will be removed (-1 - disable cleaning)", _, true, -1.0, true, 86400.0);
	cvar.AddChangeHook(CVarChanged_Clear);
	CVarChanged_Clear(cvar, NULL_STRING, NULL_STRING);

	AutoExecConfig(true, "weapon_cleaner");
}

public void CVarChanged_Clear(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fClear = cvar.IntValue + 0.0;

	static bool hooked;
	if((fClear < 0) == !hooked) return;

	hooked = !hooked;
	if(hooked)
	{
		for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) OnClientPutInServer(i);
	}
	else for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i))
	{
		SDKUnhook(i, SDKHook_WeaponDropPost, OnWeaponDropped);
		SDKUnhook(i, SDKHook_WeaponEquipPost, OnWeaponEqiped);
	}
}

public void OnClientPutInServer(int client)
{
	if(fClear < 0) return;

	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEqiped);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDropped);
}

void OnWeaponDropped(int client, int wpn)
{
	if(wpn <= MaxClients) return;

	if(hDropped[wpn]) delete hDropped[wpn];
	hDropped[wpn] = CreateTimer(fClear, Timer_CheckDropped, EntIndexToEntRef(wpn));
}

void OnWeaponEqiped(int client, int wpn)
{
	if(hDropped[wpn]) delete hDropped[wpn];
}

public void OnEntityDestroyed(int entity)
{
	if(entity > MaxClients && entity < 2048 && hDropped[entity]) delete hDropped[entity];
}

public Action Timer_CheckDropped(Handle timer, any wpn)
{
	if((wpn = EntRefToEntIndex(wpn)) != INVALID_ENT_REFERENCE)
	{
		hDropped[wpn] = null;

		static int zone;
		if((zone = CreateEntityByName("env_entity_dissolver")) == -1)
		{
			AcceptEntityInput(wpn, "Kill");
			return;
		}

		static char buffer[16];
		FormatEx(buffer, sizeof(buffer), "dissolve_%i", wpn);
		DispatchKeyValue(wpn, "targetname", buffer);
		DispatchKeyValue(zone, "target", buffer);
//		тип исчезновения: 0 - Energy, 1 - Heavy electrical, 2 - Light electrical, 3 - Core effect
		DispatchKeyValue(zone, "dissolvetype", "3");
		DispatchKeyValue(zone, "magnitude", "50");

		SetVariantString("!activator");
		AcceptEntityInput(zone, "SetParent", wpn, zone, 0);
		AcceptEntityInput(zone, "Dissolve");
	}
}

public void OnMapEnd()
{
	for(int i = MaxClients + 1; i < 2048; i++) if(hDropped[i]) delete hDropped[i];
}