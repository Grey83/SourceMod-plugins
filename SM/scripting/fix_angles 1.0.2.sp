#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools> 

static const char PLUGIN_NAME[]		= "Fix angles";
static const char PLUGIN_VERSION[]	= "1.0.2";

Handle AngTimer;

ConVar hEnable;
bool bEnable;
ConVar hTime;
float fTime;

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	author		= "Grey83",
	description	= "Fixes error 'Bad SetLocalAngles' in server console",
	version		= PLUGIN_VERSION,
	url			= "https://forums.alliedmods.net/showthread.php?t=285750"
}

public void OnPluginStart()
{
	CreateConVar("sm_fix_angles_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	hEnable	= CreateConVar("sm_fix_angles_enable", "0", "Enables/disables the plugin", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	hTime	= CreateConVar("sm_fix_angles_time", "30", "The time between inspections of entities angles", FCVAR_NOTIFY, true, 10.0, true, 120.0);

	bEnable	= GetConVarBool(hEnable);
	fTime	= GetConVarFloat(hTime);

	HookConVarChange(hEnable, OnCVarChanged);
	HookConVarChange(hTime, OnCVarChanged);

	AutoExecConfig(true, "fix_angles");
}

public void OnCVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == hEnable)
	{
		bEnable = view_as<bool>(StringToInt(newValue));
		if(bEnable && AngTimer == null) AngTimer = CreateTimer(fTime, CheckAngles, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		else if(!bEnable && AngTimer != null) KillAngTimer();
	}
	else if (convar == hTime)
	{
		fTime = StringToFloat(newValue);
		if(AngTimer != null)
		{
			KillAngTimer();
			AngTimer = CreateTimer(fTime, CheckAngles, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

void KillAngTimer()
{
	KillTimer(AngTimer);
	AngTimer = null;
}

public void OnMapStart()
{
	if(bEnable) AngTimer = CreateTimer(fTime, CheckAngles, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckAngles(Handle timer)
{
	if(bEnable)
	{
		static int MaxEnt;
		MaxEnt = GetMaxEntities();
		for(int i = MaxClients +1; i <= MaxEnt; i++)
		{
			if(IsValidEntity(i) && HasEntProp(i, Prop_Send, "m_angRotation"))
			{
				static bool wrongAngle = false;
				static float ang[3];
				GetEntPropVector(i, Prop_Send, "m_angRotation", ang);
				for(int j; j < 3; j++)
				{
					if(ang[j] < -360 || ang[j] > 360)
					{
						ang[j] = float(RoundFloat(ang[j]) % 360);
						wrongAngle = true;
					}
				}
				if(wrongAngle) SetEntPropVector(i, Prop_Send, "m_angRotation", ang);
			}
		}
		return Plugin_Continue;
	}
	else return Plugin_Stop;
}