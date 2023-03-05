#pragma semicolon 1
#pragma newdecls required

#include <sdktools_engine>
#include <sdktools_entinput>
#include <sdktools_entoutput>
#include <sdktools_functions>
#include <sdktools_trace>
#tryinclude <sdktools_variant_t>

static const char
	PL_NAME[]		= "Healing Light",

	CFG_PATH[]		= "cfg/wS_Light.txt",
	LIGHT_MODEL[]	= "models/effects/vol_light64x256.mdl",
	LIGHT_SOUND[]	= "ambient/weather/rumble_rain.wav";
static const int
	MAX_LIGHTS		= 100;	// максимальное количество создаваемых точек лечащего света
static const float
	POS[]			= {387335538.0, 0.0, 0.0},
	MIN[]			= {-30.0, -30.0, -10.0},	// размеры триггера
	MAX[]			= { 30.0,  30.0, 256.0},	// размеры триггера
	MIN_DIST		= 75.0;	// минимальная дистанция м/у позициями лечащего света

Handle
	hTimer[MAXPLAYERS+1];
ArrayList
	hRef,
	hPos;
Menu
	hMenu;
int
	iHP,
	iMaxHP;

public Plugin myinfo =
{
	name		= PL_NAME,
	author		= "wS / Schmidt, Grey83",
	description	= "Исцеляющий свет",
	version		= "2.0.0",
	url			= "http://world-source.ru/"
}

public void OnPluginStart()
{
	ConVar cvar;
	cvar = CreateConVar("sm_healing_light_hp", "2", "Add HP per second", _, true, 2.0);
	cvar.AddChangeHook(CVar_HP);
	iHP = cvar.IntValue;

	cvar = CreateConVar("sm_healing_light_hp_max", "100", "Max HP while healing", _, true, 2.0);
	cvar.AddChangeHook(CVar_MaxHP);
	iMaxHP = cvar.IntValue;

	AutoExecConfig(true, "healing_light");

	HookEvent("round_start",Event_Round, EventHookMode_PostNoCopy);
	HookEvent("round_end",	Event_Round, EventHookMode_PostNoCopy);

	hMenu = new Menu(Handler_Menu, MenuAction_Display|MenuAction_DrawItem);
	hMenu.SetTitle("%s:\n ", PL_NAME);
	hMenu.AddItem("", "Create new");
	hMenu.AddItem("", "Delete (aim)\n \n    Settings (wS_Light.txt)");
	hMenu.AddItem("", "Reload");
	hMenu.AddItem("", "Save\n ");
	hMenu.ExitButton = true;

	RegAdminCmd("sm_light_admin", Cmd_Light, ADMFLAG_ROOT);

	hRef = new ArrayList();
	hPos = new ArrayList(3);
}

public void CVar_HP(ConVar cvar, char[] oldValue, const char[] newValue)
{
	iHP = cvar.IntValue;
}

public void CVar_MaxHP(ConVar cvar, char[] oldValue, const char[] newValue)
{
	iMaxHP = cvar.IntValue;
}

public void OnMapStart()
{
	LoadCfg();
//	PrecacheModel("models/props/cs_office/vending_machine.mdl", true);
	PrecacheModel(LIGHT_MODEL, true);
	PrecacheSound(LIGHT_SOUND, true);
}

stock void LoadCfg(bool reload = false)
{
	hRef.Clear();
	hPos.Clear();

	KeyValues KV = CreateKeyValues("Light");
	if(KV.ImportFromFile(CFG_PATH))
	{
		char map[64];
		GetMapname(map, sizeof(map));

		KV.Rewind();
		if(KV.JumpToKey(map) && KV.GotoFirstSubKey(false))
		{
			int i, entity = -1;
			float pos[3];
			do
			{
				KV.GetVector(NULL_STRING, pos, POS);
				if(pos[0] == POS[0])
					continue;

				hPos.PushArray(pos, 3);
				if(reload && (entity = wS_CreateLight(i)) != -1) entity = EntIndexToEntRef(entity);
				hRef.Push(entity);
			} while((i = hPos.Length) < MAX_LIGHTS && KV.GotoNextKey(false));
		}
	}
	else LogError("Config not found!");
	delete KV;
}

public void Event_Round(Event hEvent, const char[] name, bool dontBroadcast)
{
	int i = hPos.Length;
	if(name[6] == 'e')	// чистим референсы
	{
		while(--i >= 0) hRef.Set(i, -1);
	}
	else
	{
		int ent;
		while(--i >= 0) if((ent = wS_CreateLight(i)) != -1) hRef.Set(i, EntIndexToEntRef(ent));
	}
}

