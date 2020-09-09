#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools_sound>
#include <sdktools_stringtables>
#include <sdktools_tempents>

#if SOURCEMOD_V_MINOR > 10
	#define PL_NAME	"Medic"
	#define PL_VER	"09.09.2020y"
#endif


static const char
#if SOURCEMOD_V_MINOR < 11
	PL_NAME[]	= "Medic",
	PL_VER[]	= "09.09.2020y",
#endif
	PREFIX[]	= "\x03[Medic] \x01",
	CFG[]		= "configs/medic.ini",
	SND_START[]	= "sound/medic/medic.wav",
	SND_END[]	= "sound/buttons/button9.wav";

Handle
	hTimer[MAXPLAYERS+1];
KeyValues
	hKV;
bool
	bLate,
	bAdv,
	bMedic[MAXPLAYERS+1],
	bSound[2],
	bAlive[MAXPLAYERS+1],
	bBot[MAXPLAYERS+1];
int
	m_iAccount,
	iUses[MAXPLAYERS+1],
	iLimit,
	iHeal,
	iCost,
	iTeam[MAXPLAYERS+1],
	iTime[MAXPLAYERS+1];
char
	sCfgPath[PLATFORM_MAX_PATH],
	sSId[MAXPLAYERS+1][24];

public Plugin myinfo =
{
	name		= PL_NAME,
	version		= PL_VER,
	description	= "You can call a medic.",
	author		= "tuty, Danyas & GoDtm666 (rewritten by Grey83)",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if((m_iAccount = FindSendPropInfo("CCSPlayer", "m_iAccount")) < 1)
		LogError("Can't find offset 'm_iAccount' for 'CCSPlayer' (%s)!", m_iAccount ? "the property is not found" : "no offset is available");

	CreateConVar("sm_medic_version", PL_VER, PL_NAME, FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_SPONLY);

	ConVar cvar;
	cvar = CreateConVar("sm_medic_uses", "1", "Max uses per round (-1 - unlimited uses, 0 - disable plugin)", _, true, -1.0);
	iUses[0] = cvar.IntValue;
	cvar.AddChangeHook(CVarChanged_Uses);

	cvar = CreateConVar("sm_medic_limit", "40", "Min. health in which player can no longer use the command", _, true, 1.0, true, 100.0);
	iLimit = cvar.IntValue;
	cvar.AddChangeHook(CVarChanged_Limit);

	cvar = CreateConVar("sm_medic_heal", "100", "Max. value up to which health can be restored", _, true, _, true, 99999.0);
	iHeal = cvar.IntValue;
	cvar.AddChangeHook(CVarChanged_Heal);

	if(m_iAccount > 0)
	{
		cvar = CreateConVar("sm_medic_cost", "2000", "Command use cost", _, true, _, true, 16000.0);
		iCost = cvar.IntValue;
		cvar.AddChangeHook(CVarChanged_Cost);
	}

	cvar = CreateConVar("sm_medic_advert", "1", "", _, true, _, true, 1.0);
	bAdv = cvar.BoolValue;
	cvar.AddChangeHook(CVarChanged_Adv);

	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death, EventHookMode_Pre);
	HookEvent("player_team", Event_Team, EventHookMode_Pre);
	HookEvent("round_end", Event_End, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_medic_set", Cmd_MedicSet, ADMFLAG_ROOT, "sm_medic_set <+мин|-мин|мин> <STEAM_x:y:z>");
	RegAdminCmd("sm_medic_del", Cmd_MedicDel, ADMFLAG_ROOT, "sm_medic_del <STEAM_x:y:z>");

	RegAdminCmd("sm_medic_reload", Cmd_MedicReload, ADMFLAG_ROOT, "Reload DB");

	RegConsoleCmd("sm_medic", Cmd_Medic);

	AutoExecConfig(true, "medic");

	BuildPath(Path_SM, sCfgPath, sizeof(sCfgPath), CFG);
	if((hKV = CreateKeyValues("Medic")) && !FileToKeyValues(hKV, sCfgPath))
		SetFailState("Не удалось открыть файл '%s'", sCfgPath);

	if(!bLate) return;

	bLate = false;
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i))
	{
		OnClientPreAdminCheck(i);
		iTeam[i]	= GetClientTeam(i);
		bAlive[i]	= IsPlayerAlive(i);
	}
}

