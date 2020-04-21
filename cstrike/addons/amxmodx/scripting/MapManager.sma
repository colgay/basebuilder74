#include <amxmodx>

#define VERSION "0.1"

#define NULL -1
#define NEXTMOD_INFO "map_nextmod"
#define CURRMOD_INFO "map_currmod"

new Array:g_ModPrefix;
new Array:g_ModName, Array:g_ModDesc;
new Array:g_ModMaps, Array:g_ModMapTrie;
new Array:g_ModPlugins, Array:g_ModConfigs;
new g_ModCount

new Array:g_MapList, Trie:g_MapTrie;
new g_MapCount;

new g_CurrentModId;
new g_CurrentMap[32];
new g_CurrentMapId;

new g_Nominated[MAX_PLAYERS+1][2];

new Array:g_NominatedMods, g_NumNominatedMods;
new Array:g_NominatedMaps, g_NumNominatedMaps;

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

    g_NominatedMods = ArrayCreate(1);
    g_NominatedMaps = ArrayCreate(1);

    FindAllMaps();
    LoadConfig();

    if (!g_ModCount)
    {
        set_fail_state("No mod loaded.");
        return;
    }

    ReloadMapList();

    get_mapname(g_CurrentMap, charsmax(g_CurrentMap));

    g_CurrentMapId = FindArrayIndexByString(g_MapList, g_CurrentMap);
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

public plugin_end()
{
    CreatePluginFile();
}

public client_putinserver(id)
{
    g_Nominated[id][0] = NULL;
    g_Nominated[id][1] = NULL;
}

public client_disconnected(id)
{
    UndoNominate(id, true);
}

public CmdSay(id)
{
	new msg[128];
	read_args(msg, charsmax(msg));
	remove_quotes(msg);

    new arg1[32], arg2[32];
    parse(msg, arg1, charsmax(arg1), arg2, charsmax(arg2));

    if (equal(arg1, "nom"))
    {
        if (strlen(arg2) < 3)
        {
            client_print_color(id, id, "^4[HKGSE]^1 想搵地圖嚟提名, 要打同地圖名相關嘅最少三隻字");
            return PLUGIN_CONTINUE;
        }

        ShowNominateMapMenu(id, arg2);
    }
    else if (equal(arg1, "undo") && equal(arg2, "nom"))
    {
        UndoNominate(id);
    }
    else if (strlen(arg1) >= 3 && !arg2[0])
    {
        new mapid = FindArrayIndexByString(g_MapList, arg1);
        if (mapid != NULL && CanNominateMap(id, arg1))
        {
            ShowNominateModMenu(id, arg1);
        }
    }

    return PLUGIN_CONTINUE;
}

public ShowNominateMapMenu(id, const match[])
{
    static buffer[100];
    formatex(buffer, charsmax(buffer), "提名地圖 \w%s \y", match)

    static mapname[32];
    new menu = menu_create(buffer, "HandleNominateMapMenu");

    for (new i = 0; i < g_MapCount; i++)
    {
        ArrayGetString(g_MapList, i, mapname, charsmax(mapname));

        if (!match[0] || containi(mapname, match) != -1)
        {
            if (g_CurrentMapId == i)
                formatex(buffer, charsmax(buffer), "\d%s \y(而家張圖)", mapname);
            else
                formatex(buffer, charsmax(buffer), "%s", mapname);
            
            menu_additem(menu, buffer, mapname);
        }
    }

	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleNominateMapMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}

	static mapname[32], dummy;
	menu_item_getinfo(menu, item, dummy, mapname, charsmax(mapname), _, _, dummy);
	menu_destroy(menu);

    if (CanNominateMap(id, mapname))
    {
        ShowNominateModMenu(id, mapname);
    }
}

public ShowNominateModMenu(id, const mapname[])
{
    static buffer[100], info[48];
    formatex(buffer, charsmax(buffer), "揀一個想喺 \w%s \y玩嘅模式 \y", mapname)

    new lastmod = NULL;
    new menu = menu_create(buffer, "HandleNominateModMenu");

    for (new i = 0; i < g_ModCount; i++)
    {
        if (!IsMapInMod(mapname, i))
            continue;
        
        if (g_CurrentModId == i)
            formatex(buffer, charsmax(buffer), "%a \y(而家玩緊)", ArrayGetStringHandle(g_ModName, i));
        else
            formatex(buffer, charsmax(buffer), "%a", ArrayGetStringHandle(g_ModName, i));
        
        formatex(info, charsmax(info), "%s %d", mapname, i);
        menu_additem(menu, buffer, info)

        lastmod = i;
    }

    if (menu_items(menu) < 2)
    {
        NominateMap(id, mapname, lastmod);

        menu_destroy(menu);
        return;
    }

    formatex(info, charsmax(info), "%s random", mapname);
    menu_additem(menu, "幫我揀", info);

	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu);
}

public HandleNominateModMenu(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return;
	}

	static info[48], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);

    static mapname[32], name[16]
    parse(info, mapname, charsmax(mapname), name, charsmax(name));

    new modid = NULL;
    if (equal(name, "random"))
    {
        // random pick a mod
        new Array:aMods = ArrayCreate(1);

        for (new i = 0; i < g_ModCount; i++)
        {
            if (!IsMapInMod(mapname, i))
                continue;
            
            ArrayPushCell(aMods, i);
        }

        modid = ArrayGetCell(aMods, random(ArraySize(aMods)));
        ArrayDestroy(aMods);

        client_print_color(id, id, "^4[HKGSE]^1 隨機幫你揀咗^3 %a", ArrayGetStringHandle(g_ModName, modid));
    }
    else
    {
        modid = str_to_num(name);
    }

    NominateMap(id, mapname, modid);
}

