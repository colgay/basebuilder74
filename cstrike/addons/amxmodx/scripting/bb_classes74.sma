/*================================================================================
	
	-----------------------------------
	-*- [BB] Credits Classes -*-
	-----------------------------------
	
	~~~~~~~~~~~~~~~
	- Description -
	~~~~~~~~~~~~~~~
	
	This plugin adds the bonus zombie classes into Base Builder.
	
	All classes have been balanced, but feel free to edit them if
	you are not satisfied.
	
================================================================================*/

#include <amxmodx>
#include <fakemeta>
#include <basebuilder>
#include <hamsandwich>
#include <fun>
#include <xs>

/*================================================================================
 [Plugin Customization]
=================================================================================*/
// Chainsaw Attributes
new const zclass3_name[] = { "Chainsaw" }
new const zclass3_info[] = { "HP+ DMG+" }
new const zclass3_model[] = { "bb_chainsaw" }
new const zclass3_clawmodel[] = { "v_bloodyhands" }
const zclass3_health = 3000
const zclass3_speed = 245
const Float:zclass3_gravity = 0.85
const zclass3_admin = ADMIN_LEVEL_A
const zclass3_credits = 0
#define CHAINSAW_DAMAGE 2.0

// Banshee Attributes
new const zclass4_name[] = { "Banshee" }
new const zclass4_info[] = { "Semiclip" }
new const zclass4_model[] = { "bb_banshee2" }
new const zclass4_clawmodel[] = { "v_bloodyhands" }
const zclass4_health = 2250
const zclass4_speed = 260
const Float:zclass4_gravity = 0.85
const zclass4_admin = ADMIN_LEVEL_A
const zclass4_credits = 0
#define BANSHEE_RENDERAMT 150

// Charger Attributes
new const zclass5_name[] = { "Charger" }
new const zclass5_info[] = { "HP++ Speed- Charge" }
new const zclass5_model[] = { "bb_charger" }
new const zclass5_clawmodel[] = { "v_bloodyhands" }
const zclass5_health = 3500
const zclass5_speed = 210
const Float:zclass5_gravity = 0.85
const zclass5_admin = ADMIN_LEVEL_A
const zclass5_credits = 0

// Lycan Attributes
new const zclass6_name[] = { "Werewolf" }
new const zclass6_info[] = { "=Balanced=" }
new const zclass6_model[] = { "bb_lycan" }
new const zclass6_clawmodel[] = { "v_bloodyhands" }
const zclass6_health = 3000
const zclass6_speed = 275
const Float:zclass6_gravity = 0.75
const zclass6_admin = ADMIN_LEVEL_A
const zclass6_credits = 0

// Regenerator Attributes
new const zclass7_name[] = { "Rejuvinator" }
new const zclass7_info[] = { "Regeneration" }
new const zclass7_model[] = { "bb_headshot" }
new const zclass7_clawmodel[] = { "v_bloodyhands" }
const zclass7_health = 2500
const zclass7_speed = 270
const Float:zclass7_gravity = 0.80
const zclass7_admin = ADMIN_LEVEL_A
const zclass7_credits = 0

//Every 2 seconds, regenerates 2.5% max health
#define REGENERATION_DELAY 1.5
#define HEAL_ALGORITHM (get_user_health(id) + (zclass7_health * 0.025))

// Knockback Attributes
new const zclass8_name[] = { "The Smasher" }
new const zclass8_info[] = { "Knockback" }
new const zclass8_model[] = { "bb_nazi" }
new const zclass8_clawmodel[] = { "v_bloodyhands" }
const zclass8_health = 1500
const zclass8_speed = 260
const Float:zclass8_gravity = 1.0
const zclass8_admin = ADMIN_LEVEL_A
const zclass8_credits = 0

/*============================================================================*/

new bool:g_isSolid[33]
new bool:g_isSemiClip[33]
new g_iPlayers[32], g_iNum, g_iPlayer

new g_zclass_saw
new g_zclass_banshee
new g_zclass_charger
new g_zclass_lycan
new g_zclass_regenerator
new g_zclass_knockback

#define SOUND_DELAY 3.0
new Float: g_fSoundDelay[33]

new Float: g_fRegenDelay[33]
#define PAINSHOCK 108

