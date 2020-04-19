#include <amxmodx>
#include <fakemeta>
#include <csx>
#include <basebuilder>
#include <bb_money>

new g_Friend[MAX_PLAYERS + 1];

public plugin_init()
{
    register_plugin("[BB] Status Hud", "0.1", "holla");

	register_event("StatusValue", "ev_SetTeam",     "be", "1=1");
	register_event("StatusValue", "ev_ShowStatus",  "be", "1=2", "2!0");
	register_event("StatusValue", "ev_HideStatus",  "be", "1=1", "2=0");

    set_task(0.75, "TaskUpdateHud", 0, _, _, "b");
}

public ev_SetTeam(id)
{
	g_Friend[id] = read_data(2);
}

public ev_ShowStatus(id) //called when id looks at someone
{
	new pid = read_data(2);

	if (g_Friend[id] == 1)	// friend
	{
		new clip, ammo;
        new weaponid = get_user_weapon(pid, clip, ammo);
        
        new weaponname[32];

		if (weaponid)
        {
			xmod_get_wpnname(weaponid, weaponname, 31);
        }

		set_hudmessage(0, 255, 0, -1.0, 0.55, 0, 0.00, 5.0, 0.0, 0.5, 4);
		
		if (!bb_is_user_zombie(pid))
        {
            new colorname[32];
            bb_get_user_colorname(pid, colorname, charsmax(colorname));

			show_hudmessage(id, "%n^nHP: %d | Weapon: %s^nColor: %s", pid, pev(pid, pev_health), weaponname, colorname);
        }
        else
		{
            new classname[32];
            bb_get_user_classname(pid, classname, charsmax(classname));

			show_hudmessage(id, "%n^nClass: %s^nHealth: %d", pid, classname, pev(pid, pev_health));
		}
	} 
	else
	{
		set_hudmessage(255, 0, 0, -1.0, 0.55, 0, 0.00, 5.0, 0.0, 0.5, 4);
		
        if (bb_is_user_zombie(pid))
        {
			show_hudmessage(id, "%n", pid);
        }
		else
        {
            new colorname[32];
            bb_get_user_colorname(pid, colorname, charsmax(colorname));

			show_hudmessage(id, "%n^nColor: %s", pid, colorname);
        }
	}
}

public ev_HideStatus(id)
{
	set_hudmessage(.fxtime=0.0, .holdtime=0.1, .fadeintime=0.0, .fadeouttime=0.0, .channel=4);
	show_hudmessage(id, "^n");
}

public TaskUpdateHud()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (is_user_alive(i))
            ShowHud(i);
    }
}

stock ShowHud(id)
{
    new hp = pev(id, pev_health);
    new money = bb_money_get(id);

    new class[32];
    bb_get_user_classname(id, class, charsmax(class));

    if (bb_is_user_zombie(id))
    {
        set_hudmessage(200, 75, 0, -1.0, 0.875, 0, 0.0, 1.2, 0.0, 0.2, 3);
        show_hudmessage(id, "%L: %d | $%d^n%L: %s", id, "HUD_HEALTH", hp, money, id, "HUD_CLASS", class);
    }
    else
    {
        set_hudmessage(0, 255, 0, -1.0, 0.875, 0, 0.0, 1.2, 0.0, 0.2, 3);
        show_hudmessage(id, "%L: %d | $%d^n%L: %s", id, "HUD_HEALTH", hp, money, id, "HUD_CLASS", class);
    }
}