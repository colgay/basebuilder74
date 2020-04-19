#include <amxmodx>

#define VERSION "0.1"

#define NULL -1
#define NEXTMOD_INFO "map_nextmod"
#define CURRMOD_INFO "map_currmod"

new Array:g_ModPrefix;
new Array:g_ModName;
new Array:g_ModDesc;
new Array:g_ModMaps;
new Array:g_ModMapTrie;
new Array:g_ModPlugins;
new Array:g_ModConfigs;
new g_ModCount

new Array:g_MapList;
new Trie:g_MapTrie;
new g_MapCount;

new g_CurrentModId;
new g_CurrentMap[32];
new g_CurrentMapId;

new g_Nominated[MAX_PLAYERS + 1] = {NULL, ...};
new Array:g_Nominations;
new g_NominationCount;

public plugin_precache()
{
    g_ModPrefix = ArrayCreate(32);
    g_ModName = ArrayCreate(32);
    g_ModDesc = ArrayCreate(32);
    g_ModMaps = ArrayCreate(1);
    g_ModMapTrie = ArrayCreate(1);
    g_ModPlugins = ArrayCreate(1);
    g_ModConfigs = ArrayCreate(1);
    g_MapList = ArrayCreate(32);
    g_MapTrie = TrieCreate();

    FindAllMaps();
    LoadConfig();

    if (!g_ModCount)
    {
		set_fail_state("No mod loaded.");
		return;
    }

    ReloadMapList();

    get_mapname(g_CurrentMap, charsmax(g_CurrentMap));

    g_CurrentMapId = FindArrayIndexByString(g_CurrentMap);
}

public plugin_init()
{
    register_plugin("Map Manger", VERSION, "holla");

    CheckMod();

    register_clcmd("say", "CmdSay");

    /*
    server_print("---------------- read file begin ----------------");

    new i, j, size;
    new Array:mapList = Invalid_Array;

    for (i = 0; i < g_ModCount; i++)
    {
        server_print("[%a]^n  name = %a^n  desc = %a^n  maps:", ArrayGetStringHandle(g_ModPrefix, i), 
            ArrayGetStringHandle(g_ModName, i), ArrayGetStringHandle(g_ModDesc, i));

        mapList = ArrayGetCell(g_ModMaps, i);
        size = ArraySize(mapList);

        for (j = 0; j < size; j++)
        {
            server_print("  - %a", ArrayGetStringHandle(mapList, j));
        }
    }

    server_print("---------------- read file end ----------------");
    */
}

public CmdSay(id)
{
	static msg[128];
	read_args(msg, charsmax(msg));
	remove_quotes(msg);

    static arg1[32], arg2[32];
    parse(msg, arg1, charsmax(arg1), arg2, charsmax(arg2));

    if (equal(arg1, "nom"))
    {
        ShowNominateMenu(id, arg2);
    }
}

public ShowNominateMenu(id, const match[])
{
    static buffer[100];
    formatex(buffer, charsmax(buffer), "提名地圖 \w%s \y", match)

    static mapname[32];
    new menu = menu_create(buffer, "HandleNominateMenu");

    for (new i = 0; i < g_MapCount; i++)
    {
        ArrayGetString(g_MapList, i, mapname, charsmax(mapname));

        if (!match[0] || containi(mapname, match) != -1)
        {
            if (g_CurrentMapId == i)
                formatex(buffer, charsmax(buffer), "\d%s \y(而家玩緊)", mapname);
            else if (g_Nominated[id] == i)
                formatex(buffer, charsmax(buffer), "%s \y(你提名咗)", mapname);
            else if (IsMapNominated(i))
                formatex(buffer, charsmax(buffer), "\d%s \y(人地提名咗)", mapname);
            else
                formatex(buffer, charsmax(buffer), "%s", mapname);
            
            menu_additem(menu, buffer, mapname);
        }
    }

	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleNominateMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}

	new dummy, info[32];
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);

    NominateMap(id, info);
}

stock NominateMap(id, const mapname[])
{
    if (g_Nominated[id] != NULL)
    {
        client_print_color(id, id, "^4[HKGSE] ^1每人只可以提名一張地圖, 如果你要再提名過, 打 say^3 renom ^1取消之前嘅提名");
        return;
    }

    new mapid = FindArrayIndexByString(g_MapList, mapname);
    if ()
}

