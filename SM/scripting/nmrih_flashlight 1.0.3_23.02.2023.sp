#pragma semicolon 1
#pragma newdecls required

static const int
	IN_FLASHLIGHT	= (1 << 26);
static const char
	PL_NAME[]		= "[NMRiH] Flashlight",
	PL_VER[]		= "1.0.3_23.02.2023";

bool
	bEnable;
int
	m_fEffects;

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Flashlight with any weapon in NMRiH",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if((m_fEffects = FindSendPropInfo("CBaseEntity", "m_fEffects")) < 1)
	{
		FormatEx(error, err_max, "Can't find offset 'CBaseEntity::m_fEffects'!");
		return APLRes_Failure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("nmrih_flashlight_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar = CreateConVar("sm_flashlight_enabled", "1", "Enables/Disables flashlight", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enable);
	bEnable = cvar.BoolValue;
}

public void CVarChanged_Enable(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bEnable = cvar.BoolValue;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!bEnable || !IsPlayerAlive(client))
		return Plugin_Continue;

	static bool flashlight[MAXPLAYERS+1];
	if(buttons & IN_FLASHLIGHT && !(flashlight[client]))
		SetEntData(client, m_fEffects, GetEntData(client, m_fEffects) ^ 4, _, true);
	flashlight[client] = !!(buttons & IN_FLASHLIGHT);

	return Plugin_Continue;
}