#include <amxmodx>
#include <amxmisc>
#include <basebuilder>
#include <fakemeta>
#include <hamsandwich>
#include <csx>
#include <fun>
#include <cstrike>
#include <nvault>
#include <sqlx>

#define VERSION "7.4"
#define MODNAME "^x01 [^x04 Base Builder^x01 ]"
#define MAXPLAYERS 32

#define FLAGS_CREDITS ADMIN_RCON

#define MEDAL_HUD_FX 2.0
#define MEDAL_HUD_TIME 3.0
#define MEDAL_DELAY 4.0//(MEDAL_HUD_FX + MEDAL_HUD_TIME)
#define HUDCHANNEL_MEDAL 4

enum (+=5000)
{
	TASK_MISC = 100000
}

new g_iMaxPlayers
new g_msgSayText
new g_szModName[32]

new bool:g_isConnected[MAXPLAYERS+1]
new bool:g_isAlive[MAXPLAYERS+1]

enum 
{ 
	DESC_NAME = 0, 
	DESC_DESC,
	DESC_REQ,
	DESC_REWARD
}

#define SOUND_SELECT 	"buttons/lightswitch2.wav"
#define SOUND_FAIL	"buttons/button10.wav"

/*--------------------------------------------*//*--------------------------------------------*/
//					     Credits
/*--------------------------------------------*//*--------------------------------------------*/
#define SOUND_GOAL "basebuilder/medals/credits_goal.wav"
#define SOUND_BEEP "buttons/blip2.wav"
new g_iGoal[MAXPLAYERS+1]
new g_iGoalCheck[MAXPLAYERS+1]
new bool:g_bShouldAnnounce[MAXPLAYERS+1]

#define CREDITS_KILL_ZOMBIE 1
#define CREDITS_DEATH_ZOMBIE 1
#define CREDITS_KILL_HUMAN 10
new g_iCredits[MAXPLAYERS+1]
new g_iSpawnCredits[MAXPLAYERS+1]

/*--------------------------------------------*//*--------------------------------------------*/
//					   Challenges
/*--------------------------------------------*//*--------------------------------------------*/
#define SOUND_REWARDCHALLENGE "basebuilder/medals/challenge_complete.wav"
enum
{
	CHAL_COMPLETE = -1,
	CHAL_KILLS,
	CHAL_KILLS_ZOMBIE,
	CHAL_KILLS_HUMAN,
	CHAL_KILLS_HEAD,
	CHAL_DEATHS_ZOMBIE,
	CHAL_DEATHS_HUMAN,
	CHAL_COLORBLIND,
	CHAL_OBJECT_LOCKER,
	CHAL_OBJECT_BUILDER,
	CHAL_MEDAL_1,
	CHAL_MEDAL_2,
	CHAL_MEDAL_3,
	CHAL_MEDAL_4,
	CHAL_MEDAL_5,
	CHAL_MEDAL_6,
	CHAL_MEDAL_7,
	CHAL_MEDAL_8,
	CHAL_MEDAL_9,
	CHAL_MEDAL_10,
	CHAL_MEDAL_11,
	CHAL_DMG_ZOMBIE,
	CHAL_DMG_HUMAN,
	CHAL_MEDAL_12,
	CHAL_MEDAL_13,
	CHAL_ACHHUNTER
}

static const g_szChallengeNames[][][] = 
{
	//Name			Description					Req (int)	Reward (int)
	{ "Alpha and Omega", 	"Take down 25,000 enemies", 			"25000",	"1000" 	},
	{ "Zombie Genocidist", 	"Eliminate 10,000 zombies", 			"10000",	"500" 	},
	{ "Hmm... Tasty", 	"Eat the brains of 500 humans", 			"500",		"750"	},
	{ "Shoot to Kill", 	"Headshot 1337 zombies", 			"1337",		"350" 	},
	{ "Owned", 		"Die 5,000 times as a zombie", 			"5000",		"500"	},
	{ "One For The Team",	"Die 1,000 times as a human", 			"1000",		"100" 	},
	{ "Colorblind", 		"Select a new color 250 times", 			"250",		"50" 	},
	{ "Locked-up Tight",	"Lock and claim 250 blocks", 			"250",		"250"	},
	{ "Base Builder", 	"Move 10,000 blocks",		 		"10000",	"250"	},
	{ "Fast Killer", 	"Get the ^"First Blood^" medal 100 times",	"100",		"200" 	},
	{ "1shot2kill", 		"Get the ^"Double Kill^" medal 75 times",	"50",		"350" 	},
	{ "Drop of Blood", 	"Get the ^"Triple Kill^" medal 50 times",	"50",		"500" 	},
	{ "Pool of Blood", 	"Get the ^"Multi-Kill^" medal 25 times",	"25",		"750" 	},
	{ "River of Blood", 	"Get the ^"Bloodbath^" medal 10 times",	 	"10",		"1000" 	},
	{ "The Cleaver", 	"Get the ^"Butcher^" medal 10 times",	 	"10",		"250" 	},
	{ "Ammo Conservative", 	"Get the ^"Cold Efficiency^" medal 50 times", 	"50",		"450"	},
	{ "Heat Sensor", 	"Get the ^"Lucky Shot^" medal 50 times",	"50",		"250"	},
	{ "The Easy Way Out", 	"Get the ^"Suicidal^" medal 25 times",	 	"25",		"25" 	},
	{ "The Guillotine", 	"Get the ^"Headcase^" medal 10 times",	 	"10",		"400" 	},
	{ "Commando", 		"Get the ^"Holy Shit^" medal 25 times",	 	"15",		"500" 	},
	{ "Dead Wreckening", 	"Inflict 100,000 damage as a zombie",	 	"100000",	"750" 	},
	{ "Every Bullet Counts",	"Inflict 1,000,000 damage as a human",	 	"1000000",	"250" 	},
	{ "Boomstick", 		"Get the ^"Shotgun Madness^" medal 250 times",	"250",		"500" 	},
	{ "Pinpoint Precision", 	"Get the ^"Headhunter^" medal 250 times",	"250",		"500" 	},
	{ "Challenge Hunter", 	"Unlock every other Challenge",	 		"24",		"250" 	}
}

new g_iChallengeStats[MAXPLAYERS+1][sizeof g_szChallengeNames]

//Medal-based ones are in medals section below medalnames

/*--------------------------------------------*//*--------------------------------------------*/
//					     Medals
/*--------------------------------------------*//*--------------------------------------------*/
#define SOUND_REWARDMEDAL "basebuilder/medals/medal_complete2.wav"

//Global medal sounds
new const g_szMedalSounds[][] =
{
	"basebuilder/medals/firstblood.wav",
	"basebuilder/medals/multikill.wav",
	"basebuilder/medals/megakill.wav",
	"basebuilder/medals/ludacrisskill.wav",
	"basebuilder/medals/wickedsick.wav",
	"basebuilder/medals/humiliation.wav",
	"basebuilder/medals/perfect.wav",
	"basebuilder/medals/flawless.wav",
	"basebuilder/medals/pussy.wav",
	"basebuilder/medals/impressive.wav",
	"basebuilder/medals/holyshit.wav",
	"basebuilder/medals/excellent.wav",
	"basebuilder/medals/fatality.wav"
}

enum
{
	MEDAL_NONE = -1,
	MEDAL_FIRSTBLOOD,
	MEDAL_MULTI_2,
	MEDAL_MULTI_3,
	MEDAL_MULTI_4,
	MEDAL_MULTI_5,
	MEDAL_DAMAGE,
	MEDAL_EFFICIENCY,
	MEDAL_INVISIBLE,
	MEDAL_SUICIDE,
	MEDAL_HEADSHOT,
	MEDAL_HOLYSHIT,
	MEDAL_SHOTGUN,
	MEDAL_HEADSHOT2
}

static const g_szMedalNames[][][] = 
{
	//Name			Description						"Req" (int)	Reward (int)
	{ "First Blood", 	"Get the first kill of the round",			"0",		"2"	},
	{ "Multi-Kill", 		"Kill 2 enemies in rapid succession",			"0",		"5"	},
	{ "Mega-Kill", 		"Kill 3 enemies in rapid succession",			"0",		"7"	},
	{ "Ludacriss Kill", 	"Kill 4 enemies in rapid succession",			"0",		"9"	},
	{ "Wicked Sick", 	"Kill 5 enemies in rapid succession",			"0",		"11"	},
	{ "Butcher", 		"Deal a devastating blow to an enemy",			"0",		"15"	},
	{ "Cold Efficiency", 	"Kill 2 zombies without reloading",			"2",		"5"	},
	{ "Lucky Shot", 		"Kill 2 invisible enemies in rapid succession",		"2",		"5"	},
	{ "Suicidal", 		"Commit suicide instead of letting a zombie kill you",	"1",		"1"	},
	{ "Headcase", 		"Kill a human with a headshot",				"0",		"5"	},
	{ "Holy Shit", 		"Kill a zombie with a knife",				"0",		"10"	},
	{ "Shotgun Madness",	"Kill 5 enemies in a row with a shotgun",	 	"5",		"7" 	},
	{ "Headhunter",		"Kill 2 enemies in a row with headshots",		"2",		"3" 	}
}

#define MEDALBOX_MAX 5
new g_iMedalBox[MAXPLAYERS+1][MEDALBOX_MAX]
new Float:g_fMedalDelay[MAXPLAYERS+1]

//Multi-Kill
/*--------------------------------------------*/
new Float:g_fKillTimer[MAXPLAYERS+1]
new g_iKillCounter[MAXPLAYERS+1]
#define MULTI_KILL_TIME 1.5
/*--------------------------------------------*/

//First Blood
/*--------------------------------------------*/
//Made into an integer in case I want to reference the ID
new g_iFirstKill
/*--------------------------------------------*/

//Butcher
/*--------------------------------------------*/
new g_iCurrentWeapon[MAXPLAYERS+1]
#define MEDAL_DAMAGECHECK 150.0
/*--------------------------------------------*/

//Cold Efficiency
/*--------------------------------------------*/
new g_iReloadKills[MAXPLAYERS+1]
const NOCLIP_WPN_BS    = ((1<<2)|(1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))
const m_pPlayer = 41
const m_fInReload = 54
/*--------------------------------------------*/

//Invisible Man
/*--------------------------------------------*/
#define MEDAL_RENDERAMT 200
#define INVIS_KILL_TIME 5.0
/*--------------------------------------------*/

//Shotgun Madness
/*--------------------------------------------*/
new g_iShotgunKills[MAXPLAYERS+1]
/*--------------------------------------------*/

//Shotgun Madness
/*--------------------------------------------*/
new g_iMedalHeadshots[MAXPLAYERS+1]
/*--------------------------------------------*/

/*--------------------------------------------*//*--------------------------------------------*/
//				       nVault and MySQLx
/*--------------------------------------------*//*--------------------------------------------*/
new Handle:g_hTuple1;
new Handle:g_hTuple2;
new Handle:g_hTuple3;
new Handle:g_hTuple4;
new g_szAuth[33][35];
new g_szSaveMode[3]

new g_Vault

