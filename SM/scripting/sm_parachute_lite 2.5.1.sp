#include <sourcemod>
#include <sdktools>

static const String:PARACHUTE_VERSION[] = "2.5.1_reduced";

new g_iVelocity = -1,
	g_maxplayers = -1;

new Handle:g_fallspeed,
	Handle:g_linear,
	Handle:g_decrease;

new bool:isfallspeed,
	bool:inUse[MAXPLAYERS+1],
	bool:hasPara[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name		= "SM Parachute",
	author		= "SWAT_88",
	description	= "To use your parachute press and hold SPACE(+jump) button while falling.",
	version		= PARACHUTE_VERSION,
	url			= "https://forums.alliedmods.net/showthread.php?p=580269"
};

public OnPluginStart()
{
	LoadTranslations ("sm_parachute.phrases");

	CreateConVar("sm_parachute_version", PARACHUTE_VERSION, "SM Parachute Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_fallspeed	= CreateConVar("sm_parachute_fallspeed","100", "Speed of the fall when you use the parachute", FCVAR_NONE);
	g_linear	= CreateConVar("sm_parachute_linear","0", "0: disables linear fallspeed - 1: enables it", FCVAR_NONE, true, 0.0, true, 1.0);
	g_decrease	= CreateConVar("sm_parachute_decrease","50", "0: dont use Realistic velocity-decrease - x: sets the velocity-decrease.");
	
	AutoExecConfig(true, "sm_parachute_reduced");
	
	g_iVelocity = FindSendPropOffs("CBasePlayer", "m_vecVelocity[0]");
	g_maxplayers = GetMaxClients();
	HookEvent("player_death",PlayerDeath);
	HookConVarChange(g_linear, CvarChange_Linear);
}

public OnPluginEnd(){
	CloseHandle(g_fallspeed);
	CloseHandle(g_linear);
	CloseHandle(g_decrease);
}

public OnEventShutdown()
{
	UnhookEvent("player_death",PlayerDeath);
}

public OnClientPutInServer(client)
{
	inUse[client] = false;
	hasPara[client] = false;
	g_maxplayers = GetMaxClients();
}

public OnClientDisconnect(client){
	g_maxplayers = GetMaxClients();
}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){
	new client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	hasPara[client] = false;
	EndPara(client);
	return Plugin_Continue;
}

public StartPara(client,bool:open)
{
	decl Float:velocity[3];
	decl Float:fallspeed;
	if (g_iVelocity == -1) return;
	fallspeed = GetConVarFloat(g_fallspeed)*(-1.0);
	GetEntDataVector(client, g_iVelocity, velocity);
	if(velocity[2] >= fallspeed) isfallspeed = true;
	if(velocity[2] < 0.0)
	{
		if(isfallspeed && GetConVarInt(g_linear) == 0) {}
		else if((isfallspeed && GetConVarInt(g_linear) == 1) || GetConVarFloat(g_decrease) == 0.0) velocity[2] = fallspeed;
		else velocity[2] = velocity[2] + GetConVarFloat(g_decrease);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		SetEntDataVector(client, g_iVelocity, velocity);
		SetEntityGravity(client,0.1);
	}
}

public EndPara(client)
{
	SetEntityGravity(client,1.0);
	inUse[client]=false;
}

public Check(client)
{
	static Float:speed[3];
	GetEntDataVector(client,g_iVelocity,speed);
	static cl_flags;
	cl_flags = GetEntityFlags(client);
	if(speed[2] >= 0 || (cl_flags & FL_ONGROUND)) EndPara(client);
}

public OnGameFrame()
{
	static x;
	for (x = 1; x <= g_maxplayers; x++)
	{
		if (IsClientInGame(x) && IsPlayerAlive(x))
		{
			static cl_buttons;
			cl_buttons = GetClientButtons(x);
			if (cl_buttons & IN_JUMP)
			{
				if (!inUse[x])
				{
					inUse[x] = true;
					isfallspeed = false;
					StartPara(x,true);
				}
				StartPara(x,false);
			}
			else if (inUse[x])
			{
				inUse[x] = false;
				EndPara(x);
			}
			Check(x);
		}
	}
}

public CvarChange_Linear(Handle:cvar, const String:oldvalue[], const String:newvalue[]){
	if (StringToInt(newvalue) == 0)
	{
		for (new client = 1; client <= g_maxplayers; client++)
		{
			if (IsClientInGame(client) && IsPlayerAlive(client) && hasPara[client]) SetEntityMoveType(client,MOVETYPE_WALK);
		}
	}
}