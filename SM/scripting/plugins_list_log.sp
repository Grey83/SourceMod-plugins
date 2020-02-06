public Plugin myinfo =
{
	name		= "Plugins list log",
	version		= "1.0.0",
	description	= "Saves plugins info to the log",
	author		= "Grey83",
	url			= "https://steamcommunity.com/groups/grey83ds"
}

public void OnAllPluginsLoaded()
{
	int i;
	Handle fileh, iter, plugin;
	char path[PLATFORM_MAX_PATH], name[64], ver[64], author[64], file[64];

	BuildPath(Path_SM, path, sizeof(path), "logs/plugins_list.log");
	fileh = OpenFile(path, "a");

	iter = GetPluginIterator();
	while(MorePlugins(iter))
	{
		plugin = ReadPlugin(iter);
		name[0] = ver[0] = author[0] = 0;
		GetPluginInfo(plugin, PlInfo_Name, name, sizeof(name));
		GetPluginInfo(plugin, PlInfo_Version, ver, sizeof(ver));
		GetPluginInfo(plugin, PlInfo_Author, author, sizeof(author));
		GetPluginFilename(plugin, file, sizeof(file));

		WriteFileLine(fileh, "%03i) %s\n\t \"%s\" v.%s by \"%s\"", ++i, file, name, ver, author);
	}
	WriteFileLine(fileh, "\tTotal plugins: %i\n", i);

	CloseHandle(iter);
	CloseHandle(fileh);
}