new const g_szTables[][] = 
{
	"CREATE TABLE IF NOT EXISTS `mytable1` ( `player_id` varchar(32) NOT NULL,`player_credits` int(32) default NULL,`chal_0` int(16) default NULL,`chal_1` int(16) default NULL,`chal_2` int(16) default NULL,`chal_3` int(16) default NULL,`chal_4` int(16) default NULL,`chal_5` int(16) default NULL,PRIMARY KEY (`player_id`) ) TYPE=MyISAM;",
	"CREATE TABLE IF NOT EXISTS `mytable2` ( `player_id` varchar(32) NOT NULL,`chal_6` int(16) default NULL,`chal_7` int(16) default NULL,`chal_8` int(16) default NULL,`chal_9` int(16) default NULL,`chal_10` int(16) default NULL,`chal_11` int(16) default NULL,`chal_12` int(16) default NULL,PRIMARY KEY (`player_id`) ) TYPE=MyISAM;",
	"CREATE TABLE IF NOT EXISTS `mytable3` ( `player_id` varchar(32) NOT NULL,`chal_13` int(16) default NULL,`chal_14` int(16) default NULL,`chal_15` int(16) default NULL,`chal_16` int(16) default NULL,`chal_17` int(16) default NULL,`chal_18` int(16) default NULL,`chal_19` int(16) default NULL,PRIMARY KEY (`player_id`) ) TYPE=MyISAM;",
	"CREATE TABLE IF NOT EXISTS `mytable4` ( `player_id` varchar(32) NOT NULL,`chal_20` int(16) default NULL,`chal_21` int(16) default NULL,`chal_22` int(16) default NULL,`chal_23` int(16) default NULL,`chal_24` int(16) default NULL,PRIMARY KEY (`player_id`) ) TYPE=MyISAM;"
}

/*--------------------------------------------*//*--------------------------------------------*/
//					     Unlocks
/*--------------------------------------------*//*--------------------------------------------*/
#define SOUND_UNLOCK	"basebuilder/medals/gun_unlocked.wav"
#define KEYS_GENERIC (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9)
static const g_szWeaponInfo[31][2][] = 
{ 
	//Buy Menu Name			//Cost (int)
	{ "",				"0"	},//----
	{ "P228 Compact",		"0"	},//	FREEBEE
	{ "",				"0"	},//----
	{ "Schmidt Scout",		"750"	},
	{ "",				"0"	},//----
	{ "XM1014 M4",			"1000"	},
	{ "",				"0"	},//----
	{ "Ingram MAC-10",		"500"	},
	{ "Steyr AUG A1",		"1000"	},
	{ "",				"0"	},//----
	{ "Dual Elite Berettas",		"500"	},
	{ "Fiveseven",			"250"	},
	{ "UMP 45",			"2000"	},
	{ "SG-550 Auto-Sniper",		"50000"	},
	{ "IMI Galil",			"2500"	},
	{ "Famas",			"1500"	},
	{ "USP .45 ACP Tactical",	"750"	},
	{ "Glock 18C",			"750"	},
	{ "AWP (+fast shoot)",		"1500"	},
	{ "MP5 Navy",			"1000"	},
	{ "M249 Para Machinegun",	"25000"	},
	{ "M3 Super 90",			"2000"	},
	{ "M4A1 Carbine",		"10000"	},
	{ "Schmidt TMP",			"500"	},
	{ "G3SG1 Auto-Sniper",		"25000"	},
	{ "",				"0"	},//----
	{ "Desert Eagle .50 AE",		"1000"	},
	{ "SG-552 Commando",		"0"	},//	FREEBEE
	{ "AK-47 Kalashnikov",		"15000"	},
	{ "",				"0"	},//----
	{ "ES P90", 			"1500"	}
}

new g_iMenuOptions[MAXPLAYERS+1][8]
new g_iIsUnlocked[MAXPLAYERS+1][31]
new g_iMenuMode[MAXPLAYERS+1]

new g_iPrimaryWeapon[MAXPLAYERS+1]
new g_iSecondaryWeapon[MAXPLAYERS+1]

/*--------------------------------------------*//*--------------------------------------------*/
//					     Upgrades
/*--------------------------------------------*//*--------------------------------------------*/
#define UPGRADE_BASE 100
#define UPGRADE_MULT 100
#define GetUpgradeLevel(%1)	( floatround( ( g_fClassMultiplier[id][%1] - 1.0 ) * 100.0 ) )
#define GetUpgradePercent(%1)	( floatround( g_fClassMultiplier[id][%1] - 1.0 ) )

new Float:g_fClassMultiplier[MAXPLAYERS+1][3]
static const g_szUpgradeName[3][] =
{
	"Health",
	"Speed",
	"Gravity"
}

/*--------------------------------------------*//*--------------------------------------------*/
//					      CVARs
/*--------------------------------------------*//*--------------------------------------------*/
new g_pcvar_xpmultiplier, g_iXPMultiplier,
	g_pcvar_savemode, g_iSaveMode,
	g_pcvar_savetype, g_iSaveType,
	g_pcvar_mysqlx_host, g_pcvar_mysqlx_user, g_pcvar_mysqlx_pass, g_pcvar_mysqlx_db,
	g_pcvar_active
	

public plugin_precache()
{
	//Register the plugin
	register_dictionary("basebuilder.txt")
	register_plugin("BB Credits", VERSION, "Tirant");
	register_cvar("bb_credits_version", VERSION, FCVAR_SPONLY|FCVAR_SERVER)
	set_cvar_string("bb_credits_version", VERSION)
	
	g_pcvar_active = register_cvar("bb_credits_active", "1")
	server_cmd("bb_credits_active 1")
		
	if (!get_pcvar_num(g_pcvar_active) || !is_basebuilder_active())
		return;
	
	//Precache the sounds
	precache_sound(SOUND_REWARDCHALLENGE);
	precache_sound(SOUND_REWARDMEDAL);
	precache_sound(SOUND_GOAL);
	precache_sound(SOUND_BEEP);
	precache_sound(SOUND_SELECT);
	precache_sound(SOUND_FAIL);
	precache_sound(SOUND_UNLOCK);

	for (new i = 0; i < sizeof g_szMedalSounds; i++) 	precache_sound(g_szMedalSounds[i])
	
	//Load and cache the vars
	g_pcvar_xpmultiplier = register_cvar("credits_multiplier", "1"); //Multiplies normal kills points by this number
	g_iXPMultiplier = clamp(get_pcvar_num(g_pcvar_xpmultiplier), 1);
	
	//Save cvars
	g_pcvar_savetype = register_cvar("credits_savetype", "0"); //Save type, 0 - nVault, 1 - MySQL
	g_iSaveType = clamp(get_pcvar_num(g_pcvar_savetype), 0, 0);
	g_pcvar_savemode = register_cvar("credits_savemode", "0"); //Save mode, 0 - Steam ID, 1 - IP, 2 - Name
	g_iSaveMode = clamp(get_pcvar_num(g_pcvar_savemode), 0, 2);
	
	
	switch (g_iSaveMode)
	{
		case 0:format(g_szSaveMode, charsmax(g_szSaveMode), "ID")
		case 1:format(g_szSaveMode, charsmax(g_szSaveMode), "IP")
		case 2:format(g_szSaveMode, charsmax(g_szSaveMode), "NM")
	}
	
	// SQLx cvars
	g_pcvar_mysqlx_host = register_cvar ("bb_sql_host", ""); // The host from the db
	g_pcvar_mysqlx_user = register_cvar ("bb_sql_user", ""); // The username from the db login
	g_pcvar_mysqlx_pass = register_cvar ("bb_sql_pass", ""); // The password from the db login
	g_pcvar_mysqlx_db = register_cvar ("bb_sql_dbname", ""); // The database name 
		
	formatex(g_szModName, charsmax(g_szModName), "Base Builder %s", VERSION)
}

public plugin_init()
{	
	server_cmd("bb_credits_active 1")
	
	if (!is_basebuilder_active())
		return;
		
	//Register client commands
	register_clcmd("say", "cmdSay");
	register_clcmd("say_team", "cmdSay");
	
	register_concmd("bb_addcredits", "cmdGiveCredits", 0, " <name> <credits>")
	
	register_event("HLTV", "ev_RoundStart", "a", "1=0", "2=0");
	
	RegisterHam(Ham_TakeDamage, 	"player", "ham_TakeDamage");
	RegisterHam(Ham_Spawn, 		"player", "ham_PlayerSpawn_Post", 1);
	new szWeapon[20];
	for (new i=CSW_P228;i<=CSW_P90;i++) 
	{         
		if(!(NOCLIP_WPN_BS & (1<<i)) && get_weaponname(i, szWeapon, charsmax(szWeapon)))
			RegisterHam(Ham_Weapon_Reload, szWeapon, "ham_Reload_Post", 1);
	}
	
	register_forward(FM_GetGameDescription, "fw_GetGameDescription")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
	
	register_menucmd(register_menuid("A142-UnlocksMain"),		KEYS_GENERIC,"unlocks_pushed")
	register_menucmd(register_menuid("B256-UnlocksWeapons"),	KEYS_GENERIC,"unlocksweps_pushed")
	register_menucmd(register_menuid("C069-GoalMenu"),		KEYS_GENERIC,"goal_pushed")
	register_menucmd(register_menuid("D741-WeaponsMain"),		KEYS_GENERIC,"weapons_pushed")
	register_menucmd(register_menuid("E163-PrimaryWeapons"),	KEYS_GENERIC,"primary_pushed")
	register_menucmd(register_menuid("F741-SecondaryWeapons"),	KEYS_GENERIC,"secondary_pushed")
	register_menucmd(register_menuid("G172-UpgradesMain"),		KEYS_GENERIC,"upgrades_pushed")
	
	if (g_iSaveType)
		task_InitMySQLx()
	
	//Set global variables
	g_iMaxPlayers = get_maxplayers();
	g_msgSayText = get_user_msgid("SayText");
}

public plugin_natives()
{
	register_native("credits_get_user_credits",		"native_get_user_credits", 1)
	register_native("credits_set_user_credits",		"native_set_user_credits", 1)
	register_native("credits_add_user_credits",		"native_add_user_credits", 1)
	register_native("credits_subtract_user_credits",	"native_subtract_user_credits", 1)
	
	register_native("credits_get_user_goal",		"native_get_user_goal", 1)	
	register_native("credits_set_user_goal",		"native_set_user_goal", 1)
	
	register_native("credits_show_unlocksmenu",		"native_show_unlocksmenu", 1)	
	register_native("credits_show_gunsmenu",		"native_show_gunsmenu", 1)	
}

public plugin_cfg()
{
	if (!get_pcvar_num(g_pcvar_active) || !is_basebuilder_active())
		return;
		
	g_Vault = nvault_open( "bb-credits" );

	if ( g_Vault == INVALID_HANDLE )
		set_fail_state( "Error opening Credits nVault, file does not exist!" );	
}

public fw_GetGameDescription()
{
	forward_return(FMV_STRING, g_szModName)
	return FMRES_SUPERCEDE;
}

