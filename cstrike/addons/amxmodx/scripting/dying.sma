#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

public plugin_init()
{
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", 1);
    RegisterHam(Ham_Think, "trigger_camera", "OnCameraThink");
}

public OnPlayerKilled(id)
{
    new ent = create_entity("trigger_camera");

    set_kvd(0, KV_ClassName, "trigger_camera");
    set_kvd(0, KV_fHandled, 0);
    set_kvd(0, KV_KeyName, "wait");
    set_kvd(0, KV_Value, "999999");
    dllfunc(DLLFunc_KeyValue, ent, 0);

    set_pev(ent, pev_spawnflags, SF_CAMERA_PLAYER_TARGET | SF_CAMERA_PLAYER_POSITION);
    set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_ALWAYSTHINK);
    set_pev(ent, pev_owner, id);

    DispatchSpawn(ent);

    ExecuteHam(Ham_Use, ent, id, id, USE_TOGGLE, 1.0);
    attach_view(id, ent);

    set_pev(id, pev_iuser1, 0);
}

public OnCameraThink(ent)
{
    new player = pev(ent, pev_owner);
    if (is_user_connected(player) && !is_user_alive(player))
    {
        new Float:origin[3], Float:angles[3];
        engfunc(EngFunc_GetBonePosition, player, 40, origin, angles);

        /*
        new Float:vector[3];
        angle_vector(angles, ANGLEVECTOR_UP, vector);
        vector_to_angle(vector, angles);*/

        pev(player, pev_v_angle, angles);

        set_pev(ent, pev_origin, origin);
        set_pev(ent, pev_angles, angles);

        server_print("angles = {%f, %f %f}", angles[0], angles[1], angles[2]);
    }
}