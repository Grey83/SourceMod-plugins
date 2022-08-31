static const char STRING[] = "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb"

public void OnPluginStart()
{
	StringMap list;
	ExplodeString2StringMap(STRING, ";", list, _, true);
	list = CreateTrie();
	ExplodeString2StringMap(STRING, ";", list, _, true);
	ExplodeString2StringMap(STRING, ";", list, true, _);
	ExplodeString2StringMap(STRING, " ", list, _, true);
	delete list;
}

/**
 * Breaks a string into pieces and stores each piece into a StringMap.
 *
 * @param text              The string to split.
 * @param split             The string to use as a split delimiter.
 * @param str_map           StringMap to store chunks of text.
 * @param add               False (default) to keep only new strings, true add strings to existing strings.
 * @param copyRemainder     False (default) discard excess pieces, true to ignore
 *                          delimiters after last piece.
 * @return                  Number of strings retrieved.
 */

stock int ExplodeString2StringMap(const char[] text, const char[] split, StringMap &str_map, const bool add = false, const bool copyRemainder = false)
{
	PrintToServer("\n<ExplodeString>\nText: \"%s\"", text);
	PrintToServer("Split: \"%s\" StringMap: #%i", split, view_as<int>(str_map));

	// если StringMap не существует или разделитель - пустая строка, то завершаем выполнение разбивки
	if(!str_map || !split[0])
		return 0;

	int num;
	if(!add) str_map.Clear();
	else num = str_map.Size

	int len = strlen(text), bytes = GetCharBytes(split);
	char[] source = new char[len+1];

	strcopy(source, len+1, text);
	PrintToServer("Copy: \"%s\" (%i)", source, len);

	int i, size, start;
	while(i < len && text[i])
	{
		if(text[i] == split[0] && (bytes == 1 || !strncmp(split, text[i], bytes)))	// разделитель обнаружен
		{
			// вычисляем размер копируемого куска и сохраняем его, если он не нулевой
			if((size = i - start) > 0)
			{
				strcopy(source, size+1, text[start]);
				if(TrimString(source))	// удаляем пробелы в начале и конце куска
				{
					str_map.SetValue(source, start, true);	// сохраняем кусок строки в StringMap

					PrintToServer("| %2i) \"%s\" (%i)", str_map.Size, source, size);
				}
			}

			start = i+bytes;	// запоминаем положение первого символа после разделителя
			if(bytes > 1) i = start - 1;	// смещаем положение проверки на размер разделителя, если он больше одного байта
		}
		i++;
	}

	PrintToServer("copyRemainder: %s", copyRemainder ? "true" : "false");
	if(copyRemainder && (size = len - start) > 0)
	{
		strcopy(source, size+1, text[start]);
		if(TrimString(source))	// удаляем пробелы в начале и конце куска
		{
			str_map.SetValue(source, start, true);	// сохраняем кусок строки в StringMap

			PrintToServer("| %2i) \"%s\" (%i)", str_map.Size, source, size);
		}
	}

	PrintToServer("Added: %i", str_map.Size - num);
	PrintToServer("</ExplodeString>\n", source);

	return str_map.Size - num;
}
/*
<ExplodeString>
Text: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb"
Split: ";" StringMap: #0

<ExplodeString>
Text: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb"
Split: ";" StringMap: #358548061
Copy: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb" (43)
|  1) "sfbbvnfvg" (9)
|  2) "gb gvf" (6)
|  3) "gfvbn gvcnb" (13)
copyRemainder: true
|  4) "vfbvb" (6)
Added: 4
</ExplodeString>

<ExplodeString>
Text: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb"
Split: ";" StringMap: #358548061
Copy: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb" (43)
|  4) "sfbbvnfvg" (9)
|  4) "gb gvf" (6)
|  4) "gfvbn gvcnb" (13)
copyRemainder: false
Added: 0
</ExplodeString>

<ExplodeString>
Text: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb"
Split: " " StringMap: #358548061
Copy: "sfbbvnfvg;gb gvf;  gfvbn gvcnb; ;   ; vfbvb" (43)
|  1) "sfbbvnfvg;gb" (12)
|  2) "gvf;" (4)
|  3) "gfvbn" (5)
|  4) "gvcnb;" (6)
|  5) ";" (1)
|  5) ";" (1)
copyRemainder: true
|  6) "vfbvb" (5)
Added: 6
</ExplodeString>
*/
