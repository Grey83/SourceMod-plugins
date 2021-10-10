#if defined _revival_included
	#endinput
#endif
#define _revival_included

#define REVIVAL_API_VERSION	11

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
 * @param client	Client index
 * @param type		Information type: RI_*
 * @return			Player information by selected type (-1 for wrong type)
 * @error			Invalid client index, client not connected, fake client or invalid information type.
 */
native int Revival_GetPlayerInfo(int client, int type);

/**
 * Setting current player values of selected type
 *
 * @param client	Client index
 * @param type		Information type: RI_*
 * @param value		Value of choosed type
 * @error			Invalid client index, client not connected, fake client, invalid information type or invalid value.
 */
native void Revival_SetPlayerInfo(int client, int type, int value);

/**
 * Called when a client changed status.
 *
 * @param reviver	Reviver index
 * @param target	Revive target index
 * @param frags		The number of frags that the reviver will receive
 * @param diff_hp	The amount by which the health of the reviver will be changed
 * @param health	The amount of health that the revival target will have (always > 0)
 */
forward void Revival_OnPlayerReviving(int reviver, int target, int &frags, int &diff_hp, int &health);