public cmdSay(id)
{
	if (!g_isConnected[id])
		return PLUGIN_HANDLED;

	new szMessage[32]
	read_args(szMessage, charsmax(szMessage));
	remove_quotes(szMessage);
		
	if(szMessage[0] == '/')
	{
		if (equali(szMessage, "/credits") == 1)
		{
			cmdCreditsReturn(id);
			return PLUGIN_HANDLED;
		}
		else if (equali(szMessage, "/medallist") == 1 || equali(szMessage, "/medals") == 1)
		{
			new tempstring[100];
			new motd[2048];
			format(motd,2048,"<html><body bgcolor=^"#474642^"><font size=^"2^" face=^"verdana^" color=^"FFFFFF^"><strong><b></strong></b>")
			
			for ( new i = 0; i < sizeof g_szMedalNames; i++)
			{
				format(tempstring,99,"%s - %s<br><br>", g_szMedalNames[i][0], g_szMedalNames[i][1])
				add(motd,2048,tempstring);
			}

			add(motd,2048,"</font></body></html>")
				
			show_motd(id,motd,"Available Medals");
		}
		else if (equali(szMessage, "/challist") == 1 || equali(szMessage, "/challenges") == 1)
		{
			new tempstring[100];
			new motd[2048];
			format(motd,2048,"<html><body bgcolor=^"#474642^"><font size=^"2^" face=^"verdana^" color=^"FFFFFF^"><strong><b></strong></b>")
			
			for ( new i = 0; i < sizeof g_szChallengeNames; i++)
			{
				format(tempstring,99,"%s - %s<br><br>", g_szChallengeNames[i][DESC_NAME], g_szChallengeNames[i][DESC_DESC])
				add(motd,2048,tempstring);
			}
			
			add(motd,2048,"</font></body></html>")

			show_motd(id,motd,"Available Challenges");
		}
		else if (equali(szMessage, "/mystats") == 1)
		{
			cmdDisplayStatsid(id, id)
		}
		else if (equal(szMessage, "/whostats",9))
		{
			new player = cmd_target(id, szMessage[10], 0)
		
			if (!player)
			{
				print_color(id, "%s Player^x04 %s^x01 could not be found or targetted", MODNAME, szMessage[10])
				return PLUGIN_CONTINUE
			}
		
			cmdDisplayStatsid(id, player)
		}
		else if (equal(szMessage, "/setgoal", 8))
		{
			new iNumber = str_to_num(szMessage[9])
			
			if (iNumber)
			{
				if (iNumber < g_iCredits[id])
					print_color(id, "%s You already have this many credits", MODNAME) 
				else
				{
					g_iGoal[id] = iNumber
					print_color(id, "%s You've set your goal to^x04 %d^x01 credits", MODNAME, g_iGoal[id])	
				}
			}
			else
				print_color(id, "%s You have entered an invalid number", MODNAME) 
			
			return PLUGIN_HANDLED
		}
		else if (equal(szMessage, "/goal", 5))
		{
			if (g_iCredits[id] >= g_iGoal[id])
			{
				print_color(id, "%s You've already reached your goal", MODNAME)
			}
			else if (g_iGoal[id])
			{
				print_color(id, "%s You're current is^x04 %d^x01 credits", MODNAME, g_iGoal[id])
				print_color(id, "%s Only^x04 %d^x01 more credits to go", MODNAME, g_iGoal[id] - g_iCredits[id])
			}
			else
				print_color(id, "%s You currently do not have a goal set", MODNAME)
		
			return PLUGIN_HANDLED
		}
		else if (equali(szMessage, "/unlocks") == 1 || equali(szMessage, "/unlock") == 1)
		{
			show_unlocks_menu(id)
		}
		/*else if (equali(szMessage, "/upgrades") == 1 || equali(szMessage, "/upgrade") == 1)
		{
			show_upgrades_menu(id)
		}*/
	}
	return PLUGIN_CONTINUE
}

public cmdDisplayStatsid(id,statsid)
{
	new tempstring[100];
	new motd[2048];
	new tempname[30]
	get_user_name(statsid,tempname,29)

	format(motd,2048,"<html><body bgcolor=^"#474642^"><font size=^"2^" face=^"verdana^" color=^"FFFFFF^"><strong><b>%s's Challenge Progress</strong></b><br><br>",tempname)

	for ( new i = 0; i < sizeof g_szChallengeNames; i++)
	{
		format(tempstring,99,"%s<br>        [ %d / %s ]<br>", g_szChallengeNames[i][DESC_NAME], g_iChallengeStats[statsid][i], g_szChallengeNames[i][DESC_REQ])
		add(motd,2048,tempstring);
	}
	
	add(motd,2048,"</font></body></html>")
	
	show_motd(id,motd,"Current Challenge Progress");
}

public ev_RoundStart()
{
	g_iFirstKill = 0
	
	arrayset(g_iReloadKills, 0, MAXPLAYERS+1)
	arrayset(g_iKillCounter, 0, MAXPLAYERS+1)
	arrayset(g_iShotgunKills, 0, MAXPLAYERS+1)
	arrayset(g_iMedalHeadshots, 0, MAXPLAYERS+1)
}

public client_connect(id)
{
	//Reset cached checks
	g_isConnected[id] = true;
	g_isAlive[id] = false;
	
	//Reset credits to get a fresh load
	g_iCredits[id] = 0;
	g_iGoal[id] = 0;
	
	//Reset challenges
	for ( new i = 0; i < sizeof g_szChallengeNames; i++) g_iChallengeStats[id][i] = 0

	//Reset medal counts
	g_iReloadKills[id] = 0;
	g_iKillCounter[id] = 0;
	g_iMedalHeadshots[id] = 0;
	
	//Clear the medals
	//for ( new i = 0; i < MEDALBOX_MAX; i++) g_iMedalBox[id][i] = MEDAL_NONE
	arrayset(g_iMedalBox[id], MEDAL_NONE, MEDALBOX_MAX);
	
	//Erase Unlocks
	//arrayset(g_iIsUnlocked[id], false, sizeof g_szWeaponInfo);
	
	//Reset Weapons Menu
	g_iPrimaryWeapon[id] = CSW_SG552
	g_iSecondaryWeapon[id] = CSW_P228
	
	//Reset Upgrades
	for ( new i = 0; i < 3; i++) g_fClassMultiplier[id][i] = 1.0
	
	switch (g_iSaveMode)
	{
		case 0: get_user_authid( id , g_szAuth[id] , 34 );
		case 1: get_user_ip( id , g_szAuth[id] , 34 );
		case 2: get_user_name( id , g_szAuth[id] , 34 );
	}
	
	LoadLevel(id)
}

public client_disconnect(id)
{
	SaveLevel(id)
	
	g_isConnected[id] = false
	g_isAlive[id] = false
	g_iGoal[id] = 0
	
	g_iCredits[id] = 0;

	//----------------------------
	//for ( new i = 0; i < sizeof g_szChallengeNames; i++) g_iChallengeStats[id][i] = 0
	arrayset(g_iMedalBox[id], MEDAL_NONE, MEDALBOX_MAX);
	//----------------------------
	//arrayset(g_iIsUnlocked[id], false, sizeof g_szWeaponInfo);
	//----------------------------
	g_iReloadKills[id] = 0
	g_iKillCounter[id] = 0
	g_iMedalHeadshots[id] = 0
	//----------------------------
	for ( new i = 0; i < MEDALBOX_MAX; i++) g_iMedalBox[id][i] = MEDAL_NONE
	//----------------------------
	g_iPrimaryWeapon[id] = CSW_SG552
	g_iSecondaryWeapon[id] = CSW_P228
	//----------------------------
	for ( new i = 0; i < 3; i++) g_fClassMultiplier[id][i] = 1.0
}

public fw_PlayerPreThink(id)
{
	if (!g_isConnected[id]) return ;
	
	if ((g_fMedalDelay[id] + MEDAL_DELAY) < get_gametime()/* && (g_fKillTimer[id]+MULTI_KILL_TIME) > get_gametime()*/)
	{
		for ( new i = 0; i < MEDALBOX_MAX; i++)
		{
			if (g_iMedalBox[id][i] != MEDAL_NONE )
			{
				new medal = g_iMedalBox[id][i]
				
				//Reset our medals delay
				g_fMedalDelay[id] = get_gametime()
				g_iMedalBox[id][i] = MEDAL_NONE
				
				//Announce the generic medal completed sound
				client_cmd(id, "spk %s", SOUND_REWARDMEDAL);
				client_cmd(0, "spk %s", g_szMedalSounds[medal]);
				
				//Set and show our HUD message
				set_hudmessage(255, 255, 255, -1.0, 0.30, 2, MEDAL_HUD_FX, MEDAL_HUD_TIME, 0.02, 0.02, HUDCHANNEL_MEDAL);
				show_hudmessage(id, "%s!^n%s^n+%d Credits", g_szMedalNames[medal][DESC_NAME], g_szMedalNames[medal][DESC_DESC], str_to_num(g_szMedalNames[medal][DESC_REWARD]));
				print_color(id, "%s You have completed the^x04 %s^x01 medal for^x04 %d^x01 credits", MODNAME, g_szMedalNames[medal][DESC_NAME], str_to_num(g_szMedalNames[medal][DESC_REWARD]));
					
				g_iCredits[id]+=str_to_num(g_szMedalNames[medal][DESC_REWARD])
					
				//Check challenge counter for medals
				static challenge
				switch (medal)
				{
					case MEDAL_FIRSTBLOOD: challenge = CHAL_MEDAL_1
					case MEDAL_MULTI_2: challenge = CHAL_MEDAL_2
					case MEDAL_MULTI_3: challenge = CHAL_MEDAL_3
					case MEDAL_MULTI_4: challenge = CHAL_MEDAL_4
					case MEDAL_MULTI_5: challenge = CHAL_MEDAL_5
					case MEDAL_DAMAGE: challenge = CHAL_MEDAL_6
					case MEDAL_EFFICIENCY: challenge = CHAL_MEDAL_7
					case MEDAL_INVISIBLE: challenge = CHAL_MEDAL_8
					case MEDAL_SUICIDE: challenge = CHAL_MEDAL_9
					case MEDAL_HEADSHOT: challenge = CHAL_MEDAL_10
					case MEDAL_HOLYSHIT: challenge = CHAL_MEDAL_11
					case MEDAL_SHOTGUN: challenge = CHAL_MEDAL_12
					case MEDAL_HEADSHOT2: challenge = CHAL_MEDAL_13
				}
				
				task_SetChallengeStats(id, challenge);
				
				break ;
			}
		}
	}
	else if (!g_fMedalDelay[id])
	{
		g_fMedalDelay[id] = get_gametime()	
	}
	
	if (g_iGoal[id] && g_iCredits[id] == g_iGoal[id])
	{
		g_iGoal[id] = 0
		
		print_color(id, "%s You have reached your goal!", MODNAME)
		client_cmd(id, "spk %s", SOUND_GOAL);
		
		return;
	}
	
	if (g_iCredits[id] && g_iCredits[id] > g_iSpawnCredits[id] && g_iCredits[id] % 100 == 0 && g_bShouldAnnounce[id])
	{
		g_bShouldAnnounce[id] = false
		print_color(id, "%s You're 100 credits closer to your goal", MODNAME)
		client_cmd(id, "spk %s", SOUND_BEEP)
	}
	
	return ;
}

public ham_PlayerSpawn_Post(id)
{
	if (!is_user_alive(id)) return ;
	
	g_isAlive[id] = true
	g_bShouldAnnounce[id] = true
	g_iSpawnCredits[id] = g_iCredits[id]
	
	cmdCreditsReturn(id);
}

public client_death(killer, victim, wpnindex, hitplace, TK)
{
	if (is_user_alive(victim)) return ;
	
	g_isAlive[victim] = false
	
	if (!pev_valid(killer))
		task_SetMedalSlot(victim, MEDAL_SUICIDE)
	
	if (TK || killer == victim) return ;
	
	if (!g_iFirstKill)
	{
		g_iFirstKill = killer
		
		//Global announcements
		new szPlayerName[32]
		get_user_name(killer, szPlayerName, charsmax(szPlayerName))
			
		set_hudmessage(255, 0, 0, -1.0, 0.40, 0, 0.1, 2.5, 0.02, 0.02, 2)
		show_hudmessage(0, "First Blood!^n%s has gotten the first kill", szPlayerName);
		
		task_SetMedalSlot(killer, MEDAL_FIRSTBLOOD);
	}
	
	//Everything in these brackets has to do with multi-kills within timelimits
	/*----------------------------------------------------------------------------------------*/
	g_iShotgunKills[victim] = 0
	g_iKillCounter[victim] = 0
	g_iKillCounter[killer]++
	
	if ((g_fKillTimer[killer]+MULTI_KILL_TIME) > get_gametime())
	{
		static medal = MEDAL_NONE
		switch (g_iKillCounter[killer])
		{
			case 5: medal = MEDAL_MULTI_5
			case 4: medal = MEDAL_MULTI_4
			case 3: medal = MEDAL_MULTI_3
			case 2: medal = MEDAL_MULTI_2
		}
		task_SetMedalSlot(killer, medal);
		
		//The logic here is that if they couldn't pass the multi-check, they wouldn't
		//have been able to pass this check, so why not put it in here?
		if ((g_fKillTimer[killer]+INVIS_KILL_TIME) > get_gametime())
		{
			if (g_iKillCounter[killer] == str_to_num(g_szMedalNames[MEDAL_INVISIBLE][DESC_REQ]) && pev(victim, pev_renderamt) <= MEDAL_RENDERAMT)
				task_SetMedalSlot(killer, MEDAL_INVISIBLE);
		}
	}
	else
	{
		//If their kill isn't within the kill timer, then start a new one
		//Because this could be their first kill, do not reset it if it's 1
		if (g_iKillCounter[killer] != 1)
			g_iKillCounter[killer] = 0

		g_fKillTimer[killer] = get_gametime();
	}
	/*----------------------------------------------------------------------------------------*/
	task_SetChallengeStats(killer, CHAL_KILLS)
					
	if (hitplace == HIT_HEAD)
	{
		task_SetChallengeStats(killer, CHAL_KILLS_HEAD)
				
		g_iMedalHeadshots[killer]++
		if (g_iMedalHeadshots[killer] == str_to_num(g_szMedalNames[MEDAL_HEADSHOT2][DESC_REQ]))
		{
			g_iMedalHeadshots[killer] = 0
			task_SetMedalSlot(killer, MEDAL_HEADSHOT2)
		}
	}
	else
	{
		g_iMedalHeadshots[killer] = 0;
	}
	
	switch (bb_is_user_zombie(killer))
	{
		case true:
		{
			task_SetChallengeStats(killer, CHAL_KILLS_HUMAN);
			task_SetChallengeStats(victim, CHAL_DEATHS_HUMAN);
				
			new iReward = CREDITS_KILL_HUMAN*g_iXPMultiplier
			g_iCredits[killer]+=iReward
	
			if (hitplace == HIT_HEAD)
				task_SetMedalSlot(killer, MEDAL_HEADSHOT);
		}
		case false:
		{
			task_SetChallengeStats(killer, CHAL_KILLS_ZOMBIE);
			task_SetChallengeStats(victim, CHAL_DEATHS_ZOMBIE);
			
			#if defined CREDITS_DEATH_ZOMBIE
			g_iCredits[victim]+=CREDITS_DEATH_ZOMBIE
			#endif
			
			g_iCredits[killer]+=(CREDITS_KILL_ZOMBIE*g_iXPMultiplier)
			
			if (wpnindex != CSW_C4 && wpnindex != CSW_HEGRENADE && wpnindex != CSW_KNIFE)
			{
				g_iReloadKills[killer]++
				if (g_iReloadKills[killer] == str_to_num(g_szMedalNames[MEDAL_EFFICIENCY][DESC_REQ]))
				{
					g_iReloadKills[killer] = 0
					task_SetMedalSlot(killer, MEDAL_EFFICIENCY);
				}
			}
			
			if (wpnindex == CSW_KNIFE)
			{
				task_SetMedalSlot(killer, MEDAL_HOLYSHIT);
			}
			
			if (wpnindex == CSW_M3 || wpnindex == CSW_XM1014)
			{
				g_iShotgunKills[killer]++
				if (g_iShotgunKills[killer] == str_to_num(g_szMedalNames[MEDAL_SHOTGUN][DESC_REQ]))
				{
					g_iShotgunKills[killer] = 0
					task_SetMedalSlot(killer, MEDAL_SHOTGUN);	
				}
			}
			else
				g_iShotgunKills[killer] = 0
		}
	}
}

public task_SetMedalSlot(id, medal)
{
	if (medal == MEDAL_NONE)
		return ;

	for ( new i = 0; i < MEDALBOX_MAX; i++)
	{
		if ((0<medal<5 && 0<g_iMedalBox[id][i]<5) || g_iMedalBox[id][i] == MEDAL_NONE)
		{
			g_iMedalBox[id][i] = medal
			break ;
		}
	}
	
	return ;
}

public task_SetChallengeStats(id, challenge)
{
	g_iChallengeStats[id][challenge]++
	if (g_iChallengeStats[id][challenge] == str_to_num(g_szChallengeNames[challenge][DESC_REQ]))
		task_RewardChallenge(id, challenge)
}

public task_RewardChallenge(id, challenge)
{
	//Announce the generic challenge completed sound
	client_cmd(id, "spk %s", SOUND_REWARDCHALLENGE);
	
	//Set and show our HUD message
	set_hudmessage(255, 255, 255, -1.0, 0.30, 2, MEDAL_HUD_FX, MEDAL_HUD_TIME, 0.02, 0.02, HUDCHANNEL_MEDAL);
	show_hudmessage(id, "%s^n%s^n+%d Credits", g_szChallengeNames[challenge][DESC_NAME], g_szChallengeNames[challenge][DESC_DESC], str_to_num(g_szChallengeNames[challenge][DESC_REWARD]));
	print_color(id, "%s You have completed the^x04 %s^x01 challenge for^x04 %d^x01 credits", MODNAME, g_szChallengeNames[challenge][DESC_NAME], str_to_num(g_szChallengeNames[challenge][DESC_REWARD]));
	
	g_iCredits[id]+=str_to_num(g_szChallengeNames[challenge][DESC_REWARD])
	
	task_SetChallengeStats(id, CHAL_ACHHUNTER);
}

public ev_CurWeapon(id)
{
	g_iCurrentWeapon[id] = read_data(2)
}

public ham_TakeDamage(victim, null, attacker, Float:damage, damagebits)
{
	if (!pev_valid(victim) || !pev_valid(attacker) || !is_user_connected(attacker)) return HAM_IGNORED;
	
	if (g_iCurrentWeapon[attacker] == CSW_KNIFE && damage >= MEDAL_DAMAGECHECK)
		task_SetMedalSlot(attacker, MEDAL_DAMAGE)
		
	if (bb_is_user_zombie(attacker))
	{
		g_iChallengeStats[attacker][CHAL_DMG_ZOMBIE]+=floatround(damage)
		if (g_iChallengeStats[attacker][CHAL_DMG_ZOMBIE] == str_to_num(g_szChallengeNames[CHAL_DMG_ZOMBIE][DESC_REQ]))
			task_RewardChallenge(attacker, CHAL_DMG_ZOMBIE)
	}
	else
	{
		g_iChallengeStats[attacker][CHAL_DMG_HUMAN]+=floatround(damage)
		if (g_iChallengeStats[attacker][CHAL_DMG_HUMAN] == str_to_num(g_szChallengeNames[CHAL_DMG_HUMAN][DESC_REQ]))
			task_RewardChallenge(attacker, CHAL_DMG_HUMAN)
	}
		
	return HAM_HANDLED;
}

public ham_Reload_Post(iEnt)
{    
	if( get_pdata_int(iEnt, m_fInReload, 4) )
	{
		new id = get_pdata_cbase(iEnt, m_pPlayer, 4)
		g_iReloadKills[id] = 0
	}
}

public show_unlocks_menu(id)
{
	arrayset(g_iMenuOptions[id], 0, 8)
	new szMenuBody[256];
			
	new nLen = format( szMenuBody, 255, "\rUnlocks Menu: \r%d^n", g_iCredits[id]);
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \wAssault Rifles");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \wSubmachine Guns");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \wOther Weapons");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. \wSecondary Weapons");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. \yGodly Weapons");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n^n\r0. \wClose" );
		
	show_menu(id,MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_0,szMenuBody,-1,"A142-UnlocksMain")
}