stock bool:IsMapNominated(mapid)
{
    for (new i = 0; i < g_NominationCount; i++)
    {
        if (ArrayGetCell(g_Nominations, i) == mapid)
            return true;
    }

    return false;
}

stock CheckMod()
{
    static prefix[32];
    get_localinfo(NEXTMOD_INFO, prefix, charsmax(prefix));

    if (!prefix[0])
        get_localinfo(CURRMOD_INFO, prefix, charsmax(prefix));

    g_CurrentModId = FindArrayIndexByString(g_ModPrefix, prefix);
    
    if (g_CurrentModId == NULL || !IsMapInMod(g_CurrentMap, g_CurrentModId))
    {
        g_CurrentModId = NULL;

		for (new i = 0; i < g_ModCount; i++)
		{
			if (IsMapInMod(g_CurrentMap, i))
			{
				g_CurrentModId = i;
                break;
			}
		}

        if (g_CurrentModId != NULL)
        {
            ArrayGetString(g_ModPrefix, g_CurrentModId, prefix, charsmax(prefix));

            set_localinfo(CURRMOD_INFO, "");
            set_localinfo(NEXTMOD_INFO, prefix);

            server_print("[Map Manager] Current mod is invalid, new mod (%s) selected. Restarting server...", prefix);

            server_cmd("restart");
            server_exec();
        }
        else if (prefix[0])
        {
            set_localinfo(CURRMOD_INFO, "");
            set_localinfo(NEXTMOD_INFO, "");

            server_print("[Map Manager] Current mod is invalid, nothing selected. Restarting server...", prefix);

            server_cmd("restart");
            server_exec();
        }
    }
    else
    {
        server_print("[Map Manager] Current mod is (%s)", prefix);

        set_localinfo(CURRMOD_INFO, prefix);
        set_localinfo(NEXTMOD_INFO, "");
    }
}

stock LoadConfig()
{
    static basePath[100];
    get_localinfo("amxx_configsdir", basePath, charsmax(basePath));
    add(basePath, charsmax(basePath), "/mods");

    static filePath[100];
    formatex(filePath, charsmax(filePath), "%s/mods.ini", basePath);

    new fp = fopen(filePath, "r");
    if (!fp)
    {
        //fclose(fp);
        return;
    }

    static buffer[512];
    static key[64], value[448];
    static prefix[32], name[32], desc[32];

    new modid;

    while (!feof(fp))
    {
        fgets(fp, buffer, charsmax(buffer));

        if (!buffer[0] || buffer[0] == ';')
            continue;
        
        if (buffer[0] == '[')
        {
            modid = g_ModCount;
            strtok2(buffer[1], prefix, charsmax(prefix), buffer, charsmax(buffer), ']', TRIM_FULL);
            continue;
        }

        if (!prefix[0])
            continue;

        strtok2(buffer, key, charsmax(key), value, charsmax(value), '=', TRIM_FULL);

        if (equali(key, "name"))
        {
            copy(name, charsmax(name), value);
        }
        else if (equali(key, "desc"))
        {
            copy(desc, charsmax(desc), value);
        }
        else if (equali(key, "maps"))
        {
            while (value[0] != 0 && strtok2(value, key, charsmax(key), value, charsmax(value), ',', TRIM_FULL))
            {
                formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
                ReadModMaps(modid, filePath);
            }

            if (ArraySize(g_ModMaps) > modid && GetModMapsCount(modid) > 0)
            {
                ArrayPushString(g_ModPrefix, prefix);
                ArrayPushString(g_ModName, name);
                ArrayPushString(g_ModDesc, desc);
                ArrayPushCell(g_ModPlugins, Invalid_Array);
                ArrayPushCell(g_ModConfigs, Invalid_Array);

                g_ModCount++;
            }
        }
        else if (equali(key, "amxx"))
        {
            while (value[0] != 0 && strtok2(value, key, charsmax(key), value, charsmax(value), ',', TRIM_FULL))
            {
                formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
                ReadModPlugins(modid, filePath);
            }
        }
        else if (equali(key, "cfgs"))
        {
            while (value[0] != 0 && strtok2(value, key, charsmax(key), value, charsmax(value), ',', TRIM_FULL))
            {
                formatex(filePath, charsmax(filePath), "%s/%s", basePath, key);
                ReadModConfigs(modid, filePath);
            }
        }
    }

    fclose(fp);
}

