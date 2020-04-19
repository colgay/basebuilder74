#include <amxmodx>
#include <bb_buy>
#include <bb_money>

#define VERSION "0.1"

public plugin_init()
{
    register_plugin("[BB] Buy: Money", VERSION, "holla")
}

public bb_on_buy_item_select_pre(id, itemid, ignorecost, pushed)
{
    if (ignorecost)
        return BB_ITEM_AVAILABLE;
    
    new currentMoney = bb_money_get(id);
    new requiredMoney = bb_buy_get_item_cost(itemid);

    if (currentMoney < requiredMoney)
    {
        if (pushed)
            client_print_color(id, print_team_default, "^4[BUY2]^1 %L", id, "NOT_ENOUGH_MONEY");
        
        return BB_ITEM_NOT_AVAILABLE;
    }

    return BB_ITEM_AVAILABLE;
}

public bb_on_buy_item_select_post(id, itemid, ignorecost)
{
	if (ignorecost)
		return;
	
    new currentMoney = bb_money_get(id);
    new requiredMoney = bb_buy_get_item_cost(itemid);
	
	bb_money_set(id, currentMoney - requiredMoney);

    server_print("test c=%d, r=%d", currentMoney, requiredMoney);
}