public unlocks_pushed(id,key)
{
	if (key < 5)
	{
		client_cmd(id, "spk %s", SOUND_SELECT);
		show_unlocksweps_menu(id, key);
	}
	else if (key == 9)
		client_cmd(id, "spk %s", SOUND_SELECT)

	return ;
}

public show_unlocksweps_menu(id, unlocktype)
{
	arrayset(g_iMenuOptions[id], 0, 8)
	g_iMenuMode[id] = unlocktype
	
	new szMenuBody[256], nLen, keys
	switch (unlocktype)
	{
		//Assalt Rifles
		case 0:
		{
			nLen = format( szMenuBody, 255, "\rAssault Rifles: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \w[$%s] %s", g_szWeaponInfo[CSW_AUG][1],	g_szWeaponInfo[CSW_AUG][0]);
			g_iMenuOptions[id][0] = CSW_AUG
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \w[$%s] %s", g_szWeaponInfo[CSW_FAMAS][1], 	g_szWeaponInfo[CSW_FAMAS][0]);
			g_iMenuOptions[id][1] = CSW_FAMAS
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \w[$%s] %s", g_szWeaponInfo[CSW_GALIL][1], 	g_szWeaponInfo[CSW_GALIL][0]);
			g_iMenuOptions[id][2] = CSW_GALIL
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. \w[$%s] %s", g_szWeaponInfo[CSW_M4A1][1], 	g_szWeaponInfo[CSW_M4A1][0]);
			g_iMenuOptions[id][3] = CSW_M4A1
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. \w[$%s] %s", g_szWeaponInfo[CSW_AK47][1], 	g_szWeaponInfo[CSW_AK47][0]);
			g_iMenuOptions[id][4] = CSW_AK47
			
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5
		}
		//SMGs
		case 1:
		{
			nLen = format( szMenuBody, 255, "\rSubmachine Guns: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \w[$%s] %s", g_szWeaponInfo[CSW_MAC10][1],	g_szWeaponInfo[CSW_MAC10][0]);
			g_iMenuOptions[id][0] = CSW_MAC10
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \w[$%s] %s", g_szWeaponInfo[CSW_TMP][1], 	g_szWeaponInfo[CSW_TMP][0]);
			g_iMenuOptions[id][1] = CSW_TMP
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \w[$%s] %s", g_szWeaponInfo[CSW_MP5NAVY][1], 	g_szWeaponInfo[CSW_MP5NAVY][0]);
			g_iMenuOptions[id][2] = CSW_MP5NAVY
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. \w[$%s] %s", g_szWeaponInfo[CSW_P90][1], 	g_szWeaponInfo[CSW_P90][0]);
			g_iMenuOptions[id][3] = CSW_P90
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. \w[$%s] %s", g_szWeaponInfo[CSW_UMP45][1], 	g_szWeaponInfo[CSW_UMP45][0]);
			g_iMenuOptions[id][4] = CSW_UMP45
			
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5
		}
		//Other
		case 2:
		{
			nLen = format( szMenuBody, 255, "\rOther Weapons: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \w[$%s] %s", g_szWeaponInfo[CSW_XM1014][1],	g_szWeaponInfo[CSW_XM1014][0]);
			g_iMenuOptions[id][0] = CSW_XM1014
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \w[$%s] %s", g_szWeaponInfo[CSW_M3][1], 		g_szWeaponInfo[CSW_M3][0]);
			g_iMenuOptions[id][1] = CSW_M3
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \w[$%s] %s", g_szWeaponInfo[CSW_SCOUT][1], 	g_szWeaponInfo[CSW_SCOUT][0]);
			g_iMenuOptions[id][2] = CSW_SCOUT
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. \w[$%s] %s", g_szWeaponInfo[CSW_AWP][1], 	g_szWeaponInfo[CSW_AWP][0]);
			g_iMenuOptions[id][3] = CSW_AWP
			
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4
		}
		//Secondary
		case 3:
		{
			nLen = format( szMenuBody, 255, "\rSecondary Weapons: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \w[$%s] %s", g_szWeaponInfo[CSW_FIVESEVEN][1],	g_szWeaponInfo[CSW_FIVESEVEN][0]);
			g_iMenuOptions[id][0] = CSW_FIVESEVEN
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \w[$%s] %s", g_szWeaponInfo[CSW_ELITE][1], 	g_szWeaponInfo[CSW_ELITE][0]);
			g_iMenuOptions[id][1] = CSW_ELITE
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \w[$%s] %s", g_szWeaponInfo[CSW_USP][1], 	g_szWeaponInfo[CSW_USP][0]);
			g_iMenuOptions[id][2] = CSW_USP
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. \w[$%s] %s", g_szWeaponInfo[CSW_GLOCK18][1], 	g_szWeaponInfo[CSW_GLOCK18][0]);
			g_iMenuOptions[id][3] = CSW_GLOCK18
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. \w[$%s] %s", g_szWeaponInfo[CSW_DEAGLE][1], 	g_szWeaponInfo[CSW_DEAGLE][0]);
			g_iMenuOptions[id][4] = CSW_DEAGLE
			
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5
		}
		//Godly
		case 4:
		{
			nLen = format( szMenuBody, 255, "\rGodly Weapons: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \w[$%s] %s", g_szWeaponInfo[CSW_M249][1],	g_szWeaponInfo[CSW_M249][0]);
			g_iMenuOptions[id][0] = CSW_M249
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \w[$%s] %s", g_szWeaponInfo[CSW_G3SG1][1], 	g_szWeaponInfo[CSW_G3SG1][0]);
			g_iMenuOptions[id][1] = CSW_G3SG1
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \w[$%s] %s", g_szWeaponInfo[CSW_SG550][1], 	g_szWeaponInfo[CSW_SG550][0]);
			g_iMenuOptions[id][2] = CSW_SG550
		
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3
		}
	}
	nLen += format( szMenuBody[nLen], 255-nLen, "^n^n\r9. \wBack" );
	keys += MENU_KEY_9
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r0. \wClose" );
	keys += MENU_KEY_0
	
	show_menu(id,keys,szMenuBody,-1,"B256-UnlocksWeapons")
}

