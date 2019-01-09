/**************************************************************************
 *                             UTF-8 string                               *
 *                     Автор: Феникс(komashchenko)                        *
 *                            Version: 1.2                                *
 *                  http://zizt.ru/  http://hlmod.ru/                     *
 * 03.05.2015 - V1.0: Релиз                                               *
 * 02.06.2015 - V1.1: Исправлены баги                                     *
 * 09.01.2018 - V1.2: Переведено на новый синтаксис, добавлена функция    *
 *    (by Grey83)     UTF8CharInverse(), немного оптимизировано           *
 **************************************************************************/


//#include <string>	// нет никакой необходимости добавлять этот инклюд ещё раз

enum
{
	CType_strncmp,
	CType_strcmp,
	CType_StrContains
};

/**
 * Returns whether two strings are equal.
 *
 * @param str1			First string (left).
 * @param str2			Second string (right).
 * @param caseSensitive	If true (default), comparison is case sensitive.
 * 						If false, comparison is case insensitive.
 * @return				True if equal, false otherwise.
 */
stock bool UTF8StrEqual(const char[] str1, const char[] str2, bool caseSensitive=true)
{
	return !UTF8strcmp(str1, str2, caseSensitive);
}

/**
 * Compares two strings parts lexographically.
 *
 * @param str1			First string (left).
 * @param str2			Second string (right).
 * @param num			Number of characters to compare.
 * @param caseSensitive	If true (default), comparison is case sensitive.
 *						If false, comparison is case insensitive.
 * @return				-1 if str1 < str2
 *						0 if str1 == str2
 *						1 if str1 > str2
 */
stock int UTF8strncmp(const char[] str1, const char[] str2, int num, bool caseSensitive=true)
{
	return caseSensitive ? strncmp(str1, str2, num, true) : CheckStrings(str1, str2, CT_strncmp, num);
}

/**
 * Compares two strings lexographically.
 *
 * @param str1			First string (left).
 * @param str2			Second string (right).
 * @param caseSensitive	If true (default), comparison is case sensitive.
 *						If false, comparison is case insensitive.
 * @return				-1 if str1 < str2
 *						0 if str1 == str2
 *						1 if str1 > str2
 */
stock int UTF8strcmp(const char[] str1, const char[] str2, bool caseSensitive=true)
{
	return caseSensitive ? strcmp(str1, str2, true) : CheckStrings(str1, str2, CT_strcmp);
}

/**
 * Tests whether a string is found inside another string.
 *
 * @param str			String to search in.
 * @param substr		Substring to find inside the original string.
 * @param caseSensitive	If true (default), search is case sensitive.
 *						If false, search is case insensitive.
 * @return				-1 on failure (no match found). Any other value
 *						indicates a position in the string where the match starts.
 */
stock int UTF8StrContains(const char[] str, const char[] substr, bool caseSensitive=true)
{
	return caseSensitive ? StrContains(str, substr, true) : CheckStrings(str, substr);
}

stock int CheckStrings(const char[] str1, const char[] str2, int type = CType_StrContains, int num = 0)
{
	int a = strlen(str1)+190, b = strlen(str2)+190;
	char[] aa = new char[a];
	char[] bb = new char[b];
	strcopy(aa, a, str1);
	strcopy(bb, b, str2);
	UTF8CharToLower(aa);
	UTF8CharToLower(bb);
	switch(type)
	{
		case CType_strncmp:	return strncmp(aa, bb, num, true);
		case CType_strcmp:	return strcmp(aa, bb, true);
	}
	return StrContains(aa, bb, true);
}

/**
 * Делает из нижнего регистра верхний.
 *
 * @param string		строка для конвертации.
 * @return				количество символов которые были переведены в верхний регистр
 */