stock bool:ReadModMaps(modid, const filePath[])
{
    new fp = fopen(filePath, "r");
    if (!fp)
    {
        //fclose(fp);
        return false;
    }

    // array and tries haven't created yet?
    if (ArraySize(g_ModMaps) <= modid)
    {
        // create them
        new Array:mapList = ArrayCreate(32);
        new Trie:mapTrie = TrieCreate();

        // push them to the mod
        ArrayPushCell(g_ModMaps, mapList);
        ArrayPushCell(g_ModMapTrie, mapTrie);
    }

    static buffer[128], name[48];

    while (!feof(fp))
    {
        fgets(fp, buffer, charsmax(buffer));
        parse(buffer, name, charsmax(name));

        trim(name);
        
        if (!name[0] || name[0] == ';')
            continue;
        
        HandleModMaps(modid, name);
    }

    fclose(fp);
    return true;
}

stock ReadModPlugins(modid, const filePath[])
{
    if (!file_exists(filePath))
        return 0;

	new Array:aPlugins = ArrayGetCell(g_ModPlugins, modid);
	if (aPlugins == Invalid_Array)
	{
		aPlugins = ArrayCreate(64);
		ArraySetCell(g_ModPlugins, modid, aPlugins);
	}

    ArrayPushString(aPlugins, filePath);
    return 1;
}

stock ReadModConfigs(modid, const filePath[])
{
    if (!file_exists(filePath))
        return 0;

	new Array:aConfigs = ArrayGetCell(g_ModConfigs, modid);
	if (aConfigs == Invalid_Array)
	{
		aConfigs = ArrayCreate(64);
		ArraySetCell(g_ModConfigs, modid, aConfigs);
	}

    ArrayPushString(aConfigs, filePath);
    return 1;
}

stock HandleModMaps(modid, const name[])
{
    new ex = 0;
    if (name[0] == ':') // exclude
        ex = 1;

    static name2[32], flags[32];
    argbreak(name[ex], name2, charsmax(name2), flags, charsmax(flags));

    trim(name2);
    trim(flags);

    if (name2[0] == '^0') // empty
        return 0;

    // "i"
    new bool:ignorecase = bool:(read_flags(flags) & (1 << 8));

    new len = strlen(name2);
    if (name2[len-1] == '*') // prefix_*
    {
        name2[len-1] = '^0';
        new len2 = len - 1;

        //server_print("----- search for ^"%s^" -----", name);

        new Array:list = ex ? ArrayGetCell(g_ModMaps, modid) : g_MapList;

        new size = ArraySize(list);
        static mapname[32];

        new count = 0;

        for (new i = 0; i < size; i++)
        {
            ArrayGetString(list, i, mapname, charsmax(mapname));

            if (!CompareString(mapname, name2, len2, ignorecase))
                continue;
            
            if (ex) // exclude
            {
                if (RemoveMapFromMod(modid, mapname))
                {
                    i--;
                    size--;
                    count--;
                }

                //server_print("removing map '%s' from mod(%d)", mapname, modid);
            }
            else // include
            {
                if (AddMapToMod(modid, mapname))
                    count++;
                
                //server_print("adding map '%s' to mod(%d)", mapname, modid);
            }

            //server_print("%s%s : %s", ex ? "exclude" : "include", ignorecase ? " (ignore case)" : "", mapname);
        }

        return count;
        //server_print("----- end of search -----");
    }
    // match whole map name
    else if (TrieKeyExists(g_MapTrie, name2))
    {
        if (ex) // exclude
        {
            if (RemoveMapFromMod(modid, name2))
            {
                //server_print("removing map '%s' from mod(%d)", name2, modid);
                return -1;
            }
        }
        else // add
        {
            if (AddMapToMod(modid, name2))
            {
                //server_print("adding map '%s' to mod(%d)", name2, modid);
                return 1;
            }
        }
    }

    return 0;
}

stock ReloadMapList()
{
    ArrayClear(g_MapList);
    TrieClear(g_MapTrie);

    static mapname[32];
    new Array:list = Invalid_Array;
    new size, i;

    for (new modid = 0; modid < g_ModCount; modid++)
    {
        list = ArrayGetCell(g_ModMaps, modid);
        size = ArraySize(list);

        for (i = 0; i < size; i++)
        {
            ArrayGetString(list, i, mapname, charsmax(mapname));

            if (TrieKeyExists(g_MapTrie, mapname))
                continue;
            
            ArrayPushString(g_MapList, mapname);
            TrieSetCell(g_MapTrie, mapname, 1);
            g_MapCount++;
        }
    }
}

