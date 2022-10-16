static const float MAX_AFK_TIME = 180.0;	// 3 minutes (3*60) to kick
static const int MAX_AFK_DEATHS = 3;

bool
	bCheck[MAXPLAYERS+1];
int
	iDeathAFK[MAXPLAYERS+1];
float
	fTimeAFK[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_team", Event_Team);
	HookEvent("player_death", Event_Player);
	HookEvent("player_spawn", Event_Player);
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || IsFakeClient(client))
		return;

	if(GetUserFlagBits(client))	// ignore admins
	{
		if(bCheck[client]) bCheck[client] = false;
		return;
	}

	if(!(bCheck[client] = event.GetInt("team") > 1) || event.GetInt("oldteam") < 2) fTimeAFK[client] = 0.0;
}

public void Event_Player(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || IsFakeClient(client))
		return;

	bool admin = !!GetUserFlagBits(client);
	if(!admin && bCheck[client] && fTimeAFK[client] != 0.0 && name[7] == 'd'
	&& GetClientOfUserId(event.GetInt("attacker")))
		iDeathAFK[client]++;	// count AFK non-admin deaths from other players
	if(iDeathAFK[client] >= MAX_AFK_DEATHS) KickClient(client, "AFK death too much times (%i)", MAX_AFK_DEATHS);

	if((bCheck[client] = !admin && name[7] == 's' && GetClientTeam(client) > 1))
		fTimeAFK[client] == 0.0;
}

public void OnPlayerRunCmdPost(int client, int buttons)
{
	if(!bCheck[client]) return;

	static int old_buttons[MAXPLAYERS+1];
	if(buttons != old_buttons[client])
	{
		old_buttons[client] = buttons;
		fTimeAFK[client] = 0.0;
		return;
	}

	static float time;
	time = GetEngineTime();
	if(fTimeAFK[client] == 0.0)
	{
		fTimeAFK[client] = time;
		return;
	}

	time -= fTimeAFK[client];
	if(time > MAX_AFK_TIME) KickClient(client, "AFK too much time (%.1fsec)", time);
}

public void OnClientDisconnect(int client)
{
	iDeathAFK[client] = 0;
	fTimeAFK[client] = 0.0;
	bCheck[client] = false;
}