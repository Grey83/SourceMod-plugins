#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>

static const int	iColor[]= {0, 255, 0};	// R, G, B
static const float	fPosX	= -1.0,				// position	(from left to right)
					fPosY	= -1.0;				//			(from top to bottom)

bool bIsAdmin[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegAdminCmd("sm_bt", Cmd_ButtonInfoToggle, ADMFLAG_ROOT);
}

public Action Cmd_ButtonInfoToggle(int client, int args)
{
	if(!client) return Plugin_Handled;

	bIsAdmin[client] = !bIsAdmin[client];
	PrintToChat(client, "\x03Button info is \x04%sabled\x03!", bIsAdmin[client] ? "en" : "dis");

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	static int i, prev_buttons[MAXPLAYERS+1];
	if(bIsAdmin[client] && buttons != prev_buttons[client] && IsPlayerAlive(client))
	{
		static char buffer[256];
		buffer[0] = i = 0;
		for(; i < 32; i++) if(buttons & (1<<i)) Format(buffer, sizeof(buffer), "%s(1<<%2d)\n", buffer, i);
		prev_buttons[client] = buttons;

		i = 0;
		while(buffer[i]) i++;
		buffer[i-1] = 0;

		SetHudTextParams(fPosX, fPosY, 1.0, iColor[0], iColor[1], iColor[2], 255, 0, 0.0, 0.1, 0.1);
		ShowHudText(client, 8, buffer);
	}

	return Plugin_Continue;
}