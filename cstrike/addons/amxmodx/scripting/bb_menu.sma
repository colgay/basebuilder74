#include <amxmodx>
#include <cstrike>
#include <basebuilder>
#include <bb_buy>

public plugin_init()
{
    register_plugin("[BB] Menu", "0.1", "holla");

    register_clcmd("jointeam", "CmdJoinTeam");
    register_clcmd("chooseteam", "CmdJoinTeam");

    register_dictionary("basebuilder.txt");
}

public CmdJoinTeam(id)
{
	new CsTeams:team = cs_get_user_team(id)
	
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE;

    ShowMenu(id);
    return PLUGIN_HANDLED;
}

public ShowMenu(id)
{
    new buffer[128];
    formatex(buffer, charsmax(buffer), "%L", id, "TITLE_GAME");

    new menu = menu_create(buffer, "HandleMenu");

    formatex(buffer, charsmax(buffer), "%L", id, "BUY");
    menu_additem(menu, buffer);

    formatex(buffer, charsmax(buffer), "%L", id, "ZCLASS");
    menu_additem(menu, buffer);

    formatex(buffer, charsmax(buffer), "%L", id, "CHOOSE_WEAPON");
    menu_additem(menu, buffer);

    formatex(buffer, charsmax(buffer), "%L", id, "ZOMBIE_TK");
    menu_additem(menu, buffer);

    menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
    menu_display(id, menu);
}

public HandleMenu(id, menu, item)
{
    menu_destroy(menu);

    if (item == MENU_EXIT)
        return;
    
    switch (item)
    {
        case 0: bb_show_buy_menu(id);
        case 1: bb_show_zclass_menu(id);
        case 2: client_cmd(id, "say /guns");
        case 3: client_cmd(id, "say /tk")
    }
}