public void CVarChanged_Uses(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iUses[0] = cvar.IntValue;
}

public void CVarChanged_Limit(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iLimit = cvar.IntValue;
}

public void CVarChanged_Heal(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iHeal = cvar.IntValue;
}

public void CVarChanged_Cost(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iCost = cvar.IntValue;
}

public void CVarChanged_Adv(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bAdv = cvar.BoolValue;
}

public void OnMapStart()
{
	if((bSound[0] = FileExists(SND_START, false) && PrecacheSound(SND_START[6], true)))
		AddFileToDownloadsTable(SND_START);

	if((bSound[1] = PrecacheSound(SND_END[6], false))) AddFileToDownloadsTable(SND_END);
}

public void Event_End(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++) if(hTimer[i]) delete hTimer[i];
}

public void OnClientDisconnect(int client)
{
	ResetClientState(client);
	if(hTimer[client]) delete hTimer[client];
	iTeam[client] = 0;
	bAlive[client] = false;
	sSId[client][0] = 0;
}

public Action OnClientPreAdminCheck(int client)
{
//	ResetClientState(client);
	SDKHook(client, SDKHook_OnTakeDamage, Users_OnTakeDamage);
	bBot[client] = IsFakeClient(client);
	if(bBot[client] || !hKV || !sSId[client][0] && !GetClientAuthId(client, AuthId_Steam2, sSId[client], sizeof(sSId[])))
		return Plugin_Continue;

	static int expired;
	if((expired = KvGetNum(hKV, sSId[client])) < 1 || expired > GetTime())
	{
		iTime[client] = expired;
		bMedic[client] = true;
	}
	else
	{
		KvDeleteThis(hKV);
		KvRewind(hKV);
		KeyValuesToFile(hKV, sCfgPath);
	}
	KvRewind(hKV);
	return Plugin_Continue;
}

stock void ResetClientState(int client)
{
	iUses[client] = iTime[client] = 0;
	bMedic[client] = false;
}

public Action Cmd_MedicSet(int client, int args)
{
	if(!hKV) return Plugin_Handled;

	if(args < 2)
	{
		ReplyToCommand(client, "sm_medic_set <+мин|-мин|мин> <STEAM_x:y:z>");
		return Plugin_Handled;
	}

	char time[12];
	GetCmdArg(1, time, sizeof(time));
	int val = strlen(time), fist = (time[0] == '-' || time[0] == '+') ? 1 : 0;
	ReplySource source = GetCmdReplySource();	// хз необходимо ли
	if(val == fist) return ReplyWrongTime(client, source, time);

	for(int i = fist; i < val; i++) if(time[i] < '0' || time[i] > '9') return ReplyWrongTime(client, source, time);

	char sid[24];
	GetCmdArg(2, sid, sizeof(sid));
	if(strlen(sid) < 11 || sid[0] != 's' && sid[0] != 'S' || sid[5] != '_' || sid[7] != ':' || sid[9] != ':')
	{
		ReplyToCommand(client, "Неправильный формат SteamId: '%s'! Должен быть 'STEAM_x:y:z'.", sid);
		return Plugin_Handled;
	}

	val = StringToInt(time);
	if(fist && !val) return ReplyWrongTime(client, source, time);	// добавление/убавление нуля минут

	if(fist || val)
	{
		int current = KvGetNum(hKV, sid, -1), now = GetTime();
		if(current == -1 || current < now) current = now;
		val = val * 60 + current;
	}

	KvSetNum(hKV, sid, val);
	KvRewind(hKV);
	KeyValuesToFile(hKV, sCfgPath);
	ProcessPlayers(sid, true, val);

	return Plugin_Handled;
}

stock Action ReplyWrongTime(int client, ReplySource source, char[] time)
{
	source = SetCmdReplySource(source);	// хз необходимо ли
	ReplyToCommand(client, "Неправильно указано время: '%s'!", time);
	SetCmdReplySource(source);			// хз необходимо ли
	return Plugin_Handled;
}

