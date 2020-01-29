#pragma semicolon 1
#pragma newdecls required

static const char
	PL_NAME[]	= "Kill Feed Control",
	PL_VER[]	= "1.0.0";

bool bCSGO;
int iMode;

public Plugin myinfo =
{
	name	= PL_NAME,
	version	= PL_VER,
	author	= "Grey83"
}

public void OnPluginStart()
{
	bCSGO = GetEngineVersion() == Engine_CSGO;

	CreateConVar("sm_killfeed_ctrl_version", PL_VER, PL_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cvar;
	(cvar = CreateConVar("sm_killfeed_ctrl_mode", "0", "Kiilfeed: 0 = disable, 1 = enable, 2 - hide team T death, 3 - hide team CT death, 4 - hide others deaths and kills", _, true, 0.0, true, 3.0)).AddChangeHook(CVarChanged);
	CVarChanged(cvar, "", "");

	AutoExecConfig(true, "killfeed_ctrl");
}

public void CVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iMode = cvar.IntValue;

	static bool hooked;
	if(hooked != (iMode == 1)) return;

	if((hooked = !hooked))
		HookEvent("player_death", Event_Death, EventHookMode_Pre);
	else UnhookEvent("player_death", Event_Death, EventHookMode_Pre);
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	if(iMode == 1) return;

	static int client;
	if(!iMode || iMode == 4 || (client = GetClientOfUserId(event.GetInt("userid"))) && iMode == GetClientTeam(client))
		event.BroadcastDisabled = true;
	if(iMode != 4) return;

	if(!IsFakeClient(client))
		event.FireToClient(client);
	if((client = GetClientOfUserId(event.GetInt("attacker"))) && !IsFakeClient(client))
		event.FireToClient(client);
	if(bCSGO && (client = GetClientOfUserId(event.GetInt("assister"))) && !IsFakeClient(client))
		event.FireToClient(client);

//	event.Cancel();	// раскомментировать, если будут утечки памяти
}