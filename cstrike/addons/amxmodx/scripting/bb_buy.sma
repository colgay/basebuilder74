// this is the shop system core

#include <amxmodx>
#include <bb_buy_const>

#define VERSION "0.1"

new const PREFIX[] = "^4[BUY2]^1";

new Array:g_ItemName;
new Array:g_ItemClassName;
new Array:g_ItemDesc;
new Array:g_ItemCost;
new g_ItemCount;

new Trie:g_ItemHash;

new g_MenuData[MAX_PLAYERS + 1];

new g_fwItemSelectPre, g_fwItemSelectPost;
new g_ForwardResult;

public plugin_init()
{
    register_plugin("[BB] Buy", VERSION, "holla");

    register_dictionary("basebuilder.txt");

    register_clcmd("buy2", "CmdBuy");

    g_ItemHash = TrieCreate();

    g_fwItemSelectPre = CreateMultiForward("bb_on_buy_item_select_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
    g_fwItemSelectPost = CreateMultiForward("bb_on_buy_item_select_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_natives()
{
    register_library("bb_buy");

    register_native("bb_buy_register_item", "native_register_item");
    register_native("bb_buy_find_item_id", "native_find_item_id");
    register_native("bb_buy_get_item_name", "native_get_item_name");
    register_native("bb_buy_get_item_desc", "native_get_item_desc");
    register_native("bb_buy_get_item_classname", "native_get_item_classname");
    register_native("bb_buy_get_item_cost", "native_get_item_cost");
    register_native("bb_show_buy_menu", "native_show_buy_menu");
    register_native("bb_buy_item", "native_buy_item");

    g_ItemName = ArrayCreate(32);
    g_ItemClassName = ArrayCreate(32);
    g_ItemDesc = ArrayCreate(48);
    g_ItemCost = ArrayCreate(1);
}

public CmdBuy(id)
{
    ShowBuyMenu(id);
}

public client_disconnected(id)
{
    g_MenuData[id] = 0;
}

public ShowBuyMenu(id)
{
    new buffer[128];
    formatex(buffer, charsmax(buffer), "%L", id, "BUY");

    new menu = menu_create(buffer, "HandleBuyMenu");
    new info[16];

    for (new i = 0; i < g_ItemCount; i++)
    {
        ExecuteForward(g_fwItemSelectPre, g_ForwardResult, id, i, 0, 0);

        if (g_ForwardResult == BB_ITEM_DONT_SHOW)
            continue;

        if (g_ForwardResult == BB_ITEM_NOT_AVAILABLE)
        {
            formatex(buffer, charsmax(buffer), "\d%a %a\R$%d", ArrayGetStringHandle(g_ItemName, i), 
                ArrayGetStringHandle(g_ItemDesc, i), GetItemCost(i));
        }
        else
        {
            formatex(buffer, charsmax(buffer), "%a \y%a\R$%d", ArrayGetStringHandle(g_ItemName, i), 
                            ArrayGetStringHandle(g_ItemDesc, i), GetItemCost(i));
        }
        
        num_to_str(i, info, charsmax(info));

        menu_additem(menu, buffer, info);
    }

    if (menu_items(menu) <= 0)
    {
        client_print_color(id, print_team_default, "%s %L", PREFIX, id, "FAIL_BUY");
		menu_destroy(menu);
		return;
    }

    g_MenuData[id] = min(g_MenuData[id], menu_pages(menu) - 1);

    menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
    menu_display(id, menu, g_MenuData[id]);
}

public HandleBuyMenu(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        g_MenuData[id] = 0;
        menu_destroy(menu);
        return;
    }

    g_MenuData[id] = item / 7;

    new info[16], dummy;
    menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
    menu_destroy(menu);

    new index = str_to_num(info);

    BuyItem(id, index, 0);
}

public native_register_item()
{
    new classname[32], name[32], desc[48];
    get_string(1, classname, charsmax(classname));
    get_string(2, name, charsmax(name));
    get_string(3, desc, charsmax(desc));

    new cost = get_param(4);

    return RegisterItem(classname, name, desc, cost);
}

public native_find_item_id()
{
    new classname[32];
    get_string(1, classname, charsmax(classname));

    return FindItemByClass(classname);
}

public native_get_item_classname()
{
    new itemid = get_param(1);

    new classname[32];
    GetItemClassName(itemid, classname, charsmax(classname));

    set_string(2, classname, get_param(3));
}

public native_get_item_name()
{
    new itemid = get_param(1);

    new name[32];
    GetItemName(itemid, name, charsmax(name));

    set_string(2, name, get_param(3));
}

public native_get_item_desc()
{
    new itemid = get_param(1);

    new desc[32];
    GetItemDesc(itemid, desc, charsmax(desc));

    set_string(2, desc, get_param(3));
}

public native_get_item_cost()
{
    new itemid = get_param(1);

    return GetItemCost(itemid);
}

public native_show_buy_menu()
{
    new id = get_param(1);
    ShowBuyMenu(id);
}

public native_buy_item()
{
    new id = get_param(1);
    new itemid = get_param(2);
    new ignorecost = get_param(3);

    BuyItem(id, itemid, ignorecost);
}

stock BuyItem(id, itemid, ignorecost=0)
{
    ExecuteForward(g_fwItemSelectPre, g_ForwardResult, id, itemid, ignorecost, 1);

    if (g_ForwardResult >= BB_ITEM_NOT_AVAILABLE)
        return;

    ExecuteForward(g_fwItemSelectPost, g_ForwardResult, id, itemid, ignorecost);
}

stock FindItemByClass(const classname[])
{
    new index;
    if (TrieGetCell(g_ItemHash, classname, index))
        return index;
    
    return BB_INVALID_ITEM;
}

stock RegisterItem(const classname[], const name[], const desc[], cost)
{
    TrieSetCell(g_ItemHash, classname, g_ItemCount);

    ArrayPushString(g_ItemClassName, classname);
    ArrayPushString(g_ItemName, name);
    ArrayPushString(g_ItemDesc, desc);
    ArrayPushCell(g_ItemCost, cost);

    g_ItemCount++;
    return (g_ItemCount - 1);
}

stock GetItemClassName(index, classname[], len)
{
    ArrayGetString(g_ItemClassName, index, classname, len);
}

stock GetItemName(index, name[], len)
{
    ArrayGetString(g_ItemName, index, name, len);
}

stock GetItemDesc(index, name[], len)
{
    ArrayGetString(g_ItemDesc, index, name, len);
}

stock GetItemCost(index)
{
    return ArrayGetCell(g_ItemCost, index);
}