public Action Cmd_MedicDel(int client, int args)
{
	if(!hKV) return Plugin_Handled;

	if(args < 1)
	{
		ReplyToCommand(client, "sm_medic_del <STEAM_x:y:z>");
		return Plugin_Handled;
	}

	char sid[24];
	GetCmdArg(1, sid, sizeof(sid));
	if(strlen(sid) < 11 || sid[0] != 's' && sid[0] != 'S' || sid[5] != '_' || sid[7] != ':' || sid[9] != ':')
	{
		ReplyToCommand(client, "Неправильный формат SteamId '%s'! Должен быть 'STEAM_x:y:z'.", sid);
		return Plugin_Handled;
	}

	KvRewind(hKV);
	if(KvDeleteKey(hKV, sid))
	{
		KvRewind(hKV);
		KeyValuesToFile(hKV, sCfgPath);
		ReplyToCommand(client, "Medic у игрока '%s' удален.", sid);
		ProcessPlayers(sid, false);
	}
	else ReplyToCommand(client, "SteamId '%s' в файле '%s' не найден.", sid, sCfgPath);

	return Plugin_Handled;
}

public Action Cmd_MedicReload(int client, int args)
{
	if(hKV) delete hKV;
	if((hKV = CreateKeyValues("Medic")) && !FileToKeyValues(hKV, sCfgPath))
		SetFailState("Не удалось открыть файл '%s'", sCfgPath);

	for(int i = 1; i <= MaxClients; i++) OnClientPreAdminCheck(i);

	return Plugin_Handled;
}

stock void ProcessPlayers(char[] sid, bool add, int time = 0)
{
	for(int i = 1; i <= MaxClients; i++) if(!strcmp(sSId[i], sid, false))
	{
		bMedic[i] = add;
		iTime[i] = time;
	}
}

public Action Users_OnTakeDamage(int client, int& attacker, int& inflictor, float& dmg, int& dmgtype, int& wpn, float force[3], float pos[3])
{
	if(client == attacker || !attacker || attacker > MaxClients || !IsClientInGame(attacker))
		return Plugin_Continue;

	if(!bBot[attacker] && iTeam[client] == iTeam[attacker])
	{
		static float time, start[MAXPLAYERS+1];
		if(bMedic[attacker] && !hTimer[client] && bAlive[attacker] && start[attacker] < (time = GetGameTime())
		&& GetClientHealth(client) < iHeal)
		{
			TE_Start("RadioIcon");
			TE_WriteNum("m_iAttachToClient", client);
			TE_SendToClient(attacker, 0.0);
			UsersFadeMedic(attacker, {255, 255, 0, 65});

			if(!bBot[client]) UsersFadeMedic(client, {242, 228, 228, 89});

			hTimer[client] = CreateTimer(0.03, Timer_Medic, GetClientUserId(client), TIMER_REPEAT);

			start[attacker] = time + 0.1;
			PrintToChat(attacker, "\x03[Medic]\x01 Игроку '%N' запущено восстановление здоровья.", client);
			if(!bBot[client]) PrintToChat(client, "\x03[Medic]\x01 '%N' запустил Вам восстановление здоровья.", attacker);
		}
		return Plugin_Handled;
	}

	if(hTimer[client]) delete hTimer[client];

	return Plugin_Continue;
}

