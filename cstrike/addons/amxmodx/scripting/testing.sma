#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

new OldWeapons[33];
new IsHiding[33];

public plugin_init()
{
    register_clcmd("hidej", "HideJJ");
    register_clcmd("showj", "ShowJJ");

    register_event("CurWeapon", "OnEventCurWeapon", "be", "1=1");

    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxSpeed", 1);
}

public HideJJ(id)
{
    IsHiding[id] = true;

    // store old weapons 
    OldWeapons[id] = pev(id, pev_weapons);
    
    // hide weapons
    set_pev(id, pev_weapons, 0);
    set_pev(id, pev_solid, SOLID_NOT);
    set_pev(id, pev_effects, pev(id, pev_effects) | EF_NODRAW);

    // real hide weapons
    set_ent_data_entity(id, "CBasePlayer", "m_pActiveItem", -1);
    set_pev(id, pev_viewmodel2, "");

    // set maxspeed to 1
    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

    client_print(id, print_chat, "you are sleeping");
}

public ShowJJ(id)
{
    IsHiding[id] = false;

    set_pev(id, pev_weapons, OldWeapons[id]);
    set_pev(id, pev_solid, SOLID_SLIDEBOX);
    set_pev(id, pev_effects, pev(id, pev_effects) & ~EF_NODRAW);

    engclient_cmd(id, "weapon_knife");

    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

    client_print(id, print_chat, "you wake up");
}

public OnEventCurWeapon(id)
{
    if (is_user_alive(id) && IsHiding[id])
    {
        set_ent_data_entity(id, "CBasePlayer", "m_pActiveItem", -1);
        set_pev(id, pev_viewmodel2, "");

        //client_print(id, print_chat, "detected weapon switch, hide again");
    }
}

public OnPlayerResetMaxSpeed(id)
{
    if (is_user_alive(id) && IsHiding[id])
        set_pev(id, pev_maxspeed, 1.0);
}