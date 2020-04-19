#include <amxmodx>
#include <fun>
#include <cstrike>
#include <hamsandwich>
#include <bb_buy>
#include <basebuilder>

#define VERSION "0.1"

// {classname, name, description, cost}
new const g_ItemInfo[][][] = 
{
    {"weapon_deagle", "Deagle", "pistol", "6"}, 
    {"weapon_xm1014", "XM1014", "shotgun", "8"}, 
    {"weapon_ak47", "AK47", "", "10"}, 
    {"weapon_m4a1", "M4A1", "", "10"},
    {"weapon_sg552", "SG552", "auto rifle", "12"},
    {"weapon_aug", "AUG", "auto rifle", "14"},
    {"weapon_awp", "AWP", "sniper", "15"},
    {"weapon_sg550", "SG550", "auto sniper", "16"},
    {"weapon_g3sg1", "G3SG1", "auto sniper", "17"},
    {"weapon_m249", "M249", "machine gun", "20"}
};

// Max BP ammo for weapons
new const g_MaxBpAmmo[] = { -1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90,
     90, 90, 100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100 };

new const g_WeaponType[] = { -1, 2, -1, 1, 4, 1, 5, 1, 1, 5, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 3, 1 };

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

new g_ItemFirstId = BB_INVALID_ITEM;
new g_ItemLastId;

public plugin_init()
{
    register_plugin("[BB] Item: Weapons", VERSION, "holla");

    for (new i = 0, itemid; i < sizeof(g_ItemInfo); i++)
    {
        itemid = bb_buy_register_item(g_ItemInfo[i][0], g_ItemInfo[i][1], g_ItemInfo[i][2], str_to_num(g_ItemInfo[i][3]));

        if (g_ItemFirstId == BB_INVALID_ITEM)
            g_ItemFirstId = itemid;

        g_ItemLastId = itemid;

        //server_print("BIW : #%d %s, %s, %s, %d", itemid, g_ItemInfo[i][0], g_ItemInfo[i][1], g_ItemInfo[i][2], str_to_num(g_ItemInfo[i][3]));
    }
}

public bb_on_buy_item_select_pre(id, itemid, ignorecost, pushed)
{
    if (itemid < g_ItemFirstId || itemid > g_ItemLastId)
        return BB_ITEM_AVAILABLE;
    
    if (!is_user_alive(id) || bb_is_user_zombie(id))
        return BB_ITEM_DONT_SHOW;
    
    if (bb_is_build_phase())
    {
        if (pushed)
            client_print_color(id, print_team_default, "^4[BUY2]^1 %L", id, "ITEM_AFTER_BUILD");

        return BB_ITEM_NOT_AVAILABLE;
    }

    return BB_ITEM_AVAILABLE;
}

public bb_on_buy_item_select_post(id, itemid, ignorecost)
{
    if (itemid < g_ItemFirstId || itemid > g_ItemLastId)
        return
    
    new index = itemid - g_ItemFirstId;

    new weaponname[32];
    copy(weaponname, charsmax(weaponname), g_ItemInfo[index][0]);

    new weaponid = get_weaponid(weaponname);
    DropSlotWeapons(id, g_WeaponType[weaponid]);

    give_item(id, weaponname);
    cs_set_user_bpammo(id, weaponid, g_MaxBpAmmo[weaponid]);
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