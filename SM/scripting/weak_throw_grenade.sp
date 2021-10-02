#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools_engine>
#include <sdktools_functions>

#if SOURCEMOD_V_MINOR > 10
	#define PL_NAME	"Weak throw grenade"
	#define PL_VER	"1.3.0_02.10.2021"
#else
static const char
	PL_NAME[]	= "Weak throw grenade",
	PL_VER[]	= "1.3.0_02.10.2021";
#endif

bool
	bLate,
	bAdvert[MAXPLAYERS+1],
	bGrenade[MAXPLAYERS+1],
	bInAttack2[MAXPLAYERS+1];
int
	m_hThrower;
float
	fPower;

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Weak throw grenade with hold RBM",
	author		= "lar1ch, Grey83",
	url			= "https://hlmod.ru/members/lar1ch.125154/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if((m_hThrower = FindSendPropInfo("CBaseGrenade", "m_hThrower")) < 1)
	{
		FormatEx(error, err_max, "Can't find offset 'CBaseGrenade::m_hThrower'.");
		return APLRes_Failure;
	}

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("weak_throw_grenade.phrases");

	CreateConVar("sm_weak_throw_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar = CreateConVar("sm_weak_throw_power", "150.0", "Grenade throwing power (512 = normal throwing power)", _, true, 32.0, true, 1024.0);
	cvar.AddChangeHook(CVarChange_Power);
	fPower = cvar.FloatValue;

	HookEvent("player_spawn", Event_Spawn);

	AutoExecConfig(true, "weak_throw_grenade");

	if(bLate)
	{
		for(int i = 1, wpn = FindSendPropInfo("CCSPlayer", "m_hActiveWeapon"); i <= MaxClients; i++)
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				SDKHook(i, SDKHook_WeaponSwitch, OnWeaponSwitch);
				if(wpn > 0 && IsPlayerAlive(i)) OnWeaponSwitch(i, GetEntDataEnt2(i, wpn));
			}
		bLate = false;
	}
}

public void CVarChange_Power(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fPower = cvar.FloatValue;
}

public void OnClientPutInServer(int client)
{
	bInAttack2[client] = bGrenade[client] = false;
	if(!IsFakeClient(client)) SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	static char wpn[24];
	GetEntityClassname(weapon, wpn, sizeof(wpn));
	if((bGrenade[client] = !strcmp(wpn[7], "hegrenade") || !strcmp(wpn[7], "flashbang") || !strcmp(wpn[7], "smokegrenade")) && !bAdvert[client])
	{
		if(TranslationPhraseExists("HintInfo")) PrintHintText(client, "%t", "HintInfo");
		bAdvert[client] = true;
	}
	else bInAttack2[client] = false;
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	bAdvert[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(buttons & IN_ATTACK2 && bGrenade[client])
	{
		bInAttack2[client] = !(buttons & IN_ATTACK);
		buttons |= IN_ATTACK;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "_projectile") > 8) RequestFrame(RequestFrame_Nade, EntIndexToEntRef(entity));
}

public void RequestFrame_Nade(int entity)
{
	static int client;
	if((entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE
	|| (client = GetEntDataEnt2(entity, m_hThrower)) < 1 || client > MaxClients
	|| !bInAttack2[client])
		return;

	float eye[3], pos[3], vel[3];
	GetClientEyePosition(client, eye);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
	MakeVectorFromPoints(eye, pos, vel);
	NormalizeVector(vel, vel);
	ScaleVector(vel, fPower);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", pos);
	vel[0] += pos[0];
	vel[1] += pos[1];
	vel[2] += pos[2];
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vel);
}