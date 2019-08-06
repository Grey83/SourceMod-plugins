#pragma semicolon 1
#pragma newdecls required

static const float MULT[] =
{	// https://developer.valvesoftware.com/wiki/Dimensions
	1.0,		// units/s
	0.01905,	// meters/s
	0.06858,	// kilometers/h
	0.04261364	// miles/h
};
static const char UNIT[][] =
{
	"u/s",
	"m/s",
	"km/h",
	"mph"
};

Handle
	hTimer,
	hHUD;
int
	iUnit,
	iColor[4];
float
	fCD,
	fPosX,
	fPosY;

public Plugin myinfo =
{
	name		= "Simple speedometer",
	version		= "1.0.0",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
};

public void OnPluginStart()
{
	if(!(hHUD = CreateHudSynchronizer())) SetFailState("Can't create HUD");

	ConVar cvar;
	(cvar = CreateConVar("sm_speed_update", "0.5", "Speed ​​information refresh rate. 0 - disabled", _, true, _, true, 5.0)).AddChangeHook(CVarChanged_CD);
	fCD = cvar.FloatValue;

	(cvar = CreateConVar("sm_speed_unit", "1", "0 - units/s, 1 - meters/s, 2 - kilometers/h, 3 - miles/h", _, true, _, true, 3.0)).AddChangeHook(CVarChanged_Unit);
	iUnit = cvar.IntValue;

	(cvar = CreateConVar("sm_speed_color", "0 127 255 255", "HUD info color. Set by RGBA (0 - 255). Empty = opaque white", FCVAR_PRINTABLEONLY)).AddChangeHook(CVarChanged_Color);
	CVarChanged_Color(cvar, NULL_STRING, NULL_STRING);

	(cvar = CreateConVar("sm_speed_x", "-0.435", "Position from left to right (-1.0 - center)", _, true, -2.0, true, 1.0)).AddChangeHook(CVarChanged_PosX);
	fPosX = cvar.FloatValue;

	(cvar = CreateConVar("sm_speed_y", "0.9", "Position from top to bottom (-1.0 - center)", _, true, -2.0, true, 1.0)).AddChangeHook(CVarChanged_PosY);
	fPosY = cvar.FloatValue;

	AutoExecConfig(true, "simple_speedometer");
}

public void CVarChanged_CD(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fCD = cvar.FloatValue;
	if(hTimer) delete hTimer;
	if(fCD > 0) hTimer = CreateTimer(fCD, Timer_UpdateHUD, _, TIMER_REPEAT);
}

public void CVarChanged_Unit(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iUnit = cvar.IntValue;
}

public void CVarChanged_Color(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	char buffer[16], parts[4][4];
	cvar.GetString(buffer, sizeof(buffer));
	ExplodeString(buffer, " ", parts, sizeof(parts), sizeof(parts[]));
	for(int i; i < 4; i++)
	{
		if(StringIsNumeric(parts[i]))
		{
			iColor[i] = StringToInt(parts[i]);
			if(iColor[i] > 255)		iColor[i] = 255;
			else if(iColor[i] < 0)	iColor[i] = 0;
		}
		else iColor[i] = 255;
	}
}

stock bool StringIsNumeric(const char[] str)
{
	if(!str[0]) return false;

	int x;
	while(str[x])
	{
		if(str[x] < '0' || str[x] > '9') return false;
		x++;
	}
	return true;
}

public void CVarChanged_PosX(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fPosX = cvar.FloatValue;
}

public void CVarChanged_PosY(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fPosY = cvar.FloatValue;
}

public void OnMapStart()
{
	if(fCD > 0) hTimer = CreateTimer(fCD, Timer_UpdateHUD, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	if(hTimer) delete hTimer;
}

public Action Timer_UpdateHUD(Handle timer)
{
	SetHudTextParams(fPosX, fPosY, fCD + 0.1, iColor[0], iColor[1], iColor[2], iColor[3], _, 0.0, _, 0.1);
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && GetClientTeam(i) > 1 && !IsFakeClient(i) && IsPlayerAlive(i)) ShowSpeed(i);

	return Plugin_Continue;
}

static void ShowSpeed(int client)
{
	static float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel);
	vel[2] = 0.0;

	ShowSyncHudText(client, hHUD, "%.3f %s", GetVectorLength(vel) * MULT[iUnit], UNIT[iUnit]);
}