public unlocksweps_pushed(id,key)
{
	if(key<8 && g_iMenuOptions[id][key])
	{
		static weapon
		weapon = g_iMenuOptions[id][key]
		if (str_to_num(g_szWeaponInfo[weapon][1]) && g_iCredits[id] >= str_to_num(g_szWeaponInfo[weapon][1]) && !g_iIsUnlocked[id][weapon])
		{
			g_iCredits[id]-=str_to_num(g_szWeaponInfo[weapon][1])
			g_iIsUnlocked[id][weapon] = 1
			SaveLevel(id)
			
			print_color(id, "%s Congratulations, you have unlocked the %s for use", MODNAME, g_szWeaponInfo[weapon][0]);
			client_cmd(id, "spk %s", SOUND_UNLOCK);
			return;
		}
		else if (g_iIsUnlocked[id][weapon])
		{
			print_color(id, "%s You have already unlocked this weapon", MODNAME);
			client_cmd(id, "spk %s", SOUND_FAIL);
			show_unlocksweps_menu(id, g_iMenuMode[id])
			return;
		}
		else if (g_iCredits[id] < str_to_num(g_szWeaponInfo[weapon][1]))
		{
			print_color(id, "%s You don't have enough money to unlock this weapon", MODNAME);
			client_cmd(id, "spk %s", SOUND_FAIL);
			
			g_iGoalCheck[id] = weapon
			show_goal_menu(id)
			
			return;
		}
	}
	else if(key==8)
	{
		client_cmd(id, "spk %s", SOUND_SELECT)
		show_unlocks_menu(id)
	}

	return ;
}

public show_goal_menu(id)
{
	new szMenuBody[256]
			
	new nLen = format( szMenuBody, 255, "\rSet $%s as your new goal for %s?^n", g_szWeaponInfo[g_iGoalCheck[id]][1], g_szWeaponInfo[g_iGoalCheck[id]][0]);
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \wYes");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \wNo");
		
	show_menu(id,MENU_KEY_1|MENU_KEY_2,szMenuBody,-1,"C069-GoalMenu")
}

public goal_pushed(id,key)
{
	if (key == 0)
	{
		print_color(id, "%s %s has become your new goal", MODNAME, g_szWeaponInfo[g_iGoalCheck[id]][1]);
		g_iGoal[id] = str_to_num(g_szWeaponInfo[g_iGoalCheck[id]][1])
		client_cmd(id, "spk %s", SOUND_SELECT);
		
		show_unlocksweps_menu(id, g_iMenuMode[id])
	}

	return ;
}

public show_weapons_menu(id)
{
	arrayset(g_iMenuOptions[id], 0, 8)
	
	new szMenuBody[256];		
	new nLen = format( szMenuBody, 255, "\rWeapons Menu (Primary): \r%d^n", g_iCredits[id]);
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. \wAssault Rifles");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. \wSubmachine Guns");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. \wOther Weapons");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. \yGodly Weapons");
		
	show_menu(id,MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4,szMenuBody,-1,"D741-WeaponsMain")
}

public weapons_pushed(id,key)
{
	if (key < 5)
	{
		client_cmd(id, "spk %s", SOUND_SELECT);
		show_primary_menu(id, key);
	}

	return ;
}

public show_primary_menu(id, mode)
{
	arrayset(g_iMenuOptions[id], 0, 8)
	g_iMenuMode[id] = mode
	
	g_iIsUnlocked[id][CSW_P228] = 1
	g_iIsUnlocked[id][CSW_SG552] = 1
	
	new szMenuBody[256], nLen, keys
	switch (mode)
	{
		//Assalt Rifles
		case 0:
		{
			nLen = format( szMenuBody, 255, "\rAssault Rifles: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. %s%s",	g_iIsUnlocked[id][CSW_SG552] ? "\w" : "\d", 	g_szWeaponInfo[CSW_SG552][0]);
			g_iMenuOptions[id][0] = CSW_SG552
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. %s%s",	g_iIsUnlocked[id][CSW_AUG] ? "\w" : "\d", 		g_szWeaponInfo[CSW_AUG][0]);
			g_iMenuOptions[id][1] = CSW_AUG
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. %s%s",	g_iIsUnlocked[id][CSW_FAMAS] ? "\w" : "\d", 	g_szWeaponInfo[CSW_FAMAS][0]);
			g_iMenuOptions[id][2] = CSW_FAMAS
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. %s%s",	g_iIsUnlocked[id][CSW_GALIL] ? "\w" : "\d", 	g_szWeaponInfo[CSW_GALIL][0]);
			g_iMenuOptions[id][3] = CSW_GALIL
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. %s%s",	g_iIsUnlocked[id][CSW_M4A1] ? "\w" : "\d", 	g_szWeaponInfo[CSW_M4A1][0]);
			g_iMenuOptions[id][4] = CSW_M4A1
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r6. %s%s",	g_iIsUnlocked[id][CSW_AK47] ? "\w" : "\d", 	g_szWeaponInfo[CSW_AK47][0]);
			g_iMenuOptions[id][5] = CSW_AK47
			
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6
		}
		//SMGs
		case 1:
		{
			nLen = format( szMenuBody, 255, "\rSubmachine Guns: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. %s%s",	g_iIsUnlocked[id][CSW_MAC10] ? "\w" : "\d", 	g_szWeaponInfo[CSW_MAC10][0]);
			g_iMenuOptions[id][0] = CSW_MAC10
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. %s%s",	g_iIsUnlocked[id][CSW_TMP] ? "\w" : "\d", 		g_szWeaponInfo[CSW_TMP][0]);
			g_iMenuOptions[id][1] = CSW_TMP
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. %s%s",	g_iIsUnlocked[id][CSW_MP5NAVY] ? "\w" : "\d", 	g_szWeaponInfo[CSW_MP5NAVY][0]);
			g_iMenuOptions[id][2] = CSW_MP5NAVY
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. %s%s",	g_iIsUnlocked[id][CSW_P90] ? "\w" : "\d", 		g_szWeaponInfo[CSW_P90][0]);
			g_iMenuOptions[id][3] = CSW_P90
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. %s%s",	g_iIsUnlocked[id][CSW_UMP45] ? "\w" : "\d", 	g_szWeaponInfo[CSW_UMP45][0]);
			g_iMenuOptions[id][4] = CSW_UMP45
			
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5
		}
		//Other
		case 2:
		{
			nLen = format( szMenuBody, 255, "\rOther Weapons: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. %s%s",	g_iIsUnlocked[id][CSW_XM1014] ? "\w" : "\d", 	g_szWeaponInfo[CSW_XM1014][0]);
			g_iMenuOptions[id][0] = CSW_XM1014
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. %s%s",	g_iIsUnlocked[id][CSW_M3] ? "\w" : "\d", 		g_szWeaponInfo[CSW_M3][0]);
			g_iMenuOptions[id][1] = CSW_M3
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. %s%s",	g_iIsUnlocked[id][CSW_SCOUT] ? "\w" : "\d", 	g_szWeaponInfo[CSW_SCOUT][0]);
			g_iMenuOptions[id][2] = CSW_SCOUT
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. %s%s",	g_iIsUnlocked[id][CSW_AWP] ? "\w" : "\d", 		g_szWeaponInfo[CSW_AWP][0]);
			g_iMenuOptions[id][3] = CSW_AWP

			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4
		}
		//Godly
		case 3:
		{
			nLen = format( szMenuBody, 255, "\rGodly Weapons: \r%d^n", g_iCredits[id]);
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. %s%s",	g_iIsUnlocked[id][CSW_M249] ? "\w" : "\d", 	g_szWeaponInfo[CSW_M249][0]);
			g_iMenuOptions[id][0] = CSW_M249
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. %s%s",	g_iIsUnlocked[id][CSW_G3SG1] ? "\w" : "\d", 	g_szWeaponInfo[CSW_G3SG1][0]);
			g_iMenuOptions[id][1] = CSW_G3SG1
			nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. %s%s",	g_iIsUnlocked[id][CSW_SG550] ? "\w" : "\d", 	g_szWeaponInfo[CSW_SG550][0]);
			g_iMenuOptions[id][2] = CSW_SG550
		
			keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3
		}
	}
	nLen += format( szMenuBody[nLen], 255-nLen, "^n^n\r9. \wBack" );
	keys += MENU_KEY_9
	
	show_menu(id,keys,szMenuBody,-1,"E163-PrimaryWeapons")	
}