stock GetModMapsCount(modid)
{
    new Array:list = ArrayGetCell(g_ModMaps, modid);
    return ArraySize(list);
}

stock AddMapToMod(modid, const mapname[])
{
    new Trie:trie = ArrayGetCell(g_ModMapTrie, modid);
    if (TrieKeyExists(trie, mapname))
        return 0;
    
    new Array:list = ArrayGetCell(g_ModMaps, modid);
    ArrayPushString(list, mapname);
    TrieSetCell(trie, mapname, 1);

    return 1;
}

stock RemoveMapFromMod(modid, const mapname[])
{
    new Array:list = ArrayGetCell(g_ModMaps, modid);

    static mapname[32];
    new size = ArraySize(list);

    for (new i = 0; i < size; i++)
    {
        ArrayGetString(list, i, name, charsmax(name));

        if (equal(name, mapname))
        {
            new Trie:trie = ArrayGetCell(g_ModMapTrie, modid);
            ArrayDeleteItem(list, i);
            TrieDeleteKey(trie, mapname);

            return 1;
        }
    }

    return 0;
}

stock CompareString(const source[], const string[], c=0, ignorecase=0)
{
    return ignorecase ? equali(source, string, c) : equal(source, string, c);
}

stock FindAllMaps()
{
    static fileName[48];
    new hDir = open_dir("maps", fileName, charsmax(fileName));

    if (!hDir)
    {
        server_print("dir ^"maps^" doesn't exists.");
        return;
    }

    do
    {
        new len = strlen(fileName)
        if (len <= 4 || !equali(fileName[len - 4], ".bsp"))
            continue;
        
        fileName[len - 4] = 0;
        
        if (is_map_valid(fileName))
        {
            //server_print("added map ^"%s^"", fileName);
            ArrayPushString(g_MapList, fileName);
            TrieSetCell(g_MapTrie, fileName, 1);
            g_MapCount++;
        }
    }
    while (next_file(hDir, fileName, charsmax(fileName)))

    close_dir(hDir);
}

stock IsMapInMod(const mapname[], modid)
{
    new Trie:trie = ArrayGetCell(g_ModMapTrie, modid);
    if (TrieKeyExists(trie, mapname))
        return true;
    
    return false;
}

stock FindArrayIndexByString(Array:which, const string[])
{
    static name[64];
    new size = ArraySize(which);

    for (new i = 0; i < size; i++)
    {
        ArrayGetString(which, i, name, charsmax(name));

        if (equal(name, string))
            return i;
    }

    return -1;
}

stock CreatePluginFile()
{
    static prefix[32];
    get_localinfo(NEXTMOD_INFO, prefix, charsmax(prefix));

	static basePath[100];
	get_localinfo("amxx_configsdir", basePath, charsmax(basePath));

	static pluginsFile[100];
	formatex(pluginsFile, charsmax(pluginsFile), "%s/plugins-mods.ini", basePath);

	if (file_exists(pluginsFile))
		delete_file(pluginsFile);

    new modid = FindArrayIndexByString(g_ModPrefix, prefix);
    if (modid == NULL)
        return;

    add(basePath, charsmax(basePath), "/mods");

    new Array:aPlugins = ArrayGetCell(g_ModPlugins, modid);
    if (aPlugins != Invalid_Array)
    {
        static fileToCopy[100];
        new size = ArraySize(aPlugins);

        for (new i = 0; i < size; i++)
        {
            ArrayGetString(aPlugins, i, fileToCopy, charsmax(fileToCopy));
            AppendPluginsFile(pluginsFile, fileToCopy);
        }
    }
}

stock AppendPluginsFile(const pluginsFile[], const fileToCopy[])
{
	const BUFFERSIZE = 256;

	new fp_read = fopen(fileToCopy, "rb");
	if (!fp_read)
		return 0;
	
	new fp_write = fopen(pluginsFile, "ab");
	
	static buffer[BUFFERSIZE];
	static readSize, size;
	
	fseek(fp_read, 0, SEEK_END);
	size = ftell(fp_read);
	fseek(fp_read, 0, SEEK_SET);
	
	for (new i = 0; i < size; i += BUFFERSIZE)
	{
		readSize = fread_blocks(fp_read, buffer, BUFFERSIZE, BLOCK_CHAR);
		fwrite_blocks(fp_write, buffer, readSize, BLOCK_CHAR);
	}
	
	fclose(fp_read);
	fclose(fp_write);
	return 1;
}