#if defined _bb_buy_included
  #endinput
#endif
#define _bb_buy_included

#include <bb_buy_const>

native bb_buy_register_item(const classname[], const name[], const desc[], cost);
native bb_buy_find_item_id(const classname[]);
native bb_buy_get_item_classname(itemid, buffer[], len);
native bb_buy_get_item_desc(itemid, buffer[], len);
native bb_buy_get_item_name(itemid, buffer[], len);
native bb_buy_get_item_cost(itemid);
native bb_show_buy_menu(id);
native bb_buy_item(id, itemid, ignorecost=0);

forward bb_on_buy_item_select_pre(id, itemid, ignorecost, pushed);
forward bb_on_buy_item_select_post(id, itemid, ignorecost);