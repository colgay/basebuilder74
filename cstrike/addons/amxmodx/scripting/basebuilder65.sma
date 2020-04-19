/*
Base Builder Zombie Mod
Tirant

Version 6.5 Pub
*/

#include <amxmodx>
#include <amxmisc>
#include <credits>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <csx>
#include <xs>

//Enable this only if you have bought the credits plugin
//#define BB_CREDITS

#define FLAGS_BUILD 	ADMIN_KICK
#define FLAGS_LOCK 	ADMIN_LEVEL_A
#define FLAGS_BUILDBAN 	ADMIN_KICK
#define FLAGS_SWAP 	ADMIN_KICK
#define FLAGS_REVIVE 	ADMIN_KICK
#define FLAGS_GUNS 	ADMIN_LEVEL_A
#define FLAGS_RELEASE 	ADMIN_BAN
#define FLAGS_OVERRIDE 	ADMIN_BAN

#define VERSION "6.5"
#define MODNAME "^4[Base Builder]^1"

#define LockBlock(%1,%2)  	( entity_set_int( %1, EV_INT_iuser1,     %2 ) )
#define UnlockBlock(%1)   	( entity_set_int( %1, EV_INT_iuser1,     0  ) )
#define BlockLocker(%1)   	entity_get_int( %1, EV_INT_iuser1 )

#define MovingEnt(%1)     	( entity_set_int( %1, EV_INT_iuser2,     1 ) )
#define UnmovingEnt(%1)   	( entity_set_int( %1, EV_INT_iuser2,     0 ) )
#define IsMovingEnt(%1)   	( entity_get_int( %1, EV_INT_iuser2 ) == 1 )

#define SetEntMover(%1,%2)  	( entity_set_int( %1, EV_INT_iuser3, %2 ) )
#define UnsetEntMover(%1)   	( entity_set_int( %1, EV_INT_iuser3, 0  ) )
#define GetEntMover(%1)   	( entity_get_int( %1, EV_INT_iuser3     ) )

#define SetLastMover(%1,%2)  	( entity_set_int( %1, EV_INT_iuser4, %2 ) )
#define UnsetLastMover(%1)   	( entity_set_int( %1, EV_INT_iuser4, 0  ) )
#define GetLastMover(%1)  	( entity_get_int( %1, EV_INT_iuser4     ) )

#define GROUP_HUMAN (1 << 0)
#define GROUP_OBJECT (1 << 1)

#define MAXPLAYERS 32
//#define MAXENTS 1024
#define AMMO_SLOT 376
#define MODELCHANGE_DELAY 0.5
#define AUTO_TEAM_JOIN_DELAY 0.1
#define TEAM_SELECT_VGUI_MENU_ID 2
#define OBJECT_PUSHPULLRATE 4.0
#define HUD_FRIEND_HEIGHT 0.55

#define BARRIER_COLOR 0.0, 0.0, 0.0
#define BARRIER_RENDERAMT 150.0

#define BLOCK_RENDERAMT 150.0

#define LOCKED_COLOR 125.0, 0.0, 0.0
#define LOCKED_RENDERAMT 225.0

const ZOMBIE_ALLOWED_WEAPONS_BITSUM = (1<<CSW_KNIFE)
#define OFFSET_WPN_WIN 	  41
#define OFFSET_WPN_LINUX  4

#define OFFSET_ACTIVE_ITEM 373
#define OFFSET_LINUX 5

#if cellbits == 32
	#define OFFSET_BUYZONE 235
#else
	#define OFFSET_BUYZONE 268
#endif

new g_iMaxPlayers
new g_msgStatusText
//new g_HudSync
//new g_HudSync2

new g_isConnected[MAXPLAYERS+1]
new g_isAlive[MAXPLAYERS+1]
new g_isZombie[MAXPLAYERS+1]
new g_isBuildBan[MAXPLAYERS+1]
new g_isCustomModel[MAXPLAYERS+1]

enum (+= 5000)
{
	TASK_BUILD = 10000,
	TASK_PREPTIME,
	TASK_MODELSET,
	TASK_RESPAWN,
	TASK_HEALTH,
	TASK_IDLESOUND,
	TASK_TEAMKILL
}

//Custom Sounds
new g_szRoundStart[][] = 
{
	"basebuilder/round_start.wav",
	"basebuilder/round_start2.wav"
}

#define WIN_ZOMBIES 	"basebuilder/win_zombies2.wav"
#define WIN_BUILDERS 	"basebuilder/win_builders2.wav"

#define PHASE_PREP 	"basebuilder/phase_prep3.wav"
#define PHASE_BUILD 	"basebuilder/phase_build3.wav"

#define LOCK_OBJECT 	"buttons/lightswitch2.wav"
#define LOCK_FAIL	"buttons/button10.wav"

#define GRAB_START	"basebuilder/block_grab.wav"
#define GRAB_STOP	"basebuilder/block_drop.wav"

#define INFECTION	"basebuilder/zombie_kill1.wav"

new const g_szZombiePain[][] =
{
	"basebuilder/zombie/pain/pain1.wav",
	"basebuilder/zombie/pain/pain2.wav",
	"basebuilder/zombie/pain/pain3.wav"
}

new const g_szZombieDie[][] =
{
	"basebuilder/zombie/death/death1.wav",
	"basebuilder/zombie/death/death2.wav",
	"basebuilder/zombie/death/death3.wav"
}

new const g_szZombieIdle[][] =
{
	"basebuilder/zombie/idle/idle1.wav",
	"basebuilder/zombie/idle/idle2.wav",
	"basebuilder/zombie/idle/idle3.wav"
}

new const g_szZombieHit[][] =
{
	"basebuilder/zombie/hit/hit1.wav",
	"basebuilder/zombie/hit/hit1.wav",
	"basebuilder/zombie/hit/hit1.wav"
}

new const g_szZombieMiss[][] =
{
	"basebuilder/zombie/miss/miss1.wav",
	"basebuilder/zombie/miss/miss2.wav",
	"basebuilder/zombie/miss/miss3.wav"
}

//Custom Player Models
//new Float:g_fModelsTargetTime, Float:g_fRoundStartTime
//new g_szPlayerModel[MAXPLAYERS+1][32]

//Game Name
new g_szModName[32]

new g_iCountDown, g_iEntBarrier
new bool:g_boolCanBuild, bool:g_boolPrepTime, bool:g_boolRoundEnded
//new g_iFriend[MAXPLAYERS+1]
new CsTeams:g_iTeam[MAXPLAYERS+1], CsTeams:g_iCurTeam[MAXPLAYERS+1]
new bool:g_boolFirstTeam[MAXPLAYERS+1]
new g_boolFreeZombies[MAXPLAYERS+1];
new g_boolAiming[MAXPLAYERS+1];
new Float:g_fHudMsgTime[MAXPLAYERS+1];

//Building Stores
new Float:g_fOffset[MAXPLAYERS+1][3];
new g_iOwnedEnt[MAXPLAYERS+1], g_iOwnedEntities[MAXPLAYERS+1]
new Float:g_fEntDist[MAXPLAYERS+1]
new Float:g_fPushPullTime[MAXPLAYERS+1];

static const g_szWpnEntNames[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }
			
//Weapon Names (For Guns Menu)
static const szWeaponNames[24][23] = { "Schmidt Scout", "XM1014 M4", "Ingram MAC-10", "Steyr AUG A1", "UMP 45", "SG-550 Auto-Sniper",
			"IMI Galil", "Famas", "AWP Magnum Sniper", "MP5 Navy", "M249 Para Machinegun", "M3 Super 90", "M4A1 Carbine",
			"Schmidt TMP", "G3SG1 Auto-Sniper", "SG-552 Commando", "AK-47 Kalashnikov", "ES P90", "P228 Compact",
			"Dual Elite Berettas", "Fiveseven", "USP .45 ACP Tactical", "Glock 18C", "Desert Eagle .50 AE" }
			
#define MAX_COLORS 24
new const Float:g_fColor[MAX_COLORS][3] = 
{
	{200.0, 000.0, 000.0},
	{255.0, 083.0, 073.0},
	{255.0, 117.0, 056.0},
	{255.0, 174.0, 066.0},
	{255.0, 207.0, 171.0},
	{252.0, 232.0, 131.0},
	{254.0, 254.0, 034.0},
	{059.0, 176.0, 143.0},
	{197.0, 227.0, 132.0},
	{000.0, 150.0, 000.0},
	{120.0, 219.0, 226.0},
	{135.0, 206.0, 235.0},
	{128.0, 218.0, 235.0},
	{000.0, 000.0, 255.0},
	{146.0, 110.0, 174.0},
	{255.0, 105.0, 180.0},
	{246.0, 100.0, 175.0},
	{205.0, 074.0, 076.0},
	{250.0, 167.0, 108.0},
	{234.0, 126.0, 093.0},
	{180.0, 103.0, 077.0},
	{149.0, 145.0, 140.0},
	{000.0, 000.0, 000.0},
	{255.0, 255.0, 255.0}
}

new const Float:g_fRenderAmt[MAX_COLORS] = 
{
	100.0, //Red
	135.0, //Red Orange
	140.0, //Orange
	120.0, //Yellow Orange
	140.0, //Peach
	125.0, //Yellow
	100.0, //Lemon Yellow
	125.0, //Jungle Green
	135.0, //Yellow Green
	100.0, //Green
	125.0, //Aquamarine
	150.0, //Baby Blue
	090.0, //Sky Blue
	075.0, //Blue
	175.0, //Violet
	150.0, //Hot Pink
	175.0, //Magenta
	140.0, //Mahogany
	140.0, //Tan
	140.0, //Light Brown
	165.0, //Brown
	175.0, //Gray
	125.0, //Black
	125.0   //White
}

new const g_szColorName[MAX_COLORS][] = 
{
	"Red",
	"Red Orange",
	"Orange",
	"Yellow Orange",
	"Peach",
	"Yellow",
	"Lemon Yellow",
	"Jungle Green",
	"Yellow Green",
	"Green",
	"Aquamarine",
	"Baby Blue",
	"Sky Blue",
	"Blue",
	"Violet",
	"Hot Pink",
	"Magenta",
	"Mahogany",
	"Tan",
	"Light Brown",
	"Brown",
	"Gray",
	"Black",
	"White"
}

enum
{
	COLOR_RED = 0, 		//200, 000, 000
	COLOR_REDORANGE, 	//255, 083, 073
	COLOR_ORANGE, 		//255, 117, 056
	COLOR_YELLOWORANGE, 	//255, 174, 066
	COLOR_PEACH, 		//255, 207, 171
	COLOR_YELLOW, 		//252, 232, 131
	COLOR_LEMONYELLOW, 	//254, 254, 034
	COLOR_JUNGLEGREEN, 	//059, 176, 143
	COLOR_YELLOWGREEN, 	//197, 227, 132
	COLOR_GREEN, 		//000, 200, 000
	COLOR_AQUAMARINE, 	//120, 219, 226
	COLOR_BABYBLUE, 		//135, 206, 235
	COLOR_SKYBLUE, 		//128, 218, 235
	COLOR_BLUE, 		//000, 000, 200
	COLOR_VIOLET, 		//146, 110, 174
	COLOR_PINK, 		//255, 105, 180
	COLOR_MAGENTA, 		//246, 100, 175
	COLOR_MAHOGANY,		//205, 074, 076
	COLOR_TAN, 		//250, 167, 108
	COLOR_LIGHTBROWN, 	//234, 126, 093
	COLOR_BROWN, 		//180, 103, 077
	COLOR_GRAY, 		//149, 145, 140
	COLOR_BLACK, 		//000, 000, 000
	COLOR_WHITE 		//255, 255, 255
}

new g_iColor[MAXPLAYERS+1]
new g_iColorOwner[MAX_COLORS]

//Color Menu
new g_iMenuOffset[MAXPLAYERS+1], g_iMenuOptions[MAXPLAYERS+1][8], g_iWeaponPicked[2][MAXPLAYERS+1],
	g_iPrimaryWeapon[MAXPLAYERS+1]
	
new bool:g_boolFirstTime[MAXPLAYERS+1], bool:g_boolRepick[MAXPLAYERS+1]

new Float:g_fBuildDelay[MAXPLAYERS+1]
#define BUILD_DELAY 0.75

#define KEYS_GENERIC (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9)

enum
{
	ATT_HEALTH = 0,
	ATT_SPEED,
	ATT_GRAVITY
}

//Zombie Classes
new g_iZClasses
new g_iZombieClass[MAXPLAYERS+1]
new bool:g_boolFirstSpawn[MAXPLAYERS+1]
new g_szPlayerClass[MAXPLAYERS+1][32]
new g_iNextClass[MAXPLAYERS+1]
new Float:g_fPlayerSpeed[MAXPLAYERS+1]
new bool:g_boolArraysCreated
new Array:g_zclass_name
new Array:g_zclass_info
new Array:g_zclass_modelsstart // start position in models array
new Array:g_zclass_modelsend // end position in models array
new Array:g_zclass_playermodel // player models array
new Array:g_zclass_modelindex // model indices array
new Array:g_zclass_clawmodel
new Array:g_zclass_hp
new Array:g_zclass_spd
new Array:g_zclass_grav
new Array:g_zclass_admin
new Array:g_zclass_credits
//new Float:g_fClassMultiplier[MAXPLAYERS+1][3]

new Array:g_zclass2_realname, Array:g_zclass2_name, Array:g_zclass2_info,
Array:g_zclass2_modelsstart, Array:g_zclass2_modelsend, Array:g_zclass2_playermodel,
Array:g_zclass2_clawmodel, Array:g_zclass2_hp, Array:g_zclass2_spd,
Array:g_zclass2_grav, Array:g_zclass2_admin, Array:g_zclass2_credits, Array:g_zclass_new

//Forwards
new g_fwRoundStart, g_fwPrepStarted, g_fwBuildStarted, g_fwClassPicked, g_fwClassSet,
g_fwPushPull, g_fwGrabEnt_Pre, g_fwGrabEnt_Post, g_fwDropEnt_Pre,
 g_fwDropEnt_Post, g_fwNewColor, g_fwLockEnt_Pre, g_fwLockEnt_Post, g_fwDummyResult

 //Cvars
new g_iBuildTime,
	g_iPrepTime,
	g_iGrenadeHE, g_iGrenadeFLASH, g_iGrenadeSMOKE,
	Float: g_fEntMinDist,
	Float: g_fEntSetDist,
	Float: g_fEntMaxDist,
	g_iResetEnt,
	g_iShowMovers,
	 g_iLockBlocks,
	g_iLockMax,
	g_iColorMode,
	g_iZombieTime,
	g_iInfectTime,
	g_iSupercut,
	g_iGunsMenu,
	g_pcvar_enabled,
	Float:g_fGrabMaxMoveTime, Float:g_fGrabMaxMoveUnits, 
	g_szAllowedWeapons[32],
	g_szLightLevel[32];

//new g_hahajai;
 
