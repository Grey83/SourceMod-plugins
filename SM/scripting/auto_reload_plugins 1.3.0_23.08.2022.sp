#pragma semicolon 1

StringMap smPlugins;

public Plugin myinfo =
{
	name = "АвтоПерезапуск плагинов",
	version	= "1.3.0_23.08.2022 (rewritten by Grey83)",
	author = "Rustgame (VK: Rustgamesteam)",
	description = "Автоматический перезапуск плагинов, если вы изменили их."
}

public void OnPluginStart()
{
	smPlugins = new StringMap();
}

public void OnMapStart()
{
	CreateTimer(10.0, Timer_CheckPlugins, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckPlugins(Handle timer)
{
	char dir[512], plugin[256], path[128], stime[64];
	int val, time;
	BuildPath(Path_SM, dir, sizeof(dir), "plugins/autorestart");
	DirectoryListing files = OpenDirectory(dir);
	while(files.GetNext(plugin, sizeof(plugin)))
	{
		if((val = strlen(plugin) - 4) > 0 && !strcmp(plugin[val], ".smx", true))
		{
			FormatEx(path, sizeof(path), "%s/%s", dir, plugin);
			time = GetFileTime(path, FileTime_LastChange);
			if(!smPlugins.GetValue(plugin, val))
			{
				smPlugins.SetValue(plugin, GetFileTime(path, FileTime_LastChange));
				PrintToServer("> Плагин '%s' добавлен.", plugin);
			}
			else if(val != time)
			{
				FormatTime(stime, sizeof(stime), "%D - %T", time);
				PrintToServer("\n> Плагин %s перезапущен!\n| Размер файла: %i bytes\n| Дата изменения: %s\n", plugin, FileSize(path), stime);
				smPlugins.SetValue(plugin, time);
				ServerCommand("sm plugins reload \"autorestart/%s\"", plugin);
			}
		}
	}

	return Plugin_Continue;
}