#define g_ChainsawRev "basebuilder/zombie/chainsaw_rev2.wav"
#define g_BansheeScream "basebuilder/zombie/banshee_scream3.wav"
#define g_ChargerRoar "basebuilder/zombie/charger_roar2.wav"
#define g_LycanAttack "basebuilder/zombie/wolf_attack1.wav"
#define g_LycanHowl "basebuilder/zombie/wolf_spawn1.wav"

// Zombie Classes MUST be registered on plugin_precache
#define VERSION "7.4"
public plugin_precache()
{
	register_plugin("BB Crecit Classes", VERSION, "Tirant")
	register_cvar("bb_credit_classes", VERSION, FCVAR_SPONLY|FCVAR_SERVER)
	set_cvar_string("bb_credit_classes", VERSION)

	precache_sound(g_ChainsawRev)
	precache_sound(g_BansheeScream)
	precache_sound(g_ChargerRoar)
	precache_sound(g_LycanAttack)
	precache_sound(g_LycanHowl)
	
	// Register all classes
	g_zclass_saw = bb_register_zombie_class(zclass3_name, zclass3_info, zclass3_model, zclass3_clawmodel, zclass3_health, zclass3_speed, zclass3_gravity, 0.0, zclass3_admin, zclass3_credits)
	g_zclass_banshee = bb_register_zombie_class(zclass4_name, zclass4_info, zclass4_model, zclass4_clawmodel, zclass4_health, zclass4_speed, zclass4_gravity, 0.0, zclass4_admin, zclass4_credits)
	g_zclass_charger = bb_register_zombie_class(zclass5_name, zclass5_info, zclass5_model, zclass5_clawmodel, zclass5_health, zclass5_speed, zclass5_gravity, 0.0, zclass5_admin, zclass5_credits)
	g_zclass_lycan = bb_register_zombie_class(zclass6_name, zclass6_info, zclass6_model, zclass6_clawmodel, zclass6_health, zclass6_speed, zclass6_gravity, 0.0, zclass6_admin, zclass6_credits)
	g_zclass_regenerator = bb_register_zombie_class(zclass7_name, zclass7_info, zclass7_model, zclass7_clawmodel, zclass7_health, zclass7_speed, zclass7_gravity, 0.0, zclass7_admin, zclass7_credits)
	g_zclass_knockback = bb_register_zombie_class(zclass8_name, zclass8_info, zclass8_model, zclass8_clawmodel, zclass8_health, zclass8_speed, zclass8_gravity, 0.0, zclass8_admin, zclass8_credits)
}

public plugin_init()
{
	RegisterHam(Ham_TakeDamage, "player", "ham_TakeDamage")
	RegisterHam(Ham_TakeDamage, "player", "ham_TakeDamage_Post", 1)
	RegisterHam(Ham_Spawn, "player", "ham_PlayerSpawn_Post", 1)
	
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
	register_forward(FM_PlayerPostThink, "fw_PlayerPostThink");
	register_forward(FM_AddToFullPack, "fw_addToFullPack", 1)
	register_forward(FM_EmitSound, "fw_EmitSound")
}

public ham_TakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!pev_valid(victim) || !is_user_connected(attacker))
		return HAM_IGNORED

	if (zp_get_user_zombie_class(attacker) == g_zclass_saw)
		damage*=CHAINSAW_DAMAGE

	SetHamParamFloat(4, damage)
	return HAM_HANDLED
}

public ham_PlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return ;
		
	if (bb_is_user_zombie(id) && zp_get_user_zombie_class(id) == g_zclass_banshee)
		set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransTexture, BANSHEE_RENDERAMT)
	else
		set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 255)
}

