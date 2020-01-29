#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define SHORT_CD	1
#define LONG_CD		5

new bool:bLate,
	bool:bMsg,
	bool:bInGame[MAXPLAYERS+1],
	bool:bCanCauseDmg[MAXPLAYERS+1],
	bool:bInZone[MAXPLAYERS+1],
	iCooldown[MAXPLAYERS+1],
	iTimesRepeated[MAXPLAYERS+1],
	iFirstEntry[MAXPLAYERS+1],
	iTime,
	iTeam[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name		= "No Tspawn camp",
	author		= "Grey83",
	description	= "Prohibition camp for terrorists in respawn zone",
	version		= "1.0.0",
	url			= "http://steamcommunity.com/groups/grey83ds"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	bLate = late;
}

public OnPluginStart()
{
	if(!LibraryExists("sm_zones")) SetFailState("Plugin 'Map Zones' not exists!");
	else
	{
		new Handle:hMsg = FindConVar("sm_zones_show_messages");
		if(hMsg != INVALID_HANDLE) bMsg = GetConVarBool(hMsg);
	}

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_TeamChanged);

	if(bLate)
	{
		ServerCommand("sm_actzone myzone");
		for(new i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) OnClientPostAdminCheck(i);
		bLate = false;
	}

	CreateTimer(1.0, Timer_Check, _, TIMER_REPEAT);
}

public OnClientPostAdminCheck(client)
{
	bInGame[client] = true;
	ResetValues(client);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
	iTeam[client] = bInGame[client] = false;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	LoopClients();
	// Активируем нашу зону в начале раунда
	ServerCommand("sm_actzone myzone");
}

public Event_TeamChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
	static client;
	if((client = GetClientOfUserId(GetEventInt(event, "userid")))) iTeam[client] = GetClientTeam(client);
}

stock LoopClients()
{
	for(new i = 1; i <= MaxClients; i++) ResetValues(i);
}

stock ResetValues(client)
{
	bCanCauseDmg[client] = true;
	iCooldown[client] = iTimesRepeated[client] = iFirstEntry[client] = bInZone[client] = false;
}

public Action:OnEnteredProtectedZone(zone, client, const String:prefix[])
{
	if(!IsPlayerValid(client, CS_TEAM_T) || !IsPlayerAlive(client))
		return Plugin_Continue;

	// Проверяем наличие у зоны имени и его правильность
	decl String:name[MAX_NAME_LENGTH*2];
	if(GetEntPropString(zone, Prop_Data, "m_iName", name, sizeof(name)) < 10 || !StrEqual(name[8], "myzone", false))
		return Plugin_Continue;

	bInZone[client] = true;

	// если кулдаун закончился, то сохраняем новое время первого входа в зону и сбрасываем счётчик
	if(iCooldown[client] < iTime)
	{
		iFirstEntry[client] = iTime;
		iTimesRepeated[client] = 0;
	}
	// иначе, если со времени первого входа прошло более 39 секунд, то сразу запрещаем наносить урон
	// (для отсеивания самых хитрых, которые выбегают из зоны для сброса счётчика)
	else if(iTime - iFirstEntry[client] > 39)
	{
		iTimesRepeated[client] = 40;
		bCanCauseDmg[client] = false;
		if(!IsFakeClient(client) && bMsg) PrintToChat(client, "Вы не можете наносить урон противникам, пока находитесь в этой зоне!")
	}

	return Plugin_Continue;
}

public Action:Timer_Check(Handle:timer)
{
	iTime = GetTime()
	static i;
	for(i = 1; i <= MaxClients; i++)
	{
		// Если игрок не террорист, мёртв, не в зоне или уже не может наносить урон, то переходим к следующему
		if(!IsPlayerValid(i, CS_TEAM_T) || !IsPlayerAlive(i) || !bInZone[i] || !bCanCauseDmg[i]) continue;

		switch(++iTimesRepeated[i])
		{
			// ... через сколько секунд перестанет наноситься урон
			case 10,20,30: if(!IsFakeClient(i) && bMsg) PrintToChat(i, "Вы перестанtntт наносить урон, находясь на респауне, через %i сек!", 40 - iTimesRepeated[i]);
			case 40: // После 40 секунд отключим нанесение урона
			{
				bCanCauseDmg[i] = false;
				if(!IsFakeClient(i) && bMsg) PrintToChat(i, "Вы не можете наносить урон противникам, пока находитесь в этой зоне!")
			}
		}
	}

	return Plugin_Continue;
}

public Action:OnLeftProtectedZone(zone, client, const String:prefix[])
{
	if(!IsPlayerValid(client, CS_TEAM_T) || !IsPlayerAlive(client))
		return Plugin_Continue;

	// Проверяем наличие у зоны имени и его правильность
	decl String:name[MAX_NAME_LENGTH*2];
	if(GetEntPropString(zone, Prop_Data, "m_iName", name, sizeof(name)) < 10 || !StrEqual(name[8], "myzone", false))
		return Plugin_Continue;

	bInZone[client] = false;

	// Если игроку уже запрещено наносить урон, то кулдаун будет большим, если ещё нет - коротким
	iCooldown[client] = iTime + (bCanCauseDmg[client] ? SHORT_CD : LONG_CD);

	bCanCauseDmg[client] = true;
	if(!IsFakeClient(client) && bMsg) PrintToChat(client, "Вы снова можете наносить урон противникам!")

	return Plugin_Continue;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(IsPlayerValid(victim, CS_TEAM_CT) && IsPlayerValid(attacker, CS_TEAM_T) && !bCanCauseDmg[attacker])
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

stock bool:IsPlayerValid(client, team)
{
	return 0 < client <= MaxClients && IsClientInGame(client) && iTeam[client] == team;
}