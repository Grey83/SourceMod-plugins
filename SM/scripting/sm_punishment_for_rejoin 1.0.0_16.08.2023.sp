#pragma semicolon 1
#pragma newdecls required

#include <sdktools_entinput>
#include <sdktools_functions>
#tryinclude <sdktools_variant_t>

StringMap
	hSId;
Handle
	hTimer[MAXPLAYERS+1];
char
	sSId[MAXPLAYERS+1][24];

static const char
	PL_NAME[]	= "Punishment for rejoin",
	PL_VER[]	= "1.0.0_16.08.2023";

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "Kills a player for trying to rejoin during the round",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnPluginStart()
{
	hSId = new StringMap();

	HookEvent("round_start", Event_Start, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_Spawn);
}

public void OnMapStart()
{
	OnMapEnd();
}

public void OnMapEnd()
{
	hSId.Clear();

	for(int i = 1; i <= MaxClients; i++)
	{
		sSId[i][0] = 0;
		hTimer[i] = null;
	}
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	hSId.Clear();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(!IsFakeClient(client)) FormatEx(sSId[client], sizeof(sSId[]), auth);
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")), val;
	if(client && sSId[client][0] && GetClientTeam(client) > 1 && hSId.GetValue(sSId[client], val))
		hTimer[client] = CreateTimer(0.5, Timer_Punish, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Punish(Handle timer, int client)
{
	if(!(client = GetClientOfUserId(client)))
		return Plugin_Stop;

	hTimer[client] = null;

	if(GetClientTeam(client) < 2 || !IsPlayerAlive(client))
		return Plugin_Stop;

	IgniteEntity(client, 1.5);	// Поджигаем игрока, чтобы он горел пока его бьют молнии
	SetVariantString("OnUser2 !self:SetHealth:1:1.4:1");	// и снижаем хп, чтобы под конец он умер

	PrintHintText(client, "Перезаход запрещён!");

	int tesla;
	if((tesla = CreateEntityByName("point_tesla")) == -1)
		return Plugin_Stop;

	// https://developer.valvesoftware.com/wiki/Point_tesla
	float pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	DispatchKeyValueVector(tesla, "origin", pos);
	DispatchKeyValueFloat(tesla, "m_flRadius", 100.0);
	DispatchKeyValueFloat(tesla, "beamcount_min", 5.0);	// Количество разрядов
	DispatchKeyValue(tesla, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(tesla, "m_Color", "31 127 255");	// Цвет
	DispatchKeyValueFloat(tesla, "thick_min", 3.0);		// Толщина разрядов
	DispatchKeyValueFloat(tesla, "thick_max", 7.0);
	DispatchKeyValueFloat(tesla, "lifetime_min", 0.2);	// Время существования разряда
	DispatchKeyValueFloat(tesla, "lifetime_max", 0.4);
	DispatchKeyValueFloat(tesla, "interval_min", 0.4);	// Время м/у разрядами
	DispatchKeyValueFloat(tesla, "interval_max", 0.6);

	DispatchSpawn(tesla);

	SetVariantString("!activator");
	AcceptEntityInput(client, "SetParent", client, tesla, 0);

	AcceptEntityInput(tesla, "TurnOn");
	AcceptEntityInput(tesla, "DoSpark");

	SetVariantString("OnUser1 !self:DoSpark::0.3:5");
	AcceptEntityInput(tesla, "AddOutput");
	AcceptEntityInput(tesla, "FireUser1");

	SetVariantString("OnUser2 !self:Kill::1.5:1");
	AcceptEntityInput(tesla, "AddOutput");
	AcceptEntityInput(tesla, "FireUser2");

	return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
	if(!sSId[client][0])
		return;

	if(hTimer[client]) delete hTimer[client];
	hSId.SetValue(sSId[client], 1);
	sSId[client][0] = 0;
}