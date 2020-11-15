#pragma semicolon 1
#pragma newdecls required

#include <sdktools>

#if SOURCEMOD_V_MINOR > 10
	#define PL_NAME	"SM Parachute"
	#define PL_VER	"2.5.2_reduced"
#else
static const char
	PL_NAME[]	= "SM Parachute",
	PL_VER[]	= "2.5.2_reduced";
#endif

bool
	bLinear,
	bFalling,
	bUsed[MAXPLAYERS+1];
int
	m_vecVelocity = -1;
float
	fFallSpeed,
	fDecrease;

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "To use your parachute press and hold SPACE(+jump) button while falling.",
	author		= "SWAT_88 (rewritten by Grey83)",
	url			= "https://forums.alliedmods.net/showthread.php?p=580269"
}

public void OnPluginStart()
{
	LoadTranslations("sm_parachute.phrases");

	CreateConVar("sm_parachute_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar;
	HookConVarChange((cvar = CreateConVar("sm_parachute_linear","0", "0: disables linear fallspeed - 1: enables it", FCVAR_NONE, true, 0.0, true, 1.0)), CVarChanged_Linear);
	bLinear = cvar.BoolValue;

	HookConVarChange((cvar = CreateConVar("sm_parachute_fallspeed","100", "Speed of the fall when you use the parachute")), CVarChanged_FallSpeed);
	fFallSpeed = cvar.FloatValue;

	HookConVarChange((cvar = CreateConVar("sm_parachute_decrease","50", "0: dont use Realistic velocity-decrease - x: sets the velocity-decrease.")), CVarChanged_Decrease);
	fDecrease = cvar.FloatValue;

	AutoExecConfig(true, "sm_parachute_reduced");

	m_vecVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	HookEvent("player_death",PlayerDeath);
}

public void CVarChanged_Linear(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bLinear = cvar.BoolValue;
	if(!bLinear) for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && IsPlayerAlive(i) && bUsed[i])
		SetEntityMoveType(i, MOVETYPE_WALK);
}

public void CVarChanged_FallSpeed(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fFallSpeed = cvar.FloatValue;
}

public void CVarChanged_Decrease(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fDecrease = cvar.FloatValue;
}

public void OnClientPutInServer(int client)
{
	bUsed[client] = false;
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	EndPara(client);
}

public void OnGameFrame()
{
	static int i;
	static float speed[3], fallspeed;
	for(i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && IsPlayerAlive(i))
	{
		if(GetClientButtons(i) & IN_JUMP)
		{
			if(!bUsed[i])
			{
				bUsed[i] = true;
				bFalling = false;
			}
			fallspeed = fFallSpeed*(-1.0);
			GetEntDataVector(i, m_vecVelocity, speed);
			if(speed[2] >= fallspeed) bFalling = true;
			if(speed[2] < 0.0)
			{
				if(bFalling && !bLinear) {}
				else if(bFalling && bLinear || !fDecrease) speed[2] = fallspeed;
				else speed[2] += fDecrease;
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, speed);
				SetEntDataVector(i, m_vecVelocity, speed);
				SetEntityGravity(i, 0.1);
			}
		}
		else if(bUsed[i])
		{
			bUsed[i] = false;
			EndPara(i);
		}
		GetEntDataVector(i, m_vecVelocity, speed);
		if(speed[2] >= 0 || GetEntityFlags(i) & FL_ONGROUND) EndPara(i);
	}
}

stock void EndPara(int client)
{
	SetEntityGravity(client, 1.0);
	bUsed[client] = false;
}