public void OnStartTouch(const char[] output, int ent, int client, float delay)
{
	if(0 < client <= MaxClients && !hTimer[client] && 0 < GetClientHealth(client) < iMaxHP)
		hTimer[client] = CreateTimer(1.0, Timer_Heal, client, TIMER_REPEAT);
}

public void OnEndTouch(const char[] output, int ent, int client, float delay)
{
	OnClientDisconnect(client);
}

public void OnClientDisconnect(int client)
{
	if(hTimer[client])
	{
		KillTimer(hTimer[client]);
		hTimer[client] = null;
	}
}

public Action Timer_Heal(Handle timer, int client)
{
	if(IsPlayerAlive(client))
	{
		int hp = GetClientHealth(client);
		if(hp < iMaxHP)
		{
			hp += iHP;
			if(hp > iMaxHP) hp = iMaxHP;
			SetEntityHealth(client, hp);
			if(hp < iMaxHP)
				return Plugin_Continue;
		}
	}

	hTimer[client] = null;
	return Plugin_Stop;
}

public Action Cmd_Light(int client, int args)
{
	if(client) hMenu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Handler_Menu(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_Display:
		{
			menu.SetTitle("%s: %i\n ", PL_NAME, hPos.Length);
		}
		case MenuAction_DrawItem:
		{
			switch(param)
			{
				case 0: return hPos.Length >= MAX_LIGHTS ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
				case 1: return hPos.Length < 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
			}
		}
		case MenuAction_Select:
		{
			static float end_pos[3];
			if(param != 2) wS_GetEndPos(client, end_pos);
			switch(param)
			{
				case 0: // создание
				{
					if(wS_ItsGoodDistForCreateLight(end_pos))
					{
						int i = hPos.Length;
						hPos.PushArray(end_pos, 3);
						int index = wS_CreateLight(i);
						if(index != -1)
						{
							hRef.Push(EntIndexToEntRef(index));
							PrintToChat(client, "\x04[ %s ] Light Created", PL_NAME);
							if(hPos.Length >= MAX_LIGHTS) PrintToChat(client, "[ %s ] Limit: %i", PL_NAME, MAX_LIGHTS);
						}
						else
						{
							hRef.Push(index);	// ArrayList.Set(i+1, index); - замена значения
							PrintToChat(client, "[ %s ] error.. oO", PL_NAME);
						}
					}
					else PrintToChat(client, "[ %s ] Here it is impossible", PL_NAME);
				}
				case 1: // удаление
				{
					int i = hRef.Length, ent;
					float pos[3];
					while(--i >= 0)
					{
						if((ent = hRef.Get(i)) == -1 || (ent = EntRefToEntIndex(ent)) == -1)
							continue;

						hPos.GetArray(i, pos, 3);
						if(GetVectorDistance(end_pos, pos) >= MIN_DIST)
							continue;

						hPos.Erase(i);
						hRef.Erase(i);
						DeleteEntity(ent);
						break;
					}
					if(ent == -1) PrintToChat(client, "[ %s ] Light not found (2)", PL_NAME);
				}
				case 2: // перезагрузка
				{
					int ent;
					while(hRef.Length)
					{
						if((ent = hRef.Get(0)) != -1 && (ent = EntRefToEntIndex(ent)) != -1) DeleteEntity(ent);
						hRef.Erase(0);
					}
					LoadCfg(true);
					PrintToChat(client, "\x04[ %s ] Settings reloaded (%i lights found)", PL_NAME, hPos.Length);
				}
				case 3: // сохранить
				{
					char buffer[64];
					GetMapname(buffer, sizeof(buffer));
					KeyValues KV = CreateKeyValues("Light");
					if(KV.ImportFromFile(CFG_PATH) && KV.JumpToKey(buffer))
					{
						KV.DeleteThis();
						KV.Rewind();
					}

					if(hPos.Length > 0)
					{
						KV.JumpToKey(buffer, true);
						int i = -1, max = hPos.Length;
						float pos[3];
						while(++i < max)
						{
							hPos.GetArray(i, pos, 3);
							FormatEx(buffer, sizeof(buffer), "%i", i);
							KV.SetVector(buffer, pos);
						}
					}

					KV.Rewind();
					if(!KV.ExportToFile(CFG_PATH))
					{
						LogError("Can't write file '%s'", CFG_PATH);
						PrintToChat(client, "\x04[ %s ] Failed to save settings (wS_Light.txt)", PL_NAME);
					}
					else PrintToChat(client, "\x04[ %s ] Settings have been saved (wS_Light.txt)", PL_NAME);
					delete KV;
				}
			}
			hMenu.Display(client, MENU_TIME_FOREVER);
		}
	}
	return 0;
}