stock int UTF8CharToUpper(char[] string)
{
	int I, Byte, K;
	while(string[I])
	{
		Byte = string[I];
		if(Byte >= 128)
		{
			if(Byte >= 240)
			{
				if(strlen(string[I]) < 4) break;
				else I += 4;
			}
			else if(Byte >= 224)
			{
				if(strlen(string[I]) < 3) break;
				else I += 3;
			}
			else if(Byte >= 192)
			{
				if(strlen(string[I]) < 2) break;
				Byte = (Byte % 32) * 64;
				Byte += (string[I+1] % 64);
				if(1072 <= Byte <= 1103 || Byte == 1105 || 1110 <= Byte <= 1111 || Byte == 1169)
				{
					if(1105 <= Byte <= 1111) Byte = Byte-80;
					else if(Byte != 1169) Byte = Byte-32;
					else Byte--;
					string[I]	= 192 + Byte / 64;
					string[I+1]	= 128 + (Byte % 64);
					K++;
				}
				I += 2;
			}
			else break;
		}
		else
		{
			if(97 <= Byte <= 122)
			{
				string[I] = Byte-32;
				K++;
			}
			I++;
		}
	}
	return K;
}

/**
 * Делает из верхнего регистра нижний.
 *
 * @param string		строка для конвертации.
 * @return				количество символов которые были переведены в нижний регистр
 */
stock int UTF8CharToLower(char[] string)
{
	int I, Byte, K;
	while(string[I])
	{
		Byte = string[I];
		if(Byte >= 128)
		{
			if(Byte >= 240)
			{
				if(strlen(string[I]) < 4) break;
				else I += 4;
			}
			else if(Byte >= 224)
			{
				if(strlen(string[I]) < 3) break;
				else I += 3;
			}
			else if(Byte >= 192)
			{
				if(strlen(string[I]) < 2) break;
				Byte = (Byte % 32) * 64;
				Byte += (string[I+1] % 64);
				if(1040 <= Byte <= 1071 || Byte == 1025 || 1030 <= Byte <= 1031 || Byte == 1168)
				{
					if(1025 <= Byte <= 1031) Byte = Byte+80;
					else if(Byte != 1168) Byte = Byte+32;
					else Byte++;
					string[I]	= 192 + Byte / 64;
					string[I+1]	= 128 + (Byte % 64);
					K++;
				}
				I += 2;
			}
			else break;
		}
		else
		{
			if(65 <= Byte <= 90)
			{
				string[I] = Byte+32;
				K++;
			}
			I++;
		}
	}
	return K;
}

/**
 * Инвертирует регистр.
 *
 * @param string		строка для конвертации.
 * @return				количество символов, регистр которых был инвертирован
 */
stock int UTF8CharInverse(char[] string)
{
	int I, Byte, K;
	while(string[I])
	{
		Byte = string[I];
		if(Byte >= 128)
		{
			if(Byte >= 240)
			{
				if(strlen(string[I]) < 4) break;
				else I += 4;
			}
			else if(Byte >= 224)
			{
				if(strlen(string[I]) < 3) break;
				else I += 3;
			}
			else if(Byte >= 192)
			{
				if(strlen(string[I]) < 2) break;
				Byte = (Byte % 32) * 64;
				Byte += (string[I+1] % 64);
				if(Byte == 1025 || 1030 <= Byte <= 1031 || 1040 <= Byte <= 1071 || Byte == 1168)
				{
					if(1025 <= Byte <= 1031) Byte = Byte+80;
					else if(Byte != 1168) Byte = Byte+32;
					else Byte++;
					string[I]	= 192 + Byte / 64;
					string[I+1]	= 128 + (Byte % 64);
					K++;
				}
				else if(1072 <= Byte <= 1103 || Byte == 1105 || 1110 <= Byte <= 1111 || Byte == 1169)
				{
					if(1105 <= Byte <= 1111) Byte = Byte-80;
					else if(Byte != 1169) Byte = Byte-32;
					else Byte--;
					string[I]	= 192 + Byte / 64;
					string[I+1]	= 128 + (Byte % 64);
					K++;
				}
				I += 2;
			}
			else break;
		}
		else
		{
			if(65 <= Byte <= 90)
			{
				string[I] = Byte+32;
				K++;
			}
			else if(97 <= Byte <= 122)
			{
				string[I] = Byte-32;
				K++;
			}
			I++;
		}
	}
	return K;
}