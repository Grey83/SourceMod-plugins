#pragma semicolon 1
#pragma newdecls required

#include <revival>

int
	m_iAccount,
	iReward,
	iLimit = 16000;

public Plugin myinfo =
{
	name		= "[Revival] Reward",
	version		= "1.0.2",
	description	= "Gives the player money for each player he revives.",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if((m_iAccount = FindSendPropInfo("CCSPlayer", "m_iAccount")) == -1)
	{
		FormatEx(error, err_max, "Unable to find offset CCSPlayer::m_iAccount.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar cvar = CreateConVar("sm_revival_reward", "300", "How much money to give for revival", _, true, _, true, 16000.0);
	cvar.AddChangeHook(CVarChanged_Reward);
	iReward = cvar.IntValue;

	if((cvar = FindConVar("mp_maxmoney")))
	{
		iLimit = cvar.IntValue;
		cvar.AddChangeHook(CVarChanged_Limit);
	}
}

public void CVarChanged_Reward(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iReward = cvar.IntValue;
}

public void CVarChanged_Limit(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iLimit = cvar.IntValue;
}

public void Revival_OnPlayerReviving(int reviver, int target, int &frags, int &diff_hp, int &health)
{
	if(!iReward) return;

	int money = GetEntData(reviver, m_iAccount);
	if(money >= iLimit) return;

	if((money+= iReward) > iLimit) money = iLimit;
	SetEntData(reviver, m_iAccount, money);
}