public primary_pushed(id,key)
{
	if (key < 7 && g_iMenuOptions[id][key])
	{
		static weapon
		weapon = g_iMenuOptions[id][key]
		if (g_iIsUnlocked[id][weapon])
		{
			g_iPrimaryWeapon[id] = weapon
			show_secondary_menu(id)
			client_cmd(id, "spk %s", SOUND_SELECT);
		}
		else
		{
			client_cmd(id, "spk %s", SOUND_FAIL);
			show_primary_menu(id, g_iMenuMode[id])
		}
	}
	else if (key == 8)
	{
		client_cmd(id, "spk %s", SOUND_SELECT);
		show_weapons_menu(id)
	}

	return ;
}

public show_secondary_menu(id)
{
	arrayset(g_iMenuOptions[id], 0, 8)
	new szMenuBody[256];
		
	new nLen = format( szMenuBody, 255, "\rWeapons Menu (Secondary):^n");
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. %s%s",	g_iIsUnlocked[id][CSW_P228] ? "\w" : "\d", 	g_szWeaponInfo[CSW_P228][0]);
	g_iMenuOptions[id][0] = CSW_P228
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. %s%s",	g_iIsUnlocked[id][CSW_FIVESEVEN] ? "\w" : "\d",	g_szWeaponInfo[CSW_FIVESEVEN][0]);
	g_iMenuOptions[id][1] = CSW_FIVESEVEN
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. %s%s",	g_iIsUnlocked[id][CSW_ELITE] ? "\w" : "\d", 	g_szWeaponInfo[CSW_ELITE][0]);
	g_iMenuOptions[id][2] = CSW_ELITE
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r4. %s%s",	g_iIsUnlocked[id][CSW_USP] ? "\w" : "\d", 		g_szWeaponInfo[CSW_USP][0]);
	g_iMenuOptions[id][3] = CSW_USP
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r5. %s%s",	g_iIsUnlocked[id][CSW_GLOCK18] ? "\w" : "\d", 	g_szWeaponInfo[CSW_GLOCK18][0]);
	g_iMenuOptions[id][4] = CSW_GLOCK18
	nLen += format( szMenuBody[nLen], 255-nLen, "^n\r6. %s%s",	g_iIsUnlocked[id][CSW_DEAGLE] ? "\w" : "\d", 	g_szWeaponInfo[CSW_DEAGLE][0]);
	g_iMenuOptions[id][5] = CSW_DEAGLE
		
	show_menu(id,MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6,szMenuBody,-1,"F741-SecondaryWeapons")
}

public secondary_pushed(id,key)
{
	if (key < 6 && g_iMenuOptions[id][key])
	{
		static weapon
		weapon = g_iMenuOptions[id][key]
		if (g_iIsUnlocked[id][weapon])
		{
			client_cmd(id, "spk %s", SOUND_SELECT);
			g_iSecondaryWeapon[id] = weapon
			task_GiveWeapons(id)
		}
		else
		{
			client_cmd(id, "spk %s", SOUND_FAIL);
			show_secondary_menu(id)
		}
	}

	return ;
}

public task_GiveWeapons(id)
{
	if (!g_isConnected[id] || !g_isAlive[id] || bb_is_user_zombie(id))
		return
		
	strip_user_weapons(id)
	give_item(id,"weapon_knife")
   
	new szWeapon[32], iCSW
	
	if (!g_iPrimaryWeapon[id]) g_iPrimaryWeapon[id] = CSW_SG552
	iCSW = g_iPrimaryWeapon[id]
	get_weaponname(iCSW,szWeapon,31)
	give_item(id,szWeapon)
	cs_set_user_bpammo(id,iCSW,999)
	bb_set_user_primary(id, iCSW)
	
	if (!g_iSecondaryWeapon[id]) g_iSecondaryWeapon[id] = CSW_P228
	iCSW = g_iSecondaryWeapon[id]
	get_weaponname(iCSW,szWeapon,31)
	give_item(id,szWeapon)
	cs_set_user_bpammo(id,iCSW,999)

	return;
}

public show_upgrades_menu(id)
{
	arrayset(g_iMenuOptions[id], -1, 8)
	new szMenuBody[256]
			
	new nLen = format( szMenuBody, 255, "\rUpgrades Menu: \r%d^n", g_iCredits[id]);
	if (GetUpgradeLevel(ATT_HEALTH) < 25) 
	{
		nLen += format( szMenuBody[nLen], 255-nLen, "^n\r1. [$%d] \w%s [ %d / 25 ]", (UPGRADE_BASE + ( GetUpgradeLevel(ATT_HEALTH) * UPGRADE_MULT ) ), g_szUpgradeName[ATT_HEALTH], GetUpgradeLevel(ATT_HEALTH));
		nLen += format( szMenuBody[nLen], 255-nLen, "^n^t^t Upgrade to: %d%%", GetUpgradePercent(ATT_HEALTH)+0.01);
		g_iMenuOptions[id][0] = ATT_HEALTH
	}
	if (GetUpgradeLevel(ATT_SPEED) < 25) 
	{
		nLen += format( szMenuBody[nLen], 255-nLen, "^n\r2. [$%d] \w%s [ %d / 25 ]", (UPGRADE_BASE + ( GetUpgradeLevel(ATT_SPEED) * UPGRADE_MULT ) ), g_szUpgradeName[ATT_SPEED], GetUpgradeLevel(ATT_SPEED));
		nLen += format( szMenuBody[nLen], 255-nLen, "^n^t^t Upgrade to: %d%%", GetUpgradePercent(ATT_SPEED)+0.01);
		g_iMenuOptions[id][1] = ATT_SPEED
	}
	if (GetUpgradeLevel(ATT_GRAVITY) < 25) 
	{
		nLen += format( szMenuBody[nLen], 255-nLen, "^n\r3. [$%d] \w%s [ %d / 25 ]", (UPGRADE_BASE + ( GetUpgradeLevel(ATT_GRAVITY) * UPGRADE_MULT ) ), g_szUpgradeName[ATT_GRAVITY], GetUpgradeLevel(ATT_GRAVITY));
		nLen += format( szMenuBody[nLen], 255-nLen, "^n^t^t Upgrade to: %d%%", GetUpgradePercent(ATT_GRAVITY)+0.01);
		g_iMenuOptions[id][2] = ATT_GRAVITY
	}
	nLen += format( szMenuBody[nLen], 255-nLen, "^n^n\r0. \wClose" );
		
	show_menu(id,MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0,szMenuBody,-1,"G172-UpgradesMain")
}

public upgrades_pushed(id,key)
{
	if (-1<key<3)
	{
		static i
		i = g_iMenuOptions[id][key]
		
		if ( i < 0 || GetUpgradeLevel(i) > 24 )
		{
			show_upgrades_menu(id)
			return;
		}
		
		//Check cost
		if (g_iCredits[id] < (UPGRADE_BASE + ( GetUpgradeLevel(i) * UPGRADE_MULT ) ) )
		{
			show_upgrades_menu(id)
			client_cmd(id, "spk %s", SOUND_FAIL);
			print_color(id, "%s You don't have enough credits for this upgrade", MODNAME)
			return;
		}
		
		g_iCredits[id]-=(UPGRADE_BASE + ( GetUpgradeLevel(i) * UPGRADE_MULT ) )
		g_fClassMultiplier[id][i]+=0.01
		client_cmd(id, "spk %s", SOUND_SELECT);
		print_color(id, "%s You have successfully purchased this upgrade", MODNAME)
		
		SaveLevel(id)
		
		show_upgrades_menu(id)
	}
	else if (key == 9)
	{
		client_cmd(id, "spk %s", SOUND_SELECT);
		return;
	}

	return ;
}

public cmdCreditsReturn(id)
{
	print_color(id, "*** You have^x04 %d^x01 credits. Say ^"/unlock^" or ^"/upgrade^" to buy something ***", g_iCredits[id]);
}

public bb_new_color(id, color)
{
	task_SetChallengeStats(id, CHAL_COLORBLIND)
}

public bb_lock_post(id, entity)
{
	task_SetChallengeStats(id, CHAL_OBJECT_LOCKER)
}

public bb_grab_post(id, entity)
{
	task_SetChallengeStats(id, CHAL_OBJECT_BUILDER)
}

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
}

public task_InitMySQLx()
{
	if (!g_iSaveType)
		return;
	
	new szHost[64], szUser[32], szPass[32], szDB[128];
	
	get_pcvar_string( g_pcvar_mysqlx_host, szHost, charsmax( szHost ) );
	get_pcvar_string( g_pcvar_mysqlx_user, szUser, charsmax( szUser ) );
	get_pcvar_string( g_pcvar_mysqlx_pass, szPass, charsmax( szPass ) );
	get_pcvar_string( g_pcvar_mysqlx_db, szDB, charsmax( szDB ) );
	
	g_hTuple1 = SQL_MakeDbTuple( szHost, szUser, szPass, szDB );
	g_hTuple2 = SQL_MakeDbTuple( szHost, szUser, szPass, szDB );
	g_hTuple3 = SQL_MakeDbTuple( szHost, szUser, szPass, szDB );
	g_hTuple4 = SQL_MakeDbTuple( szHost, szUser, szPass, szDB );
	
	SQL_ThreadQuery( g_hTuple1, "QueryCreateTable", g_szTables[0])
	SQL_ThreadQuery( g_hTuple2, "QueryCreateTable", g_szTables[1])
	SQL_ThreadQuery( g_hTuple3, "QueryCreateTable", g_szTables[2])
	SQL_ThreadQuery( g_hTuple4, "QueryCreateTable", g_szTables[3])
}
public QueryCreateTable( iFailState, Handle:hQuery, szError[ ], iError, iData[ ], iDataSize, Float:fQueueTime ) 
{ 
	if( iFailState == TQUERY_CONNECT_FAILED 
	|| iFailState == TQUERY_QUERY_FAILED ) 
	{ 
		log_amx( "%s", szError ); 
		
		return;
	} 
}