public plugin_precache()
{
	server_cmd("bb_credits_active 0")
	
	register_plugin("Base Builder", VERSION, "Tirant")
	register_cvar("base_builder", VERSION, FCVAR_SPONLY|FCVAR_SERVER)
	set_cvar_string("base_builder", VERSION)
	
	g_pcvar_enabled = create_cvar("bb_enabled", "1")
	
	if (!get_pcvar_num(g_pcvar_enabled))
		return;

	//new szCache[64], i;
	new i;
		
	new pcvar = create_cvar("bb_buildtime", "150") //Build Time
	bind_pcvar_num(pcvar, g_iBuildTime)

	pcvar = create_cvar("bb_preptime", "30") //Prep Time
	bind_pcvar_num(pcvar, g_iPrepTime)

	pcvar = create_cvar("bb_zombie_respawn_delay", "3") //Zombie Respawn Delay
	bind_pcvar_num(pcvar, g_iZombieTime)

	pcvar = create_cvar("bb_infection_respawn", "5") //Survivor Respawn Infection Delay
	bind_pcvar_num(pcvar, g_iInfectTime)

	pcvar = create_cvar("bb_showmovers", "1") //Show Movers
	bind_pcvar_num(pcvar, g_iShowMovers)

	pcvar = create_cvar("bb_lockblocks", "1") //Lock blocks
	bind_pcvar_num(pcvar, g_iLockBlocks)

	pcvar = create_cvar("bb_lockmax", "10") //Lock max
	bind_pcvar_num(pcvar, g_iLockMax)

	pcvar = create_cvar("bb_colormode", "1") //Color mode <0/1/2> Menu, one color per player, random
	bind_pcvar_num(pcvar, g_iColorMode)

	pcvar = create_cvar("bb_max_move_dist", "768") //Push ceiling
	bind_pcvar_float(pcvar, g_fEntMaxDist)

	pcvar = create_cvar("bb_min_move_dist", "32") //Pull floor
	bind_pcvar_float(pcvar, g_fEntMinDist)

	pcvar = create_cvar("bb_min_dist_set", "64") //Grab set
	bind_pcvar_float(pcvar, g_fEntSetDist)

	pcvar = create_cvar("bb_resetblocks", "1") //Reset blocks on new round
	bind_pcvar_num(pcvar, g_iResetEnt)

	pcvar = create_cvar("bb_zombie_supercut", "0") //One hit kill for zombies
	bind_pcvar_num(pcvar, g_iSupercut)
	
	pcvar = create_cvar("bb_gunsmenu", "0") //Use the internal guns menu
	bind_pcvar_num(pcvar, g_iGunsMenu)

	pcvar = create_cvar("bb_max_move_units", "15.0") 
	bind_pcvar_float(pcvar, g_fGrabMaxMoveUnits);

	pcvar = create_cvar("bb_max_move_time", "5.0") 
	bind_pcvar_float(pcvar, g_fGrabMaxMoveTime);
	
	pcvar = create_cvar("bb_weapons","abcdeghijlmnqrstuvwx")
	bind_pcvar_string(pcvar, g_szAllowedWeapons, charsmax(g_szAllowedWeapons));
	
	pcvar = create_cvar("bb_roundnades","h") //Grenades
	hook_cvar_change(pcvar, "hook_cvar_roundnades");

	pcvar = create_cvar("bb_light_level", "c");
	bind_pcvar_string(pcvar, g_szLightLevel, charsmax(g_szLightLevel));

	create_cvar("zp_delay", "20");

	//g_hahajai = precache_model("sprites/zbeam4.spr");
	
	for (i=0; i<sizeof g_szRoundStart; i++) 	precache_sound(g_szRoundStart[i])
	for (i=0; i<sizeof g_szZombiePain;i++) 	precache_sound(g_szZombiePain[i])
	for (i=0; i<sizeof g_szZombieDie;i++) 	precache_sound(g_szZombieDie[i])
	for (i=0; i<sizeof g_szZombieIdle;i++) 	precache_sound(g_szZombieIdle[i])
	for (i=0; i<sizeof g_szZombieHit;i++) 	precache_sound(g_szZombieHit[i])
	for (i=0; i<sizeof g_szZombieMiss;i++) 	precache_sound(g_szZombieMiss[i])
	
	precache_sound(WIN_ZOMBIES)
	precache_sound(WIN_BUILDERS)
	precache_sound(PHASE_BUILD)
	precache_sound(PHASE_PREP)
	precache_sound(LOCK_OBJECT)
	precache_sound(LOCK_FAIL)
	precache_sound(GRAB_START)
	precache_sound(GRAB_STOP)
	if (g_iInfectTime)
		precache_sound(INFECTION)
	
	i = create_entity("info_bomb_target");
	entity_set_origin(i, Float:{8192.0,8192.0,8192.0})
	
	i = create_entity("info_map_parameters");
	DispatchKeyValue(i, "buying", "3");
	DispatchKeyValue(i, "bombradius", "1");
	DispatchSpawn(i);
	
	g_zclass_name = ArrayCreate(32, 1)
	g_zclass_info = ArrayCreate(32, 1)
	g_zclass_modelsstart = ArrayCreate(1, 1)
	g_zclass_modelsend = ArrayCreate(1, 1)
	g_zclass_playermodel = ArrayCreate(32, 1)
	g_zclass_modelindex = ArrayCreate(1, 1)
	g_zclass_clawmodel = ArrayCreate(32, 1)
	g_zclass_hp = ArrayCreate(1, 1)
	g_zclass_spd = ArrayCreate(1, 1)
	g_zclass_grav = ArrayCreate(1, 1)
	g_zclass_admin = ArrayCreate(1, 1)
	g_zclass_credits = ArrayCreate(1, 1)
	
	g_zclass2_realname = ArrayCreate(32, 1)
	g_zclass2_name = ArrayCreate(32, 1)
	g_zclass2_info = ArrayCreate(32, 1)
	g_zclass2_modelsstart = ArrayCreate(1, 1)
	g_zclass2_modelsend = ArrayCreate(1, 1)
	g_zclass2_playermodel = ArrayCreate(32, 1)
	g_zclass2_clawmodel = ArrayCreate(32, 1)
	g_zclass2_hp = ArrayCreate(1, 1)
	g_zclass2_spd = ArrayCreate(1, 1)
	g_zclass2_grav = ArrayCreate(1, 1)
	g_zclass2_admin = ArrayCreate(1, 1)
	g_zclass2_credits = ArrayCreate(1, 1)
	g_zclass_new = ArrayCreate(1, 1)
	
	g_boolArraysCreated = true
	
	ev_RoundStart();
	return;
}

public plugin_cfg()
{
	g_boolArraysCreated = false
}

