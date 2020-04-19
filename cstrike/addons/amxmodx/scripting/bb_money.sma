#include <amxmodx>
#include <cstrike>

#define VERSION "0.1"

const HIDE_MONEY_BIT = (1 << 5);

new g_Money[MAX_PLAYERS + 1];

new CvarStartMoney;

public plugin_init()
{
	register_plugin("[BB] Player Money", VERSION, "holla");

	register_event("ResetHUD", "OnEventResetHud", "be");
	register_message(get_user_msgid("Money"), "OnMessageMoney");

    new pcvar = create_cvar("bb_start_money", "999");
    bind_pcvar_num(pcvar, CvarStartMoney);
}

public plugin_natives()
{
	register_library("bb_money");

	register_native("bb_money_get", "native_money_get");
	register_native("bb_money_set", "native_money_set");
}

public client_putinserver(id)
{
    g_Money[id] = CvarStartMoney;
}

public OnEventResetHud(id)
{
    RequestFrame("HideMoneyHud", id);
}

public OnMessageMoney(msg_id, msg_dest, id)
{
	cs_set_user_money(id, 0, 0);
	return PLUGIN_HANDLED;
}

public HideMoneyHud(id)
{
    static msgHideWeapon, msgCrosshair;
    
    if (!msgHideWeapon || !msgCrosshair)
    {
        msgHideWeapon = get_user_msgid("HideWeapon");
        msgCrosshair = get_user_msgid("Crosshair");
    }

	// Hide money
	message_begin(MSG_ONE, msgHideWeapon, _, id)
	write_byte(HIDE_MONEY_BIT) // what to hide bitsum
	message_end()
	
	// Hide the HL crosshair that's drawn
	message_begin(MSG_ONE, msgCrosshair, _, id)
	write_byte(0) // toggle
	message_end()
}

public native_money_get()
{
    new id = get_param(1);
    return g_Money[id];
}

public native_money_set()
{
    new id = get_param(1);
    new value = get_param(2);

    g_Money[id] = value;
}