SaveLevel(id)
{
	if ( g_iSaveType )//MySQLx
	{
		static szQuery[ 512 ];
		
		formatex( szQuery, 511, "REPLACE INTO `mytable1` (`player_id`, `player_credits`, `chal_0`, `chal_1`, `chal_2`, `chal_3`, `chal_4`, `chal_5`) VALUES ('%s', '%d', '%d', '%d', '%d', '%d', '%d', '%d');",
		g_szAuth[id] , g_iCredits[id],
		g_iChallengeStats[id][0], g_iChallengeStats[id][1],
		g_iChallengeStats[id][2], g_iChallengeStats[id][3],
		g_iChallengeStats[id][4], g_iChallengeStats[id][5],
		g_iChallengeStats[id][6], g_iChallengeStats[id][7],
		g_iChallengeStats[id][8], g_iChallengeStats[id][9],
		g_iChallengeStats[id][10], g_iChallengeStats[id][11],
		g_iChallengeStats[id][12], g_iChallengeStats[id][13],
		g_iChallengeStats[id][14], g_iChallengeStats[id][15],
		g_iChallengeStats[id][16], g_iChallengeStats[id][17],
		g_iChallengeStats[id][18], g_iChallengeStats[id][19],
		g_iChallengeStats[id][20], g_iChallengeStats[id][21],
		g_iChallengeStats[id][22], g_iChallengeStats[id][23],
		g_iChallengeStats[id][24]); 
		
		SQL_ThreadQuery( g_hTuple1, "QuerySetData", szQuery);
		
		formatex( szQuery, 511, "REPLACE INTO `mytable2` (`player_id`, `chal_6`, `chal_7`, `chal_8`, `chal_9`, `chal_10`, `chal_11`, `chal_12`) VALUES ('%s', '%d', '%d', '%d', '%d', '%d', '%d', '%d');",
		g_szAuth[id] , g_iCredits[id],
		g_iChallengeStats[id][0], g_iChallengeStats[id][1],
		g_iChallengeStats[id][2], g_iChallengeStats[id][3],
		g_iChallengeStats[id][4], g_iChallengeStats[id][5],
		g_iChallengeStats[id][6], g_iChallengeStats[id][7],
		g_iChallengeStats[id][8], g_iChallengeStats[id][9],
		g_iChallengeStats[id][10], g_iChallengeStats[id][11],
		g_iChallengeStats[id][12], g_iChallengeStats[id][13],
		g_iChallengeStats[id][14], g_iChallengeStats[id][15],
		g_iChallengeStats[id][16], g_iChallengeStats[id][17],
		g_iChallengeStats[id][18], g_iChallengeStats[id][19],
		g_iChallengeStats[id][20], g_iChallengeStats[id][21],
		g_iChallengeStats[id][22], g_iChallengeStats[id][23],
		g_iChallengeStats[id][24]); 
		
		SQL_ThreadQuery( g_hTuple2, "QuerySetData", szQuery);
		
		formatex( szQuery, 511, "REPLACE INTO `mytable3` (`player_id`, `chal_13`, `chal_14`, `chal_15`, `chal_16`, `chal_17`, `chal_18`, `chal_19`) VALUES ('%s', '%d', '%d', '%d', '%d', '%d', '%d', '%d');",
		g_szAuth[id] , g_iCredits[id],
		g_iChallengeStats[id][0], g_iChallengeStats[id][1],
		g_iChallengeStats[id][2], g_iChallengeStats[id][3],
		g_iChallengeStats[id][4], g_iChallengeStats[id][5],
		g_iChallengeStats[id][6], g_iChallengeStats[id][7],
		g_iChallengeStats[id][8], g_iChallengeStats[id][9],
		g_iChallengeStats[id][10], g_iChallengeStats[id][11],
		g_iChallengeStats[id][12], g_iChallengeStats[id][13],
		g_iChallengeStats[id][14], g_iChallengeStats[id][15],
		g_iChallengeStats[id][16], g_iChallengeStats[id][17],
		g_iChallengeStats[id][18], g_iChallengeStats[id][19],
		g_iChallengeStats[id][20], g_iChallengeStats[id][21],
		g_iChallengeStats[id][22], g_iChallengeStats[id][23],
		g_iChallengeStats[id][24]); 
		
		SQL_ThreadQuery( g_hTuple3, "QuerySetData", szQuery);
		
		formatex( szQuery, 511, "REPLACE INTO `mytable4` (`player_id`, `chal_20`, `chal_21`, `chal_22`, `chal_23`, `chal_24`) VALUES ('%s', '%d', '%d', '%d', '%d', '%d');",
		g_szAuth[id] , g_iCredits[id],
		g_iChallengeStats[id][0], g_iChallengeStats[id][1],
		g_iChallengeStats[id][2], g_iChallengeStats[id][3],
		g_iChallengeStats[id][4], g_iChallengeStats[id][5],
		g_iChallengeStats[id][6], g_iChallengeStats[id][7],
		g_iChallengeStats[id][8], g_iChallengeStats[id][9],
		g_iChallengeStats[id][10], g_iChallengeStats[id][11],
		g_iChallengeStats[id][12], g_iChallengeStats[id][13],
		g_iChallengeStats[id][14], g_iChallengeStats[id][15],
		g_iChallengeStats[id][16], g_iChallengeStats[id][17],
		g_iChallengeStats[id][18], g_iChallengeStats[id][19],
		g_iChallengeStats[id][20], g_iChallengeStats[id][21],
		g_iChallengeStats[id][22], g_iChallengeStats[id][23],
		g_iChallengeStats[id][24]); 
		
		SQL_ThreadQuery( g_hTuple4, "QuerySetData", szQuery);
	}
	else//nVault
	{
		new szData[512];
		new szKey[64];
			
		formatex( szKey , 63 , "%s-%s" , g_szAuth[id], g_szSaveMode);
		formatex( szData , 511 , "%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#" ,
		g_iCredits[id],
		g_iChallengeStats[id][0], g_iChallengeStats[id][1],
		g_iChallengeStats[id][2], g_iChallengeStats[id][3],
		g_iChallengeStats[id][4], g_iChallengeStats[id][5],
		g_iChallengeStats[id][6], g_iChallengeStats[id][7],
		g_iChallengeStats[id][8], g_iChallengeStats[id][9],
		g_iChallengeStats[id][10], g_iChallengeStats[id][11],
		g_iChallengeStats[id][12], g_iChallengeStats[id][13],
		g_iChallengeStats[id][14], g_iChallengeStats[id][15],
		g_iChallengeStats[id][16], g_iChallengeStats[id][17],
		g_iChallengeStats[id][18], g_iChallengeStats[id][19],
		g_iChallengeStats[id][20], g_iChallengeStats[id][21],
		g_iChallengeStats[id][22], g_iChallengeStats[id][23],
		g_iChallengeStats[id][24]); 
		
		nvault_set( g_Vault , szKey , szData );
		
		/*--------------------------------------------------------------------------------*/
		formatex( szKey , 63 , "%s-%s-UN" , g_szAuth[id], g_szSaveMode );
		formatex(szData , 511, "%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#",
		g_iGoal[id],
		g_iIsUnlocked[id][1],g_iIsUnlocked[id][2], g_iIsUnlocked[id][3],
		g_iIsUnlocked[id][4], g_iIsUnlocked[id][5],g_iIsUnlocked[id][6], g_iIsUnlocked[id][7],
		g_iIsUnlocked[id][8], g_iIsUnlocked[id][9],g_iIsUnlocked[id][10], g_iIsUnlocked[id][11],
		g_iIsUnlocked[id][12], g_iIsUnlocked[id][13],g_iIsUnlocked[id][14], g_iIsUnlocked[id][15],
		g_iIsUnlocked[id][16], g_iIsUnlocked[id][17],g_iIsUnlocked[id][18], g_iIsUnlocked[id][19],
		g_iIsUnlocked[id][20], g_iIsUnlocked[id][21],g_iIsUnlocked[id][22], g_iIsUnlocked[id][23],
		g_iIsUnlocked[id][24], g_iIsUnlocked[id][25],g_iIsUnlocked[id][26], g_iIsUnlocked[id][27],
		g_iIsUnlocked[id][28], g_iIsUnlocked[id][29],g_iIsUnlocked[id][30]);
	
		nvault_set( g_Vault , szKey , szData ); 
		
		/*--------------------------------------------------------------------------------*/
		formatex( szKey , 63 , "%s-%s-UP" , g_szAuth[id], g_szSaveMode );
		formatex(szData , 511, "%f#%f#%f#",
		g_fClassMultiplier[id][ATT_HEALTH], g_fClassMultiplier[id][ATT_SPEED], g_fClassMultiplier[id][ATT_GRAVITY]);
	}
}