public fw_PlayerPreThink(id)
{
	if (!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	
	if (zp_get_user_zombie_class(id) == g_zclass_regenerator && bb_is_user_zombie(id))
	{
		static Float: fGameTime;
		fGameTime = get_gametime();
		if (g_fRegenDelay[id] < fGameTime)
		{
			g_fRegenDelay[id] = fGameTime + REGENERATION_DELAY;
	
			new iHealth = floatround(HEAL_ALGORITHM);
			iHealth = clamp(iHealth, 0, zclass7_health);
			set_user_health(id, iHealth);
		}
	}
	
	get_players(g_iPlayers, g_iNum, "a")
	
	static i
	for (i = 0; i < g_iNum; i++)
	{
		g_iPlayer = g_iPlayers[i]
		if (!g_isSemiClip[g_iPlayer])
			g_isSolid[g_iPlayer] = true
		else
			g_isSolid[g_iPlayer] = false
	}
	
	if (g_isSolid[id])
	for (i = 0; i < g_iNum; i++)
	{
		g_iPlayer = g_iPlayers[i]
		
		if (!g_isSolid[g_iPlayer] || g_iPlayer == id  || !bb_is_user_zombie(id) || zp_get_user_zombie_class(id) != g_zclass_banshee)
			continue
		if (get_user_team(g_iPlayer) != get_user_team(id))
			continue
			
		set_pev(g_iPlayer, pev_solid, SOLID_NOT)
		g_isSemiClip[g_iPlayer] = true
	}
		
	return FMRES_IGNORED	
}

public fw_PlayerPostThink(id)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED
	
	get_players(g_iPlayers, g_iNum, "a")
	
	static i
	for (i = 0; i < g_iNum; i++)
	{
		g_iPlayer = g_iPlayers[i]
		if (g_isSemiClip[g_iPlayer])
		{
			set_pev(g_iPlayer, pev_solid, SOLID_SLIDEBOX)
			g_isSemiClip[g_iPlayer] = false
		}
	}
	
	return FMRES_IGNORED
}

public fw_addToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if ( !player )
		return FMRES_SUPERCEDE;
		
	if(player)
	{
		if (!is_user_alive(host) || !g_isSolid[host])
			return FMRES_IGNORED
		if (get_user_team(ent) != get_user_team(host))
			return FMRES_IGNORED
			
		set_es(es, ES_Solid, SOLID_NOT)
	}
	return FMRES_IGNORED
}

public fw_EmitSound(id,channel,const sample[],Float:volume,Float:attn,flags,pitch)
{
	if (!is_user_connected(id) || !bb_is_user_zombie(id) || bb_is_build_phase() || bb_is_prep_phase())
		return FMRES_IGNORED;
	
	if ((g_fSoundDelay[id] + SOUND_DELAY) < get_gametime())
	{
		if (equal(sample[8], "kni", 3))
		{
			if (equal(sample[14], "sla", 3) || equal(sample[14], "hit", 3) || equal(sample[14], "sta", 3)) // slash
			{
				if (zp_get_user_zombie_class(id) == g_zclass_saw)
				{
					emit_sound(id,CHAN_ITEM,g_ChainsawRev,volume,attn,flags,pitch)
					g_fSoundDelay[id] = get_gametime()
					return FMRES_SUPERCEDE;
				}
				else if (zp_get_user_zombie_class(id) == g_zclass_banshee)
				{
					emit_sound(id,CHAN_ITEM,g_BansheeScream,volume,attn,flags,pitch)
					g_fSoundDelay[id] = get_gametime()
					return FMRES_SUPERCEDE;
				}
				else if (zp_get_user_zombie_class(id) == g_zclass_charger)
				{
					emit_sound(id,CHAN_ITEM,g_ChargerRoar,volume,attn,flags,pitch)
					g_fSoundDelay[id] = get_gametime()
					
					static Float: velocity[3];
					velocity_by_aim(id, 400, velocity);
					set_pev(id, pev_velocity, velocity);
					
					return FMRES_SUPERCEDE;
				}
				else if (zp_get_user_zombie_class(id) == g_zclass_lycan)
				{
					emit_sound(id,CHAN_ITEM,g_LycanAttack,volume,attn,flags,pitch)
					g_fSoundDelay[id] = get_gametime()
					return FMRES_SUPERCEDE;
				}
			}
		}
	}
	//else
		//g_fSoundDelay[id] = get_gametime()
	
	return FMRES_IGNORED
}

public bb_zombie_class_set(id, class)
{
	if (!is_user_alive(id))
		return ;
		
	if (class == g_zclass_lycan && !bb_is_build_phase())
		emit_sound(id,CHAN_STATIC,g_LycanHowl,VOL_NORM,ATTN_NORM,0,PITCH_NORM)
		
	return ;
}

public ham_TakeDamage_Post(victim, inflictor, attacker, Float:damage, bits)
{
	if(bb_get_user_zombie_class(victim) == g_zclass_knockback && bb_is_user_zombie(victim))
	{
		set_pdata_float(victim, PAINSHOCK, 1.0, 5)
	}
}

