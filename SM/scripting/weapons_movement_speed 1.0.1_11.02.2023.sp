#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>

StringMap
	hSpeed;
bool
	bLate;
float
	fVal;
char
	sBuffer[32];

public Plugin myinfo =
{
	name		= "Weapons movement speed",
	author		= "Grey83",
	version		= "1.0.1_11.02.2023",
	description	= "Default movement speed for weapons",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("round_freeze_end", Event_Start, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	if(!hSpeed) hSpeed = CreateTrie();
	if(hSpeed.Size > 0) hSpeed.Clear();

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/weapons_movement_speed.ini");
	KeyValues kv = new KeyValues("Speed");
	if(kv.ImportFromFile(path))
	{
		kv.Rewind();
		if(kv.GotoFirstSubKey(false))
		{
			do
			{
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				if(TrimString(sBuffer) > 1 && (fVal = kv.GetFloat(NULL_STRING)) > 0.0 && fVal != 1.0)
					hSpeed.SetValue(sBuffer, fVal);
			} while(kv.GotoNextKey(false));

			if(hSpeed.Size < 1) LogError("Config '%s' does not contain valid values.", path);
		}
		else LogError("Empty config '%s'.", path);
	}
	else LogError("Unable to load config '%s'.", path);
	delete kv;

	if(!bLate)
		return;

	bLate = false;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && IsValidPlayer(i))
	{
		OnWeaponSwitch(i, 0);
		SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	}
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && IsValidPlayer(i)) OnWeaponSwitch(i, 0);
}

public void OnClientPutInServer(int client)
{
	if(IsValidPlayer(client)) SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
}

public void OnWeaponSwitch(int client, int weapon)
{
	if(hSpeed.Size < 1 || !IsPlayerAlive(client)
	|| (weapon <= MaxClients && (weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) == -1))
		return;

	GetEdictClassname(weapon, sBuffer, sizeof(sBuffer));
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", hSpeed.GetValue(sBuffer[7], fVal) ? fVal : 1.0);
}

stock bool IsValidPlayer(int client)
{
	return !IsFakeClient(client) || !IsClientReplay(client) && !IsClientSourceTV(client);
}