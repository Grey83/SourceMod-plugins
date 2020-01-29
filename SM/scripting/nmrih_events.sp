#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION 	"1.0"
#define PLUGIN_NAME 	 "[NMRiH] Events"
#define sName "-<NMRiH event>-"

new hNumber=0;

new bool:bSurvival = false;

public Plugin:myinfo =
{
	name =PLUGIN_NAME,
	author = "Grey83",
	description = "Shows events in NMRiH ds console.",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	CreateConVar("nmrih_events_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("achievement_earned", Event_AE);
	HookEvent("achievement_event", Event_A);
	HookEvent("ammo_checked", Event_AC);
	HookEvent("ammo_radial_closed", Event_ARC);
	HookEvent("ammo_radial_open", Event_ARO);
//	HookEvent("arrow_stick", Event_AS);
	HookEvent("cure", Event_C);
	HookEvent("extraction_begin", Event_EB);
	HookEvent("extraction_complete", Event_EC);
	HookEvent("extraction_expire", Event_EE);
	HookEvent("freeze_all_the_things", Event_FA);
	HookEvent("game_round_restart", Event_GRR);
	HookEvent("instant_zombie_spawn", Event_IZS);
//	HookEvent("keycode_enter", Event_KE);
	HookEvent("map_complete", Event_MC);
	HookEvent("new_wave", Event_Next);
	HookEvent("nmrih_practice_ending", Event_NPE);
	HookEvent("nmrih_reset_map", Event_RM);
	HookEvent("nmrih_round_begin", Event_RB);
//	HookEvent("npc_killed", Event_NK);
	HookEvent("object_destroyed", Event_OD);
	HookEvent("objective_begin", Event_OB);
	HookEvent("objective_complete", Event_Next);
	HookEvent("objective_fail", Event_OF);
	HookEvent("objective_text_changed", Event_OTC);
	HookEvent("pills_taken", Event_PT);
	HookEvent("player_active", Event_PA);
	HookEvent("player_death", Event_PD);
	HookEvent("player_extracted", Event_PE); // С сообщением о том, кто спасся
	HookEvent("player_hurt", Event_PH);
	HookEvent("player_join", Event_PJ);
	HookEvent("player_leave", Event_PL);
	HookEvent("safe_zone_damage", Event_SZD);
	HookEvent("safe_zone_deactivate", Event_SZDA);
	HookEvent("safe_zone_heal", Event_SZH);
	HookEvent("spec_target_updated", Event_STU);
	HookEvent("state_change", Event_SC);
	HookEvent("teamplay_round_start", Event_TRS);
	HookEvent("tokens_changed", Event_TC);
	HookEvent("WalkieSound", Event_WS);
	HookEvent("wave_complete", Event_Wave_Complete);
	HookEvent("wave_low_zombies", Event_WLZ);
	HookEvent("wave_system_begin", Event_WSB);
	HookEvent("wave_system_end", Event_WSE);
//	HookEvent("weapon_fired", Event_WF);
//	HookEvent("weapon_picked_up", Event_WPU);
//	HookEvent("zombie_head_split", Event_ZHS);
//	HookEvent("zombie_killed_by_fire", Event_ZKF);
	HookEvent("zombie_spawn_enabled", Event_ZSEd);
	HookEvent("zombie_spawn_updated", Event_ZSU);
	HookEvent("zombie_spawning_disable", Event_ZSD);
	HookEvent("zombie_spawning_enable", Event_ZSE);

	PrintToServer("%s v.%s has been successfully loaded!", PLUGIN_NAME, PLUGIN_VERSION);
}

public OnMapStart()
{
	hNumber=0;

	decl String:sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	bSurvival = !StrContains(sMap, "nms_");

	PrintToServer("%s Survival: %b", sName, bSurvival);
}

static const String:sAName[][] =
{
	"First Blood",
	"Rack It",
	"To Serve and Protect",
	"Mark It Zero",
	"Czechmate",
	"Let Your Inner Light Shine",
	"Stoner",
	"Lethal Weapon",
	"El Mariachi",
	"Sturm on the Horizon",
	"Special Weapons and Tactics",
	"White Death",
	"Motherland!",
	"Patrick Would Be Proud",
	"One for Each Eye",
	"357 Reasons",
	"Mare's Laig",
	"Box Office Hit",
	"Cabin Fever",
	"Year of the Zombie",
	"BOPE",
	" Clear Skies",
	"Freedom",
	"Closing Time!",
	"They're Coming to Get You, Barbara",
	"No Loitering",
	"Hey, Paul!",
	"Waiting for the Worms",
	"Chainsaw Massacre",
	"One Free Man",
	"Woodsman",
	"Hell's Kitchen",
	"Blunt Force Trauma",
	"Blinded By the Light",
	"Ace of Spades",
	"Solder This",
	"The Manhattan Project",
	"Remove the Head, Destroy the Brain",
	"Stabbity Style",
	"Only YOU",
	"Adolescent Resident",
	"Better Red Than Dead",
	"Boys of Summer",
	"Fire in the Hole!",
	"Come Get Some",
	"Some Room Left in Hell",
	"Pacifist",
	"We Got This!",
	"New York Minute",
	"Light's Out",
	"Rush Hour",
	"Party's Over",
	"Robin in the Hood",
	"Pincushion",
	"Hypochondriac",
	"Kevorkian",
	"Problem of Induction",
	"Band of Brothers",
	"Bare Knuckle",
	"But They Used to be People!",
	"Jungle Cleaver",
	"Just Watch Me Explode",
	"A Drink to go with the Food",
	"Safe Action",
	"Varmint Plinker",
	"For Whom the Bell Tolls",
	"It's Always Sunny in Liverpool",
	"Private Beach",
	"Sniper School",
	"Give 'Er",
	"Tri-Fold",
	"Saturday the 14th",
	"Havana on the Hudson",
	"Troll Toll",
	"Dingle Berry",
	"County of Kings",
	"Right Arm of the Free World",
	"Take it Back",
	"HAZMAT Team",
	"Hands Off My Man",
	"Heroics",
	"Katniss",
	"Social Responsibility",
	"Toofer Pt. 1",
	"Toofer Pt. 2",
	"Go Out with a BANG!",
	"All or None",
	"No Man Left Behind",
	"Way of the Zephyrs",
	"Ride the Rails",
	"Say Hello to Your Aunt Alicia!",
	"Honorary Warringtonian",
	"Army of the Dead",
	"Encore!",
	"Seven-mile Shantang",
	"PTSD",
	"Desensitization",
	"Maximum RPM",
	"Bloody Valentine",
	"No Sleep Till",
	"Tea Time",
	"Too Cleaver For Your Own Good",
	"Pass GO and Collect $200",
	"Early Bird Special",				// 103
	"Containment Loss",
	"There be No Shelter here!",
	"Commuter Hell"
};

public Event_AE(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "player");
	new iAID = GetEventInt(event, "achievement");
	PrintToServer("%N has earned the achievement '%s' (#%i)", client, sAName[iAID], iAID+1);
	PrintToChatAll("\x04%N \x01has earned the achievement \x04%s \x01(#\x04%i\x01)", client, sAName[iAID], iAID+1);
	LogToFileEx("logs/achievements.log", "Achievement '%s' (%i) earned by %N", sAName[iAID], iAID, client);
}