LoadLevel(id)
{
	if ( g_iSaveType )//MySQLx
	{
		static szQuery[ 512 ], iData[ 1 ]; 
		
		//----------------------------------------------------------------------------------
		
		formatex( szQuery, 511, "SELECT 'player_credits`, `chal_0`, `chal_1`, `chal_2`, `chal_3`, `chal_4`, `chal_5` FROM `mytable1` WHERE ( `player_id` = '%s' );", g_szAuth[id] ); 
     
		iData[ 0 ] = id;
		SQL_ThreadQuery( g_hTuple1, "QuerySelectData1", szQuery, iData, 1 );
		
		//----------------------------------------------------------------------------------
		
		formatex( szQuery, 511, "SELECT `chal_6`, `chal_7`, `chal_8`, `chal_9`, `chal_10`, `chal_11`, `chal_12` FROM `mytable2` WHERE ( `player_id` = '%s' );", g_szAuth[id] ); 
     
		iData[ 0 ] = id;
		SQL_ThreadQuery( g_hTuple2, "QuerySelectData2", szQuery, iData, 1 );
		
		//----------------------------------------------------------------------------------
		
		formatex( szQuery, 511, "SELECT `chal_13`, `chal_14`, `chal_15`, `chal_16`, `chal_17`, `chal_18`, `chal_19` FROM `mytable3` WHERE ( `player_id` = '%s' );", g_szAuth[id] ); 
     
		iData[ 0 ] = id;
		SQL_ThreadQuery( g_hTuple3, "QuerySelectData3", szQuery, iData, 1 );
		
		//----------------------------------------------------------------------------------
		
		formatex( szQuery, 511, "SELECT `chal_20`, `chal_21`, `chal_22`, `chal_23`, `chal_24` FROM `mytable4` WHERE ( `player_id` = '%s' );", g_szAuth[id] ); 
     
		iData[ 0 ] = id;
		SQL_ThreadQuery( g_hTuple4, "QuerySelectData4", szQuery, iData, 1 );
	}
	else//nVault
	{
		new szData[512];
		new szKey[64];

		formatex( szKey , 63 , "%s-%s" , g_szAuth[id], g_szSaveMode );
		formatex(szData , 511, "%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#",
		g_iCredits[id],
		g_iChallengeStats[id][0], g_iChallengeStats[id][1],
		g_iChallengeStats[id][2], g_iChallengeStats[id][3],
		g_iChallengeStats[id][4], g_iChallengeStats[id][5],
		g_iChallengeStats[id][6], g_iChallengeStats[id][7],
		g_iChallengeStats[id][8], g_iChallengeStats[id][9],
		g_iChallengeStats[id][10], g_iChallengeStats[id][11],
		g_iChallengeStats[id][12], g_iChallengeStats[id][13],
		g_iChallengeStats[id][14], g_iChallengeStats[id][15],
		g_iChallengeStats[id][16], g_iChallengeStats[id][17],
		g_iChallengeStats[id][18], g_iChallengeStats[id][19],
		g_iChallengeStats[id][20], g_iChallengeStats[id][21],
		g_iChallengeStats[id][22], g_iChallengeStats[id][23],
		g_iChallengeStats[id][24]); 
			
		nvault_get(g_Vault, szKey, szData, 511) 

		replace_all(szData , 511, "#", " ")
		
		new credits[32], ColChal[sizeof g_szChallengeNames][16]
		parse(szData, credits, 31, ColChal[0], 15, ColChal[1], 15,
		ColChal[2], 15, ColChal[3], 15, 
		ColChal[4], 15, ColChal[5], 15, 
		ColChal[6], 15, ColChal[7], 15, 
		ColChal[8], 15, ColChal[9], 15, 
		ColChal[10], 15, ColChal[11], 15, 
		ColChal[12], 15, ColChal[13], 15, 
		ColChal[14], 15, ColChal[15], 15, 
		ColChal[16], 15, ColChal[17], 15, 
		ColChal[18], 15, ColChal[19], 15, 
		ColChal[20], 15, ColChal[21], 15, 
		ColChal[22], 15, ColChal[23], 15,
		ColChal[24], 15); 
		
		g_iCredits[id] = str_to_num(credits)
		
		for ( new i = 0; i < sizeof g_szChallengeNames; i++)
			g_iChallengeStats[id][i] = str_to_num(ColChal[i]);
	
		/*--------------------------------------------------------------------------------*/
		formatex( szKey , 63 , "%s-%s-UN" , g_szAuth[id], g_szSaveMode );
		formatex(szData , 511, "%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#%i#",
		g_iGoal[id],
		g_iIsUnlocked[id][0], g_iIsUnlocked[id][1],g_iIsUnlocked[id][2], g_iIsUnlocked[id][3],
		g_iIsUnlocked[id][4], g_iIsUnlocked[id][5],g_iIsUnlocked[id][6], g_iIsUnlocked[id][7],
		g_iIsUnlocked[id][8], g_iIsUnlocked[id][9],g_iIsUnlocked[id][10], g_iIsUnlocked[id][11],
		g_iIsUnlocked[id][12], g_iIsUnlocked[id][13],g_iIsUnlocked[id][14], g_iIsUnlocked[id][15],
		g_iIsUnlocked[id][16], g_iIsUnlocked[id][17],g_iIsUnlocked[id][18], g_iIsUnlocked[id][19],
		g_iIsUnlocked[id][20], g_iIsUnlocked[id][21],g_iIsUnlocked[id][22], g_iIsUnlocked[id][23],
		g_iIsUnlocked[id][24], g_iIsUnlocked[id][25],g_iIsUnlocked[id][26], g_iIsUnlocked[id][27],
		g_iIsUnlocked[id][28], g_iIsUnlocked[id][29],g_iIsUnlocked[id][30]);
		
		nvault_get(g_Vault, szKey, szData, 511) 

		replace_all(szData , 511, "#", " ")
		
		new goal[32], ColUnlock[31][3]
		parse(szData, goal, 31, ColUnlock[1], 2, ColUnlock[2], 2, ColUnlock[3], 2,
		ColUnlock[4], 2, ColUnlock[5], 2, ColUnlock[6], 2, ColUnlock[7], 2, ColUnlock[8], 2,
		ColUnlock[9], 2, ColUnlock[10], 2, ColUnlock[11], 2, ColUnlock[12], 2, ColUnlock[13], 2,
		ColUnlock[14], 2, ColUnlock[15], 2, ColUnlock[16], 2, ColUnlock[17], 2, ColUnlock[18], 2,
		ColUnlock[19], 2, ColUnlock[20], 2, ColUnlock[21], 2, ColUnlock[22], 2, ColUnlock[23], 2,
		ColUnlock[24], 2, ColUnlock[25], 2, ColUnlock[26], 2, ColUnlock[27], 2, ColUnlock[28], 2,
		ColUnlock[29], 2, ColUnlock[30], 2); 
		
		g_iGoal[id] = str_to_num(goal)
		
		for ( new i = 1; i < 31; i++)
			g_iIsUnlocked[id][i] = str_to_num(ColUnlock[i]);
			
		/*--------------------------------------------------------------------------------*/
		formatex( szKey , 63 , "%s-%s-UP" , g_szAuth[id], g_szSaveMode );
		formatex(szData , 511, "%f#%f#%f#",
		g_fClassMultiplier[id][ATT_HEALTH], g_fClassMultiplier[id][ATT_SPEED], g_fClassMultiplier[id][ATT_GRAVITY]);
		
		nvault_get(g_Vault, szKey, szData, 511) 

		replace_all(szData , 511, "#", " ")
		
		new ColUpgrade[3][32]
		parse(szData, ColUpgrade[ATT_HEALTH], 31, ColUpgrade[ATT_SPEED], 31, ColUpgrade[ATT_GRAVITY], 31)
		
		//for ( new i = 0; i < 3; i++)
			//task_SetMultiplier(id, i, str_to_float(ColUpgrade[i]))
	}
	
	g_iIsUnlocked[id][CSW_P228] = 1
	g_iIsUnlocked[id][CSW_SG552] = 1
	
	//for ( new i = 0; i < 3; i++) bb_set_user_mult(id, i, g_fClassMultiplier[id][i])
}

/*public task_SetMultiplier(id, attribute, Float:amount)
{
	g_fClassMultiplier[id][attribute] = amount
	bb_set_user_mult(id, attribute, amount)
}*/

public QuerySelectData1( iFailState, Handle:hQuery, szError[ ], iError, iData[ ], iDataSize, Float:fQueueTime ) 
{ 
	if( iFailState == TQUERY_CONNECT_FAILED 
	|| iFailState == TQUERY_QUERY_FAILED ) 
	{ 
		log_amx( "%s", szError );
		
		return;
	} 
	else 
	{ 
		new id = iData[ 0 ];
		new ColChal[sizeof g_szChallengeNames]
		
		new ColCredits = SQL_FieldNameToNum(hQuery, "player_credits") 
		ColChal[0] = SQL_FieldNameToNum(hQuery, "chal_0")
		ColChal[1] = SQL_FieldNameToNum(hQuery, "chal_1")
		ColChal[2] = SQL_FieldNameToNum(hQuery, "chal_2")
		ColChal[3] = SQL_FieldNameToNum(hQuery, "chal_3")
		ColChal[4] = SQL_FieldNameToNum(hQuery, "chal_4")
		ColChal[5] = SQL_FieldNameToNum(hQuery, "chal_5")
		
		while (SQL_MoreResults(hQuery)) 
		{
			g_iCredits[id] = SQL_ReadResult(hQuery, ColCredits);
			for ( new i = 0; i <= 5; i++)
				g_iChallengeStats[id][i] = SQL_ReadResult(hQuery, ColChal[i]);
					
			SQL_NextRow(hQuery)
		}
	} 
}

public QuerySelectData2( iFailState, Handle:hQuery, szError[ ], iError, iData[ ], iDataSize, Float:fQueueTime ) 
{ 
	if( iFailState == TQUERY_CONNECT_FAILED 
	|| iFailState == TQUERY_QUERY_FAILED ) 
	{ 
		log_amx( "%s", szError );
		
		return;
	} 
	else 
	{ 
		new id = iData[ 0 ];
		new ColChal[sizeof g_szChallengeNames]
		
		ColChal[6] = SQL_FieldNameToNum(hQuery, "chal_6")
		ColChal[7] = SQL_FieldNameToNum(hQuery, "chal_7")
		ColChal[8] = SQL_FieldNameToNum(hQuery, "chal_8")
		ColChal[9] = SQL_FieldNameToNum(hQuery, "chal_9")
		ColChal[10] = SQL_FieldNameToNum(hQuery, "chal_10")
		ColChal[11] = SQL_FieldNameToNum(hQuery, "chal_11")
		ColChal[12] = SQL_FieldNameToNum(hQuery, "chal_12")
		
		while (SQL_MoreResults(hQuery)) 
		{
			for ( new i = 6; i <= 12; i++)
				g_iChallengeStats[id][i] = SQL_ReadResult(hQuery, ColChal[i]);
					
			SQL_NextRow(hQuery)
		}
	} 
}

public QuerySelectData3( iFailState, Handle:hQuery, szError[ ], iError, iData[ ], iDataSize, Float:fQueueTime ) 
{ 
	if( iFailState == TQUERY_CONNECT_FAILED 
	|| iFailState == TQUERY_QUERY_FAILED ) 
	{ 
		log_amx( "%s", szError );
		
		return;
	} 
	else 
	{ 
		new id = iData[ 0 ];
		new ColChal[sizeof g_szChallengeNames]
		
		ColChal[13] = SQL_FieldNameToNum(hQuery, "chal_13")
		ColChal[14] = SQL_FieldNameToNum(hQuery, "chal_14")
		ColChal[15] = SQL_FieldNameToNum(hQuery, "chal_15")
		ColChal[16] = SQL_FieldNameToNum(hQuery, "chal_16")
		ColChal[17] = SQL_FieldNameToNum(hQuery, "chal_17")
		ColChal[18] = SQL_FieldNameToNum(hQuery, "chal_18")
		ColChal[19] = SQL_FieldNameToNum(hQuery, "chal_19")
		
		while (SQL_MoreResults(hQuery)) 
		{
			for ( new i = 13; i <= 19; i++)
				g_iChallengeStats[id][i] = SQL_ReadResult(hQuery, ColChal[i]);
					
			SQL_NextRow(hQuery)
		}
	} 
}

public QuerySelectData4( iFailState, Handle:hQuery, szError[ ], iError, iData[ ], iDataSize, Float:fQueueTime ) 
{ 
	if( iFailState == TQUERY_CONNECT_FAILED 
	|| iFailState == TQUERY_QUERY_FAILED ) 
	{ 
		log_amx( "%s", szError );
		
		return;
	} 
	else 
	{ 
		new id = iData[ 0 ];
		new ColChal[sizeof g_szChallengeNames]
		
		ColChal[20] = SQL_FieldNameToNum(hQuery, "chal_20")
		ColChal[21] = SQL_FieldNameToNum(hQuery, "chal_21")
		ColChal[22] = SQL_FieldNameToNum(hQuery, "chal_22")
		ColChal[23] = SQL_FieldNameToNum(hQuery, "chal_23")
		ColChal[24] = SQL_FieldNameToNum(hQuery, "chal_24")
		
		while (SQL_MoreResults(hQuery)) 
		{
			for ( new i = 20; i < 24; i++)
				g_iChallengeStats[id][i] = SQL_ReadResult(hQuery, ColChal[i]);
					
			SQL_NextRow(hQuery)
		}
	} 
}

public QuerySetData( iFailState, Handle:hQuery, szError[ ], iError, iData[ ], iDataSize, Float:fQueueTime ) 
{ 
	if( iFailState == TQUERY_CONNECT_FAILED 
	|| iFailState == TQUERY_QUERY_FAILED ) 
	{ 
		log_amx( "%s", szError ); 
		
		return;
	} 
} 

public cmdGiveCredits(id)
{
	if(!access(id,FLAGS_CREDITS))
		return PLUGIN_HANDLED
		
	new target[32],points[21]
    	read_argv(1,target,31)
    	read_argv(2,points,20)
	
	new player = cmd_target(id,target,8)
    	if(!player) return PLUGIN_HANDLED 
	
	new szPlayerName[32]
    	get_user_name(player, szPlayerName,31)
	
	new credits = str_to_num(points)
	
	g_iCredits[player]+=credits
	SaveLevel(player)
	client_print(id,print_console,"[Credits] You have added %i credits to %s's total credits", credits, szPlayerName)
	print_color(player, "%s An admin has given you^x04 %d^x01 credits", MODNAME, credits)
	
	return PLUGIN_CONTINUE
}

public native_get_user_credits(id)
{
	return g_iCredits[id]
}

public native_set_user_credits(id, credits)
{
	g_iCredits[id] = credits
	return g_iCredits[id]
}

public native_add_user_credits(id, credits)
{
	g_iCredits[id] += credits
	return g_iCredits[id]
}

public native_subtract_user_credits(id, credits)
{
	g_iCredits[id] -= credits
	return g_iCredits[id]
}

public native_get_user_goal(id)
{
	return g_iGoal[id]
}

public native_set_user_goal(id, credits)
{
	g_iGoal[id] = credits
	return g_iGoal[id]
}

public native_show_unlocksmenu(id)
{
	show_unlocks_menu(id)
}

public native_show_gunsmenu(id)
{
	show_weapons_menu(id)
}