public void UsersFadeMedic(int client, const int color[4])
{
	Handle hBuffer = StartMessageOne("Fade", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	BfWriteShort(hBuffer, 250);		// duration
	BfWriteShort(hBuffer, 0);
	BfWriteShort(hBuffer, 0x0001);
	BfWriteByte(hBuffer, color[0]);
	BfWriteByte(hBuffer, color[1]);
	BfWriteByte(hBuffer, color[2]);
	BfWriteByte(hBuffer, color[3]);
	EndMessage();
}

public Action Timer_Medic(Handle timer, int client)
{
	if(!(client = GetClientOfUserId(client)))
		return Plugin_Stop;

	if(!bAlive[client])
	{
		hTimer[client] = null;
		return Plugin_Stop;
	}

	static int hp;
	hp = GetClientHealth(client) + 1;
	if(hp <= iHeal)
	{
		SetEntityHealth(client, hp);
		return Plugin_Continue;
	}

	PrintToChat(client, "\x03[Medic]\x01 Здоровье успешно восстановлено.");
	if(bSound[1]) EmitSoundToClient(client, SND_END[6]);
	hTimer[client] = null;
	return Plugin_Stop;
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if(!iUses[0] || !(client = GetClientOfUserId(event.GetInt("userid")))) return;

	iUses[client] = 0;
	iTeam[client] = GetClientTeam(client);
	bAlive[client] = iTeam[client] > 1 && IsPlayerAlive(client);
	if(bMedic[client] && iTime[client] > 0 && GetTime() > iTime[client]) PurgeDB(client);
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if((client = GetClientOfUserId(event.GetInt("userid"))))
	{
		bAlive[client] = false;
		if(hTimer[client]) delete hTimer[client];
	}
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	if((client = GetClientOfUserId(event.GetInt("userid"))))
	{
		if((iTeam[client] = GetClientTeam(client)) < 2) bAlive[client] = false;
		if(hTimer[client]) delete hTimer[client];
	}
}

public Action Cmd_Medic(int client, int args)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Handled;

	if(!iUses[0])
	{
		PrintToChat(client, "%sИзвините, вы не можете использовать \x04Medic\x01!", PREFIX);
		return Plugin_Handled;
	}

	float time = GetGameTime();
	static float used[MAXPLAYERS+1];
	if(used[client] > time)
		return Plugin_Handled;

	used[client] = time + 1;

	if(!bMedic[client])
	{
		PrintToChat(client, "%sНет доступа., PREFIX");
		SendMark(client, false);
		return Plugin_Handled;
	}

	if(iTime[client] > 0)
	{
		int iTemp = GetTime(), sec = iTime[client] - iTemp;
		if(iTemp > iTime[client])
		{
			PurgeDB(client);
			SendMark(client);
			return Plugin_Handled;
		}
		PrintToChat(client, "%sДоступ к медику закончится через: %dд. %dч. %dм. %02dсек.", PREFIX, sec / 3600 / 24, sec / 3600 % 24, sec / 60 % 60, sec % 60);
	}

	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "%sВы не можете использовать \x04Medic \x01пока вы мертвы!", PREFIX);
		return Plugin_Handled;
	}

	if(iLimit <= GetClientHealth(client))
	{
		PrintToChat(client, "%sУ вас достаточно здоровья, вам не нужен \x04Medic\x01! Возвращайтесь в бой!", PREFIX);
		return Plugin_Handled;
	}

	if(iUses[0] > 0 && iUses[client] >= iUses[0])
	{
		PrintToChat(client, "%sВы можете использовать \x04Medic \x01только \x03%d \x01раз за раунд!", PREFIX, iUses[0]);
		SendMark(client);
		return Plugin_Handled;
	}

	int money = m_iAccount > 0 ? GetEntData(client, m_iAccount) : 0;
	if(iCost && money < iCost)
	{
		PrintToChat(client, "%sУ вас недостаточно средств чтобы использовать \x04Medic\x01! Вам нужно %d$", PREFIX, iCost);
		SendMark(client);
		return Plugin_Handled;
	}

	if(!hTimer[client])
	{
		iUses[client]++;
		hTimer[client] = CreateTimer(0.03, Timer_Medic, GetClientUserId(client), TIMER_REPEAT);

		if(iCost && m_iAccount > 0) SetEntData(client, m_iAccount, money - iCost);
		PrintToChat(client, "\x03[Medic]\x01 Лечение запущено!");
	}
	else PrintToChat(client, "\x03[Medic]\x01 Лечение в процессе!");

	return Plugin_Handled;
}

stock void PurgeDB(int client)
{
	PrintToChat(client, "%sДоступ к медику закончился.", PREFIX);

	bMedic[client] = false;
	iTime[client] = 0;

	KvRewind(hKV);
	if(KvDeleteKey(hKV, sSId[client]))
	{
		KvRewind(hKV);
		KeyValuesToFile(hKV, sCfgPath);
	}
}

stock void SendMark(int client, bool icon = true)
{
	if(bSound[0])
	{
		static float pos[3];
		GetClientAbsOrigin(client, pos);
		EmitAmbientSound(SND_START[6], pos, client, SNDLEVEL_DRYER);
	}
	if(!icon) return;

	TE_Start("RadioIcon");
	TE_WriteNum("m_iAttachToClient", client);
	TE_SendToAll();

	if(bAdv) PrintToChatAll("\x03%N \x01(ВЫЗОВ): \x04Medic!", client);
}