#include <amxmodx>
#include <fun>
#include <cstrike>
#include <hamsandwich>
#include <basebuilder>

new const PREFIX[] = "^4[GUNS]^1";

new g_WeaponIndex[] =
{
    CSW_GLOCK18, CSW_USP, CSW_P228, CSW_DEAGLE, CSW_ELITE, CSW_FIVESEVEN, // a - f
    CSW_M3, CSW_XM1014, // g - h
    CSW_MAC10, CSW_TMP, CSW_UMP45, CSW_MP5NAVY, CSW_P90, // i - m
    CSW_GALIL, CSW_FAMAS, CSW_AK47, CSW_M4A1, CSW_SG552, CSW_AUG, // n - s
    CSW_SCOUT, CSW_AWP, CSW_G3SG1, CSW_SG550, // t - w
    CSW_M249 // x
};

new g_WeaponName[][] = 
{
    "", "P228", "", "Scout (light sniper)", "", "XM1014 (shotgun)", "", "MAC10 (smg)", "AUG (zoomable rifle)", 
    "", "Dual Elite", "FiveSeven", "UMP45 (smg)", "SG550 (auto sniper)", "Galil (rifle)", "Famas (rifle)",
    "USP", "Glock 18", "AWP (sniper)", "MP5 Navy", "M249 (machine gun)", "M3 (shotgun)", "M4A1", "TMP (smg)",
    "G3SG1 (auto sniper)", "", "Deagle", "SG552 (zoomable rifle)", "AK47", "", "P90",
};

