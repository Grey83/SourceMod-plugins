#if defined _revival_included
	#endinput
#endif
#define _revival_included

#define API_VERSION	10

enum
{
	RI_Revives,	// How many times during this round the player reviveded others
	RI_Revived,	// How many times during this round the player was reviveded by others
	RI_Target,	// Player's current target for revive
	RI_Percents	// Progress in reviving the target
};

/**
 * Getting current player information by selected type
 *
 * @param сlient	Client index
 * @param type		Information type: RI_*
 * @return			Player information by selected type (-1 for wrong type)
 * @error			Invalid client index, client not connected, or fake client.
 */
forward int Revival_GetPlayerInfo(int сlient, int type);

/**
 * Called when a client changed status.
 *
 * @param reviver	Reviver index
 * @param current	Revive target index
 * @param previous	The number of frags received for reviving
 */
forward void Revival_OnPlayerRevived(int reviver, int target, int frags);