void wS_GetEndPos(int client, float end_pos[3])
{
	float pos[3], ang[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);
	TR_TraceRayFilter(pos, ang, MASK_SOLID, RayType_Infinite, wS_Filter, client);
	TR_GetEndPosition(end_pos);
}

public bool wS_Filter(int ent, int mask, any client)
{
	return client != ent;
}

bool wS_ItsGoodDistForCreateLight(const float x_pos[3])
{
	int i = hPos.Length;
	float pos[3];
	while(--i >= 0)
	{
		hPos.GetArray(i, pos, 3);
		if(GetVectorDistance(x_pos, pos) < MIN_DIST)
			return false;
	}

	return true;
}

int wS_CreateLight(int num)
{
	int light = CreateEntityByName("prop_dynamic");
	if(light == -1)
	{
		LogError("Can't create 'prop_dynamic'!");
		return -1;
	}

	int trigger = CreateEntityByName("trigger_multiple");
	if(trigger == -1)
	{
		DeleteEntity(light);
		LogError("Can't create 'trigger_multiple'!");
		return -1;
	}

	int xMusic = CreateEntityByName("ambient_generic");

	// light
	float ground_pos[3], air_pos[3];
	hPos.GetArray(num, ground_pos, 3);
	air_pos = ground_pos;
	air_pos[2] += 256.0;
	DispatchKeyValueVector(light, "origin", air_pos);
	DispatchKeyValue(light, "model", LIGHT_MODEL);
	char light_name[20];
	Format(light_name, 20, "light_%d", light);
	DispatchKeyValue(light, "targetname", light_name);
	if(!DispatchSpawn(light))
	{
		DeleteEntity(light);
		DeleteEntity(trigger);
		DeleteEntity(xMusic);
		LogError("Can't spawn 'prop_dynamic'!");
		return -1;
	}

	// trigger
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "wait", "0");
	if(!DispatchSpawn(trigger))
	{
		DeleteEntity(light);
		DeleteEntity(trigger);
		DeleteEntity(xMusic);
		LogError("Can't spawn 'trigger_multiple'!");
		return -1;
	}

	ActivateEntity(trigger);
//	SetEntityModel(trigger, "models/props/cs_office/vending_machine.mdl");	// для триггеров вроде не нужно задавать модель
	TeleportEntity(trigger, ground_pos, NULL_VECTOR, NULL_VECTOR);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", MIN);
	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", MAX);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
	SetEntProp(trigger, Prop_Send, "m_fEffects", GetEntProp(trigger, Prop_Send, "m_fEffects")|32);
	SetVariantString(light_name);
	AcceptEntityInput(trigger, "SetParent");
	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch);

	if(xMusic != -1)
	{
		// xMusic
		DispatchKeyValueVector(xMusic, "origin", ground_pos);
		DispatchKeyValue(xMusic, "message", LIGHT_SOUND);
		DispatchKeyValue(xMusic, "radius", "700");
		DispatchKeyValue(xMusic, "health", "10");
		DispatchKeyValue(xMusic, "preset", "0");
		DispatchKeyValue(xMusic, "volstart", "10");
		DispatchKeyValue(xMusic, "pitch", "100");
		DispatchKeyValue(xMusic, "pitchstart", "100");
		if(DispatchSpawn(xMusic))
		{
			LogError("Can't spawn 'ambient_generic'!");
			ActivateEntity(xMusic);
			SetVariantString(light_name);
			AcceptEntityInput(xMusic, "SetParent");
			AcceptEntityInput(xMusic, "PlaySound");
		}
		else DeleteEntity(xMusic);
	}

	return light;
}

void DeleteEntity(int entity)
{
#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR < 10
	AcceptEntityInput(entity, "Kill");
#else
	RemoveEntity(entity);
#endif
}

void GetMapname(char[] map, int maxlength)
{
	GetCurrentMap(map, maxlength);
	if(strncmp(map, "workshop", 8, false))
		return;

	char id[12];
	FormatEx(id, sizeof(id), map[9]);
	int i = strlen(id);
	while(--i >= 0) if(id[i] == '/' || id[i] == '\\') id[i] = 0;
	GetMapDisplayName(map, map, maxlength);
	Format(map, maxlength, "%s_%s", id, map);
}