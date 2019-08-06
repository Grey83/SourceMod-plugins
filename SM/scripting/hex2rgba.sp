#pragma semicolon 1
#pragma newdecls required

public void OnPluginStart()
{
	RegConsoleCmd("sm_hex", Cmd_Hex);
}

public Action Cmd_Hex(int client, int args)
{
	if(!args)
		return Plugin_Handled;

	static char buffer[16];
	GetCmdArg(1, buffer, sizeof(buffer));
	int clr, num;
	if((num = IsColorValid(buffer)))
	{
		if(num < 5)
		{
//			PrintToServer("\nOld color value: '%s'", buffer);
			FormatEx(buffer, sizeof(buffer), ConvertColor(buffer, num));
//			PrintToServer("New color value: '%s'\n", buffer);
		}
		StringToIntEx(buffer, clr, 16);
		if(num%4) ReplyToCommand(client, "HEX color '%s' (0x%x) is '%d %d %d'!", buffer, clr, (clr & 0xFF0000) >> 16, (clr & 0xFF00) >> 8, clr & 0xFF);
		else ReplyToCommand(client, "HEX color '%s' is (0x%x) '%d %d %d %d'!", buffer, clr, (clr & 0xFF000000) >>> 24, (clr & 0xFF0000) >> 16, (clr & 0xFF00) >> 8, clr & 0xFF);
	}
	else ReplyToCommand(client, "HEX color '%s' is invalid!", buffer);

	return Plugin_Handled;
}

stock int IsColorValid(const char[] buffer)
{
	int i;
	while(buffer[i])
	{
		if(!(buffer[i] >= '0' && buffer[i] <= '9')
		&& !(buffer[i] >= 'A' && buffer[i] <= 'F')
		&& !(buffer[i] >= 'a' && buffer[i] <= 'f'))
			return 0;
		i++;
	}
	return i == 3 || i == 4 || i == 6 || i == 8 ? i : 0;
}

stock char ConvertColor(const char[] hex, int num)
{
	static char result[12];
	int i, j;
	for(; i <= num; i++) result[j++] = result[j++] = hex[i];
	result[j] = 0;
	return result;
}
