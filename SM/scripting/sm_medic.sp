#pragma semicolon 1
#pragma newdecls required

static const char	NAME[]		= "Medic",
					VERSION[]	= "1.0.0";

bool bMax,
	bUsed[MAXPLAYERS+1];
int iHP,
	m_iMaxHealth;

public Plugin myinfo =
{
	name		= NAME,
	author		= "Grey83",
	description	= "Лечение единожды за раунд игрока, написавшего команду",
	version		= VERSION,
	url			= "https://steamcommunity.com/groups/grey83ds"
};

public void OnPluginStart()
{
	if((m_iMaxHealth = FindSendPropInfo("CCSPlayer", "m_iMaxHealth")) == -1)
		SetFailState("Can't find 'm_iMaxHealth' offset");

	CreateConVar("sm_medic_version", VERSION, NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar CVar;
	(CVar = CreateConVar("sm_medic_addhp", "50", "На какое значение увеличивать здоровье (0 - отключить плагин)", _, true, _)).AddChangeHook(CVarChanged_AddHP);
	iHP = CVar.IntValue;

	(CVar = CreateConVar("sm_medic_maxhp", "1", "Увеличивать здоровье: 1 - до максимального значения, 0 - выше максимального значения", _, true, _, true, 1.0)).AddChangeHook(CVarChanged_MaxHP);
	bMax = CVar.BoolValue;

	HookEvent("round_start", Event_NewRound);

	RegConsoleCmd("sm_medic", Cmd_Medic);
	RegConsoleCmd("sm_med", Cmd_Medic);

	AutoExecConfig(true, "medic");
}

public void CVarChanged_MaxHP(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	bMax = CVar.BoolValue;
}

public void CVarChanged_AddHP(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	iHP = CVar.IntValue;
}

public void OnClientConnected(int client)
{
	bUsed[client] = false;
}

public void Event_NewRound(Event event, char[] name, bool dontBroadcast)
{
	for(int i; i <= MaxClients; i++) bUsed[i] = false;
}

public Action Cmd_Medic(int client, int args)
{
	if(!client || !iHP)
		return Plugin_Handled;

	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "Только живые могут использовать эту команду!");
		return Plugin_Handled;
	}

	if(bUsed[client])
	{
		PrintToChat(client, "Вы можете использовать эту команду только 1 раз за раунд!");
		return Plugin_Handled;
	}

	int HP = GetClientHealth(client) + iHP, maxHP = GetEntData(client, m_iMaxHealth);
	if(bMax)
	{
		if((HP - iHP) >= maxHP)
		{
			PrintToChat(client, "У Вас слишком много здоровья для лечения!");
			return Plugin_Handled;
		}
		if(HP > maxHP) HP = maxHP;
	}
	PrintToChat(client, "Ваше здоровье увеличено на %iХП!", HP);
	SetEntityHealth(client, HP);
	bUsed[client] = true;

	return Plugin_Handled;
}