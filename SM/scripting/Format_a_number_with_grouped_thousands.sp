static const int NUM[] = {2147483649, -1000000000, (1 << 31), 2147483647};


public void OnPluginStart()
{
	PrintToServer("\n%i = %s",	NUM[0], SplitInt(NUM[0]));
	PrintToServer("%i = %s",	NUM[1], SplitInt(NUM[1]));
	PrintToServer("%i = %s",	NUM[2], SplitInt(NUM[2]));
	PrintToServer("%i = %s\n",	NUM[3], SplitInt(NUM[3]));
}

stock char SplitInt(int number)
{
	static const int JOIN = ' ';
	static bool kkk, kk, k;
	static int i, j;
	static char buffer[16];

	buffer[0] = buffer[1] = 0;
	if(number & (1 << 31))
	{
		buffer[0] = '-';
		j = ~number;
		if(number != (1<<31)) j++;
	}
	else j = number;

	if((kkk	= (i = j/1000000000) > 0))
		Format(buffer, sizeof(buffer), "%s%i%c", buffer, i, JOIN);
	if((kk	= (i = j/1000000%1000) > 0) || kkk)
		Format(buffer, sizeof(buffer), kkk ? "%s%03i%c" : "%s%i%c", buffer, i, JOIN);
	if((k	= (i = j/1000%1000) > 0) || kk || kkk)
		Format(buffer, sizeof(buffer), kk || kkk ? "%s%03i%c" : "%s%i%c", buffer, i, JOIN);
	i = j%1000;
	if(number == (1<<31)) i++;
	Format(buffer, sizeof(buffer), k || kk || kkk ? "%s%03i%c": "%s%d%c", buffer, i, JOIN);

	return buffer;
}