new const g_WeaponSlotBits[] =
{ 
    // All weapons
    (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|
    (1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|
    (1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)|
    (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)|
    (1<<CSW_KNIFE)|(1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_C4),

    // Primary weapons
    (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|
    (1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|
    (1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90),
    
    // Secondary weapons
    (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE),

    // Knife
    (1<<CSW_KNIFE),

    // Grenades
    (1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE),

    // C4
    (1<<CSW_C4)
};

// Max BP ammo for weapons
new const g_MaxBpAmmo[] = { -1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90,
     90, 90, 100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100 };

new CvarPrimaryGuns[32], CvarSecondaryGuns[32];

new g_Selected[MAX_PLAYERS + 1][2];
new bool:g_Confirmed[MAX_PLAYERS + 1];
new bool:g_HasWeapon[MAX_PLAYERS + 1];

public plugin_init()
{
    register_plugin("[BB] Weapon Menu", "0.1", "holla");

    register_event("HLTV", "OnEventRestartRound", "a", "1=0", "2=0");

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);

    register_clcmd("say /guns", "CmdGuns");
    //register_clcmd("guns", "CmdGuns");

    register_dictionary("basebuilder.txt");

    new pcvar = create_cvar("bb_primary_guns", "gijklmnot");
    bind_pcvar_string(pcvar, CvarPrimaryGuns, charsmax(CvarPrimaryGuns));

    pcvar = create_cvar("bb_secondary_guns", "abcef");
    bind_pcvar_string(pcvar, CvarSecondaryGuns, charsmax(CvarSecondaryGuns));

    register_menucmd(register_menuid("Choose Weapon"), 1023, "HandleWeaponMenu");
}

public CmdGuns(id)
{
    if (!is_user_alive(id) || bb_is_user_zombie(id) || g_HasWeapon[id])
    {
        client_print_color(id, print_team_default, "%s %L", PREFIX, id, "FAIL_WEAPON");
        return PLUGIN_CONTINUE;
    }

    ShowWeaponMenu(id);
    return PLUGIN_CONTINUE;
}

public client_putinserver(id)
{
    g_Selected[id][0] = 0;
    g_Selected[id][1] = 0;
    g_Confirmed[id] = false;
    g_HasWeapon[id] = false;
}

public OnEventRestartRound()
{
    arrayset(g_Confirmed, false, sizeof(g_Confirmed));
    arrayset(g_HasWeapon, false, sizeof(g_HasWeapon));
}

public OnPlayerSpawn_Post(id)
{
    if (!is_user_alive(id))
        return;

    if (bb_is_user_zombie(id))
    {
        g_Confirmed[id] = false;
        g_HasWeapon[id] = false;
    }
    else
    {
        if (!g_Confirmed[id])
        {
            ShowWeaponMenu(id);
        }
        else if (!bb_is_build_phase())
        {
            GiveWeapons(id);
        }
    }
}

public ShowWeaponMenu(id)
{
    if (!is_user_alive(id) || bb_is_user_zombie(id) || g_HasWeapon[id])
        return;

    new weaponid;

    for (new i = 0; i < sizeof(g_WeaponIndex); i++)
    {
        weaponid = g_WeaponIndex[i];

        if (g_Selected[id][0] == 0)
        {
            if (read_flags(CvarPrimaryGuns) & (1 << i))
            {
                g_Selected[id][0] = weaponid;
                continue;
            }
        }
        if (g_Selected[id][1] == 0)
        {
            if (read_flags(CvarSecondaryGuns) & (1 << i))
            {
                g_Selected[id][1] = weaponid;
                continue;
            }
        }
    }
    
    new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0;

    new menu[512], len;

    len = formatex(menu, 511, "\y%L^n^n", id, "WEAPON_MENU");
    len += formatex(menu[len], 511-len, "\y1.\w %L:\y %s^n", id, "PRIMARY_WEAPON", g_WeaponName[g_Selected[id][0]]);
    len += formatex(menu[len], 511-len, "\y2.\w %L:\y %s^n", id, "SECONDARY_WEAPON", g_WeaponName[g_Selected[id][1]]);
    len += formatex(menu[len], 511-len, "^n\y3.\w %L^n", id, "CONFIRM_WEAPON");
    len += formatex(menu[len], 511-len, "\y0. \wExit");

    show_menu(id, keys, menu, 30, "Choose Weapon");
}

public HandleWeaponMenu(id, key)
{
    if (!is_user_alive(id) || bb_is_user_zombie(id) || g_HasWeapon[id])
        return;
    
    switch (key)
    {
        case 0:
        {
            ShowPrimaryMenu(id);
        }
        case 1:
        {
            ShowSecondaryMenu(id);
        }
        case 2:
        {
            ConfirmWeapons(id);
        }
    }
}

public ShowPrimaryMenu(id)
{
    new buffer[128];
    formatex(buffer, charsmax(buffer), "%L", id, "PRIMARY_WEAPON");

    new menu = menu_create(buffer, "HandlePrimaryMenu");

    new weaponid, info[10];

    for (new i = 0; i < sizeof g_WeaponIndex; i++)
    {
        if (~read_flags(CvarPrimaryGuns) & (1 << i))
            continue;

        weaponid = g_WeaponIndex[i];

        if (g_Selected[id][0] == weaponid)
            formatex(buffer, charsmax(buffer), "%s \y(selected)", g_WeaponName[weaponid]);
        else
            formatex(buffer, charsmax(buffer), "%s", g_WeaponName[weaponid]);
        
        num_to_str(weaponid, info, charsmax(info));

        menu_additem(menu, buffer, info);
    }

    menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
    menu_display(id, menu);
}

public HandlePrimaryMenu(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return;
    }

    if (!is_user_alive(id) || bb_is_user_zombie(id) || g_HasWeapon[id])
    {
        menu_destroy(menu);
        return;
    }

    new info[16], dummy;
    menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
    menu_destroy(menu);

    new weaponid = str_to_num(info);
    g_Selected[id][0] = weaponid;

    ShowWeaponMenu(id);

    client_print_color(id, print_team_default, "%s %L %L", PREFIX, id, "YOU_HAVE_CHOOSED_AS", g_WeaponName[g_Selected[id][0]], id, "PRIMARY_WEAPON");
}

public ShowSecondaryMenu(id)
{
    new buffer[128];
    formatex(buffer, charsmax(buffer), "%L", id, "SECONDARY_WEAPON");

    new menu = menu_create(buffer, "HandleSecondaryMenu");

    new weaponid, info[10];

    for (new i = 0; i < sizeof g_WeaponIndex; i++)
    {
        if (~read_flags(CvarSecondaryGuns) & (1 << i))
            continue;

        weaponid = g_WeaponIndex[i];

        if (g_Selected[id][1] == weaponid)
            formatex(buffer, charsmax(buffer), "%s \y(selected)", g_WeaponName[weaponid]);
        else
            formatex(buffer, charsmax(buffer), "%s", g_WeaponName[weaponid]);
        
        num_to_str(weaponid, info, charsmax(info));

        menu_additem(menu, buffer, info);
    }

    menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
    menu_display(id, menu);
}

public HandleSecondaryMenu(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return;
    }

    if (!is_user_alive(id) || bb_is_user_zombie(id) || g_HasWeapon[id])
    {
        menu_destroy(menu);
        return;
    }

    new info[16], dummy;
    menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
    menu_destroy(menu);

    new weaponid = str_to_num(info);
    g_Selected[id][1] = weaponid;

    ShowWeaponMenu(id);

    client_print_color(id, print_team_default, "%s %L %L", PREFIX, id, "YOU_HAVE_CHOOSED_AS", g_WeaponName[g_Selected[id][1]], id, "SECONDARY_WEAPON");
}

stock ConfirmWeapons(id)
{
    if (!is_user_alive(id) || bb_is_user_zombie(id) || g_HasWeapon[id])
        return;

    g_Confirmed[id] = true;

    if (bb_is_build_phase())
    {
        client_print_color(id, print_team_default, "%s ^3%L", PREFIX, id, "RECEIVE_GUNS_AFTER");
        return;
    }

    GiveWeapons(id);
}

stock GiveWeapons(id)
{
    DropSlotWeapons(id, 1);
    DropSlotWeapons(id, 2);

    new weaponname[32];

    get_weaponname(g_Selected[id][0], weaponname, charsmax(weaponname));
    give_item(id, weaponname);
    cs_set_user_bpammo(id, g_Selected[id][0], g_MaxBpAmmo[g_Selected[id][0]]);

    get_weaponname(g_Selected[id][1], weaponname, charsmax(weaponname));
    give_item(id, weaponname);
    cs_set_user_bpammo(id, g_Selected[id][1], g_MaxBpAmmo[g_Selected[id][1]]);

    g_HasWeapon[id] = true;
}

// My version
stock DropSlotWeapons(id, slot)
{
    new weapons[32], numWeapons;
    get_user_weapons(id, weapons, numWeapons);

    new weaponid, weaponname[32], ent;

    for (new i = 0; i < numWeapons; i++)
    {
        weaponid = weapons[i];

        if (~g_WeaponSlotBits[slot] & (1 << weaponid))
            continue;
        
        get_weaponname(weaponid, weaponname, charsmax(weaponname));
        ent = cs_find_ent_by_owner(-1, weaponname, id);
        
        if (ent && !ExecuteHamB(Ham_CS_Item_CanDrop, ent))
            continue;

        engclient_cmd(id, "drop", weaponname);
    }
}