public plugin_init()
{
	if (!get_pcvar_num(g_pcvar_enabled))
		return;
		
	formatex(g_szModName, charsmax(g_szModName), "Base Builder %s", VERSION)

	//register_think("func_wall", "OnWallThink");
	
	register_clcmd("say", 	   	"cmdSay");
	register_clcmd("say_team",	"cmdSay");
	
	//Added for old users
	register_clcmd("+grab",		"cmdGrabEnt");
	register_clcmd("-grab",		"cmdStopEnt");
	
	register_clcmd("bb_lock",	"cmdLockBlock",0, " - Aim at a block to lock it");
	register_clcmd("bb_claim",	"cmdLockBlock",0, " - Aim at a block to lock it");
	
	register_clcmd("bb_buildban",	"cmdBuildBan",0, " <player>");
	register_clcmd("bb_unbuildban",	"cmdBuildBan",0, " <player>");
	register_clcmd("bb_bban",	"cmdBuildBan",0, " <player>");
	
	register_clcmd("bb_swap",	"cmdSwap",0, " <player>");
	register_clcmd("bb_revive",	"cmdRevive",0, " <player>");
	if (g_iGunsMenu) register_clcmd("bb_guns",	"cmdGuns",0, " <player>");
	register_clcmd("bb_startround",	"cmdStartRound",0, " - Starts the round");
	
	register_logevent("logevent_round_start",2, 	"1=Round_Start")
	register_logevent("logevent_round_end", 2, 	"1=Round_End")
	
	register_message(get_user_msgid("TextMsg"), 	"msgRoundEnd")
	register_message(get_user_msgid("TextMsg"),	"msgSendAudio")
	register_message(get_user_msgid("StatusIcon"), 	"msgStatusIcon");
	register_message(get_user_msgid("Health"), 	"msgHealth");
	register_message(get_user_msgid("StatusValue"), 	"msgStatusValue")
	register_message(get_user_msgid("TeamInfo"), 	"msgTeamInfo");
	
	register_menucmd(register_menuid("ColorsSelect"),KEYS_GENERIC,"colors_pushed")
	register_menucmd(register_menuid("ZClassSelect"),KEYS_GENERIC,"zclass_pushed")
	register_menucmd(register_menuid("TeamKillSelect"), KEYS_GENERIC, "teamkill_pushed");
	if (g_iGunsMenu)
	{
		register_menucmd(register_menuid("WeaponMethodMenu"),(1<<0)|(1<<1)|(1<<2),"weapon_method_pushed")
		register_menucmd(register_menuid("PrimaryWeaponSelect"),KEYS_GENERIC,"prim_weapons_pushed")
		register_menucmd(register_menuid("SecWeaponSelect"),KEYS_GENERIC,"sec_weapons_pushed")
	}
	
	register_event("HLTV", 		"ev_RoundStart", "a", "1=0", "2=0")
	//register_event("AmmoX", 		"ev_AmmoX", 	 "be", "1=1", "1=2", "1=3", "1=4", "1=5", "1=6", "1=7", "1=8", "1=9", "1=10")
	//register_event("Health",   	"ev_Health", 	 "be", "1>0");
	//register_event("StatusValue", 	"ev_SetTeam", 	 "be", "1=1");
	//register_event("StatusValue", 	"ev_ShowStatus", "be", "1=2", "2!0");
	//register_event("StatusValue", 	"ev_HideStatus", "be", "1=1", "2=0");

	RegisterHam(Ham_Touch, 		"weapon_shield",  "ham_WeaponTouch");
	RegisterHam(Ham_Touch, 		"weaponbox",  	  "ham_WeaponTouch");
	RegisterHam(Ham_Touch, 		"armoury_entity", "ham_WeaponTouch");

	RegisterHam(Ham_Spawn, 		"player", 	"ham_PlayerSpawn_Post", 1)
	RegisterHam(Ham_TakeDamage, 	"player", 	"ham_TakeDamage")
	RegisterHam(Ham_TraceAttack, 	"player", 	"ham_TraceAttack")
	RegisterHam(Ham_Killed, "player", "ham_Killed");
	for (new i = 1; i < sizeof g_szWpnEntNames; i++)
		if (g_szWpnEntNames[i][0]) RegisterHam(Ham_Item_Deploy, g_szWpnEntNames[i], "ham_ItemDeploy_Post", 1)
	
	register_forward(FM_GetGameDescription, 		"fw_GetGameDescription")
	register_forward(FM_SetClientKeyValue, 		"fw_SetClientKeyValue")
	//register_forward(FM_ClientUserInfoChanged, 	"fw_ClientUserInfoChanged")
	register_forward(FM_CmdStart, 			"fw_CmdStart");
	register_forward(FM_PlayerPreThink, 		"fw_PlayerPreThink");
	register_forward(FM_PlayerPostThink, 		"fw_PlayerPostThink");
	register_forward(FM_EmitSound,			"fw_EmitSound")
	register_forward(FM_ClientKill,			"fw_Suicide")

	register_forward(FM_AddToFullPack, "fw_AddToFullPack_Post", 1);

	if (g_iShowMovers)
		register_forward(FM_TraceLine, 		"fw_Traceline", 1);
	
	//register_clcmd("drop", "clcmd_drop")
	register_clcmd("buy", "clcmd_buy")
	
	//Team Handlers
	//register_clcmd("chooseteam",	"clcmd_changeteam")
	//register_clcmd("jointeam", 	"clcmd_changeteam")
	register_message(get_user_msgid("ShowMenu"), "message_show_menu")
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu")
	
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET)
	
	g_iMaxPlayers = get_maxplayers()
	//g_HudSync = CreateHudSyncObj();
	//g_HudSync2 = CreateHudSyncObj();
	//g_msgSayText = get_user_msgid("SayText")
	g_msgStatusText = get_user_msgid("StatusText");
	
	g_iEntBarrier = find_ent_by_tname( -1, "barrier" );
	
	//Custom Forwards
	g_fwRoundStart = CreateMultiForward("bb_round_started", ET_IGNORE)
	g_fwPrepStarted = CreateMultiForward("bb_prepphase_started", ET_IGNORE)
	g_fwBuildStarted = CreateMultiForward("bb_buildphase_started", ET_IGNORE)
	g_fwClassPicked = CreateMultiForward("bb_zombie_class_picked", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwClassSet = CreateMultiForward("bb_zombie_class_set", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwPushPull = CreateMultiForward("bb_block_pushpull", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_fwGrabEnt_Pre = CreateMultiForward("bb_grab_pre", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwGrabEnt_Post = CreateMultiForward("bb_grab_post", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwDropEnt_Pre = CreateMultiForward("bb_drop_pre", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwDropEnt_Post = CreateMultiForward("bb_drop_post", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwNewColor = CreateMultiForward("bb_new_color", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwLockEnt_Pre = CreateMultiForward("bb_lock_pre", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwLockEnt_Post = CreateMultiForward("bb_lock_post", ET_IGNORE, FP_CELL, FP_CELL)
	
	register_dictionary("basebuilder.txt");
}

public plugin_natives()
{
	register_native("bb_register_zombie_class","native_register_zombie_class", 1)
	
	register_native("bb_get_user_classname","native_get_user_classname");
	register_native("bb_set_user_classname","native_set_user_classname");

	register_native("bb_get_class_cost","native_get_class_cost", 1)
	register_native("bb_get_user_zombie_class","native_get_user_zombie_class", 1)
	register_native("bb_get_user_next_class","native_get_user_next_class", 1)
	register_native("bb_set_user_zombie_class","native_set_user_zombie_class", 1)
	
	
	register_native("bb_is_user_zombie","native_is_user_zombie", 1)
	register_native("bb_is_user_banned","native_is_user_banned", 1)
	
	register_native("bb_is_build_phase","native_bool_buildphase", 1)
	register_native("bb_is_prep_phase","native_bool_prepphase", 1)
	
	register_native("bb_get_build_time","native_get_build_time", 1)
	register_native("bb_set_build_time","native_set_build_time", 1)
	
	register_native("bb_get_user_color","native_get_user_color", 1)
	register_native("bb_set_user_color","native_set_user_color", 1)
	
	register_native("bb_drop_user_block","native_drop_user_block", 1)
	register_native("bb_get_user_block","native_get_user_block", 1)
	register_native("bb_set_user_block","native_set_user_block", 1)
	
	register_native("bb_is_locked_block","native_is_locked_block", 1)
	register_native("bb_lock_block","native_lock_block", 1)
	register_native("bb_unlock_block","native_unlock_block", 1)
	
	register_native("bb_release_zombies","native_release_zombies", 1)
	
	register_native("bb_set_user_primary","native_set_user_primary", 1)
	register_native("bb_get_user_primary","native_get_user_primary", 1)
	
	register_native("bb_get_flags_build","native_get_flags_build", 1)
	register_native("bb_get_flags_lock","native_get_flags_lock", 1)
	register_native("bb_get_flags_buildban","native_get_flags_buildban", 1)
	register_native("bb_get_flags_swap","native_get_flags_swap", 1)
	register_native("bb_get_flags_revive","native_get_flags_revive", 1)
	register_native("bb_get_flags_guns","native_get_flags_guns", 1)
	register_native("bb_get_flags_release","native_get_flags_release", 1)
	register_native("bb_get_flags_override","native_get_flags_override", 1)

	register_native("bb_show_zclass_menu", "native_show_zclass_menu", 1);
	register_native("bb_get_barrier_ent", "native_get_barrier_ent", 1);
	register_native("bb_get_user_colorname", "native_get_user_colorname");
	//register_native("bb_set_user_mult","native_set_user_mult", 1)
	
	//ZP Natives Converted
	register_native("zp_register_zombie_class","native_register_zombie_class", 1)
	register_native("zp_get_user_zombie_class","native_get_user_zombie_class", 1)
	register_native("zp_get_user_next_class","native_get_user_next_class", 1)
	register_native("zp_set_user_zombie_class","native_set_user_zombie_class", 1)
	register_native("zp_get_user_zombie","native_is_user_zombie", 1)
}

public hook_cvar_roundnades(pcvar, const old_value[], const new_value[])
{
	new len = strlen(new_value);
	for (new i = 0; i < len; i++)
	{
		switch(new_value[i])
		{
			case 'h': g_iGrenadeHE++
			case 'f': g_iGrenadeFLASH++
			case 's': g_iGrenadeSMOKE++
		}
	}
}

public fw_GetGameDescription()
{
	forward_return(FMV_STRING, g_szModName)
	return FMRES_SUPERCEDE;
}

public client_putinserver(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
		
	g_isConnected[id] = true
	g_isAlive[id] = false
	g_isZombie[id] = false
	g_isBuildBan[id] = false
	g_isCustomModel[id] = false
	g_boolFirstSpawn[id] = true
	g_boolFirstTeam[id] = false
	g_boolFirstTime[id] = true
	g_boolRepick[id] = true
	
	g_iZombieClass[id] = 0
	g_iNextClass[id] = g_iZombieClass[id]
	//for (new i = 0; i < 3; i++) g_fClassMultiplier[id][i] = 1.0
	
	set_task(7.0,"Respawn_Player",id+TASK_RESPAWN);
	
	return PLUGIN_CONTINUE;
}

public client_disconnect(id)
{
	if (g_iOwnedEnt[id])
		cmdStopEnt(id)

	g_isConnected[id] = false
	g_isAlive[id] = false
	g_isZombie[id] = false
	g_isBuildBan[id] = false
	g_isCustomModel[id] = false
	g_boolFirstSpawn[id] = false
	g_boolFirstTeam[id] = false
	g_boolFirstTime[id] = false
	g_boolRepick[id] = false
	
	g_iZombieClass[id] = 0
	g_iNextClass[id] = 0
	//for (new i = 0; i < 3; i++) g_fClassMultiplier[id][i] = 1.0
	
	g_iOwnedEntities[id] = 0
	
	remove_task(id+TASK_RESPAWN)
	remove_task(id+TASK_HEALTH)
	remove_task(id+TASK_IDLESOUND)
	
	new iEnt = FM_NULLENT;
	while ((iEnt = find_ent_by_class(iEnt, "func_wall")))
	{
		if (is_valid_ent(iEnt) && g_iLockBlocks && BlockLocker(iEnt) == id)
		{
			UnlockBlock(iEnt)
			set_pev(iEnt,pev_rendermode,kRenderNormal)
				
			UnsetLastMover(iEnt);
			UnsetEntMover(iEnt);
		}
	}
}  

public ev_RoundStart()
{
	remove_task(TASK_BUILD)
	remove_task(TASK_PREPTIME)
	
	arrayset(g_iOwnedEntities, 0, MAXPLAYERS+1)
	arrayset(g_iColor, 0, MAXPLAYERS+1)
	arrayset(g_iColorOwner, 0, MAX_COLORS)
	arrayset(g_boolRepick, true, MAXPLAYERS+1)
	arrayset(g_boolFreeZombies, false, MAXPLAYERS+1);
	
	g_boolRoundEnded = false
	g_boolCanBuild = true
	//g_fRoundStartTime = get_gametime()
	
	if (g_iResetEnt)
	{
		new szTarget[7];
		new iEnt = -1;

		while ((iEnt = find_ent_by_class(iEnt, "func_wall")))
		{
			if (!is_valid_ent(iEnt))
				continue;
			
			entity_get_string(iEnt, EV_SZ_targetname, szTarget, 6);

			if (!BlockLocker(iEnt) && iEnt != g_iEntBarrier && !equal(szTarget, "ignore"))
			{
				set_pev(iEnt,pev_rendermode,kRenderNormal);
				//set_pev(iEnt, pev_groupinfo, 0);
				engfunc( EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 } );
				
				UnsetLastMover(iEnt);
				UnsetEntMover(iEnt);
			}
			else if (g_iLockBlocks && BlockLocker(iEnt))
			{
				UnlockBlock(iEnt)
				set_pev(iEnt,pev_rendermode,kRenderNormal)
				//set_pev(iEnt, pev_groupinfo, 0);
				engfunc( EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 } );
				
				UnsetLastMover(iEnt);
				UnsetEntMover(iEnt);
			}
		}
	}

	set_lights("");
}
/*
public ev_Health(taskid)
{
	if (taskid>g_iMaxPlayers)
		taskid-=TASK_HEALTH
		
	if (is_user_alive(taskid))
	{
		new szGoal[32]
		//if (is_credits_active())
		#if defined BB_CREDITS
			format(szGoal, 31, "^n%L: %d", LANG_SERVER, "HUD_GOAL", credits_get_user_goal(taskid))
		#endif
		
		if (g_isZombie[taskid])
		{
			static szCache1[32]
			ArrayGetString(g_zclass_name, g_iZombieClass[taskid], szCache1, charsmax(szCache1))
		
			set_hudmessage(200, 50, 0, -1.0, 0.9, 0, 0.0, 5.5, 0.0, 0.5, 2);
			show_hudmessage(taskid, "%L: %d^n%L: %s%s", taskid, "HUD_HEALTH", pev(taskid, pev_health), taskid, "HUD_CLASS", szCache1, szGoal);
		}
		else
		{
			set_hudmessage(0, 255, 0, -1.0, 0.9, 0, 0.0, 5.5, 0.0, 0.5, 2);
			show_hudmessage(taskid, "%L: %d%s", taskid, "HUD_HEALTH", pev(taskid, pev_health), szGoal);
		}
		
		set_task(5.0, "ev_Health", taskid+TASK_HEALTH);
	}
}*/

public msgStatusIcon(const iMsgId, const iMsgDest, const iPlayer)
{
	if(g_isAlive[iPlayer] && g_isConnected[iPlayer]) 
	{
		static szMsg[8]
		get_msg_arg_string(2, szMsg, 7)
    
		if(equal(szMsg, "buyzone"))
		{
			set_pdata_int(iPlayer, OFFSET_BUYZONE, get_pdata_int(iPlayer, OFFSET_BUYZONE) & ~(1<<0))
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
} 

public msgHealth(msgid, dest, id)
{
	if(!g_isAlive[id])
		return PLUGIN_CONTINUE;
	
	static hp;
	hp = get_msg_arg_int(1);
	
	if(hp > 255 && (hp % 256) == 0)
		set_msg_arg_int(1, ARG_BYTE, ++hp);
	
	return PLUGIN_CONTINUE;
}

public msgRoundEnd(const MsgId, const MsgDest, const MsgEntity)
{
	static Message[192]
	get_msg_arg_string(2, Message, 191)
	
	if (equal(Message, "#Terrorists_Win"))
	{
		g_boolRoundEnded = true
		set_dhudmessage(255, 50, 0, -1.0, 0.3, 0, 0.0, 4.5, 0.5, 1.0)
		show_dhudmessage(0, "%L", LANG_PLAYER, "WIN_ZOMBIE")
		set_msg_arg_string(2, "")
		client_cmd(0, "spk %s", WIN_ZOMBIES)
		
		return PLUGIN_HANDLED
	}
	else if (equal(Message, "#Target_Saved") || equal(Message, "#CTs_Win"))
	{
		g_boolRoundEnded = true
		set_dhudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 4.0, 0.5, 1.0)
		show_dhudmessage(0, "%L", LANG_PLAYER, "WIN_BUILDER")
		set_msg_arg_string(2, "")
		client_cmd(0, "spk %s", WIN_BUILDERS)
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public msgSendAudio(const MsgId, const MsgDest, const MsgEntity)
{
	static szSound[17]
	get_msg_arg_string(2,szSound,16)
	if(equal(szSound[7], "terwin") || equal(szSound[7], "ctwin") || equal(szSound[7], "rounddraw")) return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public ham_WeaponTouch(iEnt, iToucher)
{
	if ((1 <= iToucher <= MaxClients) && g_isZombie[iToucher])
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public ham_TakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_valid_ent(victim) || !g_isAlive[victim] || !is_user_connected(attacker))
		return HAM_IGNORED
	
	if (victim != attacker)
	{
		if (g_boolCanBuild && g_isZombie[victim] == g_isZombie[attacker] && g_boolFreeZombies[victim] && g_boolFreeZombies[attacker])
		{
			new vteam = get_ent_data(victim, "CBasePlayer", "m_iTeam");
			if (vteam == get_ent_data(attacker, "CBasePlayer", "m_iTeam"))
			{
				set_ent_data(victim, "CBasePlayer", "m_iTeam", vteam == 1 ? 2 : 1);
				ExecuteHamB(Ham_TakeDamage, victim, inflictor, attacker, damage, damagebits);
				set_ent_data(victim, "CBasePlayer", "m_iTeam", vteam);
				return HAM_SUPERCEDE;
			}
		}
	}

	if (g_boolCanBuild && g_isZombie[victim] != g_isZombie[attacker] && (!g_boolFreeZombies[victim] || !g_boolFreeZombies[attacker]))
		return HAM_SUPERCEDE;

	if(g_boolRoundEnded || g_boolPrepTime || victim == attacker)
		return HAM_SUPERCEDE
		
	if (g_iSupercut)
	{
		damage*=99.0
	}
		
	SetHamParamFloat(4, damage)
	return HAM_HANDLED
}

public ham_ItemDeploy_Post(weapon_ent)
{
	static owner
	owner = get_pdata_cbase(weapon_ent, OFFSET_WPN_WIN, OFFSET_WPN_LINUX);

	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	if (g_isZombie[owner] && weaponid == CSW_KNIFE)
	{
		static szClawModel[100]
		ArrayGetString(g_zclass_clawmodel, g_iZombieClass[owner], szClawModel, charsmax(szClawModel))
		format(szClawModel, charsmax(szClawModel), "models/%s.mdl", szClawModel)
		entity_set_string( owner , EV_SZ_viewmodel , szClawModel )  
		entity_set_string( owner , EV_SZ_weaponmodel , "" ) 
	}
	
	if (g_isZombie[owner] && !((1<<weaponid) & ZOMBIE_ALLOWED_WEAPONS_BITSUM))
	{
		engclient_cmd(owner, "weapon_knife")
	}
	else if (g_boolCanBuild)
	{
		engclient_cmd(owner, "weapon_knife")
		client_print(owner, print_center, "%L", owner, "FAIL_KNIFE");
	}
}

public logevent_round_start()
{
	set_pev(g_iEntBarrier,pev_solid,SOLID_BSP)
	set_pev(g_iEntBarrier,pev_rendermode,kRenderTransColor)
	set_pev(g_iEntBarrier,pev_rendercolor, Float:{ BARRIER_COLOR })
	set_pev(g_iEntBarrier,pev_renderamt, Float:{ BARRIER_RENDERAMT })
	
	client_print_color(0, print_team_default, "^x04 ---[ Base Builder %s ]---", VERSION);
	client_print_color(0, print_team_default, "^x03 %L", LANG_PLAYER, "ROUND_MESSAGE");

	client_cmd(0, "spk %s", PHASE_BUILD)
	
	remove_task(TASK_BUILD)
	set_task(1.0, "task_CountDown", TASK_BUILD,_, _, "a", g_iBuildTime);
	g_iCountDown = (g_iBuildTime-1);
	
	ExecuteForward(g_fwBuildStarted, g_fwDummyResult);
}

public task_CountDown()
{
	g_iCountDown--
	new mins = g_iCountDown/60, secs = g_iCountDown%60
	if (g_iCountDown>=0)
	{
		set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.5, 0.0, 0.2, 2);
		show_hudmessage(0, "%L - %d:%s%d", LANG_PLAYER, "BUILD_TIMER", mins, (secs < 10 ? "0" : ""), secs);
		//client_print(0, print_center, "%L - %d:%s%d", LANG_PLAYER, "BUILD_TIMER", mins, (secs < 10 ? "0" : ""), secs)
	}
	else
	{
		if (g_iPrepTime)
		{
			g_boolCanBuild = false
			g_boolPrepTime = true
			g_iCountDown = g_iPrepTime+1
			set_task(1.0, "task_PrepTime", TASK_PREPTIME,_, _, "a", g_iCountDown);
			
			new players[32], num, player
			get_players(players, num)
			for (new i = 0; i < num; i++)
			{
				player = players[i];

				if (g_isConnected[player])
				{
					g_boolFreeZombies[player] = false;
				}

				if (g_isAlive[player])
				{
					ExecuteHamB(Ham_CS_RoundRespawn, player);
					
					if (g_iOwnedEnt[player])
						cmdStopEnt(player);
				}
			}

			set_dhudmessage(255, 255, 255, -1.0, 0.25, 0, 0.0, 7.5, 0.5, 1.0)
			show_dhudmessage(0, "%L", LANG_PLAYER, "PREP_ANNOUNCE");

			client_print_color(0, print_team_default, "%s^x04 %L", MODNAME, LANG_PLAYER, "PREP_ANNOUNCE")
			
			client_cmd(0, "spk %s", PHASE_PREP)
			
			ExecuteForward(g_fwPrepStarted, g_fwDummyResult);
		}
		else
			Release_Zombies()

		remove_task(TASK_BUILD);
		return PLUGIN_HANDLED;
	}
	
	new szTimer[32]
	if (g_iCountDown>10)
	{
		if (mins && !secs) num_to_word(mins, szTimer, 31)
		else if (!mins && secs == 30) num_to_word(secs, szTimer, 31)
		else return PLUGIN_HANDLED;
		
		client_cmd(0, "spk ^"fvox/%s %s remaining^"", szTimer, (mins ? "minutes" : "seconds"))
	}
	else
	{
		num_to_word(g_iCountDown, szTimer, 31)
		client_cmd(0, "spk ^"fvox/%s^"", szTimer)
	}
	return PLUGIN_CONTINUE;
}

public task_PrepTime()
{
	g_iCountDown--
	
	if (g_iCountDown>=0)
	{
		set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.5, 0.0, 0.2, 2);
		show_hudmessage(0, "%L - 0:%s%d", LANG_PLAYER, "PREP_TIMER", (g_iCountDown < 10 ? "0" : ""), g_iCountDown);
		//client_print(0, print_center, "%L - 0:%s%d", LANG_PLAYER, "PREP_TIMER", (g_iCountDown < 10 ? "0" : ""), g_iCountDown)
	}

	if (0<g_iCountDown<11)
	{
		new szTimer[32]
		num_to_word(g_iCountDown, szTimer, 31)
		client_cmd(0, "spk ^"fvox/%s^"", szTimer)
	}
	else if (g_iCountDown == 0)
	{
		Release_Zombies()
		remove_task(TASK_PREPTIME);
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE;
}

public logevent_round_end()
{
	if (g_boolRoundEnded)
	{
		new players[32], num, player
		get_players(players, num)
		for (new i = 0; i < num; i++)
		{
			player = players[i]
			
			if (g_iCurTeam[player] == g_iTeam[player] )
				cs_set_user_team(player, (g_iTeam[player] = (g_iTeam[player] == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T)))
			else
				g_iTeam[player] = g_iTeam[player] == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T
		}
		client_print_color(0, print_team_default, "%s^x04 %L", MODNAME, LANG_PLAYER, "SWAP_ANNOUNCE")
	}
	remove_task(TASK_BUILD)	
	return PLUGIN_HANDLED
}

public client_death(g_attacker, g_victim, wpnindex, hitplace, TK)
{
	if (is_user_alive(g_victim))
		return PLUGIN_HANDLED;
	
	remove_task(g_victim+TASK_IDLESOUND)
	
	g_isAlive[g_victim] = false;
	/*
	if (TK == 0 && g_attacker != g_victim && g_isZombie[g_attacker] && !g_isZombie[g_victim])
	{
		client_cmd(0, "spk %s", INFECTION)
		ew szPlayerName[32]
		get_user_name(g_victim, szPlayerName, 31)
		set_hudmessage(255, 255, 255, -1.0, 0.45, 0, 1.0, 5.0, 0.1, 0.2, 1)
		show_hudmessage(0, "%L", LANG_PLAYER, "INFECT_ANNOUNCE", szPlayerName);
	}*/
	
	set_hudmessage(255, 255, 255, -1.0, 0.4, 0, 1.0, 10.0, 0.1, 0.2, 1)
	if (g_isZombie[g_victim])
	{
		show_hudmessage(g_victim, "%L", g_victim, "DEATH_ZOMBIE", g_iZombieTime);
		set_task(float(g_iZombieTime), "Respawn_Player", g_victim+TASK_RESPAWN)
	}
	else if (g_iInfectTime)
	{
		show_hudmessage(g_victim, "%L", g_victim, "DEATH_HUMAN", g_iInfectTime);
		cs_set_user_team(g_victim, CS_TEAM_T)
		g_isZombie[g_victim] = true
		set_task(float(g_iInfectTime), "Respawn_Player", g_victim+TASK_RESPAWN)
	}
	
	return PLUGIN_CONTINUE;
}

public Respawn_Player(id)
{
	id-=TASK_RESPAWN
	
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
	
	if (((g_boolCanBuild || g_boolPrepTime) && cs_get_user_team(id) == CS_TEAM_CT) || cs_get_user_team(id) == CS_TEAM_T)
	{
		ExecuteHamB(Ham_CS_RoundRespawn, id)
		
		//Loop the task until they have successfully spawned
		if (!g_isAlive[id])
			set_task(3.0,"Respawn_Human",id+TASK_RESPAWN)
	}
	return PLUGIN_HANDLED
}

public ham_PlayerSpawn_Post(id)
{
	if (is_user_alive(id))
	{
		g_isAlive[id] = true;
		
		g_isZombie[id] = (cs_get_user_team(id) == CS_TEAM_T ? true : false)
		
		remove_task(id + TASK_RESPAWN)
		remove_task(id + TASK_MODELSET)
		remove_task(id + TASK_IDLESOUND)
		if (g_isZombie[id])
		{
			if (g_boolFirstSpawn[id])
			{
				client_print_color(id, print_team_default, "This server is running Base Builder v%s by Tirant", VERSION);
				//show_zclass_menu(id, 0)
				g_boolFirstSpawn[id] = false
			}
			
			if (g_iNextClass[id] != g_iZombieClass[id])
				g_iZombieClass[id] = g_iNextClass[id]

			if (!g_boolFreeZombies[id])
			{
				set_pev(id, pev_health, float(ArrayGetCell(g_zclass_hp, g_iZombieClass[id]))/**g_fClassMultiplier[id][ATT_HEALTH]*/)
				set_pev(id, pev_gravity, Float:ArrayGetCell(g_zclass_grav, g_iZombieClass[id])/**g_fClassMultiplier[id][ATT_GRAVITY]*/)
				g_fPlayerSpeed[id] = float(ArrayGetCell(g_zclass_spd, g_iZombieClass[id]))/**g_fClassMultiplier[id][ATT_SPEED]*/

				set_user_rendering(id);
				ShowTeamKillMenu(id);
			}
			else
			{
				set_user_rendering(id, kRenderFxGlowShell, 200, 0, 0, kRenderNormal, 16);
				set_pev(id, pev_health, 200.0);
				set_pev(id, pev_gravity, 1.0);
				g_fPlayerSpeed[id] = 250.0;
			}

			//Handles the knife and claw model
			strip_user_weapons(id)
			give_item(id, "weapon_knife")
							
			static szClawModel[100]
			ArrayGetString(g_zclass_clawmodel, g_iZombieClass[id], szClawModel, charsmax(szClawModel))
			format(szClawModel, charsmax(szClawModel), "models/%s.mdl", szClawModel)
			entity_set_string( id , EV_SZ_viewmodel , szClawModel )  
			entity_set_string( id , EV_SZ_weaponmodel , "" ) 
						
			ArrayGetString(g_zclass_name, g_iZombieClass[id], g_szPlayerClass[id], charsmax(g_szPlayerClass[]))
			
			set_task(random_float(60.0, 360.0), "task_ZombieIdle", id+TASK_IDLESOUND, _, _, "b")

			new model[32];
			ArrayGetString(g_zclass_playermodel, g_iZombieClass[id], model, charsmax(model));

			cs_set_user_model(id, model);
			/*
			new szCurrentModel[32]
			fm_get_user_model(id, szCurrentModel, charsmax(szCurrentModel))
			if (!equal(szCurrentModel, g_szPlayerModel[id]))
			{
				if (get_gametime() - g_fRoundStartTime < 5.0)
					set_task(5.0 * MODELCHANGE_DELAY, "fm_user_model_update", id + TASK_MODELSET)
				else
					fm_user_model_update(id + TASK_MODELSET)
			}*/
			
			ExecuteForward(g_fwClassSet, g_fwDummyResult, id, g_iZombieClass[id]);
		}
		else
		{
			set_user_rendering(id);
			cs_reset_user_model(id);

			entity_set_string( id , EV_SZ_viewmodel , "models/v_knife.mdl" )  
			
			if (((/*g_boolPrepTime && */g_iPrepTime && !g_boolCanBuild) || (g_boolCanBuild && !g_iPrepTime)) && g_iGunsMenu)
			{
				//if (is_credits_active())
				#if defined BB_CREDITS
					credits_show_gunsmenu(id)
				#else
					show_method_menu(id)
				#endif
			}
				
			if (!g_iColor[id])
			{
				new i = random(MAX_COLORS)
				if (g_iColorMode)
				{
					while (g_iColorOwner[i])
					{
						i = random(MAX_COLORS)
					}
				}
				client_print_color(id, print_team_default, "%s^x04 %L:^x01 %s", MODNAME, id, "COLOR_PICKED", g_szColorName[i]);
				g_iColor[id] = i
				g_iColorOwner[i] = id

				if (g_iOwnedEnt[id])
				{
					set_pev(g_iOwnedEnt[id],pev_rendercolor, g_fColor[g_iColor[id]] )
					set_pev(g_iOwnedEnt[id],pev_renderamt, g_fRenderAmt[g_iColor[id]] )
				}
			}

			copy(g_szPlayerClass[id], charsmax(g_szPlayerClass[]), "Builder");
		}
		
		//ev_Health(id)
	}
}

public task_ZombieIdle(taskid)
{
	taskid-=TASK_IDLESOUND
	if (g_isAlive[taskid] && g_isConnected[taskid] && !g_isZombie[taskid])
		emit_sound(taskid, CHAN_VOICE, g_szZombieIdle[random(sizeof g_szZombieIdle - 1)], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public fw_SetClientKeyValue(id, const infobuffer[], const key[])
{   
	if (g_isCustomModel[id] && equal(key, "model"))
		return FMRES_SUPERCEDE
	return FMRES_IGNORED
}
/*
public fw_ClientUserInfoChanged(id)
{
	if (!g_isCustomModel[id])
		return FMRES_IGNORED
	static szCurrentModel[32]
	fm_get_user_model(id, szCurrentModel, charsmax(szCurrentModel))
	if (!equal(szCurrentModel, g_szPlayerModel[id]) && !task_exists(id + TASK_MODELSET))
		fm_set_user_model(id + TASK_MODELSET)
	return FMRES_IGNORED
}

public fm_user_model_update(taskid)
{
	static Float:fCurTime
	fCurTime = get_gametime()
	
	if (fCurTime - g_fModelsTargetTime >= MODELCHANGE_DELAY)
	{
		fm_set_user_model(taskid)
		g_fModelsTargetTime = fCurTime
	}
	else
	{
		set_task((g_fModelsTargetTime + MODELCHANGE_DELAY) - fCurTime, "fm_set_user_model", taskid)
		g_fModelsTargetTime += MODELCHANGE_DELAY
	}
}

public fm_set_user_model(player)
{
	player -= TASK_MODELSET
	engfunc(EngFunc_SetClientKeyValue, player, engfunc(EngFunc_GetInfoKeyBuffer, player), "model", g_szPlayerModel[player])
	g_isCustomModel[player] = true
}

stock fm_get_user_model(player, model[], len)
{
	engfunc(EngFunc_InfoKeyValue, engfunc(EngFunc_GetInfoKeyBuffer, player), "model", model, len)
}

stock fm_reset_user_model(player)
{
	g_isCustomModel[player] = false
	dllfunc(DLLFunc_ClientUserInfoChanged, player, engfunc(EngFunc_GetInfoKeyBuffer, player))
}
*/
public message_show_menu(msgid, dest, id) 
{
	if (!(!get_user_team(id) && !is_user_bot(id) && !access(id, ADMIN_IMMUNITY)))
		return PLUGIN_CONTINUE

	static team_select[] = "#Team_Select"
	static menu_text_code[sizeof team_select]
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1)
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE

	static param_menu_msgid[2]
	param_menu_msgid[0] = msgid
	set_task(AUTO_TEAM_JOIN_DELAY, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid)

	return PLUGIN_HANDLED
}

public message_vgui_menu(msgid, dest, id) 
{
	if (get_msg_arg_int(1) != TEAM_SELECT_VGUI_MENU_ID || !(!get_user_team(id) && !is_user_bot(id) && !access(id, ADMIN_IMMUNITY)))// 
		return PLUGIN_CONTINUE
		
	static param_menu_msgid[2]
	param_menu_msgid[0] = msgid
	set_task(AUTO_TEAM_JOIN_DELAY, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid)

	return PLUGIN_HANDLED
}

public task_force_team_join(menu_msgid[], id) 
{
	if (get_user_team(id))
		return

	static msg_block
	msg_block = get_msg_block(menu_msgid[0])
	set_msg_block(menu_msgid[0], BLOCK_SET)
	engclient_cmd(id, "jointeam", "5")
	engclient_cmd(id, "joinclass", "5")
	set_msg_block(menu_msgid[0], msg_block)
}

public msgTeamInfo(msgid, dest)
{
	if (dest != MSG_ALL && dest != MSG_BROADCAST)
		return;
	
	static id, team[2]
	id = get_msg_arg_int(1)

	get_msg_arg_string(2, team, charsmax(team))
	switch (team[0])
	{
		case 'T' : // TERRORIST
		{
			g_iCurTeam[id] = CS_TEAM_T;
		}
		case 'C' : // CT
		{
			g_iCurTeam[id] = CS_TEAM_CT;
		}
		case 'S' : // SPECTATOR
		{
			g_iCurTeam[id] = CS_TEAM_SPECTATOR;
		}
		default : g_iCurTeam[id] = CS_TEAM_UNASSIGNED;
	}
	if (!g_boolFirstTeam[id])
	{
		g_boolFirstTeam[id] = true
		g_iTeam[id] = g_iCurTeam[id]
	}
}

public clcmd_changeteam(id)
{
	static CsTeams:team
	team = cs_get_user_team(id)
	
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE;

	show_zclass_menu(id, 0)
	return PLUGIN_HANDLED;
}
/*
public clcmd_drop(id)
{
	client_print (id, print_center, "%L", id, "FAIL_DROP")
	return PLUGIN_HANDLED
}*/

public clcmd_buy(id)
{
	client_print (id, print_center, "%L", id, "FAIL_BUY")
	return PLUGIN_HANDLED
}

public msgStatusValue()
{
	set_msg_block(g_msgStatusText, BLOCK_SET);
}
/*
public ev_SetTeam(id)
{
	g_iFriend[id] = read_data(2)
}

public ev_ShowStatus(id) //called when id looks at someone
{
	new szName[32], pid = read_data(2);
	get_user_name(pid, szName, 31);

	if (g_iFriend[id] == 1)	// friend
	{
		new clip, ammo, wpnid = get_user_weapon(pid, clip, ammo), szWpnName[32];

		if (wpnid)
			xmod_get_wpnname(wpnid, szWpnName, 31);

		set_hudmessage(0, 255, 0, -1.0, HUD_FRIEND_HEIGHT, 0, 0.00, 5.0, 0.0, 0.5, 4);
		new nLen, szStatus[512]
		if (!g_isZombie[pid])
			nLen += format( szStatus[nLen], 511-nLen, "%s^nHealth: %d | Weapon: %s^nColor: %s", szName, pev(pid, pev_health), szWpnName, g_szColorName[g_iColor[pid]]);
		else
		{
			nLen += format( szStatus[nLen], 511-nLen, "%s^nClass: %s^nHealth: %d", szName, g_szPlayerClass[pid], pev(pid, pev_health));
			
			if (is_credits_active())
			{
				nLen += format( szStatus[nLen], 511-nLen, "^n^nClass Multipliers:", szName, g_szPlayerClass[pid], pev(pid, pev_health));
				nLen += format( szStatus[nLen], 511-nLen, "^nHealth: %f", g_fClassMultiplier[pid][ATT_HEALTH]);
				nLen += format( szStatus[nLen], 511-nLen, "^nSpeed: %f", g_fClassMultiplier[pid][ATT_SPEED]);
				nLen += format( szStatus[nLen], 511-nLen, "^nGravity: %f", g_fClassMultiplier[pid][ATT_GRAVITY]);
			}
		}
		show_hudmessage(id, szStatus);
	} 
	if (g_iFriend[id] != 1) //enemy
	{
		set_hudmessage(255, 0, 0, -1.0, HUD_FRIEND_HEIGHT, 0, 0.00, 5.0, 0.0, 0.5, 4);
		if (g_isZombie[pid])
			show_hudmessage(id, "%s", szName);
		else
			show_hudmessage(id, "%s^n%L: %s", szName, id, "COLOR", g_szColorName[g_iColor[pid]]);
	}
}

public ev_HideStatus(id)
{
	set_hudmessage(.fxtime=0.0, .holdtime=0.1, .fadeintime=0.0, .fadeouttime=0.0, .channel=4);
	show_hudmessage(id, "^n");
}*/

public cmdSay(id)
{
	if (!g_isConnected[id])
		return PLUGIN_HANDLED;

	new szMessage[32]
	read_args(szMessage, charsmax(szMessage));
	remove_quotes(szMessage);
		
	if(szMessage[0] == '/')
	{
		if (equali(szMessage, "/commands") == 1 || equali(szMessage, "/cmd")  == 1 )
		{
			client_print_color(id, print_team_default, "%s /class, /respawn, /random, /mycolor, /guns%s%s%s", MODNAME, (g_iColorMode ? ", /whois <color>": ""), (g_iColorMode != 2 ? ", /colors":""), (access(id, FLAGS_LOCK) ? ", /lock":"")  );
		}
		else if (equali(szMessage, "/class") == 1)
		{
			show_zclass_menu(id, 0)
		}
		else if (equali(szMessage, "/respawn") == 1 || equali(szMessage, "/revive")  == 1 || equali(szMessage, "/fixspawn")  == 1)
		{
			if (g_boolCanBuild && !g_isZombie[id])
				ExecuteHamB(Ham_CS_RoundRespawn, id)
			else if (g_isZombie[id])
			{
				if (pev(id, pev_health) == float(ArrayGetCell(g_zclass_hp, g_iZombieClass[id])) || !is_user_alive(id))
					ExecuteHamB(Ham_CS_RoundRespawn, id)
				else
					client_print(id, print_center, "%L", id, "FAIL_SPAWN");
			}
		}
		else if (equali(szMessage, "/lock") == 1 || equali(szMessage, "/claim") == 1 && g_isAlive[id])
		{
			if (access(id, FLAGS_LOCK))
				cmdLockBlock(id)
			else
				client_print(id, print_center, "%L", id, "FAIL_ACCESS");
			return PLUGIN_HANDLED;
		}
		else if (equal(szMessage, "/whois",6) && g_iColorMode)
		{
			for ( new i=0; i<MAX_COLORS; i++)
			{
				if (equali(szMessage[7], g_szColorName[i]) == 1)
				{
					if (g_iColorOwner[i])
					{
						new szPlayerName[32]
						get_user_name(g_iColorOwner[i], szPlayerName, 31)
						client_print_color(id, print_team_default, "%s^x04 %s^x01%L^x04 %s", MODNAME, szPlayerName, id, "COLOR_IS", g_szColorName[i]);
					}
					else
						client_print_color(id, print_team_default, "%s %L^x04 %s", MODNAME, id, "COLOR_NONE", g_szColorName[i]);
						
					break;
				}
			}
		}
		else if (equali(szMessage, "/colors") == 1 && !g_isZombie[id] && g_boolCanBuild && g_iColorMode != 2)
		{
			show_colors_menu(id, 0)
		}
		else if (equali(szMessage, "/mycolor") == 1 && !g_isZombie[id])
		{
			client_print_color(id, print_team_default, "%s^x04 %L:^x01 %s", MODNAME, id, "COLOR_YOURS", g_szColorName[g_iColor[id]]);
			return PLUGIN_HANDLED
		}
		else if (equali(szMessage, "/random") == 1 && !g_isZombie[id] && g_boolCanBuild)
		{
			new i = random(MAX_COLORS)
			if (g_iColorMode)
			{
				while (g_iColorOwner[i])
				{
					i = random(MAX_COLORS)
				}
			}
			client_print_color(id, print_team_default, "%s^x04 %L:^x01 %s", MODNAME, id, "COLOR_RANDOM", g_szColorName[i]);
			g_iColorOwner[g_iColor[id]] = 0
			g_iColor[id] = i
			g_iColorOwner[i] = id
			
			new iEnt = FM_NULLENT;
			while ((iEnt = find_ent_by_class(iEnt, "func_wall")))
			{
				if (is_valid_ent(iEnt) && g_iLockBlocks && BlockLocker(iEnt) == id)
					set_pev(iEnt,pev_rendercolor,g_fColor[g_iColor[id]])
			}
			
			ExecuteForward(g_fwNewColor, g_fwDummyResult, id, g_iColor[id]);
		}
		else if (equali(szMessage, "/guns", 5) && g_iGunsMenu)
		{
			if (access(id, FLAGS_GUNS))
			{
				new player = cmd_target(id, szMessage[6], 0)
			
				if (!player)
				{
					//if (is_credits_active())
					#if defined BB_CREDITS
						credits_show_gunsmenu(id)
					#else
						show_method_menu(id)
					#endif
					return PLUGIN_CONTINUE
				}
				
				cmdGuns(id, player)
			}
			
			if(!g_isAlive[id] || g_isZombie[id])
				return PLUGIN_HANDLED
			
			if(!g_boolCanBuild && !access(id, FLAGS_GUNS) && !g_boolRepick[id])
				return PLUGIN_HANDLED	
		
			//if (is_credits_active())
			#if defined BB_CREDITS
				credits_show_gunsmenu(id)
			#else
				show_method_menu(id)
			#endif
			return PLUGIN_HANDLED
		}
		else if (equal(szMessage, "/swap",5) && access(id, FLAGS_SWAP))
		{
			new player = cmd_target(id, szMessage[6], 0)
		
			if (!player)
			{
				client_print_color(id, print_team_default, "%s %L", MODNAME, id, "PLAYER_NOT_FOUND", szMessage[6])
				return PLUGIN_CONTINUE
			}
			
			cmdSwap(id, player)
		}
		else if (equal(szMessage, "/revive",7) && access(id, FLAGS_REVIVE))
		{
			new player = cmd_target(id, szMessage[8], 0)
		
			if (!player)
			{
				client_print_color(id, print_team_default, "%s %L", MODNAME, id, "PLAYER_NOT_FOUND", szMessage[6])
				return PLUGIN_CONTINUE
			}
			
			cmdRevive(id, player)
		}
		else if (equal(szMessage, "/ban",4) && access(id, FLAGS_BUILDBAN))
		{
			new player = cmd_target(id, szMessage[5], 0)
		
			if (!player)
			{
				client_print_color(id, print_team_default, "%s %L", MODNAME, id, "PLAYER_NOT_FOUND", szMessage[6])
				return PLUGIN_CONTINUE
			}
			
			cmdBuildBan(id, player)
		}
		else if (equal(szMessage, "/releasezombies",5) && access(id, FLAGS_RELEASE))
		{
			cmdStartRound(id)
		}
		else if (equal(szMessage, "/tk", 3))
		{
			cmdTeamKill(id);
		}
	}
	return PLUGIN_CONTINUE
}

public cmdSwap(id, target)
{
	if (access(id, FLAGS_SWAP))
	{
		new player
		
		if (target) player = target
		else
		{
			new arg[32]
			read_argv(1, arg, 31)
			player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
		}

		if (!player || !is_user_connected(player))
			return client_print(id, print_console, "[Base Builder] %L", id, "FAIL_NAME");
			
		cs_set_user_team(player,( g_iTeam[player] = g_iTeam[player] == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T))
			
		if (is_user_alive(player))
			ExecuteHamB(Ham_CS_RoundRespawn, player)
		
		new szAdminAuthid[32],szAdminName[32],szPlayerName[32],szPlayerID[32]
		get_user_name(id,szAdminName,31)
		get_user_authid (id,szAdminAuthid,31)
		get_user_name(player, szPlayerName, 31)
		get_user_authid (player,szPlayerID,31)
		
		client_print(id, print_console, "[Base Builder] Player %s was swapped from the %s team to the %s team", szPlayerName, g_iTeam[player] == CS_TEAM_CT ? "zombie":"builder", g_iTeam[player] == CS_TEAM_CT ? "builder":"zombie")
		Log("[SWAP] Admin: %s || SteamID: %s swapped Player: %s || SteamID: %s", szAdminName, szAdminAuthid, szPlayerName, szPlayerID)
		
		//set_hudmessage(255,0, 0, -1.0, 0.4, 0, 0.0, 7.5, 0.0, 0.5, 1)
		//show_hudmessage(player, "%L", player, "ADMIN_SWAP");
		
		client_print_color(0, print_team_default, "%s %L", MODNAME, LANG_PLAYER, "PLAYER_SWAP_TEAM", szPlayerName, g_iTeam[player] == CS_TEAM_CT ? "builder":"zombie")
	}
	return PLUGIN_HANDLED	
}

public cmdRevive(id, target)
{
	if (access(id, FLAGS_REVIVE))
	{
		new player
		if (target) player = target
		else
		{
			new arg[32]
			read_argv(1, arg, 31)
			player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
		}

		if (!player || !is_user_connected(player))
			return client_print(id, print_console, "[Base Builder] %L", id, "FAIL_NAME");
			
		ExecuteHamB(Ham_CS_RoundRespawn, player)
		
		new szAdminAuthid[32],szAdminName[32],szPlayerName[32],szPlayerID[32]
		get_user_name(id,szAdminName,31)
		get_user_authid (id,szAdminAuthid,31)
		get_user_name(player, szPlayerName, 31)
		get_user_authid (player,szPlayerID,31)
		
		client_print(id, print_console, "[Base Builder] Player %s has been^x04 revived", szPlayerName)
		Log("[REVIVE] Admin: %s || SteamID: %s revived Player: %s || SteamID: %s", szAdminName, szAdminAuthid, szPlayerName, szPlayerID)
		
		//set_hudmessage(255,0, 0, -1.0, 0.4, 0, 0.0, 7.5, 0.0, 0.5, 1)
		//show_hudmessage(player, "%L", player, "ADMIN_REVIVE");
		
		client_print_color(0, print_team_default, "%s %L", MODNAME, LANG_PLAYER, "PLAYER_REVIVED", szPlayerName)
	}
	return PLUGIN_HANDLED	
}

public cmdGuns(id, target)
{
	if (access(id, FLAGS_GUNS))
	{
		new player
		if (target) player = target
		else
		{
			new arg[32]
			read_argv(1, arg, 31)
			player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
		}

		if (!player || !is_user_connected(player))
			return client_print(id, print_console, "[Base Builder] %L", id, "FAIL_NAME");
			
		if (!g_isAlive[player])
			return client_print(id, print_console, "[Base Builder] %L", id, "FAIL_DEAD");

		//if (is_credits_active())
		#if defined BB_CREDITS
			credits_show_gunsmenu(player)
		#else
			show_method_menu(player)
		#endif
		
		new szAdminAuthid[32],szAdminName[32],szPlayerName[32],szPlayerID[32]
		get_user_name(id,szAdminName,31)
		get_user_authid (id,szAdminAuthid,31)
		get_user_name(player, szPlayerName, 31)
		get_user_authid (player,szPlayerID,31)
		
		client_print(id, print_console, "[Base Builder] Player %s has had his weapons menu re-opened", szPlayerName);
		Log("[GUNS] Admin: %s || SteamID: %s opened the guns menu for Player: %s || SteamID: %s", szAdminName, szAdminAuthid, szPlayerName, szPlayerID);
		
		//set_hudmessage(255,0, 0, -1.0, 0.4, 0, 0.0, 7.5, 0.0, 0.5, 1)
		//show_hudmessage(player, "%L", player, "ADMIN_GUNS");
		
		client_print_color(0, print_team_default, "%s %L", MODNAME, LANG_PLAYER, "PLAYER_REOPEN_GUNMENU", szPlayerName)
	}
	return PLUGIN_HANDLED	
}

public cmdStartRound(id)
{
	if (access(id, FLAGS_RELEASE))
	{
		native_release_zombies()
	}
}

public Release_Zombies()
{
	g_boolCanBuild = false
	remove_task(TASK_BUILD);
	
	g_boolPrepTime = false
	remove_task(TASK_PREPTIME);
	
	new players[32], num, player, szWeapon[32]
	get_players(players, num, "a")
	for(new i = 0; i < num; i++)
	{
		player = players[i]

		if (!g_isZombie[player])
		{
			if (g_iOwnedEnt[player])
				cmdStopEnt(player)

			if(g_iGrenadeHE		) give_item(player,"weapon_hegrenade"	), cs_set_user_bpammo(player,CSW_HEGRENADE,	g_iGrenadeHE)
			if(g_iGrenadeFLASH	) give_item(player,"weapon_flashbang"	), cs_set_user_bpammo(player,CSW_FLASHBANG,	g_iGrenadeFLASH)
			if(g_iGrenadeSMOKE	) give_item(player,"weapon_smokegrenade"	), cs_set_user_bpammo(player,CSW_SMOKEGRENADE,	g_iGrenadeSMOKE)

			if (g_iPrimaryWeapon[player])
			{
				get_weaponname(g_iPrimaryWeapon[player],szWeapon,sizeof szWeapon - 1)
				engclient_cmd(player, szWeapon);
			}
		}
	}
			
	set_pev(g_iEntBarrier,pev_solid,SOLID_NOT)
	set_pev(g_iEntBarrier,pev_renderamt,Float:{ 0.0 })

	set_lights(g_szLightLevel);
	
	set_dhudmessage(200, 100, 0, -1.0, 0.25, 0, 0.0, 8.5, 0.5, 1.0)
	show_dhudmessage(0, "%L", LANG_PLAYER, "RELEASE_ANNOUNCE");
	client_cmd(0, "spk %s", g_szRoundStart[ random( sizeof g_szRoundStart ) ] )
	
	ExecuteForward(g_fwRoundStart, g_fwDummyResult);
}

public fw_CmdStart( id, uc_handle, randseed )
{
	if (!g_isConnected[id] || !g_isAlive[id])
		return FMRES_IGNORED

	//new button = pev(id, pev_button)
	new button = get_uc( uc_handle , UC_Buttons );
	new oldbutton = pev(id, pev_oldbuttons)

	if( button & IN_USE && !(oldbutton & IN_USE) && !g_iOwnedEnt[id])
		cmdGrabEnt(id)
	else if( oldbutton & IN_USE && !(button & IN_USE) && g_iOwnedEnt[id])
		cmdStopEnt(id)

	return FMRES_IGNORED;
}

public cmdGrabEnt(id)
{
	if (get_gametime() < g_fBuildDelay[id] + BUILD_DELAY)
	{
		client_print (id, print_center, "%L", id, "BUILD_SPAM")
		return PLUGIN_HANDLED
	}
	else
	{
		g_fBuildDelay[id] = get_gametime()
	}

	if (g_isBuildBan[id])
	{
		client_print (id, print_center, "%L", id, "BUILD_BANNED")
		client_cmd(id, "spk %s", LOCK_FAIL);
		return PLUGIN_HANDLED;
	}
	
	if (g_isZombie[id] && !access(id, FLAGS_OVERRIDE))
		return PLUGIN_HANDLED
		
	if (!g_boolCanBuild && !access(id, FLAGS_BUILD) && !access(id, FLAGS_OVERRIDE))
	{
		client_print (id, print_center, "%L", id, "BUILD_NOTIME")
		return PLUGIN_HANDLED
	}
	
	if (g_iOwnedEnt[id] && is_valid_ent(g_iOwnedEnt[id])) 
		cmdStopEnt(id)
	
	/*
	new ent, bodypart
	get_user_aiming (id,ent,bodypart)
	*/

    new Float:start[3], Float:end[3];
    pev(id, pev_origin, start);
    pev(id, pev_view_ofs, end);
    xs_vec_add(start, end, start);

    velocity_by_aim(id, 4096, end);
    xs_vec_add(start, end, end);

    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, id, 0);

    new ent = get_tr2(0, TR_pHit);

	if (!is_valid_ent(ent) || ent == g_iEntBarrier || is_user_alive(ent) || IsMovingEnt(ent))
		return PLUGIN_HANDLED;
	
	if ((BlockLocker(ent) && BlockLocker(ent) != id) || (BlockLocker(ent) && !access(id, FLAGS_OVERRIDE)))
		return PLUGIN_HANDLED;
	
	new szClass[10], szTarget[7];
	entity_get_string(ent, EV_SZ_classname, szClass, 9);
	entity_get_string(ent, EV_SZ_targetname, szTarget, 6);
	if (!equal(szClass, "func_wall") || equal(szTarget, "ignore"))
		return PLUGIN_HANDLED;
		
	ExecuteForward(g_fwGrabEnt_Pre, g_fwDummyResult, id, ent);

	new Float:endpos[3], Float:origin[3];
    get_tr2(0, TR_vecEndPos, endpos);
    entity_get_vector(ent, EV_VEC_origin, origin);

    xs_vec_sub(origin, endpos, g_fOffset[id]);

    g_fEntDist[id] = get_distance_f(start, endpos);

    if (g_fEntMinDist && g_fEntDist[id] < g_fEntMinDist)
        g_fEntDist[id] = g_fEntMinDist;
    else if (g_fEntMaxDist && g_fEntDist[id] > g_fEntMaxDist)
        return PLUGIN_HANDLED;

/*
	new Float:fOrigin[3], iAiming[3], Float:fAiming[3]
	
	get_user_origin(id, iAiming, 3);
	IVecFVec(iAiming, fAiming);
	entity_get_vector(ent, EV_VEC_origin, fOrigin);

	g_fOffset1[id] = fOrigin[0] - fAiming[0];
	g_fOffset2[id] = fOrigin[1] - fAiming[1];
	g_fOffset3[id] = fOrigin[2] - fAiming[2];
	
	g_fEntDist[id] = get_user_aiming(id, ent, bodypart);
		
	if (g_fEntMinDist)
	{
		if (g_fEntDist[id] < g_fEntMinDist)
			g_fEntDist[id] = g_fEntSetDist;
	}
	else if (g_fEntMaxDist)
	{
		if (g_fEntDist[id] > g_fEntMaxDist)
			return PLUGIN_HANDLED
	}*/

	set_pev(ent,pev_rendermode,kRenderTransColor)
	set_pev(ent,pev_rendercolor, g_fColor[g_iColor[id]] )
	set_pev(ent,pev_renderamt, g_fRenderAmt[g_iColor[id]] )
		
	MovingEnt(ent);
	SetEntMover(ent, id);
	g_iOwnedEnt[id] = ent
/*
	set_pev(id, pev_groupinfo, GROUP_HUMAN|GROUP_OBJECT);

	new gpinfo;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		gpinfo = pev(id, pev_groupinfo);
		if (gpinfo == 0)
		{
			set_pev(id, pev_groupinfo, GROUP_HUMAN);
		}
	}

	set_pev(ent, pev_groupinfo, GROUP_OBJECT);*/

	//Checked after object is successfully grabbed
	if (!g_boolCanBuild && (access(id, FLAGS_BUILD) || access(id, FLAGS_OVERRIDE)))
	{
		new adminauthid[32],adminname[32]
		get_user_authid (id,adminauthid,31)
		get_user_name(id,adminname,31)
		Log("[MOVE] Admin: %s || SteamID: %s moved an entity", adminname, adminauthid)
	}
	
	client_cmd(id, "spk %s", GRAB_START);
	
	ExecuteForward(g_fwGrabEnt_Post, g_fwDummyResult, id, ent);
	
	return PLUGIN_HANDLED
}

public cmdStopEnt(id)
{
	if (!g_iOwnedEnt[id])
		return PLUGIN_HANDLED;
		
	new ent = g_iOwnedEnt[id]
	
	ExecuteForward(g_fwDropEnt_Pre, g_fwDummyResult, id, ent);
	
	if (BlockLocker(ent))
	{
		switch(g_iLockBlocks)
		{
			case 0:
			{
				set_pev(ent,pev_rendermode,kRenderTransColor)
				set_pev(ent,pev_rendercolor, Float:{ LOCKED_COLOR })
				set_pev(ent,pev_renderamt,Float:{ LOCKED_RENDERAMT })
			}
			case 1:
			{
				set_pev(ent,pev_rendermode,kRenderTransColor)
				set_pev(ent,pev_rendercolor, g_fColor[g_iColor[id]])
				set_pev(ent,pev_renderamt,Float:{ LOCKED_RENDERAMT })
			}
		}
	}
	else
		set_pev(ent,pev_rendermode,kRenderNormal)	
	
	UnsetEntMover(ent);
	SetLastMover(ent,id);
	g_iOwnedEnt[id] = 0;
	UnmovingEnt(ent);

/*
	set_pev(id, pev_groupinfo, 0);

	new gpinfo;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		gpinfo = pev(id, pev_groupinfo);
		if (gpinfo == GROUP_HUMAN)
		{
			set_pev(id, pev_groupinfo, 0);
		}
	}

	set_pev(ent, pev_groupinfo, 0);*/
	
	if (IsObjectInWall(ent))
	{
		engfunc(EngFunc_SetOrigin, ent, Float:{ 0.0, 0.0, 0.0 });
		client_print_color(0, print_team_default, "%s %L", MODNAME, LANG_PLAYER, "OBJECT_INSIDE_WALL", id, ent);
	}
	
	client_cmd(id, "spk %s", GRAB_STOP);
	
	ExecuteForward(g_fwDropEnt_Post, g_fwDummyResult, id, ent);
	
	return PLUGIN_HANDLED;
}

public cmdLockBlock(id)
{
	if (!g_boolCanBuild && g_iLockBlocks)
	{
		client_print(id, print_center, "%L", id, "FAIL_LOCK");
		return PLUGIN_HANDLED;
	}
	
	if (!access(id, FLAGS_LOCK) || (g_isZombie[id] && !access(id, FLAGS_OVERRIDE)))
		return PLUGIN_HANDLED;
		
	new ent, bodypart
	get_user_aiming (id,ent,bodypart)
	
	new szTarget[7], szClass[10];
	entity_get_string(ent, EV_SZ_targetname, szTarget, 6);
	entity_get_string(ent, EV_SZ_classname, szClass, 9);
	if (!ent || !is_valid_ent(ent) || is_user_alive(ent) || ent == g_iEntBarrier || !equal(szClass, "func_wall") || equal(szTarget, "ignore"))
		return PLUGIN_HANDLED;
	
	ExecuteForward(g_fwLockEnt_Pre, g_fwDummyResult, id, ent);
	
	switch (g_iLockBlocks)
	{
		case 0:
		{
			if (!BlockLocker(ent) && !IsMovingEnt(ent))
			{
				LockBlock(ent, id);
				set_pev(ent,pev_rendermode,kRenderTransColor)
				set_pev(ent,pev_rendercolor,Float:{LOCKED_COLOR})
				set_pev(ent,pev_renderamt,Float:{LOCKED_RENDERAMT})
				client_cmd(id, "spk %s", LOCK_OBJECT);
			}
			else if (BlockLocker(ent))
			{
				UnlockBlock(ent)
				set_pev(ent,pev_rendermode,kRenderNormal)
				client_cmd(id, "spk %s", LOCK_OBJECT);
			}
		}
		case 1:
		{
			if (!BlockLocker(ent) && !IsMovingEnt(ent))
			{
				if (g_iOwnedEntities[id]<g_iLockMax || !g_iLockMax)
				{
					LockBlock(ent, id)
					g_iOwnedEntities[id]++
					set_pev(ent,pev_rendermode,kRenderTransColor)
					set_pev(ent,pev_rendercolor,g_fColor[g_iColor[id]])
					set_pev(ent,pev_renderamt,Float:{LOCKED_RENDERAMT})
					
					client_print(id, print_center, "%L [ %d / %d ]", id, "BUILD_CLAIM_NEW", g_iOwnedEntities[id], g_iLockMax)
					client_cmd(id, "spk %s", LOCK_OBJECT);
				}
				else if (g_iOwnedEntities[id]>=g_iLockMax)
				{
					client_print(id, print_center, "%L", id, "BUILD_CLAIM_MAX", g_iLockMax)
					client_cmd(id, "spk %s", LOCK_FAIL);
				}
			}
			else if (BlockLocker(ent))
			{
				if (BlockLocker(ent) == id || access(id, FLAGS_OVERRIDE))
				{
					g_iOwnedEntities[BlockLocker(ent)]--
					set_pev(ent,pev_rendermode,kRenderNormal)
					
					client_print(BlockLocker(ent), print_center, "%L [ %d / %d ]", BlockLocker(ent), "BUILD_CLAIM_LOST", g_iOwnedEntities[BlockLocker(ent)], g_iLockMax)
					
					UnlockBlock(ent)
					client_cmd(id, "spk %s", LOCK_OBJECT);
				}
				else
				{
					client_print(id, print_center, "%L", id, "BUILD_CLAIM_FAIL")
					client_cmd(id, "spk %s", LOCK_FAIL);
				}
			}	
		}
	}
	
	ExecuteForward(g_fwLockEnt_Post, g_fwDummyResult, id, ent);
	
	return PLUGIN_HANDLED
}

public cmdBuildBan(id, target)
{
	if (access(id, FLAGS_BUILDBAN))
	{
		new player
		if (target) player = target
		else
		{
			new arg[32]
			read_argv(1, arg, 31)
			player = cmd_target(id, arg, CMDTARGET_OBEY_IMMUNITY)
		}
		
		if (!player)
			return client_print(id, print_console, "[Base Builder] %L", id, "FAIL_NAME");
		
		new szAdminAuthid[32],szAdminName[32],szPlayerName[32],szPlayerID[32]
		get_user_name(id,szAdminName,31)
		get_user_authid (id,szAdminAuthid,31)
		get_user_name(player, szPlayerName, 31)
		get_user_authid (player,szPlayerID,31)
		
		g_isBuildBan[player] = g_isBuildBan[player] ? false : true
		
		if (g_isBuildBan[player] && g_iOwnedEnt[player])
			cmdStopEnt(player)
		
		client_print(id, print_console, "[Base Builder] Player %s was %s from building", szPlayerName, g_isBuildBan[player] ? "banned":"unbanned")
		Log("[MOVE] Admin: %s || SteamID: %s banned Player: %s || SteamID: %s from building", szAdminName, szAdminAuthid, szPlayerName, szPlayerID)
		
		//set_hudmessage(255,0, 0, -1.0, 0.4, 0, 0.0, 7.5, 0.0, 0.5, 1)
		//show_hudmessage(player, "%L", player, "ADMIN_BUILDBAN", g_isBuildBan[player] ? "disabled":"re-enabled");
		
		new status[32];
		if (g_isBuildBan[player])
			formatex(status, charsmax(status), "%L", LANG_PLAYER, "BANNED")
		else
			formatex(status, charsmax(status), "%L", LANG_PLAYER, "UNBANNED")

		client_print_color(0, print_team_default, "%s %L", MODNAME, LANG_PLAYER, "PLAYER_CAN_BUILDING", szPlayerName, status)
	}
	
	return PLUGIN_HANDLED;
}

public fw_PlayerPostThink(id)
{
	if (is_user_alive(id))
	{
		new ent;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!is_user_alive(i) || i == id)
				continue;
			
			ent = g_iOwnedEnt[i];
			if (!is_valid_ent(ent))
				continue;
			
			set_pev(ent, pev_solid, SOLID_BSP);
		}
	}
}

public fw_PlayerPreThink(id)
{
	if (!is_user_connected(id))
	{
		cmdStopEnt(id)
		return PLUGIN_HANDLED
	}

	if (is_user_alive(id))
	{
		new ent;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!is_user_alive(i) || i == id)
				continue;
			
			ent = g_iOwnedEnt[i];
			if (!is_valid_ent(ent))
				continue;
			
			set_pev(ent, pev_solid, SOLID_NOT);
		}
	}

	if (g_isZombie[id])
		set_pev(id, pev_maxspeed, g_fPlayerSpeed[id])
	
	if (!g_iOwnedEnt[id] || !is_valid_ent(g_iOwnedEnt[id]))
		return FMRES_HANDLED
	
	new button = entity_get_int(id, EV_INT_button);
	new oldbutton = entity_get_int(id, EV_INT_oldbuttons);

	if (button & IN_ATTACK)
	{
		if (~oldbutton & IN_ATTACK)
		{
			g_fPushPullTime[id] = get_gametime();
		}
		else
		{
			new Float:timeDiff = get_gametime() - g_fPushPullTime[id];
			g_fEntDist[id] += floatmin(timeDiff / g_fGrabMaxMoveTime, 1.0) * g_fGrabMaxMoveUnits;
		
			if (g_fEntDist[id] > g_fEntMaxDist)
			{
				g_fEntDist[id] = g_fEntMaxDist;
				client_print(id, print_center, "%L", id, "OBJECT_MAX");
			}
			else
			{
				client_print(id, print_center, "%L", id, "OBJECT_PUSH");
			}
		}

		ExecuteForward(g_fwPushPull, g_fwDummyResult, id, g_iOwnedEnt[id], 1);
	}
	else if (button & IN_ATTACK2)
	{
		if (~oldbutton & IN_ATTACK2)
		{
			g_fPushPullTime[id] = get_gametime();
		}
		else
		{
			new Float:timeDiff = get_gametime() - g_fPushPullTime[id];
			g_fEntDist[id] -= floatmin(timeDiff / g_fGrabMaxMoveTime, 1.0) * g_fGrabMaxMoveUnits;
		
			if (g_fEntDist[id] < g_fEntMinDist)
			{
				g_fEntDist[id] = g_fEntMinDist;
				client_print(id, print_center, "%L", id, "OBJECT_MIN")
			}
			else
			{
				client_print(id, print_center, "%L", id, "OBJECT_PULL")
			}
		}

		ExecuteForward(g_fwPushPull, g_fwDummyResult, id, g_iOwnedEnt[id], 2);
	}

	new Float:origin[3], Float:vec[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	entity_get_vector(id, EV_VEC_view_ofs, vec);
	xs_vec_add(origin, vec, origin);

	velocity_by_aim(id, 1, vec);

	new Float:moveTo[3];
	xs_vec_mul_scalar(vec, g_fEntDist[id], vec);
	xs_vec_add(origin, vec, moveTo);
	xs_vec_add(moveTo, g_fOffset[id], moveTo);

	entity_set_origin(g_iOwnedEnt[id], moveTo);

		/*
	new buttons = pev(id, pev_button)
	if (buttons & IN_ATTACK)
	{
		g_fEntDist[id] += OBJECT_PUSHPULLRATE;
		
		if (g_fEntDist[id] > g_fEntMaxDist)
		{
			g_fEntDist[id] = g_fEntMaxDist
			client_print(id, print_center, "%L", LANG_SERVER, "OBJECT_MAX")
		}
		else
			client_print(id, print_center, "%L", LANG_SERVER, "OBJECT_PUSH")
			
		ExecuteForward(g_fwPushPull, g_fwDummyResult, id, g_iOwnedEnt[id], 1);
	}
	else if (buttons & IN_ATTACK2)
	{
		g_fEntDist[id] -= OBJECT_PUSHPULLRATE;
			
		if (g_fEntDist[id] < g_fEntSetDist)
		{
			g_fEntDist[id] = g_fEntSetDist
			client_print(id, print_center, "%L", LANG_SERVER, "OBJECT_MIN")
		}
		else
			client_print(id, print_center, "%L", LANG_SERVER, "OBJECT_PULL")
			
		ExecuteForward(g_fwPushPull, g_fwDummyResult, id, g_iOwnedEnt[id], 2);
	}
	
	new iOrigin[3], iLook[3], Float:fOrigin[3], Float:fLook[3], Float:vMoveTo[3], Float:fLength
	    
	get_user_origin(id, iOrigin, 1);
	IVecFVec(iOrigin, fOrigin);
	get_user_origin(id, iLook, 3);
	IVecFVec(iLook, fLook);
	    
	fLength = get_distance_f(fLook, fOrigin);
	if (fLength == 0.0) fLength = 1.0;

	vMoveTo[0] = (fOrigin[0] + (fLook[0] - fOrigin[0]) * g_fEntDist[id] / fLength) + g_fOffset1[id];
	vMoveTo[1] = (fOrigin[1] + (fLook[1] - fOrigin[1]) * g_fEntDist[id] / fLength) + g_fOffset2[id];
	vMoveTo[2] = (fOrigin[2] + (fLook[2] - fOrigin[2]) * g_fEntDist[id] / fLength) + g_fOffset3[id];
	vMoveTo[2] = float(floatround(vMoveTo[2], floatround_floor));

	entity_set_origin(g_iOwnedEnt[id], vMoveTo);*/
	
	return FMRES_HANDLED
}

public fw_Traceline(Float:start[3], Float:end[3], conditions, id, trace)
{
	if (!is_user_alive(id) || is_user_bot(id))
		return FMRES_IGNORED
	
	new ent = get_tr2(trace, TR_pHit)
	
	if (is_valid_ent(ent))
	{
		new ent,body
		get_user_aiming(id,ent,body)
		
		new szClass[10], szTarget[7];
		entity_get_string(ent, EV_SZ_classname, szClass, 9);
		entity_get_string(ent, EV_SZ_targetname, szTarget, 6);
		if (equal(szClass, "func_wall") && !equal(szTarget, "ignore") && ent != g_iEntBarrier && g_iShowMovers == 1)
		{
			if (g_boolCanBuild || access(id, ADMIN_SLAY))
			{
				g_boolAiming[id] = true;

				if (get_gametime() < g_fHudMsgTime[id] + 0.1)
					return FMRES_IGNORED;

				set_hudmessage(0, 150, 250, -1.0, 0.55, 0, 0.0, 0.5, 0.0, 0.25, 4);
				if (!BlockLocker(ent))
				{
					new szCurMover[32], szLastMover[32]
					if (GetEntMover(ent))
					{
						get_user_name(GetEntMover(ent),szCurMover,31)
						if (!GetLastMover(ent))
							show_hudmessage(id, "%L: %s^n%L: %L", id, "CURRENT_MOVER", szCurMover, id, "LAST_MOVER", id, "NONE");
					}
					if (GetLastMover(ent))
					{
						get_user_name(GetLastMover(ent),szLastMover,31)
						if (!GetEntMover(ent))
							show_hudmessage(id, "%L: %L^n%L: %s", id, "CURRENT_MOVER", id, "NONE", id, "LAST_MOVER", szLastMover);
					}
					if (GetEntMover(ent) && GetLastMover(ent))
						show_hudmessage(id, "%L: %s^n%L: %s", id, "CURRENT_MOVER", szCurMover, id, "LAST_MOVER", szLastMover);
					else if (!GetEntMover(ent) && !GetLastMover(ent))
						show_hudmessage(id, "%L", id, "OBJECT_NOT_MOVED");
				}
				else
				{
					new szEntOwner[32]
					get_user_name(BlockLocker(ent),szEntOwner,31)
					show_hudmessage(id, "%L: %s", id, "OBJECT_CLAIMED_BY", szEntOwner);
				}

				g_fHudMsgTime[id] = get_gametime();
			}
		}
	}
	else if (g_boolAiming[id])
	{
		g_boolAiming[id] = false;
		set_hudmessage(.fxtime=0.0, .holdtime=0.1, .fadeintime=0.0, .fadeouttime=0.0, .channel=4);
		show_hudmessage(id, "^n");
	}
	
	return FMRES_IGNORED
}

public fw_EmitSound(id,channel,const sample[],Float:volume,Float:attn,flags,pitch)
{
	if (!is_user_connected(id) || !g_isZombie[id] || g_boolCanBuild || g_boolPrepTime || g_boolRoundEnded)
		return FMRES_IGNORED;
		
	if(equal(sample[7], "die", 3) || equal(sample[7], "dea", 3))
	{
		emit_sound(id,channel,g_szZombieDie[random(sizeof g_szZombieDie - 1)],volume,attn,flags,pitch)
		return FMRES_SUPERCEDE
	}
	
	if(equal(sample[7], "bhit", 4))
	{
		emit_sound(id,channel,g_szZombiePain[random(sizeof g_szZombiePain - 1)],volume,attn,flags,pitch)
		return FMRES_SUPERCEDE
	}
	
	// Zombie attacks with knife
	if (equal(sample[8], "kni", 3))
	{
		if (equal(sample[14], "sla", 3)) // slash
		{
			emit_sound(id,channel,g_szZombieMiss[random(sizeof g_szZombieMiss - 1)],volume,attn,flags,pitch)
			return FMRES_SUPERCEDE;
		}
		if (equal(sample[14], "hit", 3)) // hit
		{
			if (sample[17] == 'w') // wall
			{
				emit_sound(id,channel,g_szZombieHit[random(sizeof g_szZombieHit - 1)],volume,attn,flags,pitch)
				return FMRES_SUPERCEDE;
			}
			else
			{
				emit_sound(id,channel,g_szZombieHit[random(sizeof g_szZombieHit - 1)],volume,attn,flags,pitch)
				return FMRES_SUPERCEDE;
			}
		}
		if (equal(sample[14], "sta", 3)) // stab
		{
			emit_sound(id,channel,g_szZombieMiss[random(sizeof g_szZombieMiss - 1)],volume,attn,flags,pitch)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED
}

public fw_Suicide(id) return FMRES_SUPERCEDE

public show_colors_menu(id,offset)
{
	if(offset<0) offset = 0

	new keys, curnum, menu[512]
	for(new i=offset;i<MAX_COLORS;i++)
	{
		if (g_iColorMode == 0 || (g_iColorMode == 1 && !g_iColorOwner[i]))
		{
			g_iMenuOptions[id][curnum] = i
			keys += (1<<curnum)
	
			curnum++
			format(menu,511,"%s^n\y%d. \w%s", menu, curnum, g_szColorName[i])
	
			if(curnum==8)
				break;
		}
	}

	format(menu,511,"\y%L\r%s\w^n^n%s^n", id, "SELECT_YOUR_COLOR", g_szColorName[g_iColor[id]], menu)
	if(curnum==8 && offset<12)
	{
		keys += (1<<8)
		format(menu,511,"%s^n\y9. \wNext",menu)
	}
	if(offset)
	{
		keys += (1<<9)
		format(menu,511,"%s^n\y0. \wBack",menu)
	}

	show_menu(id,keys,menu,-1,"ColorsSelect")
}

public colors_pushed(id,key)
{
	if(key<8)
	{
		g_iColorOwner[g_iMenuOptions[id][key]] = id
		g_iColorOwner[g_iColor[id]] = 0
		g_iColor[id] = g_iMenuOptions[id][key]
		client_print_color(id, print_team_default, "%s %L", MODNAME, id, "YOU_PICKED_COLOR", g_szColorName[g_iColor[id]])
		g_iMenuOffset[id] = 0
		
		ExecuteForward(g_fwNewColor, g_fwDummyResult, id, g_iColor[id]);
	}
	else
	{
		if(key==8)
			g_iMenuOffset[id] += 8
		if(key==9)
			g_iMenuOffset[id] -= 8
		show_colors_menu(id,g_iMenuOffset[id])
	}

	return ;
}

public show_zclass_menu(id,offset)
{
	if(offset<0) offset = 0

	new keys, curnum, menu[512], szCache1[32], szCache2[32], iCache3
	for(new i=offset;i<g_iZClasses;i++)
	{
		ArrayGetString(g_zclass_name, i, szCache1, charsmax(szCache1))
		ArrayGetString(g_zclass_info, i, szCache2, charsmax(szCache2))
		iCache3 = ArrayGetCell(g_zclass_admin, i)
		
		// Add to menu
		if (i == g_iZombieClass[id])
			format(menu,511,"%s^n\d%d. %s %s \r%s", menu, curnum+1, szCache1, szCache2, iCache3 == ADMIN_ALL ? "" : "(Admin Only)")
		else
			format(menu,511,"%s^n\y%d. \w%s \y%s \r%s", menu, curnum+1, szCache1, szCache2, iCache3 == ADMIN_ALL ? "" : "(Admin Only)")
		
		g_iMenuOptions[id][curnum] = i
		keys += (1<<curnum)
	
		curnum++
		
		if(curnum==8)
			break;
	}

	format(menu,511,"\y%L^n\w%s^n", id, "SELECT_YOUR_CLASS", menu)
	if(curnum==8 && offset<12)
	{
		keys += (1<<8)
		format(menu,511,"%s^n\y9. \wNext",menu)
	}
	if(offset)
	{
		keys += (1<<9)
		format(menu,511,"%s^n\y0. \wBack",menu)
	}

	show_menu(id,keys,menu,-1,"ZClassSelect")
}

public zclass_pushed(id,key)
{
	if(key<8)
	{
		if (g_iMenuOptions[id][key] == g_iZombieClass[id])
		{
			client_cmd(id, "spk %s", LOCK_FAIL);
			
			client_print_color(id, print_team_default, "%s %L", MODNAME, id, "CLASS_CURRENT")
			show_zclass_menu(id,g_iMenuOffset[id])
			return ;
		}
		
		new iCache3 = ArrayGetCell(g_zclass_admin, g_iMenuOptions[id][key])
		
		if ((iCache3 != ADMIN_ALL || !iCache3) && !access(id, iCache3))
		{
			client_print_color(id, print_team_default, "%s %L", MODNAME, id, "CLASS_NO_ACCESS")
			show_zclass_menu(id,g_iMenuOffset[id])
			return ;
		}
		
		g_iNextClass[id] = g_iMenuOptions[id][key]
	
		new szCache1[32]
		ArrayGetString(g_zclass_name, g_iMenuOptions[id][key], szCache1, charsmax(szCache1))
		
		if (!g_isZombie[id] || (g_isZombie[id] && (g_boolCanBuild || g_boolPrepTime)))
			client_print_color(id, print_team_default, "%s %L", MODNAME, id, "YOU_SELECTED_CLASS", szCache1)
		if (!g_isAlive[id])
			client_print_color(id, print_team_default, "%s %L", MODNAME, id, "CLASS_RESPAWN")
		g_iMenuOffset[id] = 0
		
		if (g_isZombie[id] && (g_boolCanBuild || g_boolPrepTime) && !g_boolFreeZombies[id])
			ExecuteHamB(Ham_CS_RoundRespawn, id)
			
		ExecuteForward(g_fwClassPicked, g_fwDummyResult, id, g_iZombieClass[id]);
	}
	else
	{
		if(key==8)
			g_iMenuOffset[id] += 8
		if(key==9)
			g_iMenuOffset[id] -= 8
		show_zclass_menu(id,g_iMenuOffset[id])
	}

	return ;
}

/*------------------------------------------------------------------------------------------------*/
public show_method_menu(id)
{
	if(g_boolFirstTime[id])
	{
		g_boolFirstTime[id] = false
		show_primary_menu(id,0)
	}
	else
	{
		g_iMenuOffset[id] = 0

		new menu[128];
		formatex(menu, charsmax(menu), "%L", id, "WEAPON_MENU")
		show_menu(id,(1<<0)|(1<<1),menu,-1,"WeaponMethodMenu")
	}
}

public weapon_method_pushed(id,key)
{
	switch(key)
	{
		case 0: show_primary_menu(id,0)
		case 1: give_weapons(id)
	}
	return ;
}

public show_primary_menu(id,offset)
{
	if(offset<0) offset = 0

	new flags = read_flags(g_szAllowedWeapons)

	new keys, curnum, menu[512]
	for(new i=offset;i<19;i++)
	{
		if(flags & power(2,i))
		{
			g_iMenuOptions[id][curnum] = i
			keys += (1<<curnum)
	
			curnum++
			format(menu,511,"%s^n%d. %s",menu,curnum,szWeaponNames[i])
	
			if(curnum==8)
				break;
		}
	}

	format(menu,511,"\y%L:\w^n%s^n", id, "PRIMARY_WEAPON",menu)
	if(curnum==8 && offset<12)
	{
		keys += (1<<8)
		format(menu,511,"%s^n\y9. \wNext",menu)
	}
	if(offset)
	{
		keys += (1<<9)
		format(menu,511,"%s^n\y0. \wBack",menu)
	}

	show_menu(id,keys,menu,-1,"PrimaryWeaponSelect")
}

public prim_weapons_pushed(id,key)
{
	if (g_isZombie[id] || !g_isAlive[id])
		return;

	if(key<8)
	{
		g_iWeaponPicked[0][id] = g_iMenuOptions[id][key]
		g_iMenuOffset[id] = 0
		show_secondary_menu(id,0)
	}
	else
	{
		if(key==8)
			g_iMenuOffset[id] += 8
		if(key==9)
			g_iMenuOffset[id] -= 8
		show_primary_menu(id,g_iMenuOffset[id])
	}
	return ;
}

public show_secondary_menu(id,offset)
{
	if(offset<0) offset = 0

	new flags = read_flags(g_szAllowedWeapons)

	new keys, curnum, menu[2048]
	for(new i=18;i<24;i++)
	{
		if(flags & power(2,i))
		{
			g_iMenuOptions[id][curnum] = i
			keys += (1<<curnum)
	
			curnum++
			format(menu,511,"%s^n\y%d. \w%s",menu,curnum,szWeaponNames[i])
		}
	}

	format(menu,511,"\y%L:\w^n%s", id, "SECONDARY_WEAPON",menu)

	show_menu(id,keys,menu,-1,"SecWeaponSelect")
}

public sec_weapons_pushed(id,key)
{
	if (g_isZombie[id] || !g_isAlive[id])
		return;

	if(key<8)
	{
		g_iWeaponPicked[1][id] = g_iMenuOptions[id][key]
	}
	give_weapons(id)
	return ;
}

public give_weapons(id)
{
	strip_user_weapons(id)
	give_item(id,"weapon_knife")
   
	new szWeapon[32], csw
	csw = csw_contant(g_iWeaponPicked[0][id])
	get_weaponname(csw,szWeapon,31)
	give_item(id,szWeapon)
	cs_set_user_bpammo(id,csw,999)
	g_iPrimaryWeapon[id] = csw

	csw = csw_contant(g_iWeaponPicked[1][id])
	get_weaponname(csw,szWeapon,31)
	give_item(id,szWeapon)
	cs_set_user_bpammo(id,csw,999)
	
	g_boolRepick[id] = false
}

stock csw_contant(weapon)
{
	new num = 29
	switch(weapon)
	{
		case 0: num = 3
		case 1: num = 5
		case 2: num = 7
		case 3: num = 8
		case 4: num = 12
		case 5: num = 13
		case 6: num = 14
		case 7: num = 15
		case 8: num = 18
		case 9: num = 19
		case 10: num = 20
		case 11: num = 21
		case 12: num = 22
		case 13: num = 23
		case 14: num = 24
		case 15: num = 27
		case 16: num = 28
		case 17: num = 30
		case 18: num = 1
		case 19: num = 10
		case 20: num = 11
		case 21: num = 16
		case 22: num = 17
		case 23: num = 26
		case 24:
		{
			new flags = read_flags(g_szAllowedWeapons)
			do
			{
				num = random_num(0,18)
				if(!(num & flags))
				{
					num = -1
				}
			}
			while(num==-1)
			num = csw_contant(num)
		}
		case 25:
		{
			new flags = read_flags(g_szAllowedWeapons)
			do
			{
				num = random_num(18,23)
				if(!(num & flags))
				{
					num = -1
				}
			}
			while(num==-1)
			num = csw_contant(num)
		}
	}
	return num;
}
/*------------------------------------------------------------------------------------------------*/

Log(const message_fmt[], any:...)
{
	static message[256];
	vformat(message, sizeof(message) - 1, message_fmt, 2);
	
	static filename[96];
	static dir[64];
	if( !dir[0] )
	{
		get_basedir(dir, sizeof(dir) - 1);
		add(dir, sizeof(dir) - 1, "/logs");
	}
	
	format_time(filename, sizeof(filename) - 1, "%m-%d-%Y");
	format(filename, sizeof(filename) - 1, "%s/BaseBuilder_%s.log", dir, filename);
	
	log_to_file(filename, "%s", message);
}
/*
print_color(target, const message[], any:...)
{
	static buffer[512], i, argscount
	argscount = numargs()
	
	// Send to everyone
	if (!target)
	{
		static player
		for (player = 1; player <= g_iMaxPlayers; player++)
		{
			// Not connected
			if (!g_isConnected[player])
				continue;
			
			// Remember changed arguments
			static changed[5], changedcount // [5] = max LANG_PLAYER occurencies
			changedcount = 0
			
			// Replace LANG_PLAYER with player id
			for (i = 2; i < argscount; i++)
			{
				if (getarg(i) == LANG_PLAYER)
				{
					setarg(i, 0, player)
					changed[changedcount] = i
					changedcount++
				}
			}
			
			// Format message for player
			vformat(buffer, charsmax(buffer), message, 3)
			
			// Send it
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, player)
			write_byte(player)
			write_string(buffer)
			message_end()
			
			// Replace back player id's with LANG_PLAYER
			for (i = 0; i < changedcount; i++)
				setarg(changed[i], 0, LANG_PLAYER)
		}
	}
	// Send to specific target
	else
	{
		// Format message for player
		vformat(buffer, charsmax(buffer), message, 3)
		
		// Send it
		message_begin(MSG_ONE, g_msgSayText, _, target)
		write_byte(target)
		write_string(buffer)
		message_end()
	}
}*/

stock fm_cs_get_current_weapon_ent(id)
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX);


public native_register_zombie_class(const name[], const info[], const model[], const clawmodel[], hp, speed, Float:gravity, Float:knockback, adminflags, credits)
{
	if (!g_boolArraysCreated)
		return 0;
		
	// Strings passed byref
	param_convert(1)
	param_convert(2)
	param_convert(3)
	param_convert(4)
	
	// Add the class
	ArrayPushString(g_zclass_name, name)
	ArrayPushString(g_zclass_info, info)
	
	ArrayPushCell(g_zclass_modelsstart, ArraySize(g_zclass_playermodel))
	ArrayPushString(g_zclass_playermodel, model)
	ArrayPushCell(g_zclass_modelsend, ArraySize(g_zclass_playermodel))
	ArrayPushCell(g_zclass_modelindex, -1)
	
	ArrayPushString(g_zclass_clawmodel, clawmodel)
	ArrayPushCell(g_zclass_hp, hp)
	ArrayPushCell(g_zclass_spd, speed)
	ArrayPushCell(g_zclass_grav, gravity)
	ArrayPushCell(g_zclass_admin, adminflags)
	ArrayPushCell(g_zclass_credits, credits)
	
	// Set temporary new class flag
	ArrayPushCell(g_zclass_new, 1)
	
	// Override zombie classes data with our customizations
	new i, k, buffer[32], Float:buffer2, nummodels_custom, nummodels_default, prec_mdl[100], size = ArraySize(g_zclass2_realname)
	for (i = 0; i < size; i++)
	{
		ArrayGetString(g_zclass2_realname, i, buffer, charsmax(buffer))
		
		// Check if this is the intended class to override
		if (!equal(name, buffer))
			continue;
		
		// Remove new class flag
		ArraySetCell(g_zclass_new, g_iZClasses, 0)
		
		// Replace caption
		ArrayGetString(g_zclass2_name, i, buffer, charsmax(buffer))
		ArraySetString(g_zclass_name, g_iZClasses, buffer)
		
		// Replace info
		ArrayGetString(g_zclass2_info, i, buffer, charsmax(buffer))
		ArraySetString(g_zclass_info, g_iZClasses, buffer)
		
		nummodels_custom = ArrayGetCell(g_zclass2_modelsend, i) - ArrayGetCell(g_zclass2_modelsstart, i)
		nummodels_default = ArrayGetCell(g_zclass_modelsend, g_iZClasses) - ArrayGetCell(g_zclass_modelsstart, g_iZClasses)
			
		// Replace each player model and model index
		for (k = 0; k < min(nummodels_custom, nummodels_default); k++)
		{
			ArrayGetString(g_zclass2_playermodel, ArrayGetCell(g_zclass2_modelsstart, i) + k, buffer, charsmax(buffer))
			ArraySetString(g_zclass_playermodel, ArrayGetCell(g_zclass_modelsstart, g_iZClasses) + k, buffer)
				
			// Precache player model and replace its modelindex with the real one
			formatex(prec_mdl, charsmax(prec_mdl), "models/player/%s/%s.mdl", buffer, buffer)
			ArraySetCell(g_zclass_modelindex, ArrayGetCell(g_zclass_modelsstart, g_iZClasses) + k, engfunc(EngFunc_PrecacheModel, prec_mdl))
		}
			
		// We have more custom models than what we can accommodate,
		// Let's make some space...
		if (nummodels_custom > nummodels_default)
		{
			for (k = nummodels_default; k < nummodels_custom; k++)
			{
				ArrayGetString(g_zclass2_playermodel, ArrayGetCell(g_zclass2_modelsstart, i) + k, buffer, charsmax(buffer))
				ArrayInsertStringAfter(g_zclass_playermodel, ArrayGetCell(g_zclass_modelsstart, g_iZClasses) + k - 1, buffer)
				
				// Precache player model and retrieve its modelindex
				formatex(prec_mdl, charsmax(prec_mdl), "models/player/%s/%s.mdl", buffer, buffer)
				ArrayInsertCellAfter(g_zclass_modelindex, ArrayGetCell(g_zclass_modelsstart, g_iZClasses) + k - 1, engfunc(EngFunc_PrecacheModel, prec_mdl))
			}
				
			// Fix models end index for this class
			ArraySetCell(g_zclass_modelsend, g_iZClasses, ArrayGetCell(g_zclass_modelsend, g_iZClasses) + (nummodels_custom - nummodels_default))
		}
		
		// Replace clawmodel
		ArrayGetString(g_zclass2_clawmodel, i, buffer, charsmax(buffer))
		ArraySetString(g_zclass_clawmodel, g_iZClasses, buffer)
		
		// Precache clawmodel
		formatex(prec_mdl, charsmax(prec_mdl), "models/%s.mdl", buffer)
		engfunc(EngFunc_PrecacheModel, prec_mdl)
		
		// Replace health
		buffer[0] = ArrayGetCell(g_zclass2_hp, i)
		ArraySetCell(g_zclass_hp, g_iZClasses, buffer[0])
		
		// Replace speed
		buffer[0] = ArrayGetCell(g_zclass2_spd, i)
		ArraySetCell(g_zclass_spd, g_iZClasses, buffer[0])
		
		// Replace gravity
		buffer2 = Float:ArrayGetCell(g_zclass2_grav, i)
		ArraySetCell(g_zclass_grav, g_iZClasses, buffer2)
		
		// Replace admin flags
		buffer2 = ArrayGetCell(g_zclass2_admin, i)
		ArraySetCell(g_zclass_admin, g_iZClasses, buffer2)
	
		// Replace credits
		buffer2 = ArrayGetCell(g_zclass2_credits, i)
		ArraySetCell(g_zclass_credits, g_iZClasses, buffer2)
	}
	
	// If class was not overriden with customization data
	if (ArrayGetCell(g_zclass_new, g_iZClasses))
	{
		// Precache default class model and replace modelindex with the real one
		formatex(prec_mdl, charsmax(prec_mdl), "models/player/%s/%s.mdl", model, model)
		ArraySetCell(g_zclass_modelindex, ArrayGetCell(g_zclass_modelsstart, g_iZClasses), engfunc(EngFunc_PrecacheModel, prec_mdl))
		
		// Precache default clawmodel
		formatex(prec_mdl, charsmax(prec_mdl), "models/%s.mdl", clawmodel)
		engfunc(EngFunc_PrecacheModel, prec_mdl)
	}

	g_iZClasses++
	
	return g_iZClasses-1
}

public native_get_class_cost(classid)
{
	if (classid < 0 || classid >= g_iZClasses)
		return -1;
	
	return ArrayGetCell(g_zclass_credits, classid)
}

public native_show_zclass_menu(id, offset)
{
	show_zclass_menu(id, offset ? g_iMenuOffset[id] : 0);
}

public native_get_user_zombie_class(id) return g_iZombieClass[id];
public native_get_user_next_class(id) return g_iNextClass[id];
public native_set_user_zombie_class(id, classid)
{
	if (classid < 0 || classid >= g_iZClasses)
		return 0;
	
	g_iNextClass[id] = classid
	return 1;
}

public native_get_barrier_ent()
{
	return g_iEntBarrier;
}

public native_get_user_colorname()
{
	new id = get_param(1);

	set_string(2, g_szColorName[id], get_param(3));
}

public native_is_user_zombie(id) return g_isZombie[id]
public native_is_user_banned(id) return g_isBuildBan[id]

public native_bool_buildphase() return g_boolCanBuild
public native_bool_prepphase() return g_boolPrepTime

public native_get_build_time()
{
	if (g_boolCanBuild)
		return g_iCountDown
		
	return 0;
}

public native_set_build_time(time)
{
	if (g_boolCanBuild)
	{
		g_iCountDown = time
		return 1
	}
		
	return 0;
}

public native_get_user_color(id) return g_iColor[id]
public native_set_user_color(id, color)
{
	g_iColor[id] = color
}

public native_drop_user_block(id)
{
	cmdStopEnt(id)
}
public native_get_user_block(id)
{
	if (g_iOwnedEnt[id])
		return g_iOwnedEnt[id]
		
	return 0;
}
public native_set_user_block(id, entity)
{
	if (is_valid_ent(entity) && !is_user_alive(entity) && !MovingEnt(entity))
		g_iOwnedEnt[id] = entity
}

public native_is_locked_block(entity)
{
	if (is_valid_ent(entity) && !is_user_alive(entity))
		return BlockLocker(entity) ? true : false
		
	return -1;
}
public native_lock_block(entity)
{
	if (is_valid_ent(entity) && !is_user_alive(entity) && !BlockLocker(entity))
	{
		LockBlock(entity, 33);
		set_pev(entity,pev_rendermode,kRenderTransColor)
		set_pev(entity,pev_rendercolor,Float:{LOCKED_COLOR})
		set_pev(entity,pev_renderamt,Float:{LOCKED_RENDERAMT})
	}
}
public native_unlock_block(entity)
{
	if (is_valid_ent(entity) && !is_user_alive(entity) && BlockLocker(entity))
	{
		UnlockBlock(entity)
		set_pev(entity,pev_rendermode,kRenderNormal)
	}
}

public native_release_zombies()
{
	if (g_boolCanBuild || g_boolPrepTime)
	{
		Release_Zombies()
		return 1;
	}
	return 0;
}

public native_set_user_primary(id, csw_primary)
{
	if (CSW_P228<=csw_primary<=CSW_P90)
	{
		g_iPrimaryWeapon[id] = csw_primary
		return g_iPrimaryWeapon[id];
	}
		
	return -1;
}

public native_get_user_primary(id) { return g_iPrimaryWeapon[id];}

public native_get_flags_build() 	{	return FLAGS_BUILD;}
public native_get_flags_lock() 	{	return FLAGS_LOCK;}
public native_get_flags_buildban() {	return FLAGS_BUILDBAN;}
public native_get_flags_swap() 		{return FLAGS_SWAP;}
public native_get_flags_revive() 	{return FLAGS_REVIVE;}
public native_get_flags_guns() 		{return FLAGS_GUNS;}
public native_get_flags_release() {	return FLAGS_RELEASE;}
public native_get_flags_override() 	{return FLAGS_OVERRIDE;}

public native_get_user_classname()
{
	new id = get_param(1);

	set_string(2, g_szPlayerClass[id], get_param(3));
}


public native_set_user_classname()
{
	new id = get_param(1);

	new classname[32];
	get_string(2, classname, charsmax(classname));

	copy(g_szPlayerClass[id], charsmax(g_szPlayerClass[]), classname);
}

/*public native_set_user_mult(id, attribute, Float: amount)
{
	if (attribute < ATT_HEALTH || attribute > ATT_GRAVITY)
		return 0;
		
	if (amount < 1.0)
		amount = 1.0
		
	g_fClassMultiplier[id][attribute] = amount
	
	return 1;
}*/

public ham_TraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
	if (victim != attacker && is_user_connected(attacker))
	{
		if (g_boolCanBuild && g_isZombie[victim] == g_isZombie[attacker] && g_boolFreeZombies[victim] && g_boolFreeZombies[attacker])
		{
			new vteam = get_ent_data(victim, "CBasePlayer", "m_iTeam");
			if (vteam == get_ent_data(attacker, "CBasePlayer", "m_iTeam"))
			{
				set_ent_data(victim, "CBasePlayer", "m_iTeam", vteam == 1 ? 2 : 1);
				ExecuteHamB(Ham_TraceAttack, victim, attacker, damage, direction, tracehandle, damagebits);
				set_ent_data(victim, "CBasePlayer", "m_iTeam", vteam);
				return HAM_SUPERCEDE;
			}
		}
	}

	return HAM_IGNORED;
}

public ham_Killed(victim, attacker, shouldgib)
{
	if (victim != attacker && is_user_connected(attacker))
	{
		if (g_boolCanBuild && g_isZombie[victim] == g_isZombie[attacker] && g_boolFreeZombies[victim] && g_boolFreeZombies[attacker])
		{
			new vteam = get_ent_data(victim, "CBasePlayer", "m_iTeam");
			if (vteam == get_ent_data(attacker, "CBasePlayer", "m_iTeam"))
			{
				set_ent_data(victim, "CBasePlayer", "m_iTeam", vteam == 1 ? 2 : 1);
				ExecuteHamB(Ham_Killed, victim, attacker, shouldgib);
				set_ent_data(victim, "CBasePlayer", "m_iTeam", vteam);
				return HAM_SUPERCEDE;
			}
		}
	}

	return HAM_IGNORED;
}

public cmdTeamKill(id)
{
	if (!g_isZombie[id])
		return;

	if (!g_boolCanBuild)
	{
		client_print_color(id, print_team_default, "%s %L", MODNAME, id, "ONLY_IN_BUILD_PHASE");
		return;
	}

	if (g_boolFreeZombies[id])
	{
		client_print_color(id, print_team_default, "%s %L", MODNAME, id, "ALREADY_FREE");
		return;
	}

	ShowTeamKillMenu(id);
}

public ShowTeamKillMenu(id)
{
	if (!g_isZombie[id] || !g_boolCanBuild || g_boolFreeZombies[id])
		return;

	static menu[128];
	formatex(menu, charsmax(menu), "%L", id, "MENU_TEAMKILL");

	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_0;
	show_menu(id, keys, menu, 30, "TeamKillSelect");

	client_print(0, print_chat, "teamkill menu");
}

public teamkill_pushed(id, key)
{
	if (!g_isZombie[id] || !g_boolCanBuild || g_boolFreeZombies[id])
		return;

	if (key == 0)
	{
		g_boolFreeZombies[id] = true;

		ExecuteHam(Ham_CS_RoundRespawn, id);
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (g_isAlive[i] && g_isZombie[i])
			{
				client_print_color(i, print_team_default, "%s %L", MODNAME, LANG_PLAYER, "JOINED_ZOMBIE_FREE", id);
			}
		}
	}
}

public fw_AddToFullPack_Post(es, e, ent, host, hostflags, player, pSet)
{
	if (!(1 <= ent <= MaxClients) && is_valid_ent(ent) && IsMovingEnt(ent) && g_iOwnedEnt[host] != ent && g_isAlive[host])
	{
		set_es(es, ES_Solid, SOLID_NOT);
	}
}

stock bool:IsPlayerStuck(id)
{
    static Float:originF[3]
    pev(id, pev_origin, originF)
    
    engfunc(EngFunc_TraceHull, originF, originF, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0)
    
    if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
        return true;
    
    return false;
}

stock bool:IsObjectInWall(ent)
{
	new Float:orig[3];
	entity_get_vector(ent, EV_VEC_origin, orig);
	
	new Float:min[3], Float:max[3];
	entity_get_vector(ent, EV_VEC_mins, min);
	entity_get_vector(ent, EV_VEC_maxs, max);

	new Float:start[3], Float:end[3];
	xs_vec_add(orig, min, start);
	xs_vec_add(orig, max, end);

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {255, 0, 0}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	start[0] = orig[0] + min[0];
	start[1] = orig[1] + min[1];
	start[2] = orig[2] + max[2];

	end[0] = orig[0] + max[0];
	end[1] = orig[1] + max[1];
	end[2] = orig[2] + min[2];

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {0, 100, 255}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	xs_vec_add(orig, min, start);

	end[0] = orig[0] + max[0];
	end[1] = orig[1] + min[1];
	end[2] = orig[2] + min[2];

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {200, 200, 200}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	start[0] = orig[0] + min[0];
	start[1] = orig[1] + max[1];
	start[2] = orig[2] + max[2];

	xs_vec_add(orig, max, end);

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {200, 200, 200}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	xs_vec_add(orig, min, start);

	end[0] = orig[0] + min[0];
	end[1] = orig[1] + min[1];
	end[2] = orig[2] + max[2];

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {200, 200, 200}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	start[0] = orig[0] + max[0];
	start[1] = orig[1] + max[1];
	start[2] = orig[2] + min[2];

	xs_vec_add(orig, max, end);

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {200, 200, 200}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	xs_vec_add(orig, min, start);

	end[0] = orig[0] + min[0];
	end[1] = orig[1] + max[1];
	end[2] = orig[2] + min[2];

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {200, 200, 200}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;

	start[0] = orig[0] + max[0];
	start[1] = orig[1] + min[1];
	start[2] = orig[2] + max[2];

	xs_vec_add(orig, max, end);

	//drawLine2(0, start, end, g_hahajai, 0, 0, 100, 10, 0, {200, 200, 200}, 200);
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ent, 0);
	if (!CheckSolid())
		return false;
	
	return true;
}

stock bool:CheckSolid()
{
	if (!get_tr2(0, TR_StartSolid) || !get_tr2(0, TR_AllSolid) || get_tr2(0, TR_InOpen))
		return false;
	
	return true;
}

// Draw a line
stock drawLine(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, 
	sprite, frame=0, rate=0, life=10, width=10, noise=0, const color[3]={255,255,255}, alpha=127, scroll=0)
{
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id);
	write_byte(TE_BEAMPOINTS);
	write_coord_f(x1);
	write_coord_f(y1);
	write_coord_f(z1);
	write_coord_f(x2);
	write_coord_f(y2);
	write_coord_f(z2);
	write_short(sprite);
	write_byte(frame);
	write_byte(rate);
	write_byte(life);
	write_byte(width);
	write_byte(noise);
	write_byte(color[0]);
	write_byte(color[1]);
	write_byte(color[2]);
	write_byte(alpha);
	write_byte(scroll);
	message_end();
}

// Draw a line with vector3D
stock drawLine2(id, Float:start[3], Float:end[3], sprite, frame=0, rate=0, life=10,
	width=10, noise=0, const color[3]={255,255,255}, alpha=127, scroll=0)
{
	drawLine(id, start[0], start[1], start[2], end[0], end[1], end[2],
		sprite, frame, rate, life, width, noise, color, alpha, scroll);
}