public Event_A(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:buffer[64];
	GetEventString(event, "achievement_name", buffer, sizeof(buffer));
	new iVal = GetEventInt(event, "cur_val");
	new iMax = GetEventInt(event, "max_val");
	new iUID = GetClientOfUserId(GetEventInt(event, "userid"));
	PrintToServer("%N's achievement %s progress: %i/%i", iUID, buffer, iVal, iMax);
	PrintToChatAll("\x04%N\x01's achievement \x04%s\x01 progress: \x04%i\x01/\x04%i", iUID, buffer, iVal, iMax);
	LogToFileEx("logs/achievements.log", "%N's achievement %s progress: %i/%i", iUID, buffer, iVal, iMax);
//	https://steamdb.info/app/224260/stats/
}

public Event_AC(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Ammo checked", sName);
}

public Event_ARC(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Ammo radial closed", sName);
}

public Event_ARO(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Ammo radial open", sName);
}
/*
public Event_AS(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Arrow stick", sName);
}
*/
public Event_C(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Cure", sName);
}

public Event_EB(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Extraction begin", sName);
	PrintToChatAll("\x04Extraction begin");
}

public Event_EC(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Extraction complete", sName);
	PrintToChatAll("\x04Extraction complete");
}

public Event_EE(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Extraction expire", sName);
	PrintToChatAll("\x04Extraction expire");
}

public Event_FA(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Freeze all the things", sName);
}

public Event_GRR(Handle:event, const String:name[], bool:dontBroadcast)
{
	hNumber=0;
	PrintToServer("%s Game round restart", sName);
}