stock NominateMap(id, const mapname[], modid)
{
    if (!CanNominateMap(id, mapname) || modid == NULL)
        return 0;
    
    if (!IsModNominated(modid))
    {
        ArrayPushCell(g_NominatedMods, modid);
        g_NumNominatedMods++;
    }

    new mapid = FindArrayIndexByString(g_MapList, mapname);
    if (!IsMapNominated(mapid))
    {
        ArrayPushCell(g_NominatedMaps, mapid);
        g_NumNominatedMaps++;
    }

    g_Nominated[id][0] = mapid;
    g_Nominated[id][1] = modid;

    client_print_color(0, id, "^4[HKGSE]^3 %n ^1提名咗地圖^4 %s ^1(%a)", id, mapname, ArrayGetStringHandle(g_ModName, modid));
    return 1;
}

stock UndoNominate(id, bool:dont_notice=false)
{
    if (g_Nominated[id][0] == NULL)
    {
        if (!dont_notice)
            client_print_color(id, id, "^4[HKGSE]^1 你仲未提名過地圖, 如果想提名地圖, 打^3 nom part_of_mapname ^1(例如^3 nom dust^1)");
        
        return 0;
    }

    new mapid = g_Nominated[id][0];
    new modid = g_Nominated[id][1];

    g_Nominated[id][0] = NULL;
    g_Nominated[id][1] = NULL;

    new bool:hasmod = false;
    new bool:hasmap = false;

    for (new i = 1; i < MaxClients; i++)
    {
        if (!is_user_connected(i))
            continue;
        
        if (g_Nominated[id][1] == modid)
        {
            hasmod = true;
            break;
        }

        if (g_Nominated[id][0] == mapid)
        {
            hasmap = true;
            break;
        }
    }

    if (!dont_notice)
        client_print_color(0, id, "^4[HKGSE]^3 %n ^1取消咗提名^4 %a ^1(%a)", id, ArrayGetStringHandle(g_MapList, mapid), ArrayGetStringHandle(g_ModName, modid));

    new message[180];

    if (!hasmod)
    {
        new index = FindArrayIndexByCell(g_NominatedMods, modid);
        ArrayDeleteItem(g_NominatedMods, index);
        g_NumNominatedMods--;

        if (!dont_notice)
            formatex(message, charsmax(message), "^4 模式^3 %a", ArrayGetStringHandle(g_ModName, modid));
    }

    if (!hasmap)
    {
        new index = FindArrayIndexByCell(g_NominatedMaps, mapid);
        ArrayDeleteItem(g_NominatedMaps, index);
        g_NumNominatedMaps--;

        if (!dont_notice)
            format(message, charsmax(message), "%s %s^4 地圖^3 %a", message, message[0] ? "^1同" : "", ArrayGetStringHandle(g_MapList, mapid));
    }

    if (message[0])
    {
        client_print_color(0, print_team_default, "%s ^1已經喺提名名單上移除", message);
    }

    return 1;
}

stock bool:CanNominateMap(id, const mapname[])
{
    if (g_Nominated[id][0] != NULL)
    {
        client_print_color(id, id, "^4[HKGSE]^1 每人只可以提名一張地圖, 如果你想再提名過, 打^3 undo nom ^1取消之前嘅提名");
        return false;
    }

    new mapid = FindArrayIndexByString(g_MapList, mapname);
    if (mapid == g_CurrentMapId)
    {
        client_print_color(id, id, "^4[HKGSE]^1 你唔可以提名而家玩緊嘅地圖");
        return false;
    }

    if (IsMapNominated(mapid) && !HasModToNominate(mapname))
    {
        client_print_color(id, id, "^4[HKGSE]^1 呢張地圖已經俾人提名咗");
        return false;
    }

    return true;
}

stock bool:HasModToNominate(const mapname[])
{
    new index;

    for (new i = 0; i < g_ModCount; i++)
    {
        if (!IsMapInMod(mapname, i))
            continue;
        
        index = FindArrayIndexByCell(g_NominatedMods, i);
        if (index != NULL) // already in nominated list
            continue;
        
        return true;
    }

    return false;
}

stock bool:IsModNominated(modid)
{
    for (new i = 0; i < g_NumNominatedMods; i++)
    {
        if (ArrayGetCell(g_NominatedMods, i) == modid)
            return true;
    }

    return false;
}

stock bool:IsMapNominated(mapid)
{
    for (new i = 0; i < g_NumNominatedMaps; i++)
    {
        if (ArrayGetCell(g_NominatedMaps, i) == mapid)
            return true;
    }

    return false;
}

stock CheckMod()
{
    new prefix[32];
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
    g_MapCount = 0;
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

    static name[32];
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

stock FindArrayIndexByCell(Array:which, cell)
{
    new size = ArraySize(which);

    for (new i = 0; i < size; i++)
    {
        if (ArrayGetCell(which, i) == cell)
            return i;
    }

    return NULL;
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

    return NULL;
}

stock CreatePluginFile()
{
    new prefix[32];
    get_localinfo(NEXTMOD_INFO, prefix, charsmax(prefix));

    if (!prefix[0])
        get_localinfo(CURRMOD_INFO, prefix, charsmax(prefix));

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