public Event_IZS(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Instant zombie spawn", sName);
}
/*
public Event_KE(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Keycode enter", sName);
}
*/
public Event_MC(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Map complete", sName);
	PrintToChatAll("\x04Map complete");
}

public Event_Next(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(bSurvival)
	{
		new bool:bResupply = GetEventBool(event, "resupply");
		if(!bResupply)
		{
			hNumber++;
			PrintToServer("%s Wave: %d", sName, hNumber);
		}
		else
		{
			PrintToServer("%s Wave: %d (Resupply)", sName, hNumber);
		}
	}
	else
	{
		hNumber++;
		PrintToServer("%s Objective: %d", sName, hNumber);
	}
}

public Event_NPE(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Practice ending", sName);
}

public Event_RM(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Reset map", sName);
}

public Event_RB(Handle:event, const String:name[], bool:dontBroadcast)
{
	hNumber=0;
	PrintToServer("%s Round begin", sName);
}
/*
public Event_NK(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iEntity = GetEventInt(event, "entidx");
	new client = GetEventInt(event, "killeridx");
	new bTurned = GetEventBool(event, "isturned");
	if (0 < client <= MaxClients)
		PrintToServer("%s NPC killed\nEntIndex: %d\nKiller: %N\nTurned: %b", sName, iEntity, client, bTurned);
}
*/
public Event_OD(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Object destroyed", sName);
}

public Event_OB(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Objective begin", sName);
}

public Event_OC(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Objective complete", sName);
}

public Event_OF(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Objective fail", sName);
}

public Event_OTC(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Objective text changed", sName);
}

public Event_PT(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Pills taken", sName);
}

public Event_PA(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	PrintToServer("%s Player %N active", sName, client);
}

public Event_PD(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Player death", sName);
}

public Event_PE(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "player_id");
	PrintToServer("Player %N extracted", client);
	PrintToChatAll("\x01Player \x0700DF00%N \x01has been evacuated", client);
}

public Event_PH(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:sWeapon[64];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	new iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	new iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (0 < iAttacker <= MaxClients)
	{
		if (iAttacker != iVictim)
			PrintToServer("Player %N was attacked by %N with %s", iVictim, iAttacker, sWeapon);
		else PrintToServer("Player %N attacked himself with %s", iVictim, sWeapon);
	}
}

public Event_PJ(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Player join", sName);
}

public Event_PL(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Player leave", sName);
}

public Event_SZD(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Safe zone damage", sName);
}

public Event_SZDA(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iID = GetEventInt(event, "id");
	new bKilled = GetEventBool(event, "killed");
	if (!bKilled) PrintToServer("%s Safe zone %d deactivate", sName, iID);
	else PrintToServer("%s Safe zone %d deactivate (killed)", sName, iID);
}

public Event_SZH(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iIndex = GetEventInt(event, "index");
	new iAmount = GetEventInt(event, "amount");
	new iHealth = GetEventInt(event, "health");
	PrintToServer("%s Safe zone %d (%dHP) heal (+%d)", sName, iIndex, iHealth, iAmount);
}

public Event_STU(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Spec target updated", sName);
}

public Event_SC(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iState = GetEventInt(event, "state");
	new iGameType = GetEventInt(event, "game_type");
	PrintToServer("%s State changed to %d\nGame type: %d", sName, iState, iGameType);
}

public Event_TRS(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Teamplay round start", sName);
}

public Event_TC(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iTokens = GetEventInt(event, "tokens");
	PrintToServer("%s Tokens changed (%d)", sName, iTokens);
}

public Event_WS(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Walkie sound", sName);
}

public Event_Wave_Complete(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Wave %d complete", sName, hNumber);
}

public Event_WLZ(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Wave low zombies", sName);
}

public Event_WSB(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Wave system begin", sName);
}

public Event_WSE(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Wave system end", sName);
}
/*
public Event_WF(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Weapon fired", sName);
}

public Event_WPU(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Weapon picked up", sName);
}

public Event_ZHS(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "player_id");
	PrintToServer("%s Zombie head split\nKiller: %N", sName, client);
}

public Event_ZKF(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "igniter_id");
	new iEntity = GetEventInt(event, "zombie_id");
	PrintToServer("%s Zombie killed by fire.\nEntIndex: %d\nKiller: %N", sName, iEntity, client);
}
*/
public Event_ZSEd(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Zombie spawn enabled", sName);
}

public Event_ZSU(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Zombie spawn updated", sName);
}

public Event_ZSD(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Zombie spawning disable", sName);
}

public Event_ZSE(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("%s Zombie spawning enable", sName);
}