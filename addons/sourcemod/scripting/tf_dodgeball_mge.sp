#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required

// ====[ INCLUDES ]====================================================
#include <entity_prop_stocks>
#include <morecolors>
#include <sdktools>
#include <sdkhooks>
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
// ====[ CONSTANTS ]===================================================
#define PLUGIN_VERSION "1.0.0"
#define MAX_FILE_LEN 80
#define MAXARENAS 31
#define MAXSPAWNS 15
#define HUDFADEOUTTIME 120.0
#define SLOT_ONE 1 //arena slot 1
#define SLOT_TWO 2 //arena slot 2
#define SLOT_THREE 3 //arena slot 3
#define SLOT_FOUR 4 //arena slot 4
// TFDB General
#define FPS_LOGIC_RATE 20.0
#define FPS_LOGIC_INTERVAL 1.0 / FPS_LOGIC_RATE
// TFDB Maximum Structs
#define MAX_ROCKETS 100
#define MAX_ROCKET_CLASSES 50
#define MAX_ROCKET_SPAWNER_CLASSES 50
#define MAX_ROCKET_SPAWN_POINTS 100
//tf teams
#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLU 3
#define NEUTRAL 1
//arena status
#define AS_IDLE 0
#define AS_PRECOUNTDOWN 1
#define AS_COUNTDOWN 2
#define AS_FIGHT 3
#define AS_AFTERFIGHT 4
#define AS_REPORTED 5
//sounds
#define STOCK_SOUND_COUNT 24
//
#define DEFAULT_CDTIME 3

// Pyrovision
#define PYROVISION_ATTRIBUTE "vision opt in flags"
// Rocket bounce
#define	MAX_EDICT_BITS 11
#define	MAX_EDICTS (1 << MAX_EDICT_BITS)
// Flags & types
enum Musics
{
	Music_RoundStart,
	Music_RoundWin,
	Music_RoundLose,
	Music_Gameplay,
	SizeOfMusicsArray
};

enum BehaviourTypes
{
	Behaviour_Unknown,
	Behaviour_Homing
};

enum DragTypes
{
	DragType_Aim, 
	DragType_Direction
};

enum RocketFlags
{
	RocketFlag_None = 0,
	RocketFlag_PlaySpawnSound = 1 << 0,
	RocketFlag_PlayBeepSound = 1 << 1,
	RocketFlag_PlayAlertSound = 1 << 2,
	RocketFlag_ElevateOnDeflect = 1 << 3,
	RocketFlag_IsNeutral = 1 << 4,
	RocketFlag_Exploded = 1 << 5,
	RocketFlag_OnSpawnCmd = 1 << 6,
	RocketFlag_OnDeflectCmd = 1 << 7,
	RocketFlag_OnKillCmd = 1 << 8,
	RocketFlag_OnExplodeCmd = 1 << 9,
	RocketFlag_CustomModel = 1 << 10,
	RocketFlag_CustomSpawnSound = 1 << 11,
	RocketFlag_CustomBeepSound = 1 << 12,
	RocketFlag_CustomAlertSound = 1 << 13,
	RocketFlag_Elevating = 1 << 14,
	RocketFlag_IsAnimated = 1 << 15
};

enum RocketSound
{
	RocketSound_Spawn,
	RocketSound_Beep,
	RocketSound_Alert
};

enum SpawnerFlags
{
	SpawnerFlag_Team_Red = 1,
	SpawnerFlag_Team_Blu = 2,
	SpawnerFlag_Team_Both = 3
};

#define TestFlags(%1,%2)	(!!((%1) & (%2)))
#define TestFlagsAnd(%1,%2) (((%1) & (%2)) == %2)

// TFDB Sounds & Particles
#define SOUND_DEFAULT_SPAWN				"weapons/sentry_rocket.wav"
#define SOUND_DEFAULT_BEEP				"weapons/sentry_scan.wav"
#define SOUND_DEFAULT_ALERT				"weapons/sentry_spot.wav"
#define SOUND_DEFAULT_SPEEDUPALERT		"misc/doomsday_lift_warning.wav"
#define SNDCHAN_MUSIC					32
#define PARTICLE_NUKE_1					"fireSmokeExplosion"
#define PARTICLE_NUKE_2					"fireSmokeExplosion1"
#define PARTICLE_NUKE_3					"fireSmokeExplosion2"
#define PARTICLE_NUKE_4					"fireSmokeExplosion3"
#define PARTICLE_NUKE_5					"fireSmokeExplosion4"
#define PARTICLE_NUKE_COLLUMN			"fireSmoke_collumnP"
#define PARTICLE_NUKE_1_ANGLES			view_as<float> ({270.0, 0.0, 0.0})
#define PARTICLE_NUKE_2_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_3_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_4_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_5_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_COLLUMN_ANGLES	PARTICLE_NUKE_1_ANGLES

// Debug
//#define DEBUG
//#define DEBUG_LOG

// ====[ TFDB VARIABLES ]===================================================
// Handle, String, Float, Bool, NUM, TFCT

// CVars
Handle g_hCvarSpeedo;
Handle g_hCvarAnnounce;
Handle g_hCvarPyroVisionEnabled = INVALID_HANDLE;
Handle g_hCvarDeflectCountAnnounce;
Handle g_hCvarRedirectBeep;
Handle g_hMaxBouncesConVar;
Handle g_hCvarDelayPrevention;
Handle g_hCvarDelayPreventionTime;
Handle g_hCvarDelayPreventionSpeedup;

// Gameplay
int g_iRocketsFired[MAXARENAS + 1]; // No. of rockets fired since round start
Handle g_hLogicTimer; // Logic timer
float g_fLastRocketSpawnTime[MAXARENAS + 1]; // Time at which the last rocket had spawned
float g_fNextRocketSpawnTime[MAXARENAS + 1]; // Time at which the next rocket will be able to spawn
int g_iLastDeadTeam[MAXARENAS + 1]; // The team of the last dead client. If none, it's a random team.
int g_iLastDeadClient[MAXARENAS + 1]; // The last dead client. If none, it's a random client.
int g_iPlayerCount[MAXARENAS + 1];
Handle g_hHud;
int g_iRocketSpeed[MAXARENAS + 1];
Handle g_hTimerHud;
int g_nBounces[MAX_EDICTS];
int g_config_iMaxBounces = 2;

// Structs
bool g_bRocketIsValid[MAX_ROCKETS];
bool g_bRocketIsNuke[MAX_ROCKETS];
bool g_bPreventingDelay;
int g_iRocketEntity[MAX_ROCKETS];
int g_iRocketTarget[MAX_ROCKETS];
int g_iRocketSpawner[MAX_ROCKETS];
int g_iRocketClass[MAX_ROCKETS];
RocketFlags g_iRocketFlags[MAX_ROCKETS];
DragTypes g_iRocketDragType[MAX_ROCKETS];
float g_fRocketSpeed[MAX_ROCKETS];
float g_fRocketDirection[MAX_ROCKETS][3];
int g_iRocketDeflections[MAX_ROCKETS];
float g_fRocketLastDeflectionTime[MAX_ROCKETS];
float g_fRocketLastBeepTime[MAX_ROCKETS];
int g_iLastCreatedRocket;
int g_iRocketCount;

// Classes
char g_strRocketClassName[MAX_ROCKET_CLASSES][16];
char g_strRocketClassLongName[MAX_ROCKET_CLASSES][32];
char g_strSavedClassName[32];
BehaviourTypes g_iRocketClassBehaviour[MAX_ROCKET_CLASSES];
char g_strRocketClassModel[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
RocketFlags g_iRocketClassFlags[MAX_ROCKET_CLASSES];
float g_fRocketClassBeepInterval[MAX_ROCKET_CLASSES];
char g_strRocketClassSpawnSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
char g_strRocketClassBeepSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
char g_strRocketClassAlertSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
float g_fRocketClassCritChance[MAX_ROCKET_CLASSES];
float g_fRocketClassDamage[MAX_ROCKET_CLASSES];
float g_fRocketClassDamageIncrement[MAX_ROCKET_CLASSES];
float g_fRocketClassSpeed[MAX_ROCKET_CLASSES];
float g_fRocketClassSpeedIncrement[MAX_ROCKET_CLASSES];
float g_fRocketClassTurnRate[MAX_ROCKET_CLASSES];
float g_fRocketClassTurnRateIncrement[MAX_ROCKET_CLASSES];
float g_fRocketClassElevationRate[MAX_ROCKET_CLASSES];
float g_fRocketClassElevationLimit[MAX_ROCKET_CLASSES];
float g_fRocketClassRocketsModifier[MAX_ROCKET_CLASSES];
float g_fRocketClassPlayerModifier[MAX_ROCKET_CLASSES];
float g_fRocketClassControlDelay[MAX_ROCKET_CLASSES];
DragTypes g_iRocketClassDragType[MAX_ROCKET_CLASSES];
float g_fRocketClassTargetWeight[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnSpawn[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnDeflect[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnKill[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnExplode[MAX_ROCKET_CLASSES];
Handle g_hRocketClassTrie;
char g_iRocketClassCount;

// Spawner classes
char g_strRocketSpawnersName[MAX_ROCKET_SPAWNER_CLASSES][32];
int g_iSpawnersMaxRockets[MAX_ROCKET_SPAWNER_CLASSES];
float g_fRocketSpawnersInterval[MAX_ROCKET_SPAWNER_CLASSES];
Handle g_hRocketSpawnersChancesTable[MAX_ROCKET_SPAWNER_CLASSES];
Handle g_hRocketSpawnersTrie;
int g_iRocketSpawnersCount;

// Array containing the spawn points for the Red team, and
// their associated spawner class.
int g_iCurrentRedRocketSpawn[MAXARENAS + 1];
int g_iRocketSpawnPointsRedCount[MAXARENAS + 1];
int g_iRocketSpawnPointsRedClass[MAX_ROCKET_SPAWN_POINTS / (MAXARENAS + 1)][MAXARENAS + 1];
int g_iRocketSpawnPointsRedEntity[MAX_ROCKET_SPAWN_POINTS / (MAXARENAS + 1)][MAXARENAS + 1];

// Array containing the spawn points for the Blu team, and
// their associated spawner class.
int g_iCurrentBluRocketSpawn[MAXARENAS + 1];
int g_iRocketSpawnPointsBluCount[MAXARENAS + 1];
int g_iRocketSpawnPointsBluClass[MAX_ROCKET_SPAWN_POINTS / (MAXARENAS + 1)][MAXARENAS + 1];
int g_iRocketSpawnPointsBluEntity[MAX_ROCKET_SPAWN_POINTS / (MAXARENAS + 1)][MAXARENAS + 1];

// The default spawner class.
int g_iDefaultRedRocketSpawner;
int g_iDefaultBluRocketSpawner;

// ====[ MGE VARIABLES ]===================================================

// HUD Handles
Handle 
	hm_HP,
	hm_Score,
	hm_TeammateHP;

// Global Variables
char g_sMapName[64],
	 g_arenaFile[128];
	 
bool g_bAutoCvar;

int g_iDefaultTeamSize,
	g_iDefaultFragLimit;

// Global CVar Handles
ConVar 
	gcvar_WfP,
	gcvar_maxTeamSize,
	gcvar_fragLimit,
	gcvar_autoCvar,
	gcvar_arenaFile;

// Arena Vars
Handle g_tKothTimer[MAXARENAS + 1];
char g_sArenaName[MAXARENAS + 1][64];

float 
	g_fArenaSpawnOrigin[MAXARENAS + 1][MAXSPAWNS+1][3],
	g_fArenaSpawnAngles[MAXARENAS + 1][MAXSPAWNS+1][3],
	g_fArenaRocketMinimum[MAXARENAS + 1][3],
	g_fArenaRocketMaximum[MAXARENAS + 1][3],
	g_fArenaHPRatio[MAXARENAS + 1],
	g_fArenaMinSpawnDist[MAXARENAS + 1],
	g_fArenaRespawnTime[MAXARENAS + 1],
	g_fTotalTime[MAXARENAS + 1];

bool 
	g_bFourPersonArena[MAXARENAS + 1],
	g_bArenaShowHPToPlayers[MAXARENAS + 1],
	g_bTimerRunning[MAXARENAS + 1];

int 
	g_iArenaCount,
	g_iArenaScore[MAXARENAS + 1][3],
	g_iArenaQueue[MAXARENAS + 1][MAXPLAYERS + 1],
	g_iArenaStatus[MAXARENAS + 1],
	g_iArenaCd[MAXARENAS + 1],//countdown to round start
	g_iArenaMaxTeamSize[MAXARENAS + 1],
	g_iArenaFraglimit[MAXARENAS + 1],
	g_iArenaCdTime[MAXARENAS + 1],
	g_iArenaSpawns[MAXARENAS + 1],
	g_iArenaEarlyLeave[MAXARENAS + 1];

// Player vars
Handle g_hWelcomeTimer[MAXPLAYERS + 1];

bool 
	g_bHitBlip[MAXPLAYERS + 1],
	g_bShowHud[MAXPLAYERS + 1] = true,
	g_iPlayerWaiting[MAXPLAYERS + 1];
	
int 
	g_iPlayerArena[MAXPLAYERS + 1],
	g_iPlayerSlot[MAXPLAYERS + 1],
	g_iPlayerHP[MAXPLAYERS + 1], //true HP of players
	g_iPlayerSpecTarget[MAXPLAYERS + 1],
	g_iPlayerMaxHP[MAXPLAYERS + 1];

// Bot things
bool g_bPlayerAskedForBot[MAXPLAYERS + 1];

// Debug log
char g_sLogFile[PLATFORM_MAX_PATH];

static const char stockSounds[][] =  // Sounds that do not need to be downloaded.
{
	"vo/intel_teamcaptured.wav", 
	"vo/intel_teamdropped.wav", 
	"vo/intel_teamstolen.wav", 
	"vo/intel_enemycaptured.wav", 
	"vo/intel_enemydropped.wav", 
	"vo/intel_enemystolen.wav", 
	"vo/announcer_ends_5sec.wav", 
	"vo/announcer_ends_4sec.wav", 
	"vo/announcer_ends_3sec.wav", 
	"vo/announcer_ends_2sec.wav", 
	"vo/announcer_ends_1sec.wav", 
	"vo/announcer_ends_10sec.wav", 
	"vo/announcer_control_point_warning.wav", 
	"vo/announcer_control_point_warning2.wav", 
	"vo/announcer_control_point_warning3.wav", 
	"vo/announcer_overtime.wav", 
	"vo/announcer_overtime2.wav", 
	"vo/announcer_overtime3.wav", 
	"vo/announcer_overtime4.wav", 
	"vo/announcer_we_captured_control.wav", 
	"vo/announcer_we_lost_control.wav", 
	"items/spawn_item.wav", 
	"vo/announcer_victory.wav", 
	"vo/announcer_you_failed.wav"
};

public Plugin myinfo =
{
	name = "TFDBMGE",
	author = "Soul, an edited and combined YADP & MGEMod.",
	description = "Duel mod with realistic game situations from the TF2 gamemode Dodgeball.",
	version = PLUGIN_VERSION
}
/*
** ------------------------------------------------------------------
**	   ____           ______                  __  _                  
**	  / __ \____     / ____/__  ______  _____/ /_(_)____  ____  _____
**	 / / / / __ \   / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
**	/ /_/ / / / /  / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  ) 
**	\____/_/ /_/  /_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/  
**
** ------------------------------------------------------------------
**/

/* OnPluginStart()
 *
 * When the plugin is loaded.
 * Cvars, variables, and console commands are initialzed here.
 * -------------------------------------------------------------------------- */
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("tfdbmge.phrases");
	
	//TFDB ConVars
	g_hCvarSpeedo = CreateConVar("tf_dodgeball_speedo", "1", "Enable HUD speedometer");
	g_hCvarAnnounce = CreateConVar("tf_dodgeball_announce", "1", "Enable kill announces in chat");
	g_hCvarPyroVisionEnabled = CreateConVar("tf_dodgeball_pyrovision", "0", "Enable pyrovision for everyone");
	g_hMaxBouncesConVar = CreateConVar("tf_dodgeball_rbmax", "10000", "Max number of times a rocket will bounce.", FCVAR_NONE, true, 0.0, false);
	g_hCvarDeflectCountAnnounce = CreateConVar("tf_dodgeball_count_deflect", "1", "Enable number of deflections in kill announce");
	g_hCvarRedirectBeep = CreateConVar("tf_dodgeball_rdrbeep", "1", "Do redirects beep?");
	
	g_hCvarDelayPrevention = CreateConVar("tf_dodgeball_delay_prevention", "0", "Enable delay prevention?");
	g_hCvarDelayPreventionTime = CreateConVar("tf_dodgeball_dp_time", "5", "How much time (in seconds) before delay prevention activates?", FCVAR_NONE, true, 0.0, false);
	g_hCvarDelayPreventionSpeedup = CreateConVar("tf_dodgeball_dp_speedup", "100", "How much speed (in hammer units per second) should the rocket gain (20 Refresh Rate for every 0.1 seconds) for delay prevention? Multiply by (15/352) for mph.", FCVAR_NONE, true, 0.0, false);
	
	// MGE ConVars
	CreateConVar("tfdbmge_version", PLUGIN_VERSION, "TFDBMGE version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	gcvar_maxTeamSize = CreateConVar("tfdb_teamsize", "1", "Default number of players to spawn for each team in an arena.");
	gcvar_fragLimit = CreateConVar("tfdbmge_fraglimit", "3", "Default frag limit in duel", FCVAR_NONE, true, 1.0);
	gcvar_autoCvar = CreateConVar("tfdbmge_autocvar", "1", "Automatically set reccomended game cvars? (0 = Disabled)", FCVAR_NONE, true, 0.0, true, 1.0);
	gcvar_WfP = FindConVar("mp_waitingforplayers_cancel");
	gcvar_arenaFile = CreateConVar("tfdbmge_arenafile", "configs/tfdbmge_arenas.cfg", "Arenas config file");
	
	// Populate global variables with their corresponding convar values.
	g_iDefaultTeamSize = gcvar_maxTeamSize.IntValue;
	g_iDefaultFragLimit = gcvar_fragLimit.IntValue;
	g_bAutoCvar = gcvar_autoCvar.IntValue ? true : false;
	
	gcvar_arenaFile.GetString(g_arenaFile, sizeof(g_arenaFile));
	
	for (int i = 0; i < MAXARENAS + 1; ++i)
	{
		g_bTimerRunning[i] = false;
		g_fTotalTime[i] = 0.0;
	}
	
	// Hook convar changes.
	gcvar_arenaFile.AddChangeHook(handler_ConVarChange);
	gcvar_maxTeamSize.AddChangeHook(handler_ConVarChange);
	gcvar_fragLimit.AddChangeHook(handler_ConVarChange);
	gcvar_autoCvar.AddChangeHook(handler_ConVarChange);
	
	HookConVarChange(g_hMaxBouncesConVar, tf2dodgeball_hooks);
	HookConVarChange(g_hCvarPyroVisionEnabled, tf2dodgeball_hooks);
	
	// Create/register client commands.
	RegConsoleCmd("tfdbmge", Command_Menu, "TFDBMGE Menu");
	RegConsoleCmd("add", Command_Menu, "Usage: add <arena number/arena name>. Add to an arena.");
	RegConsoleCmd("remove", Command_Remove, "Remove from current arena.");
	RegConsoleCmd("hitblip", Command_ToogleHitblip, "Toggle hitblip.");
	RegConsoleCmd("hud", Command_ToggleHud, "Toggle text hud.");
	RegConsoleCmd("hidehud", Command_ToggleHud, "Toggle text hud. (alias)");
	RegConsoleCmd("mgehelp", Command_Help);
	RegConsoleCmd("first", Command_First, "Join the first available arena.");
	RegConsoleCmd("spec_next", Command_Spec);
	RegConsoleCmd("spec_prev", Command_Spec);
	RegAdminCmd("sm_tfdb", Command_DodgeballAdminMenu, ADMFLAG_GENERIC, "A menu for admins to modify things inside the plugin.");
	RegAdminCmd("loc", Command_Loc, ADMFLAG_BAN, "Shows client origin and angle vectors");
	RegAdminCmd("botme", Command_AddBot, ADMFLAG_BAN, "Add bot to your arena");
	
	g_hRocketClassTrie = CreateTrie();
	g_hRocketSpawnersTrie = CreateTrie();
	
	// Create the HUD text handles for later use.
	hm_HP = CreateHudSynchronizer();
	hm_Score = CreateHudSynchronizer();
	hm_TeammateHP = CreateHudSynchronizer();
	g_hHud = CreateHudSynchronizer();
	
	AutoExecConfig(true, "tf2_dodgeball");
	
	// Set up the log file for debug logging.
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/tfdbmge.log");
	
	/*	This is here in the event of the plugin being hot-loaded while players are in the server.
		Should probably delete this, as the rest of the code doesn't really support hot-loading. */
		
	PrintToChatAll("[TFDBMGE] Plugin reloaded. Slaying all players to avoid bugs.");
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i))
		{
			ForcePlayerSuicide(i);
			OnClientPostAdminCheck(i);
		}
	}
}

/* OnGetGameDescription(String:gameDesc[64])
 *
 * Used to change the game description from
 * "Team Fortress 2" to "TFDBMGE vx.x.x"
 * -------------------------------------------------------------------------- */
public Action OnGetGameDescription(char gameDesc[64])
{
	Format(gameDesc, sizeof(gameDesc), "TFDBMGE v%s", PLUGIN_VERSION);
	return Plugin_Changed;
}

/* OnMapStart()
*
* When the map starts.
* Sounds, models, and spawns are loaded here.
* Most events are hooked here as well.
* -------------------------------------------------------------------------- */
public void OnMapStart()
{
	for (int i = 0; i < STOCK_SOUND_COUNT; i++)/* Stock sounds are considered mandatory. */
	PrecacheSound(stockSounds[i], true);
	
	// Spawns
	int isMapAm = LoadPlayerSpawnPoints();
	if (isMapAm)
	{
		EnableDodgeball();
		
		CreateTimer(1.0, Timer_SpecHudToAllArenas, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		
		if (g_bAutoCvar)
		{
			/*	TFDBMGE often creates situtations where the number of players on RED and BLU will be uneven.
			If the server tries to force a player to a different team due to autobalance being on, it will interfere with TFDBMGE's queue system.
			These cvar settings are considered mandatory for TFDBMGE. */
			ServerCommand("mp_autoteambalance 0");
			ServerCommand("mp_teams_unbalance_limit 32");
			ServerCommand("mp_tournament 0");
			LogMessage("AutoCvar: Setting mp_autoteambalance 0, mp_teams_unbalance_limit 32, & mp_tournament 0");
		}
		
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
		HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
		HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
	} else {
		SetFailState("Map not supported. TFDBMGE disabled.");
	}
	
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		g_iPlayerWaiting[i] = false;
		
	}
	
	for (int i = 0; i < MAXARENAS; i++)
	{
		g_bTimerRunning[i] = false;
		g_fTotalTime[i] = 0.0;
	}
}

/* OnMapEnd()
 *
 * When the map ends.
 * Repeating timers can be killed here.
 * Hooks are removed here.
 * -------------------------------------------------------------------------- */
public void OnMapEnd()
{
	DisableDodgeball();
	
	UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	UnhookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	UnhookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
	
	for (int arena_index = 1; arena_index <= g_iArenaCount; arena_index++)
	{
		if (g_bTimerRunning[arena_index])
		{
			g_bTimerRunning[arena_index] = false;
		}
	}
}

/* OnClientPostAdminCheck(client)
 *
 * Called once a client is authorized and fully in-game.
 * Client-specific variables are initialized here.
 * -------------------------------------------------------------------------- */
public void OnClientPostAdminCheck(int client)
{
	if (client)
	{
		if (IsFakeClient(client))
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (g_bPlayerAskedForBot[i])
				{
					int arena_index = g_iPlayerArena[i];
					DataPack pk;
					CreateDataTimer(1.5, Timer_AddBotInQueue, pk);
					pk.WriteCell(GetClientUserId(client));
					pk.WriteCell(arena_index);
					g_bPlayerAskedForBot[i] = false;
					break;
				}
			}
		} else {
			CreateTimer(5.0, Timer_ShowAdv, GetClientUserId(client)); /* Show advice to type !add in chat */
			g_bHitBlip[client] = false;
			g_bShowHud[client] = true;
			g_hWelcomeTimer[client] = CreateTimer(15.0, Timer_WelcomePlayer, GetClientUserId(client));
		}
	}
}

/* OnClientDisconnect(client)
*
* When a client disconnects from the server.
* Client-specific timers are killed here.
* -------------------------------------------------------------------------- */
public void OnClientDisconnect(int client)
{
	if (IsValidClient(client, /* ignoreKickQueue */ true) && g_iPlayerArena[client])
	{
		RemoveFromQueue(client, true);
	}
	else
	{
		int 
			arena_index = g_iPlayerArena[client], 
			player_slot = g_iPlayerSlot[client], 
			after_leaver_slot = player_slot + 1, 
			foe_slot = (player_slot == SLOT_ONE || player_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE, 
			foe = g_iArenaQueue[arena_index][foe_slot];
		
		//Turn all this logic into a helper meathod	
		int player_teammate, foe2;
		
		if (g_bFourPersonArena[arena_index])
		{
			player_teammate = getTeammate(client, player_slot, arena_index);
			foe2 = getTeammate(foe, foe_slot, arena_index);
		}
		
		g_iPlayerArena[client] = 0;
		g_iPlayerSlot[client] = 0;
		g_iArenaQueue[arena_index][player_slot] = 0;
		
		if (g_bFourPersonArena[arena_index])
		{
			if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
			{
				int next_client = g_iArenaQueue[arena_index][SLOT_FOUR + 1];
				g_iArenaQueue[arena_index][SLOT_FOUR + 1] = 0;
				g_iArenaQueue[arena_index][player_slot] = next_client;
				g_iPlayerSlot[next_client] = player_slot;
				after_leaver_slot = SLOT_FOUR + 2;
				char playername[MAX_NAME_LENGTH];
				CreateTimer(2.0, Timer_StartDuel, arena_index);
				GetClientName(next_client, playername, sizeof(playername));
				
				MC_PrintToChatAll("%t", "JoinsArenaNoStats", playername, g_sArenaName[arena_index]);
				
				
			} else {
				
				if (foe && IsFakeClient(foe))
				{
					ConVar cvar = FindConVar("tf_bot_quota");
					int quota = cvar.IntValue;
					ServerCommand("tf_bot_quota %d", quota - 1);
				}
				
				if (foe2 && IsFakeClient(foe2))
				{
					ConVar cvar = FindConVar("tf_bot_quota");
					int quota = cvar.IntValue;
					ServerCommand("tf_bot_quota %d", quota - 1);
				}
				
				if (player_teammate && IsFakeClient(player_teammate))
				{
					ConVar cvar = FindConVar("tf_bot_quota");
					int quota = cvar.IntValue;
					ServerCommand("tf_bot_quota %d", quota - 1);
				}
				
				g_iArenaStatus[arena_index] = AS_IDLE;
				return;
			}
		}
		else
		{
			if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
			{
				int next_client = g_iArenaQueue[arena_index][SLOT_TWO + 1];
				g_iArenaQueue[arena_index][SLOT_TWO + 1] = 0;
				g_iArenaQueue[arena_index][player_slot] = next_client;
				g_iPlayerSlot[next_client] = player_slot;
				after_leaver_slot = SLOT_TWO + 2;
				char playername[MAX_NAME_LENGTH];
				CreateTimer(2.0, Timer_StartDuel, arena_index);
				GetClientName(next_client, playername, sizeof(playername));
				
				MC_PrintToChatAll("%t", "JoinsArenaNoStats", playername, g_sArenaName[arena_index]);
				
				
			} else {
				if (foe && IsFakeClient(foe))
				{
					ConVar cvar = FindConVar("tf_bot_quota");
					int quota = cvar.IntValue;
					ServerCommand("tf_bot_quota %d", quota - 1);
				}
				
				g_iArenaStatus[arena_index] = AS_IDLE;
				return;
			}
		}
		
		if (g_iArenaQueue[arena_index][after_leaver_slot])
		{
			while (g_iArenaQueue[arena_index][after_leaver_slot])
			{
				g_iArenaQueue[arena_index][after_leaver_slot - 1] = g_iArenaQueue[arena_index][after_leaver_slot];
				g_iPlayerSlot[g_iArenaQueue[arena_index][after_leaver_slot]] -= 1;
				after_leaver_slot++;
			}
			g_iArenaQueue[arena_index][after_leaver_slot - 1] = 0;
		}
	}
	
	if (g_hWelcomeTimer[client] != null)
	{
		delete g_hWelcomeTimer[client];
	}
}

/*
** -------------------------------------------------------------------------------
**	    ____       _              ______                  __  _                  
**	   / __ \_____(_)_   __      / ____/__  ______  _____/ /_(_)____  ____  _____
**	  / /_/ / ___/ /| | / /     / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
**	 / ____/ /  / / | |/ /_    / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  ) 
**	/_/   /_/  /_/  |___/(_)  /_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/  
**	
** -------------------------------------------------------------------------------
**/

int StartCountDown(int arena_index)
{
	int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE]; /* Red (slot one) player. */
	int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO]; /* Blu (slot two) player. */
	
	if (g_bFourPersonArena[arena_index])
	{
		int red_f2 = g_iArenaQueue[arena_index][SLOT_THREE]; /* 2nd Red (slot three) player. */
		int blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR]; /* 2nd Blu (slot four) player. */
		
		if (red_f1)
			ResetPlayer(red_f1);
		if (blu_f1)
			ResetPlayer(blu_f1);
		if (red_f2)
			ResetPlayer(red_f2);
		if (blu_f2)
			ResetPlayer(blu_f2);
		
		
		if (red_f1 && blu_f1 && red_f2 && blu_f2)
		{
			g_iArenaCd[arena_index] = g_iArenaCdTime[arena_index] + 1;
			g_iArenaStatus[arena_index] = AS_PRECOUNTDOWN;
			CreateTimer(0.0, Timer_CountDown, arena_index, TIMER_FLAG_NO_MAPCHANGE);
			return 1;
		} else {
			g_iArenaStatus[arena_index] = AS_IDLE;
			return 0;
		}
	}
	else {
		if (red_f1)
			ResetPlayer(red_f1);
		if (blu_f1)
			ResetPlayer(blu_f1);
		
		if (red_f1 && blu_f1)
		{
			g_iArenaCd[arena_index] = g_iArenaCdTime[arena_index] + 1;
			g_iArenaStatus[arena_index] = AS_PRECOUNTDOWN;
			CreateTimer(0.0, Timer_CountDown, arena_index, TIMER_FLAG_NO_MAPCHANGE);
			return 1;
		}
		else
		{
			g_iArenaStatus[arena_index] = AS_IDLE;
			return 0;
		}
	}
}

// ====[ HUD ]====================================================
void ShowSpecHudToArena(int arena_index)
{
	if (!arena_index)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TEAM_SPEC && g_iPlayerSpecTarget[i] > 0 && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index)
			ShowSpecHudToClient(i);
	}
}

void ShowCountdownToSpec(int arena_index, char[] text)
{
	if (!arena_index)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TEAM_SPEC && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index)
			PrintCenterText(i, text);
	}
}

void ShowPlayerHud(int client)
{
	if (!IsValidClient(client))
		return;
	
	// HP
	int arena_index = g_iPlayerArena[client];
	int client_slot = g_iPlayerSlot[client];
	//int client_foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
	//int client_foe = (g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_TWO : SLOT_ONE]); //test
	int client_teammate;
	//int client_foe2;
	char hp_report[128];
	
	if (g_bFourPersonArena[arena_index])
	{
		client_teammate = getTeammate(client, client_slot, arena_index);
		//client_foe2 = getTeammate(client_foe, client_foe_slot, arena_index);
	}
	
	if (g_bArenaShowHPToPlayers[arena_index])
	{
		float hp_ratio = ((float(g_iPlayerHP[client])) / (float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]));
		if (hp_ratio > 0.66)
			SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 0, 255, 0, 255); // Green
		else if (hp_ratio >= 0.33)
			SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 0, 255); // Yellow
		else if (hp_ratio < 0.33)
			SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
		
		ShowSyncHudText(client, hm_HP, "Health : %d", g_iPlayerHP[client]);
	} else {
		ShowSyncHudText(client, hm_HP, "", g_iPlayerHP[client]);
	}
	
	// We want ammomod players to be able to see what their health is, even when they have the text hud turned off.
	// We also want to show them BBALL notifications	
	if (!g_bShowHud[client])
		return;
	
	// Score
	SetHudTextParams(0.01, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
	char report[128];
	
	int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
	int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
	int red_f2;
	int blu_f2;
	if (g_bFourPersonArena[arena_index])
	{
		red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
		blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
	}
	
	if (g_bFourPersonArena[arena_index])
	{
		if (red_f1)
		{
			if (red_f2)
			{
				Format(report, sizeof(report), "%s\n%N and %N : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
			}
			else
			{
				Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
			}
			
			
		}
		if (blu_f1)
		{
			if (blu_f2)
			{
				Format(report, sizeof(report), "%s\n%N and %N : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
			}
			else
			{
				Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
			}
		}
	}
	
	else
	{
		if (red_f1)
		{
			Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
		}
		
		if (blu_f1)
		{
			Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
		}
	}
	ShowSyncHudText(client, hm_Score, "%s", report);
	
	
	//Hp of teammate
	if (g_bFourPersonArena[arena_index])
	{
		
		if (client_teammate)
			Format(hp_report, sizeof(hp_report), "%N : %d", client_teammate, g_iPlayerHP[client_teammate]);
	}
	SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
	ShowSyncHudText(client, hm_TeammateHP, hp_report);
}

void ShowSpecHudToClient(int client)
{
	if (!IsValidClient(client) || !IsValidClient(g_iPlayerSpecTarget[client]) || !g_bShowHud[client])
		return;
	
	int arena_index = g_iPlayerArena[g_iPlayerSpecTarget[client]];
	int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
	int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
	int red_f2;
	int blu_f2;
	
	if (g_bFourPersonArena[arena_index])
	{
		red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
		blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
	}
	
	char hp_report[128];
	
	//If its a 2v2 arena show the teamates hp
	if (g_bFourPersonArena[arena_index])
	{
		if (red_f1)
			Format(hp_report, sizeof(hp_report), "%N : %d", red_f1, g_iPlayerHP[red_f1]);
		
		if (red_f2)
			Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, red_f2, g_iPlayerHP[red_f2]);
		
		if (blu_f1)
			Format(hp_report, sizeof(hp_report), "%s\n\n%N : %d", hp_report, blu_f1, g_iPlayerHP[blu_f1]);
		
		if (blu_f2)
			Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, blu_f2, g_iPlayerHP[blu_f2]);
	}
	else
	{
		if (red_f1)
			Format(hp_report, sizeof(hp_report), "%N : %d", red_f1, g_iPlayerHP[red_f1]);
		
		if (blu_f1)
			Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, blu_f1, g_iPlayerHP[blu_f1]);
	}
	
	SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
	ShowSyncHudText(client, hm_HP, hp_report);
	
	// Score
	char report[128];
	SetHudTextParams(0.01, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
	
	int fraglimit = g_iArenaFraglimit[arena_index];
	
	if (g_iArenaStatus[arena_index] != AS_IDLE)
	{
		if (fraglimit > 0)
			Format(report, sizeof(report), "Arena %s. Frag Limit(%d)", g_sArenaName[arena_index], fraglimit);
		else
			Format(report, sizeof(report), "Arena %s. No Frag Limit", g_sArenaName[arena_index]);
	}
	else
	{
		Format(report, sizeof(report), "Arena[%s]", g_sArenaName[arena_index]);
	}
	
	if (g_bFourPersonArena[arena_index])
	{
		if (red_f1)
		{
			if (red_f2)
			{
				Format(report, sizeof(report), "%s\n%N and %N : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
			}
			else
			{
				Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
			}
			
			
		}
		if (blu_f1)
		{
			if (blu_f2)
			{
				Format(report, sizeof(report), "%s\n%N and %N : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
			}
			else
			{
				Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
			}
		}
	}
	
	else
	{
		if (red_f1)
		{
			Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
		}
		
		if (blu_f1)
		{
			Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
		}
	}
	
	ShowSyncHudText(client, hm_Score, "%s", report);
}

void HideHud(int client)
{
	if (!IsValidClient(client))
		return;
	
	ClearSyncHud(client, hm_Score);
	ClearSyncHud(client, hm_HP);
}

// ====[ QUEUE ]==================================================== 
void RemoveFromQueue(int client, bool calcstats = false, bool specfix = false)
{
	int arena_index = g_iPlayerArena[client];
	
	if (arena_index == 0)
	{
		return;
	}
	
	int player_slot = g_iPlayerSlot[client];
	g_iPlayerArena[client] = 0;
	g_iPlayerSlot[client] = 0;
	g_iArenaQueue[arena_index][player_slot] = 0;
	
	if (IsValidClient(client) && GetClientTeam(client) != TEAM_SPEC)
	{
		ForcePlayerSuicide(client);
		ChangeClientTeam(client, 1);
		
		if (specfix)
			CreateTimer(0.1, Timer_SpecFix, GetClientUserId(client));
	}
	
	int after_leaver_slot = player_slot + 1;
	
	//I beleive I don't need to do this anymore BUT
	//If the player was in the arena, and the timer was running, kill it
	if (((player_slot <= SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot <= SLOT_FOUR)) && g_bTimerRunning[arena_index])
	{
		delete g_tKothTimer[arena_index];
		g_bTimerRunning[arena_index] = false;
	}
	
	if (g_bFourPersonArena[arena_index])
	{
		int foe_team_slot;
		int player_team_slot;
		
		if (player_slot <= SLOT_FOUR && player_slot > 0)
		{
			int foe_slot = (player_slot == SLOT_ONE || player_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
			int foe = g_iArenaQueue[arena_index][foe_slot];
			int player_teammate;
			int foe2;
			
			foe_team_slot = (foe_slot > 2) ? (foe_slot - 2) : foe_slot;
			player_team_slot = (player_slot > 2) ? (player_slot - 2) : player_slot;
			
			if (g_bFourPersonArena[arena_index])
			{
				player_teammate = getTeammate(client, player_slot, arena_index);
				foe2 = getTeammate(foe, foe_slot, arena_index);
			}
			
			if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && calcstats && foe)
			{
				char foe_name[MAX_NAME_LENGTH * 2];
				char player_name[MAX_NAME_LENGTH * 2];
				char foe2_name[MAX_NAME_LENGTH];
				char player_teammate_name[MAX_NAME_LENGTH];
				
				GetClientName(foe, foe_name, sizeof(foe_name));
				GetClientName(client, player_name, sizeof(player_name));
				GetClientName(foe2, foe2_name, sizeof(foe2_name));
				GetClientName(player_teammate, player_teammate_name, sizeof(player_teammate_name));
				
				Format(foe_name, sizeof(foe_name), "%s and %s", foe_name, foe2_name);
				Format(player_name, sizeof(player_name), "%s and %s", player_name, player_teammate_name);
				
				g_iArenaStatus[arena_index] = AS_REPORTED;
				
				if (g_iArenaScore[arena_index][foe_team_slot] > g_iArenaScore[arena_index][player_team_slot])
				{
					if (g_iArenaScore[arena_index][foe_team_slot] >= g_iArenaEarlyLeave[arena_index])
					{
						MC_PrintToChatAll("%t", "XdefeatsYearly", foe_name, g_iArenaScore[arena_index][foe_team_slot], player_name, g_iArenaScore[arena_index][player_team_slot], g_sArenaName[arena_index]);
					}
				}
			}
			
			if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
			{
				int next_client = g_iArenaQueue[arena_index][SLOT_FOUR + 1];
				g_iArenaQueue[arena_index][SLOT_FOUR + 1] = 0;
				g_iArenaQueue[arena_index][player_slot] = next_client;
				g_iPlayerSlot[next_client] = player_slot;
				after_leaver_slot = SLOT_FOUR + 2;
				char playername[MAX_NAME_LENGTH];
				CreateTimer(2.0, Timer_StartDuel, arena_index);
				GetClientName(next_client, playername, sizeof(playername));
				
				MC_PrintToChatAll("%t", "JoinsArenaNoStats", playername, g_sArenaName[arena_index]);
				
				
			}
			else
			{
				if (foe && IsFakeClient(foe))
				{
					ConVar cvar = FindConVar("tf_bot_quota");
					int quota = cvar.IntValue;
					ServerCommand("tf_bot_quota %d", quota - 1);
				}
				
				g_iArenaStatus[arena_index] = AS_IDLE;
				return;
			}
		}
	}
	
	else
	{
		if (player_slot == SLOT_ONE || player_slot == SLOT_TWO)
		{
			int foe_slot = player_slot == SLOT_ONE ? SLOT_TWO : SLOT_ONE;
			int foe = g_iArenaQueue[arena_index][foe_slot];
			
			if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && calcstats && foe)
			{
				char foe_name[MAX_NAME_LENGTH];
				char player_name[MAX_NAME_LENGTH];
				GetClientName(foe, foe_name, sizeof(foe_name));
				GetClientName(client, player_name, sizeof(player_name));
				
				g_iArenaStatus[arena_index] = AS_REPORTED;
				
				if (g_iArenaScore[arena_index][foe_slot] > g_iArenaScore[arena_index][player_slot])
				{
					if (g_iArenaScore[arena_index][foe_slot] >= g_iArenaEarlyLeave[arena_index])
					{
						MC_PrintToChatAll("%t", "XdefeatsYearly", foe_name, g_iArenaScore[arena_index][foe_slot], player_name, g_iArenaScore[arena_index][player_slot], g_sArenaName[arena_index]);
					}
				}
			}
			
			if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
			{
				int next_client = g_iArenaQueue[arena_index][SLOT_TWO + 1];
				g_iArenaQueue[arena_index][SLOT_TWO + 1] = 0;
				g_iArenaQueue[arena_index][player_slot] = next_client;
				g_iPlayerSlot[next_client] = player_slot;
				after_leaver_slot = SLOT_TWO + 2;
				char playername[MAX_NAME_LENGTH];
				CreateTimer(2.0, Timer_StartDuel, arena_index);
				GetClientName(next_client, playername, sizeof(playername));
				
				MC_PrintToChatAll("%t", "JoinsArenaNoStats", playername, g_sArenaName[arena_index]);
				
				
			} else {
				if (foe && IsFakeClient(foe))
				{
					ConVar cvar = FindConVar("tf_bot_quota");
					int quota = cvar.IntValue;
					ServerCommand("tf_bot_quota %d", quota - 1);
				}
				
				g_iArenaStatus[arena_index] = AS_IDLE;
				return;
			}
		}
	}
	if (g_iArenaQueue[arena_index][after_leaver_slot])
	{
		while (g_iArenaQueue[arena_index][after_leaver_slot])
		{
			g_iArenaQueue[arena_index][after_leaver_slot - 1] = g_iArenaQueue[arena_index][after_leaver_slot];
			g_iPlayerSlot[g_iArenaQueue[arena_index][after_leaver_slot]] -= 1;
			after_leaver_slot++;
		}
		g_iArenaQueue[arena_index][after_leaver_slot - 1] = 0;
	}
}

void AddInQueue(int client, int arena_index, bool showmsg = true, int playerPrefTeam = 0)
{
	if (!IsValidClient(client))
		return;
	
	if (g_iPlayerArena[client])
	{
		PrintToChatAll("client <%N> is already on arena %d", client, arena_index);
	}
	
	//Set the player to the preffered team if there is room, otherwise just add him in wherever there is a slot
	int player_slot = SLOT_ONE;
	if (playerPrefTeam == TEAM_RED)
	{
		if (!g_iArenaQueue[arena_index][SLOT_ONE])
			player_slot = SLOT_ONE;
		else if (g_bFourPersonArena[arena_index] && !g_iArenaQueue[arena_index][SLOT_THREE])
			player_slot = SLOT_THREE;
		else
		{
			while (g_iArenaQueue[arena_index][player_slot])
				player_slot++;
		}
	}
	else if (playerPrefTeam == TEAM_BLU)
	{
		if (!g_iArenaQueue[arena_index][SLOT_TWO])
			player_slot = SLOT_TWO;
		else if (g_bFourPersonArena[arena_index] && !g_iArenaQueue[arena_index][SLOT_FOUR])
			player_slot = SLOT_FOUR;
		else
		{
			while (g_iArenaQueue[arena_index][player_slot])
				player_slot++;
		}
	}
	else
	{
		while (g_iArenaQueue[arena_index][player_slot])
			player_slot++;
	}
	
	g_iPlayerArena[client] = arena_index;
	g_iPlayerSlot[client] = player_slot;
	g_iArenaQueue[arena_index][player_slot] = client;
	
	if (showmsg)
	{
		MC_PrintToChat(client, "%t", "ChoseArena", g_sArenaName[arena_index]);
	}
	if (g_bFourPersonArena[arena_index])
	{
		if (player_slot <= SLOT_FOUR)
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			
			MC_PrintToChatAll("%t", "JoinsArenaNoStats", name, g_sArenaName[arena_index]);
			
			if (g_iArenaQueue[arena_index][SLOT_ONE] && g_iArenaQueue[arena_index][SLOT_TWO] && g_iArenaQueue[arena_index][SLOT_THREE] && g_iArenaQueue[arena_index][SLOT_FOUR])
			{
				CreateTimer(1.5, Timer_StartDuel, arena_index);
			}
			else
				CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
		} else {
			if (GetClientTeam(client) != TEAM_SPEC)
				ChangeClientTeam(client, TEAM_SPEC);
			if (player_slot == SLOT_FOUR + 1)
				MC_PrintToChat(client, "%t", "NextInLine");
			else
				MC_PrintToChat(client, "%t", "InLine", player_slot - SLOT_FOUR);
		}
	}
	else
	{
		if (player_slot <= SLOT_TWO)
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			
			MC_PrintToChatAll("%t", "JoinsArenaNoStats", name, g_sArenaName[arena_index]);
			
			if (g_iArenaQueue[arena_index][SLOT_ONE] && g_iArenaQueue[arena_index][SLOT_TWO])
			{
				CreateTimer(1.5, Timer_StartDuel, arena_index);
			} else
				CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
		} else {
			if (GetClientTeam(client) != TEAM_SPEC)
				ChangeClientTeam(client, TEAM_SPEC);
			if (player_slot == SLOT_TWO + 1)
				MC_PrintToChat(client, "%t", "NextInLine");
			else
				MC_PrintToChat(client, "%t", "InLine", player_slot - SLOT_TWO);
		}
	}
	
	return;
}

// ====[ UTIL ]====================================================
bool LoadPlayerSpawnPoints()
{
	char txtfile[256];
	BuildPath(Path_SM, txtfile, sizeof(txtfile), g_arenaFile);
	
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	KeyValues kv = new KeyValues("SpawnConfig");
	
	char kvmap[32];
	int i;
	g_iArenaCount = 0;
	
	for (i = 0; i <= MAXARENAS; i++)
	g_iArenaSpawns[i] = 0;
	
	if (kv.ImportFromFile(txtfile))
	{
		if (kv.GotoFirstSubKey())
		{
			do
			{
				kv.GetSectionName(kvmap, sizeof(kvmap));
				if (StrEqual(g_sMapName, kvmap, false))
				{
					if (kv.GotoFirstSubKey())
					{
						do
						{
							g_iArenaCount++;
							kv.GetSectionName(g_sArenaName[g_iArenaCount], 64);
							
							// Iterate through all the info target points and check 'em out.
							int iEntity = -1;
							while ((iEntity = FindEntityByClassname(iEntity, "info_target")) != -1)
							{
								char strName[32]; GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
								float fPosition[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPosition);
								float fAngles[3]; GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngles);
								char checkNameRed[32];
								strcopy(checkNameRed, sizeof(checkNameRed), g_sArenaName[g_iArenaCount]);
								StrCat(checkNameRed, sizeof(checkNameRed), "_red_spawn");
								char checkNameBlue[32];
								strcopy(checkNameBlue, sizeof(checkNameBlue), g_sArenaName[g_iArenaCount]);
								StrCat(checkNameBlue, sizeof(checkNameBlue), "_blue_spawn");
								if (StrContains(strName, checkNameRed) != -1)
								{
									g_iArenaSpawns[g_iArenaCount]++;
									g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]] = fPosition;
									g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]] = fAngles;
								}
								else if (StrContains(strName, checkNameBlue) != -1)
								{
									g_iArenaSpawns[g_iArenaCount]++;
									g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]] = fPosition;
									g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]] = fAngles;
								}
								else
								{
								}
							}
							
							if (g_iArenaSpawns[g_iArenaCount] != 0)
							{
								LogMessage("Loaded %d spawns on arena %s.", g_iArenaSpawns[g_iArenaCount], g_sArenaName[g_iArenaCount]);
							}
							else
							{
								LogError("Could not load spawns on arena %s.", g_sArenaName[g_iArenaCount]);
							}
							
							//optional parametrs
							g_iArenaMaxTeamSize[g_iArenaCount] = kv.GetNum("maxteamsize", g_iDefaultTeamSize);
							g_iArenaFraglimit[g_iArenaCount] = kv.GetNum("fraglimit", g_iDefaultFragLimit);
							g_iArenaCdTime[g_iArenaCount] = kv.GetNum("cdtime", DEFAULT_CDTIME);
							g_fArenaHPRatio[g_iArenaCount] = kv.GetFloat("hpratio", 1.5);
							g_iArenaEarlyLeave[g_iArenaCount] = kv.GetNum("earlyleave", 0);
							g_bArenaShowHPToPlayers[g_iArenaCount] = kv.GetNum("showhp", 1) ? true : false;
							g_fArenaMinSpawnDist[g_iArenaCount] = kv.GetFloat("mindist", 100.0);
							g_bFourPersonArena[g_iArenaCount] = kv.GetNum("4player", 0) ? true : false;
							g_fArenaRespawnTime[g_iArenaCount] = kv.GetFloat("respawntime", 0.1);
						} while (kv.GotoNextKey());
					}
					break;
				}
			} while (kv.GotoNextKey());
			if (g_iArenaCount)
			{
				LogMessage("Loaded %d arenas. TFDBMGE enabled.", g_iArenaCount);
				delete kv;
				return true;
			} else {
				delete kv;
				return false;
			}
		} else {
			LogError("Error in cfg file.");
			return false;
		}
	} else {
		LogError("Error. Can't find cfg file");
		return false;
	}
}

int ResetPlayer(int client)
{
	int arena_index = g_iPlayerArena[client];
	int player_slot = g_iPlayerSlot[client];
	
	if (!arena_index || !player_slot)
	{
		return 0;
	}
	
	g_iPlayerSpecTarget[client] = 0;
	
	if (player_slot == SLOT_ONE || player_slot == SLOT_THREE)
		ChangeClientTeam(client, TEAM_RED);
	else
		ChangeClientTeam(client, TEAM_BLU);
	
	//This logic doesn't work with 2v2's
	//new team = GetClientTeam(client);
	//if (player_slot - team != SLOT_ONE - TEAM_RED) 
	//	ChangeClientTeam(client, player_slot + TEAM_RED - SLOT_ONE);
	
	TFClassType class;
	class = TFClass_Pyro;
	
	if (!IsPlayerAlive(client))
	{
		if (class != TF2_GetPlayerClass(client))
			TF2_SetPlayerClass(client, class);
		TF2_RespawnPlayer(client);
	}
	else
	{
		TF2_RegeneratePlayer(client);
		ExtinguishEntity(client);
	}
	
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Primary));
	}
	
	g_iPlayerMaxHP[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	
	g_iPlayerHP[client] = RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]);
	
	SetEntProp(client, Prop_Data, "m_iHealth", RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]));
	
	ShowPlayerHud(client);
	CreateTimer(0.1, Timer_Tele, GetClientUserId(client));
	
	return 1;
}

void ResetKiller(int killer, int arena_index)
{	
	int reset_hp = RoundToNearest(float(g_iPlayerMaxHP[killer]) * g_fArenaHPRatio[arena_index]);
	g_iPlayerHP[killer] = reset_hp;
	SetEntProp(killer, Prop_Data, "m_iHealth", reset_hp);
	RequestFrame(RegenKiller, killer);
}

// ====[ MAIN MENU ]====================================================
void ShowMainMenu(int client, bool listplayers = true)
{
	if (client <= 0)
		return;
	
	char title[128];
	char menu_item[128];
	
	Menu menu = new Menu(Menu_Main);
	
	Format(title, sizeof(title), "%T", "MenuTitle", client);
	menu.SetTitle(title);
	char si[4];
	
	for (int i = 1; i <= g_iArenaCount; i++)
	{
		int numslots = 0;
		for (int NUM = 1; NUM <= MAXPLAYERS + 1; NUM++)
		{
			if (g_iArenaQueue[i][NUM])
				numslots++;
			else
				break;
		}
		
		if (numslots > 2)
			Format(menu_item, sizeof(menu_item), "%s (2)(%d)", g_sArenaName[i], (numslots - 2));
		else if (numslots > 0)
			Format(menu_item, sizeof(menu_item), "%s (%d)", g_sArenaName[i], numslots);
		else
			Format(menu_item, sizeof(menu_item), "%s", g_sArenaName[i]);
		
		IntToString(i, si, sizeof(si));
		menu.AddItem(si, menu_item);
	}
	
	Format(menu_item, sizeof(menu_item), "%T", "MenuRemove", client);
	menu.AddItem("1000", menu_item);
	
	menu.ExitButton = true;
	menu.Display(client, 0);
	
	char report[128];
	
	//listing players
	if (!listplayers)
		return;
	
	for (int i = 1; i <= g_iArenaCount; i++)
	{
		int red_f1 = g_iArenaQueue[i][SLOT_ONE];
		int blu_f1 = g_iArenaQueue[i][SLOT_TWO];
		if (red_f1 > 0 || blu_f1 > 0)
		{
			Format(report, sizeof(report), "\x05%s:", g_sArenaName[i]);
			
			if (red_f1 > 0 && blu_f1 > 0)
				Format(report, sizeof(report), "%s \x04%N \x05vs \x04%N \x05", report, red_f1, blu_f1);
			else if (red_f1 > 0)
				Format(report, sizeof(report), "%s \x04%N \x05", report, red_f1);
			else if (blu_f1 > 0)
				Format(report, sizeof(report), "%s \x04%N \x05", report, blu_f1);
			
			if (g_iArenaQueue[i][SLOT_TWO + 1])
			{
				Format(report, sizeof(report), "%s Waiting: ", report);
				int j = SLOT_TWO + 1;
				while (g_iArenaQueue[i][j + 1])
				{
					Format(report, sizeof(report), "%s\x04%N \x05, ", report, g_iArenaQueue[i][j]);
					j++;
				}
				Format(report, sizeof(report), "%s\x04%N", report, g_iArenaQueue[i][j]);
			}
			PrintToChat(client, "%s", report);
		}
	}
}

public int Menu_Main(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int client = param1;
			if (!client)return;
			char capt[32];
			char sanum[32];
			
			menu.GetItem(param2, sanum, sizeof(sanum), _, capt, sizeof(capt));
			int arena_index = StringToInt(sanum);
			
			if (arena_index > 0 && arena_index <= g_iArenaCount)
			{
				if (arena_index == g_iPlayerArena[client])
				{
					//show warn msg
					ShowMainMenu(client, false);
					return;
				}
				
				if (g_iPlayerArena[client])
					RemoveFromQueue(client, true);
				
				AddInQueue(client, arena_index);
				
			} else {
				RemoveFromQueue(client, true);
			}
		}
		case MenuAction_Cancel:
		{
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

//   ___                     _
//  / __|__ _ _ __  ___ _ __| |__ _ _  _
// | (_ / _` | '  \/ -_) '_ \ / _` | || |
//  \___\__,_|_|_|_\___| .__/_\__,_|\_, |
//                     |_|          |__/

/* OnDodgeBallGameFrame()
**
** Function called every tick of the Dodgeball logic timer.
** -------------------------------------------------------------------------- */
public Action OnDodgeBallGameFrame(Handle hTimer, any Data)
{
	for (int arena_index = 1; arena_index <= g_iArenaCount; arena_index++)
	{
		// Only if both teams are playing
		if (BothTeamsPlayingInArea(arena_index) == false || g_iArenaStatus[arena_index] != AS_FIGHT)
		{
			continue;
		}
		
		// Manage the active rockets
		int iIndex = -1;
		while ((iIndex = FindNextValidRocket(iIndex)) != -1)
		{
			switch (g_iRocketClassBehaviour[g_iRocketClass[iIndex]])
			{
				case Behaviour_Unknown: {  }
				case Behaviour_Homing: { HomingRocketThink(iIndex, arena_index); }
			}
		}
		
		// Check if we need to fire more rockets.
		if (GetGameTime() >= g_fNextRocketSpawnTime[arena_index])
		{
			if (g_iLastDeadTeam[arena_index] == view_as<int>(TFTeam_Red))
			{
				int iSpawnerEntity = g_iRocketSpawnPointsRedEntity[g_iCurrentRedRocketSpawn[arena_index]][arena_index];
				int iSpawnerClass = g_iRocketSpawnPointsRedClass[g_iCurrentRedRocketSpawn[arena_index]][arena_index];
				if (g_iRocketCount < g_iSpawnersMaxRockets[iSpawnerClass])
				{
					PrintToServer("Attempting to create red rocket in arena %s", g_sArenaName[arena_index]);
					CreateRocket(iSpawnerEntity, iSpawnerClass, view_as<int>(TFTeam_Red), arena_index);
					g_iCurrentRedRocketSpawn[arena_index] = (g_iCurrentRedRocketSpawn[arena_index] + 1) % g_iRocketSpawnPointsRedCount[arena_index];
				}
			}
			else
			{
				int iSpawnerEntity = g_iRocketSpawnPointsBluEntity[g_iCurrentBluRocketSpawn[arena_index]][arena_index];
				int iSpawnerClass = g_iRocketSpawnPointsBluClass[g_iCurrentBluRocketSpawn[arena_index]][arena_index];
				if (g_iRocketCount < g_iSpawnersMaxRockets[iSpawnerClass])
				{
					CreateRocket(iSpawnerEntity, iSpawnerClass, view_as<int>(TFTeam_Blue), arena_index);
					g_iCurrentBluRocketSpawn[arena_index] = (g_iCurrentBluRocketSpawn[arena_index] + 1) % g_iRocketSpawnPointsBluCount[arena_index];
				}
			}
		}
	}
}

//  ___         _       _
// | _ \___  __| |_____| |_ ___
// |   / _ \/ _| / / -_)  _(_-<
// |_|_\___/\__|_\_\___|\__/__/

/* CreateRocket()
**
** Fires a new rocket entity from the spawner's position.
** -------------------------------------------------------------------------- */
public void CreateRocket(int iSpawnerEntity, int iSpawnerClass, int iTeam, int arena_index)
{
	int iIndex = FindFreeRocketSlot();
	if (iIndex != -1)
	{
		// Fetch a random rocket class and it's parameters.
		int iClass = GetRandomRocketClass(iSpawnerClass);
		RocketFlags iFlags = g_iRocketClassFlags[iClass];
		DragTypes iDragType = g_iRocketClassDragType[iClass];
		
		// Create rocket entity.
		int iEntity = CreateEntityByName(TestFlags(iFlags, RocketFlag_IsAnimated) ? "tf_projectile_sentryrocket" : "tf_projectile_rocket");
		if (iEntity && IsValidEntity(iEntity))
		{
			// Fetch spawn point's location and angles.
			float fPosition[3];
			float fAngles[3];
			float fDirection[3];
			GetEntPropVector(iSpawnerEntity, Prop_Send, "m_vecOrigin", fPosition);
			GetEntPropVector(iSpawnerEntity, Prop_Send, "m_angRotation", fAngles);
			GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
			
			// Setup rocket entity.
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", 0);
			SetEntProp(iEntity, Prop_Send, "m_bCritical", (GetURandomFloatRange(0.0, 100.0) <= g_fRocketClassCritChance[iClass]) ? 1 : 0, 1);
			SetEntProp(iEntity, Prop_Send, "m_iTeamNum", iTeam, 1);
			SetEntProp(iEntity, Prop_Send, "m_iDeflected", 1);
			TeleportEntity(iEntity, fPosition, fAngles, view_as<float>( { 0.0, 0.0, 0.0 } ));
			
			// Setup rocket structure with the newly created entity.
			int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
			int iTarget = SelectTarget(iTargetTeam, arena_index);
			float fModifier = CalculateModifier(iClass, 0, arena_index);
			g_bRocketIsValid[iIndex] = true;
			g_iRocketFlags[iIndex] = iFlags;
			g_iRocketDragType[iIndex] = iDragType;
			g_iRocketEntity[iIndex] = EntIndexToEntRef(iEntity);
			g_iRocketTarget[iIndex] = EntIndexToEntRef(iTarget);
			g_iRocketSpawner[iIndex] = iSpawnerClass;
			g_iRocketClass[iIndex] = iClass;
			g_iRocketDeflections[iIndex] = 0;
			g_fRocketLastDeflectionTime[iIndex] = GetGameTime();
			g_fRocketLastBeepTime[iIndex] = GetGameTime();
			g_fRocketSpeed[iIndex] = CalculateRocketSpeed(iClass, fModifier);
			g_iRocketSpeed[arena_index] = RoundFloat(g_fRocketSpeed[iIndex] * 0.042614);

			CopyVectors(fDirection, g_fRocketDirection[iIndex]);
			SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(iClass, fModifier), true);
			DispatchSpawn(iEntity);

			// Apply custom model, if specified on the flags.
			if (TestFlags(iFlags, RocketFlag_CustomModel))
			{
				SetEntityModel(iEntity, g_strRocketClassModel[iClass]);
				UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
			}

			// Emit required sounds.
			EmitRocketSound(RocketSound_Spawn, iClass, iEntity, iTarget, iFlags);
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);

			// Done
			g_iRocketCount++;
			g_iRocketsFired[arena_index]++;
			g_fLastRocketSpawnTime[arena_index] = GetGameTime();
			g_fNextRocketSpawnTime[arena_index] = GetGameTime() + g_fRocketSpawnersInterval[iSpawnerClass];
			g_bRocketIsNuke[iIndex] = false;
		}
	}
}

/* DestroyRocket()
**
** Destroys the rocket at the given index.
** -------------------------------------------------------------------------- */
void DestroyRocket(int iIndex)
{
	if (IsValidRocket(iIndex) == true)
	{
		int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
		if (iEntity && IsValidEntity(iEntity))RemoveEdict(iEntity);
		g_bRocketIsValid[iIndex] = false;
		g_iRocketCount--;
	}
}

/* DestroyRockets()
**
** Destroys all the rockets that are currently active.
** -------------------------------------------------------------------------- */
void DestroyRockets()
{
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++)
	{
		DestroyRocket(iIndex);
	}
	g_iRocketCount = 0;
}

/* IsValidRocket()
**
** Checks if a rocket structure is valid.
** -------------------------------------------------------------------------- */
bool IsValidRocket(int iIndex)
{
	if ((iIndex >= 0) && (g_bRocketIsValid[iIndex] == true))
	{
		if (EntRefToEntIndex(g_iRocketEntity[iIndex]) == -1)
		{
			g_bRocketIsValid[iIndex] = false;
			g_iRocketCount--;
			return false;
		}
		return true;
	}
	return false;
}

/* FindNextValidRocket()
**
** Retrieves the index of the next valid rocket from the current offset.
** -------------------------------------------------------------------------- */
int FindNextValidRocket(int iIndex, bool bWrap = false)
{
	for (int iCurrent = iIndex + 1; iCurrent < MAX_ROCKETS; iCurrent++)
	if (IsValidRocket(iCurrent))
		return iCurrent;

	return (bWrap == true) ? FindNextValidRocket(-1, false) : -1;
}

/* FindFreeRocketSlot()
**
** Retrieves the next free rocket slot since the current one. If all of them
** are full, returns -1.
** -------------------------------------------------------------------------- */
int FindFreeRocketSlot()
{
	int iIndex = g_iLastCreatedRocket;
	int iCurrent = iIndex;

	do
	{
		if (!IsValidRocket(iCurrent))return iCurrent;
		if ((++iCurrent) == MAX_ROCKETS)iCurrent = 0;
	} while (iCurrent != iIndex);

	return -1;
}

/* FindRocketByEntity()
**
** Finds a rocket index from it's entity.
** -------------------------------------------------------------------------- */
int FindRocketByEntity(int iEntity)
{
	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1)
		if (EntRefToEntIndex(g_iRocketEntity[iIndex]) == iEntity)
			return iIndex;
			
	return -1;
}

/* HomingRocketThink()
**
** Logic process for the Behaviour_Homing type rockets, which is simply a
** homing rocket that picks a random target.
** -------------------------------------------------------------------------- */
void HomingRocketThink(int iIndex, int arena_index)
{
	// Retrieve the rocket's attributes.
	int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
	int iClass = g_iRocketClass[iIndex];
	RocketFlags iFlags = g_iRocketFlags[iIndex];
	int iTarget = EntRefToEntIndex(g_iRocketTarget[iIndex]);
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iDeflectionCount = GetEntProp(iEntity, Prop_Send, "m_iDeflected") - 1;
	float fModifier = CalculateModifier(iClass, iDeflectionCount, arena_index);

	// Check if the target is available
	if (!IsValidClient(iTarget, true))
	{
		iTarget = SelectTarget(iTargetTeam, arena_index);
		if (!IsValidClient(iTarget, true))return;
		g_iRocketTarget[iIndex] = EntIndexToEntRef(iTarget);

		if (GetConVarBool(g_hCvarRedirectBeep))
		{
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		}
	}
	// Has the rocket been deflected recently? If so, set new target.
	else if ((iDeflectionCount > g_iRocketDeflections[iIndex]))
	{
		int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(iClient))
		{
			if (g_iRocketDragType[iIndex] == DragType_Direction)
			{
				// Calculate new direction from the player's forward (puts player angles into rocket orientation)
				float fViewAngles[3];
				float fDirection[3];
				GetClientEyeAngles(iClient, fViewAngles);
				GetAngleVectors(fViewAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
				CopyVectors(fDirection, g_fRocketDirection[iIndex]);
			}
			else if (g_iRocketDragType[iIndex] == DragType_Aim)
			{
				// Calculate new direction from player's aim (rocket aims where player aims)
				float fRocketPos[3];
				float fRocketAng[3];
				float fTargetPos[3];
				GetPlayerEyePosition(iClient, fTargetPos);
				
				GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", fRocketPos);
				GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fRocketAng);
				
				float tmpVec[3];
				tmpVec[0] = fTargetPos[0] - fRocketPos[0];
				tmpVec[1] = fTargetPos[1] - fRocketPos[1];
				tmpVec[2] = fTargetPos[2] - fRocketPos[2];
				GetVectorAngles(tmpVec, fRocketAng);
				
				float fDirection[3];
				GetAngleVectors(fRocketAng, fDirection, NULL_VECTOR, NULL_VECTOR);
				CopyVectors(fDirection, g_fRocketDirection[iIndex]);
			}
			UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
		}
		// Set new target & deflection count
		iTarget = SelectTarget(iTargetTeam, arena_index, iIndex);
		g_iRocketTarget[iIndex] = EntIndexToEntRef(iTarget);
		g_iRocketDeflections[iIndex] = iDeflectionCount;
		g_fRocketLastDeflectionTime[iIndex] = GetGameTime();
		g_fRocketSpeed[iIndex] = CalculateRocketSpeed(iClass, fModifier);
		g_iRocketSpeed[arena_index] = RoundFloat(g_fRocketSpeed[iIndex] * 0.042614);
		g_bPreventingDelay = false;
		
		SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(iClass, fModifier), true);
		if (TestFlags(iFlags, RocketFlag_ElevateOnDeflect))g_iRocketFlags[iIndex] |= RocketFlag_Elevating;
		EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		//Send out temp entity to target
		//SendTempEnt(iTarget, "superrare_greenenergy", iEntity, _, _, true);
	}
	else
	{
		// If the delay time since the last reflection has been elapsed, rotate towards the client.
		if ((GetGameTime() - g_fRocketLastDeflectionTime[iIndex]) >= g_fRocketClassControlDelay[iClass])
		{
			// Calculate turn rate and retrieve directions.
			float fTurnRate = CalculateRocketTurnRate(iClass, fModifier);
			float fDirectionToTarget[3]; CalculateDirectionToClient(iEntity, iTarget, fDirectionToTarget);

			// Elevate the rocket after a deflection (if it's enabled on the class definition, of course.)
			if (g_iRocketFlags[iIndex] & RocketFlag_Elevating)
			{
				if (g_fRocketDirection[iIndex][2] < g_fRocketClassElevationLimit[iClass])
				{
					g_fRocketDirection[iIndex][2] = FMin(g_fRocketDirection[iIndex][2] + g_fRocketClassElevationRate[iClass], g_fRocketClassElevationLimit[iClass]);
					fDirectionToTarget[2] = g_fRocketDirection[iIndex][2];
				}
				else
				{
					g_iRocketFlags[iIndex] &= ~RocketFlag_Elevating;
				}
			}

			// Smoothly change the orientation to the new one.
			LerpVectors(g_fRocketDirection[iIndex], fDirectionToTarget, g_fRocketDirection[iIndex], fTurnRate);
		}

		// If it's a nuke, beep every some time
		if ((GetGameTime() - g_fRocketLastBeepTime[iIndex]) >= g_fRocketClassBeepInterval[iClass])
		{
			g_bRocketIsNuke[iIndex] = true;
			EmitRocketSound(RocketSound_Beep, iClass, iEntity, iTarget, iFlags);
			g_fRocketLastBeepTime[iIndex] = GetGameTime();
		}
		
		if (GetConVarBool(g_hCvarDelayPrevention))
		{
			checkRoundDelays(iIndex, arena_index);
		}
	}

	// Done
	ApplyRocketParameters(iIndex);
}

/* CalculateModifier()
**
** Gets the modifier for the damage/speed/rotation calculations.
** -------------------------------------------------------------------------- */
float CalculateModifier(int iClass, int iDeflections, int arena_index)
{
	return iDeflections +
	(g_iRocketsFired[arena_index] * g_fRocketClassRocketsModifier[iClass]) +
	(g_iPlayerCount[arena_index] * g_fRocketClassPlayerModifier[iClass]);
}

/* CalculateRocketDamage()
**
** Calculates the damage of the rocket based on it's type and deflection count.
** -------------------------------------------------------------------------- */
float CalculateRocketDamage(int iClass, float fModifier)
{
	return g_fRocketClassDamage[iClass] + g_fRocketClassDamageIncrement[iClass] * fModifier;
}

/* CalculateRocketSpeed()
**
** Calculates the speed of the rocket based on it's type and deflection count.
** -------------------------------------------------------------------------- */
float CalculateRocketSpeed(int iClass, float fModifier)
{
	return g_fRocketClassSpeed[iClass] + g_fRocketClassSpeedIncrement[iClass] * fModifier;
}

/* CalculateRocketTurnRate()
**
** Calculates the rocket's turn rate based upon it's type and deflection count.
** -------------------------------------------------------------------------- */
float CalculateRocketTurnRate(int iClass, float fModifier)
{
	return g_fRocketClassTurnRate[iClass] + g_fRocketClassTurnRateIncrement[iClass] * fModifier;
}

/* CalculateDirectionToClient()
**
** As the name indicates, calculates the orientation for the rocket to move
** towards the specified client.
** -------------------------------------------------------------------------- */
void CalculateDirectionToClient(int iEntity, int iClient, float fOut[3])
{
	float fRocketPosition[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
	GetClientEyePosition(iClient, fOut);
	MakeVectorFromPoints(fRocketPosition, fOut, fOut);
	NormalizeVector(fOut, fOut);
}

/* ApplyRocketParameters()
**
** Transforms and applies the speed, direction and angles for the rocket
** entity.
** -------------------------------------------------------------------------- */
void ApplyRocketParameters(int iIndex)
{
	int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
	float fAngles[3]; GetVectorAngles(g_fRocketDirection[iIndex], fAngles);
	float fVelocity[3]; CopyVectors(g_fRocketDirection[iIndex], fVelocity);
	ScaleVector(fVelocity, g_fRocketSpeed[iIndex]);
	SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fVelocity);
	SetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngles);
}

/* UpdateRocketSkin()
**
** Changes the skin of the rocket based on it's team.
** -------------------------------------------------------------------------- */
void UpdateRocketSkin(int iEntity, int iTeam, bool bNeutral)
{
	if (bNeutral == true)SetEntProp(iEntity, Prop_Send, "m_nSkin", 2);
	else SetEntProp(iEntity, Prop_Send, "m_nSkin", (iTeam == view_as<int>(TFTeam_Blue)) ? 0 : 1);
}

/* GetRandomRocketClass()
**
** Generates a random value and retrieves a rocket class based upon a chances table.
** -------------------------------------------------------------------------- */
int GetRandomRocketClass(int iSpawnerClass)
{
	int iRandom = GetURandomIntRange(0, 101);
	Handle hTable = g_hRocketSpawnersChancesTable[iSpawnerClass];
	int iTableSize = GetArraySize(hTable);
	int iChancesLower = 0;
	int iChancesUpper = 0;

	for (int iEntry = 0; iEntry < iTableSize; iEntry++)
	{
		iChancesLower += iChancesUpper;
		iChancesUpper = iChancesLower + GetArrayCell(hTable, iEntry);

		if ((iRandom >= iChancesLower) && (iRandom < iChancesUpper))
		{
			return iEntry;
		}
	}

	return 0;
}

/* EmitRocketSound()
**
** Emits one of the rocket sounds
** -------------------------------------------------------------------------- */
void EmitRocketSound(RocketSound iSound, int iClass, int iEntity, int iTarget, RocketFlags iFlags)
{
	switch (iSound)
	{
		case RocketSound_Spawn:
		{
			if (TestFlags(iFlags, RocketFlag_PlaySpawnSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomSpawnSound))EmitSoundToAll(g_strRocketClassSpawnSound[iClass], iEntity);
				else EmitSoundToAll(SOUND_DEFAULT_SPAWN, iEntity);
			}
		}
		case RocketSound_Beep:
		{
			if (TestFlags(iFlags, RocketFlag_PlayBeepSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomBeepSound))EmitSoundToAll(g_strRocketClassBeepSound[iClass], iEntity);
				else EmitSoundToAll(SOUND_DEFAULT_BEEP, iEntity);
			}
		}
		case RocketSound_Alert:
		{
			if (TestFlags(iFlags, RocketFlag_PlayAlertSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomAlertSound))EmitSoundToClient(iTarget, g_strRocketClassAlertSound[iClass]);
				else EmitSoundToClient(iTarget, SOUND_DEFAULT_ALERT, _, _, _, _, 0.5);
			}
		}
	}
}

//  ___         _       _      ___ _
// | _ \___  __| |_____| |_   / __| |__ _ ______ ___ ___
// |   / _ \/ _| / / -_)  _| | (__| / _` (_-<_-</ -_|_-<
// |_|_\___/\__|_\_\___|\__|  \___|_\__,_/__/__/\___/__/
//

/* DestroyRocketClasses()
**
** Frees up all the rocket classes defined now.
** -------------------------------------------------------------------------- */
void DestroyRocketClasses()
{
	for (int iIndex = 0; iIndex < g_iRocketClassCount; iIndex++)
	{
		Handle hCmdOnSpawn = g_hRocketClassCmdsOnSpawn[iIndex];
		Handle hCmdOnKill = g_hRocketClassCmdsOnKill[iIndex];
		Handle hCmdOnExplode = g_hRocketClassCmdsOnExplode[iIndex];
		Handle hCmdOnDeflect = g_hRocketClassCmdsOnDeflect[iIndex];
		if (hCmdOnSpawn != INVALID_HANDLE)CloseHandle(hCmdOnSpawn);
		if (hCmdOnKill != INVALID_HANDLE)CloseHandle(hCmdOnKill);
		if (hCmdOnExplode != INVALID_HANDLE)CloseHandle(hCmdOnExplode);
		if (hCmdOnDeflect != INVALID_HANDLE)CloseHandle(hCmdOnDeflect);
		g_hRocketClassCmdsOnSpawn[iIndex] = INVALID_HANDLE;
		g_hRocketClassCmdsOnKill[iIndex] = INVALID_HANDLE;
		g_hRocketClassCmdsOnExplode[iIndex] = INVALID_HANDLE;
		g_hRocketClassCmdsOnDeflect[iIndex] = INVALID_HANDLE;
	}
	g_iRocketClassCount = 0;
	ClearTrie(g_hRocketClassTrie);
}

//  ___                          ___     _     _                     _    ___ _
// / __|_ __  __ ___ __ ___ _   | _ \___(_)_ _| |_ ___  __ _ _ _  __| |  / __| |__ _ ______ ___ ___
// \__ \ '_ \/ _` \ V  V / ' \  |  _/ _ \ | ' \  _(_-< / _` | ' \/ _` | | (__| / _` (_-<_-</ -_|_-<
// |___/ .__/\__,_|\_/\_/|_||_| |_| \___/_|_||_\__/__/ \__,_|_||_\__,_|  \___|_\__,_/__/__/\___/__/
//     |_|

/* DestroyRocketSpawners()
**
** Frees up all the spawner points defined up to now.
** -------------------------------------------------------------------------- */
void DestroyRocketSpawners()
{
	for (int iIndex = 0; iIndex < g_iRocketSpawnersCount; iIndex++)
	{
		CloseHandle(g_hRocketSpawnersChancesTable[iIndex]);
	}
	g_iRocketSpawnersCount = 0;
	for (int arena_index = 1; arena_index <= g_iArenaCount; arena_index++)
	{
		g_iRocketSpawnPointsRedCount[arena_index] = 0;
		g_iRocketSpawnPointsBluCount[arena_index] = 0;
	}
	g_iDefaultRedRocketSpawner = -1;
	g_iDefaultBluRocketSpawner = -1;
	g_strSavedClassName[0] = '\0';
	ClearTrie(g_hRocketSpawnersTrie);
}

/* PopulateRocketSpawnPoints()
**
** Iterates through all the possible rocket spawn points and assigns them a spawner.
** -------------------------------------------------------------------------- */
void PopulateRocketSpawnPoints(int arena_index)
{
	// Clear the current settings
	g_iRocketSpawnPointsRedCount[arena_index] = 0;
	g_iRocketSpawnPointsBluCount[arena_index] = 0;
	
	char spawnerNameRed[64];
	// Spawners should have their arena name prepended.
	strcopy(spawnerNameRed, sizeof(spawnerNameRed), g_sArenaName[arena_index]);
	StrCat(spawnerNameRed, sizeof(spawnerNameRed), "_rocket_spawn_red");
	
	char spawnerNameBlu[64];
	// Spawners should have their arena name prepended.
	strcopy(spawnerNameBlu, sizeof(spawnerNameBlu), g_sArenaName[arena_index]);
	StrCat(spawnerNameBlu, sizeof(spawnerNameBlu), "_rocket_spawn_blue");
	
	// Iterate through all the info target points and check 'em out.
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "info_target")) != -1)
	{
		char strName[32]; GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
		if (StrEqual(strName, spawnerNameRed))
		{
			// Find most appropiate spawner class for this entity.
			int iIndex = FindRocketSpawnerByName(strName);
			if (!IsValidRocket(iIndex))
			{
				iIndex = g_iDefaultRedRocketSpawner;
			}

			// Upload to point list
			g_iRocketSpawnPointsRedClass[g_iRocketSpawnPointsRedCount[arena_index]][arena_index] = iIndex;
			g_iRocketSpawnPointsRedEntity[g_iRocketSpawnPointsRedCount[arena_index]][arena_index] = iEntity;
			g_iRocketSpawnPointsRedCount[arena_index]++;
		}
		if (StrEqual(strName, spawnerNameBlu))
		{
			// Find most appropiate spawner class for this entity.
			int iIndex = FindRocketSpawnerByName(strName);
			if (!IsValidRocket(iIndex))
			{
				iIndex = g_iDefaultBluRocketSpawner;
			}

			// Upload to point list
			g_iRocketSpawnPointsBluClass[g_iRocketSpawnPointsBluCount[arena_index]][arena_index] = iIndex;
			g_iRocketSpawnPointsBluEntity[g_iRocketSpawnPointsBluCount[arena_index]][arena_index] = iEntity;
			g_iRocketSpawnPointsBluCount[arena_index]++;
		}
	}

	// Check if there exists spawn points
	if (g_iRocketSpawnPointsRedCount[arena_index] == 0)
		SetFailState("No RED spawn points found in this arena.");

	if (g_iRocketSpawnPointsBluCount[arena_index] == 0)
		SetFailState("No BLU spawn points found in this arena.");
}

/* FindRocketSpawnerByName()
**
** Finds the first spawner wich contains the given name.
** -------------------------------------------------------------------------- */
int FindRocketSpawnerByName(char strName[32])
{
	int iIndex = -1;
	GetTrieValue(g_hRocketSpawnersTrie, strName, iIndex);
	return iIndex;
}

/*
**����������������������������������������������������������������������������������
**    ______            _____
**   / ____/___  ____  / __(_)___ _
**  / /   / __ \/ __ \/ /_/ / __ `/
** / /___/ /_/ / / / / __/ / /_/ /
** \____/\____/_/ /_/_/ /_/\__, /
**                        /____/
**����������������������������������������������������������������������������������
*/

/* ParseConfiguration()
**
** Parses a Dodgeball configuration file. It doesn't clear any of the previous
** data, so multiple files can be parsed.
** -------------------------------------------------------------------------- */
bool ParseConfigurations(char strConfigFile[] = "general.cfg")
{
	// Parse configuration
	char strPath[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	Format(strFileName, sizeof(strFileName), "configs/dodgeball/%s", strConfigFile);
	BuildPath(Path_SM, strPath, sizeof(strPath), strFileName);

	// Try to parse if it exists
	LogMessage("Executing configuration file %s", strPath);
	if (FileExists(strPath, true))
	{
		KeyValues kvConfig = CreateKeyValues("TF2_Dodgeball");

		if (FileToKeyValues(kvConfig, strPath) == false)
			SetFailState("Error while parsing the configuration file.");

		kvConfig.GotoFirstSubKey();

		// Parse the subsections
		do
		{
			char strSection[64];
			KvGetSectionName(kvConfig, strSection, sizeof(strSection));

			if (StrEqual(strSection, "classes"))
				ParseRocketClasses(kvConfig);
			else if (StrEqual(strSection, "spawners"))
				ParseRocketSpawners(kvConfig);
		}
		while (KvGotoNextKey(kvConfig));

		CloseHandle(kvConfig);
	}
}

/* ParseClasses()
**
** Parses the rocket classes data from the given configuration file.
** -------------------------------------------------------------------------- */
void ParseRocketClasses(Handle kvConfig)
{
	char strName[64];
	char strBuffer[256];

	KvGotoFirstSubKey(kvConfig);
	do
	{
		int iIndex = g_iRocketClassCount;
		RocketFlags iFlags;

		// Basic parameters
		KvGetSectionName(kvConfig, strName, sizeof(strName)); strcopy(g_strRocketClassName[iIndex], 16, strName);
		KvGetString(kvConfig, "name", strBuffer, sizeof(strBuffer)); strcopy(g_strRocketClassLongName[iIndex], 32, strBuffer);
		if (KvGetString(kvConfig, "model", strBuffer, sizeof(strBuffer)))
		{
			strcopy(g_strRocketClassModel[iIndex], PLATFORM_MAX_PATH, strBuffer);
			if (strlen(g_strRocketClassModel[iIndex]) != 0)
			{
				iFlags |= RocketFlag_CustomModel;
				if (KvGetNum(kvConfig, "is animated", 0))iFlags |= RocketFlag_IsAnimated;
			}
		}

		KvGetString(kvConfig, "behaviour", strBuffer, sizeof(strBuffer), "homing");
		if (StrEqual(strBuffer, "homing"))g_iRocketClassBehaviour[iIndex] = Behaviour_Homing;
		else g_iRocketClassBehaviour[iIndex] = Behaviour_Unknown;

		if (KvGetNum(kvConfig, "play spawn sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlaySpawnSound;
			if (KvGetString(kvConfig, "spawn sound", g_strRocketClassSpawnSound[iIndex], PLATFORM_MAX_PATH) && (strlen(g_strRocketClassSpawnSound[iIndex]) != 0))
			{
				iFlags |= RocketFlag_CustomSpawnSound;
			}
		}

		if (KvGetNum(kvConfig, "play beep sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlayBeepSound;
			g_fRocketClassBeepInterval[iIndex] = KvGetFloat(kvConfig, "beep interval", 0.5);
			if (KvGetString(kvConfig, "beep sound", g_strRocketClassBeepSound[iIndex], PLATFORM_MAX_PATH) && (strlen(g_strRocketClassBeepSound[iIndex]) != 0))
			{
				iFlags |= RocketFlag_CustomBeepSound;
			}
		}

		if (KvGetNum(kvConfig, "play alert sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlayAlertSound;
			if (KvGetString(kvConfig, "alert sound", g_strRocketClassAlertSound[iIndex], PLATFORM_MAX_PATH) && strlen(g_strRocketClassAlertSound[iIndex]) != 0)
			{
				iFlags |= RocketFlag_CustomAlertSound;
			}
		}

		// Behaviour modifiers
		if (KvGetNum(kvConfig, "elevate on deflect", 1) == 1)iFlags |= RocketFlag_ElevateOnDeflect;
		if (KvGetNum(kvConfig, "neutral rocket", 0) == 1)iFlags |= RocketFlag_IsNeutral;

		// Movement parameters
		g_fRocketClassDamage[iIndex] = KvGetFloat(kvConfig, "damage");
		g_fRocketClassDamageIncrement[iIndex] = KvGetFloat(kvConfig, "damage increment");
		g_fRocketClassCritChance[iIndex] = KvGetFloat(kvConfig, "critical chance");
		g_fRocketClassSpeed[iIndex] = KvGetFloat(kvConfig, "speed");
		g_fRocketClassSpeedIncrement[iIndex] = KvGetFloat(kvConfig, "speed increment");
		g_fRocketClassTurnRate[iIndex] = KvGetFloat(kvConfig, "turn rate");
		g_fRocketClassTurnRateIncrement[iIndex] = KvGetFloat(kvConfig, "turn rate increment");
		g_fRocketClassElevationRate[iIndex] = KvGetFloat(kvConfig, "elevation rate");
		g_fRocketClassElevationLimit[iIndex] = KvGetFloat(kvConfig, "elevation limit");
		g_fRocketClassControlDelay[iIndex] = KvGetFloat(kvConfig, "control delay");
		KvGetString(kvConfig, "drag behaviour", strBuffer, sizeof(strBuffer), "direction");
		if (StrEqual(strBuffer, "direction"))g_iRocketClassDragType[iIndex] = DragType_Direction;
		else if (StrEqual(strBuffer, "aim"))g_iRocketClassDragType[iIndex] = DragType_Aim;
		g_fRocketClassPlayerModifier[iIndex] = KvGetFloat(kvConfig, "no. players modifier");
		g_fRocketClassRocketsModifier[iIndex] = KvGetFloat(kvConfig, "no. rockets modifier");
		g_fRocketClassTargetWeight[iIndex] = KvGetFloat(kvConfig, "direction to target weight");

		// Done
		SetTrieValue(g_hRocketClassTrie, strName, iIndex);
		g_iRocketClassFlags[iIndex] = iFlags;
		g_iRocketClassCount++;
	}
	while (KvGotoNextKey(kvConfig));
	KvGoBack(kvConfig);
}

/* ParseSpawners()
**
** Parses the spawn points classes data from the given configuration file.
** -------------------------------------------------------------------------- */
void ParseRocketSpawners(KeyValues kvConfig)
{
    kvConfig.JumpToKey("spawners"); //jump to spawners section
    char strBuffer[256];
    kvConfig.GotoFirstSubKey(); //goto to first subkey of "spawners" section

    do
    {
        int iIndex = g_iRocketSpawnersCount;

        // Basic parameters
        kvConfig.GetSectionName(strBuffer, sizeof(strBuffer)); //okay, here we got section name, as example, red
        strcopy(g_strRocketSpawnersName[iIndex], 32, strBuffer); //here we copied it to the g_strSpawnersName array
        g_iSpawnersMaxRockets[iIndex] = kvConfig.GetNum("max rockets", 1); //get some values...
        g_fRocketSpawnersInterval[iIndex] = kvConfig.GetFloat("interval", 1.0);

        // Chances table
        g_hRocketSpawnersChancesTable[iIndex] = CreateArray(); //not interested in this
        for (int iClassIndex = 0; iClassIndex < g_iRocketClassCount; iClassIndex++)
        {
            Format(strBuffer, sizeof(strBuffer), "%s%%", g_strRocketClassName[iClassIndex]);
            PushArrayCell(g_hRocketSpawnersChancesTable[iIndex], KvGetNum(kvConfig, strBuffer, 0));
            if (KvGetNum(kvConfig, strBuffer, 0) == 100)	strcopy(g_strSavedClassName, sizeof(g_strSavedClassName), g_strRocketClassLongName[iClassIndex]);
        }

        // Done.
        SetTrieValue(g_hRocketSpawnersTrie, g_strRocketSpawnersName[iIndex], iIndex); //okay, push section name to g_hSpawnersTrie
        g_iRocketSpawnersCount++;
    } while (kvConfig.GotoNextKey());

    kvConfig.Rewind(); //rewind

    GetTrieValue(g_hRocketSpawnersTrie, "Red", g_iDefaultRedRocketSpawner); //get value by section name, section name exists in the g_hSpawnersTrie, everything should work
    GetTrieValue(g_hRocketSpawnersTrie, "Blue", g_iDefaultBluRocketSpawner);
}

// ====[ MGE CVARS ]====================================================
// i think this shit needs a switch case rewrite
public void handler_ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gcvar_fragLimit)
		g_iDefaultFragLimit = StringToInt(newValue);
	else if (convar == gcvar_autoCvar)
		StringToInt(newValue) ? (g_bAutoCvar = true) : (g_bAutoCvar = false);
	else if (convar == gcvar_arenaFile)
	{
		strcopy(g_arenaFile, sizeof(g_arenaFile), newValue);
		LoadPlayerSpawnPoints();
	}
}

// ====[ COMMANDS ]====================================================
public Action Command_Menu(int client, int args)
{  	
	//handle commands "!ammomod" "!add" and such //building queue's menu and listing arena's	
	int playerPrefTeam = 0;
	
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	char sArg[32];
	if (GetCmdArg(1, sArg, sizeof(sArg)) > 0)
	{
		//If they want to add to a color
		char cArg[32];
		if (GetCmdArg(2, cArg, sizeof(cArg)) > 0)
		{
			if (StrContains("blu", cArg, false) >= 0)
			{
				playerPrefTeam = TEAM_BLU;
			}
			else if (StrContains("red", cArg, false) >= 0)
			{
				playerPrefTeam = TEAM_RED;
			}
		}
		// Was the argument an arena_index number?
		int iArg = StringToInt(sArg);
		if (iArg > 0 && iArg <= g_iArenaCount)
		{
			if (g_iPlayerArena[client] == iArg)
				return Plugin_Handled;
			
			if (g_iPlayerArena[client])
				RemoveFromQueue(client, true);
			
			AddInQueue(client, iArg, true, playerPrefTeam);
			return Plugin_Handled;
		}
		
		// Was the argument an arena name?
		GetCmdArgString(sArg, sizeof(sArg));
		int count;
		int found_arena;
		for (int i = 1; i <= g_iArenaCount; i++)
		{
			if (StrContains(g_sArenaName[i], sArg, false) >= 0)
			{
				count++;
				found_arena = i;
				if (count > 1)
				{
					ShowMainMenu(client);
					return Plugin_Handled;
				}
			}
		}
		
		// If there was only one string match, and it was a valid match, place the player in that arena if they aren't already in it.
		if (found_arena > 0 && found_arena <= g_iArenaCount && found_arena != g_iPlayerArena[client])
		{
			if (g_iPlayerArena[client])
				RemoveFromQueue(client, true);
			
			AddInQueue(client, found_arena, true, playerPrefTeam);
			return Plugin_Handled;
		}
	}
	
	// Couldn't find a matching arena for the argument.
	ShowMainMenu(client);
	return Plugin_Handled;
}

public Action Command_Remove(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	RemoveFromQueue(client, true);
	return Plugin_Handled;
}

public Action Command_Spec(int client, int args)
{  //detecting spectator target
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	CreateTimer(0.1, Timer_ChangeSpecTarget, GetClientUserId(client));
	return Plugin_Continue;
}

public Action Command_AddBot(int client, int args)
{  //adding bot to client's arena
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	int arena_index = g_iPlayerArena[client];
	int player_slot = g_iPlayerSlot[client];
	
	if (arena_index && (player_slot == SLOT_ONE || player_slot == SLOT_TWO || (g_bFourPersonArena[arena_index] && (player_slot == SLOT_THREE || player_slot == SLOT_FOUR))))
	{
		ServerCommand("tf_bot_add");
		g_bPlayerAskedForBot[client] = true;
	}
	return Plugin_Handled;
}

public Action Command_Loc(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	float vec[3];
	float ang[3];
	GetClientAbsOrigin(client, vec);
	GetClientEyeAngles(client, ang);
	PrintToChat(client, "%.0f %.0f %.0f %.0f", vec[0], vec[1], vec[2], ang[1]);
	return Plugin_Handled;
}

public Action Command_ToogleHitblip(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	g_bHitBlip[client] = !g_bHitBlip[client];
	
	PrintToChat(client, "\x01Hitblip is \x04%sabled\x01.", g_bHitBlip[client] ? "en":"dis");
	return Plugin_Handled;
}

public Action Command_ToggleHud(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	g_bShowHud[client] = !g_bShowHud[client];
	
	if (g_bShowHud[client])
	{
		if (g_iPlayerArena[client])
			ShowPlayerHud(client);
		else
			ShowSpecHudToClient(client);
	} else {
		HideHud(client);
	}
	
	PrintToChat(client, "\x01HUD is \x04%sabled\x01.", g_bShowHud[client] ? "en":"dis");
	return Plugin_Handled;
}

public Action Command_Help(int client, int args)
{
	if (!client || !IsValidClient(client))
		return Plugin_Continue;
	
	PrintToChat(client, "%t", "Cmd_SeeConsole");
	PrintToConsole(client, "\n\n----------------------------");
	PrintToConsole(client, "%t", "Cmd_MGECmds");
	PrintToConsole(client, "%t", "Cmd_TFDBMGE");
	PrintToConsole(client, "%t", "Cmd_Add");
	PrintToConsole(client, "%t", "Cmd_Remove");
	PrintToConsole(client, "%t", "Cmd_First");
	PrintToConsole(client, "%t", "Cmd_Top5");
	PrintToConsole(client, "%t", "Cmd_Rank");
	PrintToConsole(client, "%t", "Cmd_HitBlip");
	PrintToConsole(client, "%t", "Cmd_Hud");
	PrintToConsole(client, "%t", "Cmd_Handicap");
	PrintToConsole(client, "----------------------------\n\n");
	
	return Plugin_Handled;
}

public Action Command_First(int client, int args)
{
	if (!client || !IsValidClient(client))
		return Plugin_Continue;
	
	// Try to find an arena with one person in the queue..
	for (int i = 1; i <= g_iArenaCount; i++)
	{
		if (!g_iArenaQueue[i][SLOT_TWO] && g_iPlayerArena[client] != i)
		{
			if (g_iArenaQueue[i][SLOT_ONE])
			{
				if (g_iPlayerArena[client])
					RemoveFromQueue(client, true);
				
				AddInQueue(client, i, true);
				return Plugin_Handled;
			}
		}
	}
	
	// Couldn't find an arena with only one person in the queue, so find one with none.
	if (!g_iPlayerArena[client])
	{
		for (int i = 1; i <= g_iArenaCount; i++)
		{
			if (!g_iArenaQueue[i][SLOT_TWO] && g_iPlayerArena[client] != i)
			{
				if (g_iPlayerArena[client])
					RemoveFromQueue(client, true);
				
				AddInQueue(client, i, true);
				return Plugin_Handled;
			}
		}
	}
	
	// Couldn't find any empty or half-empty arenas, so display the menu.
	ShowMainMenu(client);
	return Plugin_Handled;
}

public Action Command_DodgeballAdminMenu(int client, int args)
{
	Menu menu = new Menu(DodgeballAdmin_Handler, MENU_ACTIONS_ALL);

	menu.SetTitle("Dodgeball Admin Menu");

	menu.AddItem("0", "Main Rocket Class");
	menu.AddItem("1", "Refresh Configurations");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int DodgeballAdmin_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Start:
		{
			// It's important to log anything in any way, the best is printtoserver, but if you just want to log to client to make it easier to get progress done, feel free.
			PrintToServer("Displaying menu"); // Log it
		}

		case MenuAction_Display:
		{
			PrintToServer("Client %d was sent menu with panel %x", param1, param2); // Log so you can check if it gets sent.
		}

		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			switch (param2)
			{
				case 0:
				{
					if (!g_strSavedClassName[0]) {
						MC_PrintToChat(param1, "\x05No\01 main rocket class detected, \x05aborting\01...");
						return;
					}
					DrawRocketClassMenu(param1);
				}
				case 1:
				{
					// Clean up everything
					DestroyRocketClasses();
					DestroyRocketSpawners();
					// Then reinitialize
					char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
					char strMapFile[PLATFORM_MAX_PATH]; Format(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
					ParseConfigurations();
					ParseConfigurations(strMapFile);
					MC_PrintToChatAll("\x05%N\01 refreshed the \x05dodgeball configs\01.", param1);
				}
			}
		}

		case MenuAction_Cancel:
		{
			PrintToServer("Client %d's menu was cancelled for reason %d", param1, param2); // Logging once again.
		}

		case MenuAction_End:
		{
			delete menu;
		}

		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}

		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
}

void DrawRocketClassMenu(int client)
{
	Menu menu = new Menu(DodgeballAdminRocketClass_Handler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("Which class should the rocket be set to?");
	
	for (int currentClass = 0; currentClass < g_iRocketClassCount; currentClass++)
	{
		char classNumber[16];
		IntToString(currentClass, classNumber, sizeof(classNumber));
		if (StrEqual(g_strSavedClassName, g_strRocketClassLongName[currentClass]))
		{
			char currentClassName[32];
			strcopy(currentClassName, sizeof(currentClassName), "[Current] ");
			StrCat(currentClassName, sizeof(currentClassName), g_strSavedClassName);
			menu.AddItem(classNumber, currentClassName);
		}
		else menu.AddItem(classNumber, g_strRocketClassLongName[currentClass]);
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int DodgeballAdminRocketClass_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Start:
		{
			// It's important to log anything in any way, the best is printtoserver, but if you just want to log to client to make it easier to get progress done, feel free.
			PrintToServer("Displaying menu"); // Log it
		}
		
		case MenuAction_Display:
		{
			PrintToServer("Client %d was sent menu with panel %x", param1, param2); // Log so you can check if it gets sent.
		}
		
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			
			SetMainRocketClass(param2, false, param1);
		}
		
		case MenuAction_Cancel:
		{
			PrintToServer("Client %d's menu was cancelled for reason %d", param1, param2); // Logging once again.
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
}

/*
**����������������������������������������������������������������������������������
**	   __  ___													__
**	  /  |/  /___ _____  ____ _____ ____  ____ ___  ___  ____  / /_
**   / /|_/ / __ `/ __ \/ __ `/ __ `/ _ \/ __ `__ \/ _ \/ __ \/ __/
**  / /  / / /_/ / / / / /_/ / /_/ /  __/ / / / / /  __/ / / / /_
** /_/  /_/\__,_/_/ /_/\__,_/\__, /\___/_/ /_/ /_/\___/_/ /_/\__/
**							/____/
**����������������������������������������������������������������������������������
*/

//   ___                       _
//  / __|___ _ _  ___ _ _ __ _| |
// | (_ / -_) ' \/ -_) '_/ _` | |
//  \___\___|_||_\___|_| \__,_|_|

/* EnableDodgeBall()
**
** Enables and hooks all the required events.
** -------------------------------------------------------------------------- */
void EnableDodgeball()
{
	// Parse configuration files
	char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
	char strMapFile[PLATFORM_MAX_PATH]; Format(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
	ParseConfigurations();
	ParseConfigurations(strMapFile);

	ServerCommand("tf_flamethrower_burstammo 0");
	ServerCommand("tf_dodgeball_rbmax %f", GetConVarFloat(g_hMaxBouncesConVar));

	// Check if we have all the required information
	if (g_iRocketClassCount == 0)
		SetFailState("No rocket class defined.");

	if (g_iRocketSpawnersCount == 0)
		SetFailState("No spawner class defined.");

	if (g_iDefaultRedRocketSpawner == -1)
		SetFailState("No spawner class definition for the Red spawners exists in the config file.");

	if (g_iDefaultBluRocketSpawner == -1)
		SetFailState("No spawner class definition for the Blu spawners exists in the config file.");

	// Hook events and info_target outputs.
	HookEvent("object_deflected", Event_ObjectDeflected);
	HookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Post);

	// Precache sounds
	PrecacheSound(SOUND_DEFAULT_SPAWN, true);
	PrecacheSound(SOUND_DEFAULT_BEEP, true);
	PrecacheSound(SOUND_DEFAULT_ALERT, true);
	PrecacheSound(SOUND_DEFAULT_SPEEDUPALERT, true);

	// Precache particles
	PrecacheParticle(PARTICLE_NUKE_1);
	PrecacheParticle(PARTICLE_NUKE_2);
	PrecacheParticle(PARTICLE_NUKE_3);
	PrecacheParticle(PARTICLE_NUKE_4);
	PrecacheParticle(PARTICLE_NUKE_5);
	PrecacheParticle(PARTICLE_NUKE_COLLUMN);
}

/* DisableDodgeball()
**
** Disables all hooks and frees arrays.
** -------------------------------------------------------------------------- */
void DisableDodgeball()
{
	// Clean up everything
	DestroyRockets();
	DestroyRocketClasses();
	DestroyRocketSpawners();
	if (g_hLogicTimer != INVALID_HANDLE)
	{
		KillTimer(g_hLogicTimer);
	}
	g_hLogicTimer = INVALID_HANDLE;

	// Unhook events and info_target outputs;
	UnhookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Post);
}

/*
** ------------------------------------------------------------------
**		______                  __      
**	   / ____/_   _____  ____  / /______
**	  / __/  | | / / _ \/ __ \/ __/ ___/
**	 / /___  | |/ /  __/ / / / /_(__  ) 
**	/_____/  |___/\___/_/ /_/\__/____/  
** 
** ------------------------------------------------------------------
**/

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int arena_index = g_iPlayerArena[iClient];
	
	if (!IsValidClient(iClient))return;
	
	if(!g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] != SLOT_ONE && g_iPlayerSlot[iClient] != SLOT_TWO)
	{
		ChangeClientTeam(iClient, TEAM_SPEC);
		return;
	}
		
	else if(g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] != SLOT_ONE && g_iPlayerSlot[iClient] != SLOT_TWO && (g_iPlayerSlot[iClient]!=SLOT_THREE && g_iPlayerSlot[iClient]!=SLOT_FOUR))
	{
		ChangeClientTeam(iClient, TEAM_SPEC);
		return;
	}
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	if (!(iClass == TFClass_Pyro || iClass == view_as<TFClassType>(TFClass_Unknown)))
	{
		TF2_SetPlayerClass(iClient, TFClass_Pyro, false, true);
		TF2_RespawnPlayer(iClient);
	}
	
	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
			SetEntPropEnt(i, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(i, TFWeaponSlot_Primary));
	}
	
	if (!GetConVarBool(g_hCvarPyroVisionEnabled))
	{
		return;
	}
	TF2Attrib_SetByName(iClient, PYROVISION_ATTRIBUTE, 1.0);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int arena_index = g_iPlayerArena[victim];
	int victim_slot = g_iPlayerSlot[victim];
	
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(iVictim))
	{
		g_iLastDeadClient[g_iPlayerArena[iVictim]] = iVictim;
		g_iLastDeadTeam[g_iPlayerArena[iVictim]] = GetClientTeam(iVictim);

		int iInflictor = GetEventInt(event, "inflictor_entindex");
		int iIndex = FindRocketByEntity(iInflictor);

		if (iIndex != -1)
		{
			int iTarget = EntRefToEntIndex(g_iRocketTarget[iIndex]);
			int iDeflections = g_iRocketDeflections[iIndex];

			float fSpeed = CalculateSpeed(g_fRocketSpeed[iIndex]);

			if (GetConVarBool(g_hCvarAnnounce))
			{
				if (GetConVarBool(g_hCvarDeflectCountAnnounce))
				{
					if (iVictim == iTarget)
					{
						MC_PrintToChatAll("\x05%N\01 died to their rocket travelling \x05%.0f\x01 mph with \x05%i\x01 deflections!", g_iLastDeadClient, fSpeed, iDeflections);
					}
					else
					{
						MC_PrintToChatAll("\x05%N\x01 died to \x05%.15N's\x01 rocket travelling \x05%.0f\x01 mph with \x05%i\x01 deflections!", g_iLastDeadClient, iTarget, fSpeed, iDeflections);
					}
				}
				else
				{
					MC_PrintToChatAll("\x05%N\01 died to a rocket travelling \x05%.f\x01 mph!", g_iLastDeadClient, fSpeed);
				}
			}
		}
	}

	SetRandomSeed(view_as<int>(GetGameTime()));
	
	int killer_slot = (victim_slot == SLOT_ONE || victim_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
	int killer = g_iArenaQueue[arena_index][killer_slot];
	int killer_teammate;
	int victim_teammate;
	
	//gets the killer and victims team slot (red 1, blu 2)
	int killer_team_slot = (killer_slot > 2) ? (killer_slot - 2) : killer_slot;
	int victim_team_slot = (victim_slot > 2) ? (victim_slot - 2) : victim_slot;
	
	if (g_bFourPersonArena[arena_index])
	{
		victim_teammate = getTeammate(victim, victim_slot, arena_index);
		killer_teammate = getTeammate(killer, killer_slot, arena_index);
	}
	
	if (!arena_index)
	{
		ChangeClientTeam(victim, TEAM_SPEC);
	}
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (g_iArenaStatus[arena_index] < AS_FIGHT && IsValidClient(attacker) && IsPlayerAlive(attacker))
	{
		TF2_RegeneratePlayer(attacker);
		int raised_hp = RoundToNearest(float(g_iPlayerMaxHP[attacker]) * g_fArenaHPRatio[arena_index]);
		g_iPlayerHP[attacker] = raised_hp;
		SetEntProp(attacker, Prop_Data, "m_iHealth", raised_hp);
	}
	
	if (g_iArenaStatus[arena_index] < AS_FIGHT || g_iArenaStatus[arena_index] > AS_FIGHT)
	{
		CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(victim));
		return Plugin_Handled;
	}
	
	if ((g_bFourPersonArena[arena_index] && !IsPlayerAlive(killer)) || (g_bFourPersonArena[arena_index] && !IsPlayerAlive(killer_teammate) && !IsPlayerAlive(killer)))
	{
	}
	
	if (!g_bFourPersonArena[arena_index] || (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate))) // Kills shouldn't give points in bball. Or if only 1 player in a two person arena dies
		g_iArenaScore[arena_index][killer_team_slot] += 1;
	
	//Currently set up so that if its a 2v2 duel the round will reset after both players on one team die and a point will be added for that round to the other team
	//Another possibility is to make it like dm where its instant respawn for every player, killer gets hp, and a point is awarded for every kill
	
	int fraglimit = g_iArenaFraglimit[arena_index];
	
	if (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate) || !g_bFourPersonArena[arena_index])
	{
		g_iArenaStatus[arena_index] = AS_AFTERFIGHT;
		
		if (g_hTimerHud != INVALID_HANDLE)
		{
			KillTimer(g_hTimerHud);
			g_hTimerHud = INVALID_HANDLE;
		}
		//if (g_hLogicTimer != INVALID_HANDLE)
		//{
		//	KillTimer(g_hLogicTimer);
		//	g_hLogicTimer = INVALID_HANDLE;
		//}
		
		DestroyRockets();
	}
	
	if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && fraglimit > 0 && g_iArenaScore[arena_index][killer_team_slot] >= fraglimit)
	{
		g_iArenaStatus[arena_index] = AS_REPORTED;
		char killer_name[128];
		char victim_name[128];
		GetClientName(killer, killer_name, sizeof(killer_name));
		GetClientName(victim, victim_name, sizeof(victim_name));
		
		
		if (g_bFourPersonArena[arena_index])
		{
			char killer_teammate_name[128];
			char victim_teammate_name[128];
			
			GetClientName(killer_teammate, killer_teammate_name, sizeof(killer_teammate_name));
			GetClientName(victim_teammate, victim_teammate_name, sizeof(victim_teammate_name));
			
			Format(killer_name, sizeof(killer_name), "%s and %s", killer_name, killer_teammate_name);
			Format(victim_name, sizeof(victim_name), "%s and %s", victim_name, victim_teammate_name);
		}
		
		MC_PrintToChatAll("%t", "XdefeatsY", killer_name, g_iArenaScore[arena_index][killer_team_slot], victim_name, g_iArenaScore[arena_index][victim_team_slot], fraglimit, g_sArenaName[arena_index]);
		
		if (!g_bFourPersonArena[arena_index])
		{
			if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
			{
				RemoveFromQueue(victim, false, true);
				AddInQueue(victim, arena_index, false);
			} else {
				CreateTimer(3.0, Timer_StartDuel, arena_index);
			}
		}
		else
		{
			if (g_iArenaQueue[arena_index][SLOT_FOUR + 1] && g_iArenaQueue[arena_index][SLOT_FOUR + 2])
			{
				RemoveFromQueue(victim_teammate, false, true);
				RemoveFromQueue(victim, false, true);
				AddInQueue(victim_teammate, arena_index, false);
				AddInQueue(victim, arena_index, false);
			}
			else if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
			{
				RemoveFromQueue(victim, false, true);
				AddInQueue(victim, arena_index, false);
			}
			else {
				CreateTimer(3.0, Timer_StartDuel, arena_index);
			}
		}
	}
	else
	{
		if(!g_bFourPersonArena[arena_index])
		{
			ResetKiller(killer, arena_index);
			CreateTimer(3.0, Timer_NewRound, arena_index);
		}
		else if (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate))
		{
			CreateTimer(3.0, Timer_NewRound, arena_index);
		}
		
		if (g_bFourPersonArena[arena_index] && (GetClientTeam(victim_teammate) == TEAM_SPEC || !IsPlayerAlive(victim_teammate)))
		{
			//Reset the teams
			if (killer_team_slot == SLOT_ONE)
			{
				ChangeClientTeam(victim, TEAM_BLU);
				ChangeClientTeam(victim_teammate, TEAM_BLU);
				
				ChangeClientTeam(killer_teammate, TEAM_RED);
			}
			else
			{
				ChangeClientTeam(victim, TEAM_RED);
				ChangeClientTeam(victim_teammate, TEAM_RED);
				
				ChangeClientTeam(killer_teammate, TEAM_BLU);
			}
			
			//Should there be a 3 second count down in between rounds in 2v2 or just spawn and go?
			//Timer_NewRound would create a 3 second count down where as just reseting all the players would make it just go
			/*
			if (killer)
				ResetPlayer(killer);
			if (victim_teammate)
				ResetPlayer(victim_teammate);	
			if (victim)
				ResetPlayer(victim);
			if (killer_teammate)
				ResetPlayer(killer_teammate);
				
			g_iArenaStatus[arena_index] = AS_FIGHT;
			*/
			
			CreateTimer(0.1, Timer_NewRound, arena_index);
		}
		
		if (g_bFourPersonArena[arena_index] && victim_teammate && IsPlayerAlive(victim_teammate))
		{
			//Set the player as waiting
			g_iPlayerWaiting[victim] = true;
			//change the player to spec to keep him from respawning 
			CreateTimer(5.0, Timer_ChangePlayerSpec, victim);
			//instead of respawning him
			CreateTimer(g_fArenaRespawnTime[arena_index], Timer_ResetPlayer, GetClientUserId(victim));
		}
		else
			CreateTimer(g_fArenaRespawnTime[arena_index], Timer_ResetPlayer, GetClientUserId(victim));
		
	}
	
	ShowPlayerHud(victim);
	ShowPlayerHud(killer);
	
	if (g_bFourPersonArena[arena_index])
	{
		ShowPlayerHud(victim_teammate);
		ShowPlayerHud(killer_teammate);
	}
	
	ShowSpecHudToArena(arena_index);
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!client)
		return Plugin_Continue;
	
	int team = event.GetInt("team");
	
	if (team == TEAM_SPEC)
	{
		HideHud(client);
		CreateTimer(1.0, Timer_ChangeSpecTarget, GetClientUserId(client));
		int arena_index = g_iPlayerArena[client];
		
		if (arena_index && ((!g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] <= SLOT_TWO) || (g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] <= SLOT_FOUR && !isPlayerWaiting(client))))
		{
			MC_PrintToChat(client, "%t", "SpecRemove");
			RemoveFromQueue(client, true);
		}
	}
	else if (IsValidClient(client))
	{  // this code fixes spawn exploit
		int arena_index = g_iPlayerArena[client];
		
		if (arena_index == 0)
		{
			TF2_SetPlayerClass(client, view_as<TFClassType>(0));
		}
	}
	
	event.SetInt("silent", true);
	return Plugin_Changed;
}

/*
** Make sure the client only has the flamethrower equipped.
** -------------------------------------------------------------------------- */
public Action Event_PlayerInventory(Handle hEvent, char[] strEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(iClient))return;

	for (int iSlot = 1; iSlot < 5; iSlot++)
	{
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity != -1)RemoveEdict(iEntity);
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	gcvar_WfP.SetInt(1); //cancel waiting for players
	
	return Plugin_Continue;
}

/* OnPlayerRunCmd()
**
** Block flamethrower's Mouse1 attack and start predicting for any players that can.
** -------------------------------------------------------------------------- */
public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	iButtons &= ~IN_ATTACK;
	return Plugin_Continue;
}

/* OnObjectDeflected
**
**
** Check if client is human, don't airblast if bool is false
** -------------------------------------------------------------------------- */
public Action Event_ObjectDeflected(Handle event, const char[] name, bool dontBroadcast)
{
	int object1 = GetEventInt(event, "object_entindex");
	if ((object1 >= 1) && (object1 <= MaxClients))
	{
		float Vel[3];
		TeleportEntity(object1, NULL_VECTOR, NULL_VECTOR, Vel); // Stops knockback
		TF2_RemoveCondition(object1, TFCond_Dazed); // Stops slowdown
		SetEntPropVector(object1, Prop_Send, "m_vecPunchAngle", Vel);
		SetEntPropVector(object1, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake
	}
}

/*
** ------------------------------------------------------------------
**	 _______                          
**	 /_  __(_)____ ___  ___  __________
**	  / / / // __ `__ \/ _ \/ ___/ ___/
**	 / / / // / / / / /  __/ /  (__  ) 
**	/_/ /_//_/ /_/ /_/\___/_/  /____/  
**	
** ------------------------------------------------------------------
**/

public void RegenKiller(any killer)
{	
	TF2_RegeneratePlayer(killer);
}

public Action Timer_WelcomePlayer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (!IsValidClient(client))
		return;
	
	MC_PrintToChat(client, "%t", "Welcome1", PLUGIN_VERSION);
	if (StrContains(g_sMapName, "tfdbmge_", false) == 0)
		MC_PrintToChat(client, "%t", "Welcome2");
	MC_PrintToChat(client, "%t", "Welcome3");
	g_hWelcomeTimer[client] = null;
}

public Action Timer_SpecFix(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
		return;
	
	ChangeClientTeam(client, TEAM_RED);
	ChangeClientTeam(client, TEAM_SPEC);
}

public Action Timer_SpecHudToAllArenas(Handle timer, int userid)
{
	for (int i = 1; i <= g_iArenaCount; i++)
	{
		ShowSpecHudToArena(i);
	}
	
	return Plugin_Continue;
}

public Action Timer_CountDown(Handle timer, any arena_index)
{
	int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
	int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
	int red_f2;
	int blu_f2;
	if (g_bFourPersonArena[arena_index])
	{
		red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
		blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
	}
	if (g_bFourPersonArena[arena_index])
	{
		if (red_f1 && blu_f1 && red_f2 && blu_f2)
		{
			g_iArenaCd[arena_index]--;
			
			if (g_iArenaCd[arena_index] <= 3 && g_iArenaCd[arena_index] >= 1)
			{
				char msg[64];
				
				switch (g_iArenaCd[arena_index])
				{
					case 1:msg = "ONE";
					case 2:msg = "TWO";
					case 3:msg = "THREE";
				}
				
				PrintCenterText(red_f1, msg);
				PrintCenterText(blu_f1, msg);
				PrintCenterText(red_f2, msg);
				PrintCenterText(blu_f2, msg);
				ShowCountdownToSpec(arena_index, msg);
				g_iArenaStatus[arena_index] = AS_COUNTDOWN;
			} else if (g_iArenaCd[arena_index] <= 0)
			{
				g_iArenaStatus[arena_index] = AS_FIGHT;
				
				g_iRocketSpeed[arena_index] = 0;
				
				if (g_hTimerHud != INVALID_HANDLE)
				{
					KillTimer(g_hTimerHud);
					g_hTimerHud = INVALID_HANDLE;
				}
				g_hTimerHud = CreateTimer(1.0, Timer_HudSpeed, arena_index, TIMER_REPEAT);
				
				char msg[64];
				Format(msg, sizeof(msg), "FIGHT", g_iArenaCd[arena_index]);
				PrintCenterText(red_f1, msg);
				PrintCenterText(blu_f1, msg);
				PrintCenterText(red_f2, msg);
				PrintCenterText(blu_f2, msg);
				ShowCountdownToSpec(arena_index, msg);
				
				return Plugin_Stop;
			}
			
			
			CreateTimer(1.0, Timer_CountDown, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		} else {
			g_iArenaStatus[arena_index] = AS_IDLE;
			g_iArenaCd[arena_index] = 0;
			return Plugin_Stop;
		}
	}
	else
	{
		if (red_f1 && blu_f1)
		{
			g_iArenaCd[arena_index]--;
			
			if (g_iArenaCd[arena_index] <= 3 && g_iArenaCd[arena_index] >= 1)
			{
				char msg[64];
				
				switch (g_iArenaCd[arena_index])
				{
					case 1:msg = "ONE";
					case 2:msg = "TWO";
					case 3:msg = "THREE";
				}
				
				PrintCenterText(red_f1, msg);
				PrintCenterText(blu_f1, msg);
				ShowCountdownToSpec(arena_index, msg);
				g_iArenaStatus[arena_index] = AS_COUNTDOWN;
			} else if (g_iArenaCd[arena_index] <= 0) {
				g_iArenaStatus[arena_index] = AS_FIGHT;
				char msg[64];
				Format(msg, sizeof(msg), "FIGHT", g_iArenaCd[arena_index]);
				PrintCenterText(red_f1, msg);
				PrintCenterText(blu_f1, msg);
				ShowCountdownToSpec(arena_index, msg);
				
				return Plugin_Stop;
			}
			
			CreateTimer(1.0, Timer_CountDown, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		} else {
			g_iArenaStatus[arena_index] = AS_IDLE;
			g_iArenaCd[arena_index] = 0;
			return Plugin_Stop;
		}
	}
}

public Action Timer_Tele(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	int arena_index = g_iPlayerArena[client];
	
	if (!arena_index)
		return;
	
	int player_slot = g_iPlayerSlot[client];
	if ((!g_bFourPersonArena[arena_index] && player_slot > SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot > SLOT_FOUR))
	{
		return;
	}
	
	float vel[3] =  { 0.0, 0.0, 0.0 };
	
	// 2v2 arenas handle spawns differently, each team, has their own spawns.
	if (g_bFourPersonArena[arena_index])
	{
		int random_int;
		int offset_high, offset_low;
		if (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE)
		{
			offset_high = ((g_iArenaSpawns[arena_index]) / 2);
			random_int = GetRandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
		} else {
			offset_high = (g_iArenaSpawns[arena_index]);
			offset_low = (((g_iArenaSpawns[arena_index]) / 2) + 1);
			random_int = GetRandomInt(offset_low, offset_high);
		}
		
		TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
		EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
		ShowPlayerHud(client);
		return;
	}
	
	// Create an array that can hold all the arena's spawns.
	int[] RandomSpawn = new int[g_iArenaSpawns[arena_index] + 1];
	
	// Fill the array with the spawns.
	for (int i = 0; i < g_iArenaSpawns[arena_index]; i++)
	RandomSpawn[i] = i + 1;
	
	// Shuffle them into a random order.
	SortIntegers(RandomSpawn, g_iArenaSpawns[arena_index], Sort_Random);
	
	// Now when the array is gone through sequentially, it will still provide a random spawn.
	float besteffort_dist;
	int besteffort_spawn;
	for (int i = 0; i < g_iArenaSpawns[arena_index]; i++)
	{
		int client_slot = g_iPlayerSlot[client];
		int foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
		if (foe_slot)
		{
			float distance;
			int foe = g_iArenaQueue[arena_index][foe_slot];
			if (IsValidClient(foe))
			{
				float foe_pos[3];
				GetClientAbsOrigin(foe, foe_pos);
				distance = GetVectorDistance(foe_pos, g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]]);
				if (distance > g_fArenaMinSpawnDist[arena_index])
				{
					TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]], g_fArenaSpawnAngles[arena_index][RandomSpawn[i]], vel);
					EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]], _, SNDLEVEL_NORMAL, _, 1.0);
					ShowPlayerHud(client);
					return;
				} else if (distance > besteffort_dist) {
					besteffort_dist = distance;
					besteffort_spawn = i;
				}
			}
		}
	}
	
	if (besteffort_spawn)
	{
		// Couldn't find a spawn that was far enough away, so use the one that was the farthest.
		TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][besteffort_spawn], g_fArenaSpawnAngles[arena_index][besteffort_spawn], vel);
		EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][besteffort_spawn], _, SNDLEVEL_NORMAL, _, 1.0);
		ShowPlayerHud(client);
		return;
	} else {
		// No foe, so just pick a random spawn.
		int random_int = GetRandomInt(1, g_iArenaSpawns[arena_index]);
		TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
		EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
		ShowPlayerHud(client);
		return;
	}
}

public Action Timer_NewRound(Handle timer, any arena_index)
{
	PopulateRocketSpawnPoints(arena_index);
	
	if (g_iLastDeadTeam[arena_index] == 0)
	{
		g_iLastDeadTeam[arena_index] = GetURandomIntRange(view_as<int>(TFTeam_Red), view_as<int>(TFTeam_Blue));
	}
	if (!IsValidClient(g_iLastDeadClient[arena_index]))
	{
		g_iLastDeadClient[arena_index] = 0;
	}
	
	g_iPlayerCount[arena_index] = CountAlivePlayers(arena_index);
	g_iRocketsFired[arena_index] = 0;
	g_iCurrentRedRocketSpawn[arena_index] = 0;
	g_iCurrentBluRocketSpawn[arena_index] = 0;
	g_fNextRocketSpawnTime[arena_index] = GetGameTime();
	
	StartCountDown(arena_index);
}

public Action Timer_StartDuel(Handle timer, any arena_index)
{
	if (g_hLogicTimer == INVALID_HANDLE)
	{
		g_hLogicTimer = CreateTimer(FPS_LOGIC_INTERVAL, OnDodgeBallGameFrame, _, TIMER_REPEAT);
	}
	
	PopulateRocketSpawnPoints(arena_index);
	
	if (g_iLastDeadTeam[arena_index] == 0)
	{
		g_iLastDeadTeam[arena_index] = GetURandomIntRange(view_as<int>(TFTeam_Red), view_as<int>(TFTeam_Blue));
	}
	if (!IsValidClient(g_iLastDeadClient[arena_index]))
	{
		g_iLastDeadClient[arena_index] = 0;
	}
	
	g_iPlayerCount[arena_index] = CountAlivePlayers(arena_index);
	g_iRocketsFired[arena_index] = 0;
	g_iCurrentRedRocketSpawn[arena_index] = 0;
	g_iCurrentBluRocketSpawn[arena_index] = 0;
	g_fNextRocketSpawnTime[arena_index] = GetGameTime();
	
	g_iArenaScore[arena_index][SLOT_ONE] = 0;
	g_iArenaScore[arena_index][SLOT_TWO] = 0;
	ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_ONE]);
	ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_TWO]);
	
	if (g_bFourPersonArena[arena_index])
	{
		ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_THREE]);
		ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_FOUR]);
	}
	
	ShowSpecHudToArena(arena_index);
	
	StartCountDown(arena_index);
}

public Action Timer_ResetPlayer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (IsValidClient(client))
		ResetPlayer(client);
}

public Action Timer_ChangePlayerSpec(Handle timer, any player)
{
	if (IsValidClient(player) && !IsPlayerAlive(player))
		ChangeClientTeam(player, TEAM_SPEC);
}

public Action Timer_ChangeSpecTarget(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (!client || !IsValidClient(client))
		return Plugin_Stop;
	
	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
	if (IsValidClient(target) && g_iPlayerArena[target]) {
		g_iPlayerSpecTarget[client] = target;
		ShowSpecHudToClient(client);
	} else {
		HideHud(client);
		g_iPlayerSpecTarget[client] = 0;
	}
	
	return Plugin_Stop;
}

public Action Timer_ShowAdv(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (IsValidClient(client) && g_iPlayerArena[client] == 0)
	{
		MC_PrintToChat(client, "%t", "Adv");
		CreateTimer(15.0, Timer_ShowAdv, userid);
	}
	
	return Plugin_Continue;
}

public Action Timer_AddBotInQueue(Handle timer, DataPack pk)
{
	pk.Reset();
	int client = GetClientOfUserId(pk.ReadCell());
	int arena_index = pk.ReadCell();
	AddInQueue(client, arena_index);
}

public Action Timer_RegenArena(Handle timer, any arena_index)
{
	if (g_iArenaStatus[arena_index] != AS_FIGHT)
		return Plugin_Stop;
	
	int client = g_iArenaQueue[arena_index][SLOT_ONE];
	int client2 = g_iArenaQueue[arena_index][SLOT_TWO];
	
	if (IsPlayerAlive(client))
	{
		TF2_RegeneratePlayer(client);
		int raised_hp = RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]);
		g_iPlayerHP[client] = raised_hp;
		SetEntProp(client, Prop_Data, "m_iHealth", raised_hp);
	}
	
	if (IsPlayerAlive(client2))
	{
		TF2_RegeneratePlayer(client2);
		int raised_hp2 = RoundToNearest(float(g_iPlayerMaxHP[client2]) * g_fArenaHPRatio[arena_index]);
		g_iPlayerHP[client2] = raised_hp2;
		SetEntProp(client2, Prop_Data, "m_iHealth", raised_hp2);
	}
	
	if (g_bFourPersonArena[arena_index])
	{
		int client3 = g_iArenaQueue[arena_index][SLOT_THREE];
		int client4 = g_iArenaQueue[arena_index][SLOT_FOUR];
		if (IsPlayerAlive(client3))
		{
			TF2_RegeneratePlayer(client3);
			int raised_hp3 = RoundToNearest(float(g_iPlayerMaxHP[client3]) * g_fArenaHPRatio[arena_index]);
			g_iPlayerHP[client3] = raised_hp3;
			SetEntProp(client3, Prop_Data, "m_iHealth", raised_hp3);
		}
		if (IsPlayerAlive(client4))
		{
			TF2_RegeneratePlayer(client4);
			int raised_hp4 = RoundToNearest(float(g_iPlayerMaxHP[client4]) * g_fArenaHPRatio[arena_index]);
			g_iPlayerHP[client4] = raised_hp4;
			SetEntProp(client4, Prop_Data, "m_iHealth", raised_hp4);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_HudSpeed(Handle hTimer, int arena_index)
{
	if (GetConVarBool(g_hCvarSpeedo))
	{
		SetHudTextParams(-1.0, 0.9, 1.1, 255, 255, 255, 255);
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsValidClient(iClient) && !IsFakeClient(iClient) && g_iRocketSpeed[g_iPlayerArena[iClient]] != 0 && g_iPlayerArena[iClient] == arena_index)
			{
				ShowSyncHudText(iClient, g_hHud, "Speed: %i mph", g_iRocketSpeed[g_iPlayerArena[iClient]]);
			}
		}
	}
}

/*
**����������������������������������������������������������������������������������
**	 ______			   __
**  /_  __/___  ____  / /____
**   / / / __ \/ __ \/ / ___/
**  / / / /_/ / /_/ / (__  )
** /_/  \____/\____/_/____/
**
**����������������������������������������������������������������������������������
*/

stock int GetClosestRocket(float fPosition[3], int iTeam, int iClient = -1)
{
	float vPos1[3], vPos2[3];
	if (iClient != -1)
	{
		char clientname[MAX_NAME_LENGTH];
		GetClientName(iClient, clientname, sizeof(clientname));
		GetClientEyePosition(iClient, vPos1);
	}
	else
	{
		CopyVectors(fPosition, vPos1);
	}
	
	int iClosestEntity = -1;
	float flClosestDistance = -1.0;
	float flEntityDistance;

	int iEntity = -1;
			
	while((iEntity = FindEntityByClassname(iEntity, "tf_projectile_rocket")) != INVALID_ENT_REFERENCE)
	{
		if(IsValidEntity(iEntity))
		{
			char classname[32];
			GetEntityClassname(iEntity, classname, sizeof(classname));
			if (StrEqual(classname, "tf_projectile_rocket", false))
			{
				int rocketTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");
				if(rocketTeam != iTeam)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vPos2);
					flEntityDistance = GetVectorDistance(vPos1, vPos2);
					if((flEntityDistance < flClosestDistance) || flClosestDistance == -1.0)
					{
						flClosestDistance = flEntityDistance;
						iClosestEntity = iEntity;
					}
				}
			}
			else PrintToServer("GetClosestRocket: %s not a valid rocket!", classname);
		}
	}
	return iClosestEntity;
}

stock float GetBounceVelocity(float vVelocity[3], float vNormal[3])
{
	//Accurate
	float dotProduct = GetVectorDotProduct(vNormal, vVelocity);
	
	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);
	
	//Accurate
	float vBounceVec[3];
	float vCopyVelocity[3];
	vCopyVelocity = vVelocity;
	SubtractVectors(vCopyVelocity, vNormal, vBounceVec);
	return vBounceVec;
}

/* ApplyDamage()
**
** Applies a damage to a player.
** -------------------------------------------------------------------------- */
public Action ApplyDamage(Handle hTimer, any hDataPack)
{
	ResetPack(hDataPack, false);
	int iClient = ReadPackCell(hDataPack);
	int iDamage = ReadPackCell(hDataPack);
	CloseHandle(hDataPack);
	SlapPlayer(iClient, iDamage, true);
}

/* CopyVectors()
**
** Copies the contents from a vector to another.
** -------------------------------------------------------------------------- */
stock void CopyVectors(float fFrom[3], float fTo[3])
{
	fTo[0] = fFrom[0];
	fTo[1] = fFrom[1];
	fTo[2] = fFrom[2];
}

/* LerpVectors()
**
** Calculates the linear interpolation of the two given vectors and stores
** it on the third one.
** -------------------------------------------------------------------------- */
stock void LerpVectors(float fA[3], float fB[3], float fC[3], float t)
{
	if (t < 0.0)t = 0.0;
	if (t > 1.0)t = 1.0;

	fC[0] = fA[0] + (fB[0] - fA[0]) * t;
	fC[1] = fA[1] + (fB[1] - fA[1]) * t;
	fC[2] = fA[2] + (fB[2] - fA[2]) * t;
}

/* BothTeamsPlayingInArea()
**
** Checks if there are players on both teams in the given arena.
** -------------------------------------------------------------------------- */
stock bool BothTeamsPlayingInArea(int arena_index)
{
	bool bRedFound;
	bool bBluFound;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient, true) == false || (g_iPlayerArena[iClient] != arena_index && !IsFakeClient(iClient)))
		{
			continue;
		}
		
		int iTeam = GetClientTeam(iClient);
		if (iTeam == view_as<int>(TFTeam_Red))
		{
			bRedFound = true;
		}
		
		if (iTeam == view_as<int>(TFTeam_Blue))
		{
			bBluFound = true;
		}
	}
	return bRedFound && bBluFound;
}

/* BothTeamsPlayingInArea()
**
** Checks if there are players on both teams..
** -------------------------------------------------------------------------- */
stock bool BothTeamsPlaying()
{
	bool bRedFound;
	bool bBluFound;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient, true) == false)
		{
			continue;
		}
		
		int iTeam = GetClientTeam(iClient);
		if (iTeam == view_as<int>(TFTeam_Red))
		{
			bRedFound = true;
		}
		
		if (iTeam == view_as<int>(TFTeam_Blue))
		{
			bBluFound = true;
		}
	}
	return bRedFound && bBluFound;
}

/* CountAlivePlayers()
**
** Retrieves the number of players alive in the specified arena.
** -------------------------------------------------------------------------- */
stock int CountAlivePlayers(int arena_index)
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient, true) && (g_iPlayerArena[iClient] == arena_index || IsFakeClient(iClient)))
		{	
			iCount++;
		}
	}
	return iCount;
}

/* GetTotalClientCount()
**
** Retrieves the number of real players connected.
** -------------------------------------------------------------------------- */
stock int GetTotalClientCount() {
	int count = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 1) {
			count += 1;
		}
	}
	return count;
}

/* SelectTarget()
**
** Determines a random target of the given team in the given arena for the homing rocket.
** -------------------------------------------------------------------------- */
stock int SelectTarget(int iTeam, int arena_index, int iRocket = -1)
{
	int iTarget = -1;
	float fTargetWeight = 0.0;
	float fRocketPosition[3];
	float fRocketDirection[3];
	float fWeight;
	bool bUseRocket;

	if (iRocket != -1)
	{
		int iClass = g_iRocketClass[iRocket];
		int iEntity = EntRefToEntIndex(g_iRocketEntity[iRocket]);

		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
		CopyVectors(g_fRocketDirection[iRocket], fRocketDirection);
		fWeight = g_fRocketClassTargetWeight[iClass];

		bUseRocket = true;
	}

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		// If the client isn't connected, skip.
		if (!IsValidClient(iClient, true))
		{
			continue;
		}
		
		if (iTeam && GetClientTeam(iClient) != iTeam)
		{
			continue;
		}
		
		if (g_iPlayerArena[iClient] != arena_index && !IsFakeClient(iClient))
		{
			continue;
		}

		// Determine if this client should be the target.
		float fNewWeight = GetURandomFloatRange(0.0, 100.0);

		if (bUseRocket == true)
		{
			float fClientPosition[3]; GetClientEyePosition(iClient, fClientPosition);
			float fDirectionToClient[3]; MakeVectorFromPoints(fRocketPosition, fClientPosition, fDirectionToClient);
			fNewWeight += GetVectorDotProduct(fRocketDirection, fDirectionToClient) * fWeight;
		}

		if ((iTarget == -1) || fNewWeight >= fTargetWeight)
		{
			iTarget = iClient;
			fTargetWeight = fNewWeight;
		}
	}

	return iTarget;
}

/* StopSoundToAll()
**
** Stops a sound for all the clients on the given channel.
** -------------------------------------------------------------------------- */
stock void StopSoundToAll(int iChannel, const char[] strSound)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient))StopSound(iClient, iChannel, strSound);
	}
}

/* PlayParticle()
**
** Plays a particle system at the given location & angles.
** -------------------------------------------------------------------------- */
stock void PlayParticle(float fPosition[3], float fAngles[3], char[] strParticleName, float fEffectTime = 5.0, float fLifeTime = 9.0)
{
	int iEntity = CreateEntityByName("info_particle_system");
	if (iEntity && IsValidEdict(iEntity))
	{
		TeleportEntity(iEntity, fPosition, fAngles, NULL_VECTOR);
		DispatchKeyValue(iEntity, "effect_name", strParticleName);
		ActivateEntity(iEntity);
		AcceptEntityInput(iEntity, "Start");
		CreateTimer(fEffectTime, StopParticle, EntIndexToEntRef(iEntity));
		CreateTimer(fLifeTime, KillParticle, EntIndexToEntRef(iEntity));
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
	}
}

/* StopParticle()
**
** Turns of the particle system. Automatically called by PlayParticle
** -------------------------------------------------------------------------- */
public Action StopParticle(Handle hTimer, any iEntityRef)
{
	if (iEntityRef != INVALID_ENT_REFERENCE)
	{
		int iEntity = EntRefToEntIndex(iEntityRef);
		if (iEntity && IsValidEntity(iEntity))
		{
			AcceptEntityInput(iEntity, "Stop");
		}
	}
}

/* KillParticle()
**
** Destroys the particle system. Automatically called by PlayParticle
** -------------------------------------------------------------------------- */
public Action KillParticle(Handle hTimer, any iEntityRef)
{
	if (iEntityRef != INVALID_ENT_REFERENCE)
	{
		int iEntity = EntRefToEntIndex(iEntityRef);
		if (iEntity && IsValidEntity(iEntity))
		{
			RemoveEdict(iEntity);
		}
	}
}

/* PrecacheParticle()
**
** Forces the client to precache a particle system.
** -------------------------------------------------------------------------- */
stock void PrecacheParticle(char[] strParticleName)
{
	PlayParticle(view_as<float>( { 0.0, 0.0, 0.0 } ), view_as<float>( { 0.0, 0.0, 0.0 } ), strParticleName, 0.1, 0.1);
}

/* FindEntityByClassnameSafe()
**
** Used to iterate through entity types, avoiding problems in cases where
** the entity may not exist anymore.
** -------------------------------------------------------------------------- */
stock void FindEntityByClassnameSafe(int iStart, const char[] strClassname)
{
	while (iStart > -1 && !IsValidEntity(iStart))
	{
		iStart--;
	}
	return FindEntityByClassname(iStart, strClassname);
}

/* GetAnalogueTeam()
**
** Gets the analogue team for this. In case of Red, it's Blue, and viceversa.
** -------------------------------------------------------------------------- */
stock int GetAnalogueTeam(int iTeam)
{
	if (iTeam == view_as<int>(TFTeam_Red))return view_as<int>(TFTeam_Blue);
	return view_as<int>(TFTeam_Red);
}

/* PrecacheSoundEx()
**
** Precaches a sound and adds it to the download table.
** -------------------------------------------------------------------------- */
stock void PrecacheSoundEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false)
{
	char strFinalPath[PLATFORM_MAX_PATH];
	Format(strFinalPath, sizeof(strFinalPath), "sound/%s", strFileName);
	PrecacheSound(strFileName, bPreload);
	if (bAddToDownloadTable == true)AddFileToDownloadsTable(strFinalPath);
}

/* PrecacheModelEx()
**
** Precaches a models and adds it to the download table.
** -------------------------------------------------------------------------- */
stock void PrecacheModelEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false)
{
	PrecacheModel(strFileName, bPreload);
	if (bAddToDownloadTable)
	{
		char strDepFileName[PLATFORM_MAX_PATH];
		Format(strDepFileName, sizeof(strDepFileName), "%s.res", strFileName);

		if (FileExists(strDepFileName))
		{
			// Open stream, if possible
			Handle hStream = OpenFile(strDepFileName, "r");
			if (hStream == INVALID_HANDLE) { LogMessage("Error, can't read file containing model dependencies."); return; }

			while (!IsEndOfFile(hStream))
			{
				char strBuffer[PLATFORM_MAX_PATH];
				ReadFileLine(hStream, strBuffer, sizeof(strBuffer));
				CleanString(strBuffer);

				// If file exists...
				if (FileExists(strBuffer, true))
				{
					// Precache depending on type, and add to download table
					if (StrContains(strBuffer, ".vmt", false) != -1)PrecacheDecal(strBuffer, true);
					else if (StrContains(strBuffer, ".mdl", false) != -1)PrecacheModel(strBuffer, true);
					else if (StrContains(strBuffer, ".pcf", false) != -1)PrecacheGeneric(strBuffer, true);
					AddFileToDownloadsTable(strBuffer);
				}
			}

			// Close file
			CloseHandle(hStream);
		}
	}
}

/* CleanString()
**
** Cleans the given string from any illegal character.
** -------------------------------------------------------------------------- */
stock void CleanString(char[] strBuffer)
{
	// Cleanup any illegal characters
	int Length = strlen(strBuffer);
	for (int iPos = 0; iPos < Length; iPos++)
	{
		switch (strBuffer[iPos])
		{
			case '\r':strBuffer[iPos] = ' ';
			case '\n':strBuffer[iPos] = ' ';
			case '\t':strBuffer[iPos] = ' ';
		}
	}

	// Trim string
	TrimString(strBuffer);
}

/* FMax()
**
** Returns the maximum of the two values given.
** -------------------------------------------------------------------------- */
stock float FMax(float a, float b)
{
	return (a > b) ? a:b;
}

/* FMin()
**
** Returns the minimum of the two values given.
** -------------------------------------------------------------------------- */
stock float FMin(float a, float b)
{
	return (a < b) ? a:b;
}

/* GetURandomIntRange()
**
**
** -------------------------------------------------------------------------- */
stock int GetURandomIntRange(const int iMin, const int iMax)
{
	return iMin + (GetURandomInt() % (iMax - iMin + 1));
}

/* GetURandomFloatRange()
**
**
** -------------------------------------------------------------------------- */
stock float GetURandomFloatRange(float fMin, float fMax)
{
	return fMin + (GetURandomFloat() * (fMax - fMin));
}

// Pyro vision
public void tf2dodgeball_hooks(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(g_hCvarPyroVisionEnabled))
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				TF2Attrib_SetByName(i, PYROVISION_ATTRIBUTE, 1.0);
			}
		}
	}
	else
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				TF2Attrib_RemoveByName(i, PYROVISION_ATTRIBUTE);
			}
		}
	}
	if(convar == g_hMaxBouncesConVar)
		g_config_iMaxBounces = StringToInt(newValue);
}

// Asherkins RocketBounce

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!StrEqual(classname, "tf_projectile_rocket", false))
		return;

	if (StrEqual(classname, "tf_projectile_rocket") || StrEqual(classname, "tf_projectile_sentryrocket"))
	{
		if (IsValidEntity(entity))
		{
			SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", entity);
			SetEntPropEnt(entity, Prop_Send, "m_hLauncher", entity);
		}
	}

	g_nBounces[entity] = 0;
	SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
}

public Action OnStartTouch(int entity, int other)
{
	if (other > 0 && other <= MaxClients)
		return Plugin_Continue;

	// Only allow a rocket to bounce x times.
	if (g_nBounces[entity] >= g_config_iMaxBounces)
		return Plugin_Continue;

	SDKHook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public Action OnTouch(int entity, int other)
{
	float vOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);

	float vAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);

	float vVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);

	if (!TR_DidHit(trace))
	{
		CloseHandle(trace);
		return Plugin_Continue;
	}

	float vNormal[3];
	TR_GetPlaneNormal(trace, vNormal);

	//PrintToServer("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);

	CloseHandle(trace);

	float dotProduct = GetVectorDotProduct(vNormal, vVelocity);

	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);

	float vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);

	float vNewAngles[3];
	GetVectorAngles(vBounceVec, vNewAngles);

	//PrintToServer("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
	//PrintToServer("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));

	TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);

	g_nBounces[entity]++;

	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public bool TEF_ExcludeEntity(int entity, int contentsMask, any data)
{
	return (entity != data);
}

// Used for Aim Drag Type
public bool GetPlayerEyePosition(int client, float pos[3])
{
	float vAngles[3];
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRocketEntityFilterPlayer, client);
	
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return true;
	}
	CloseHandle(trace);
	return false;
}

public bool TraceRocketEntityFilterPlayer(int entity, int contentsMask, any data)
{
	if ( entity <= 0 ) return true;
	if ( entity == data ) return false;
	
	char sClassname[128];
	GetEdictClassname(entity, sClassname, sizeof(sClassname));
	if(StrEqual(sClassname, "func_respawnroomvisualizer", false))
		return false;
	else
		return true;
}

public Action TauntCheck(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	switch (damagecustom)
	{
		case TF_CUSTOM_TAUNT_ARMAGEDDON:
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

void checkRoundDelays(int entId, int arena_index)
{
	int iEntity = EntRefToEntIndex(g_iRocketEntity[entId]);
	int iTarget = EntRefToEntIndex(g_iRocketTarget[entId]);
	float timeToCheck;
	if (g_iRocketDeflections[entId] == 0)
		timeToCheck = g_fLastRocketSpawnTime[arena_index];
	else
		timeToCheck = g_fRocketLastDeflectionTime[entId];
	
	if (iTarget != INVALID_ENT_REFERENCE && (GetGameTime() - timeToCheck) >= GetConVarFloat(g_hCvarDelayPreventionTime))
	{
		g_fRocketSpeed[entId] += GetConVarFloat(g_hCvarDelayPreventionSpeedup);
		if (!g_bPreventingDelay)
		{
			PrintToChatAll("\x03%N is delaying, the rocket will now speed up.", iTarget);
			EmitSoundToAll(SOUND_DEFAULT_SPEEDUPALERT, iEntity, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
		}
		g_bPreventingDelay = true;
	}
}

/* SetMainRocketClass()
**
** Takes a specified rocket class index and sets it as the only rocket class able to spawn.
** -------------------------------------------------------------------------- */
stock void SetMainRocketClass(int Index, bool isVote, int client = 0)
{
	char sCurrentDragType[32];
	if (g_iRocketClassDragType[Index] == DragType_Direction)
	{
		sCurrentDragType = "direction";
	}
	else if (g_iRocketClassDragType[Index] == DragType_Aim)
	{
		sCurrentDragType = "aim";
	}
	PrintToChatAll("Current Rocket Drag Type: %s", sCurrentDragType);
	
	int iClass = 0;
	
	for (int arena_index = 1; arena_index <= g_iArenaCount; arena_index++)
	{
		int iSpawnerClassRed = g_iRocketSpawnPointsRedClass[g_iCurrentRedRocketSpawn[arena_index]][arena_index];
		char strBufferRed[256];
		strcopy(strBufferRed, sizeof(strBufferRed), "Red");
		
		Format(strBufferRed, sizeof(strBufferRed), "%s%%", g_strRocketClassName[Index]);
		SetArrayCell(g_hRocketSpawnersChancesTable[iSpawnerClassRed], Index, 100);
		
		for (int iClassIndex = 0; iClassIndex < g_iRocketClassCount; iClassIndex++)
		{
			if (!(iClassIndex == Index))
			{
				Format(strBufferRed, sizeof(strBufferRed), "%s%%", g_strRocketClassName[iClassIndex]);
				SetArrayCell(g_hRocketSpawnersChancesTable[iSpawnerClassRed], iClassIndex, 0);
			}
		}
		
		if (arena_index == 1)
		{
			iClass = GetRandomRocketClass(iSpawnerClassRed);
		}
		
		int iSpawnerClassBlu = g_iRocketSpawnPointsBluClass[g_iCurrentBluRocketSpawn[arena_index]][arena_index];
		char strBufferBlue[256];
		strcopy(strBufferBlue, sizeof(strBufferBlue), "Blue");
		
		Format(strBufferBlue, sizeof(strBufferBlue), "%s%%", g_strRocketClassName[Index]);
		SetArrayCell(g_hRocketSpawnersChancesTable[iSpawnerClassBlu], Index, 100);
		
		char strSelectionBlue[256];
		strcopy(strSelectionBlue, sizeof(strBufferBlue), strBufferBlue);
		
		for (int iClassIndex = 0; iClassIndex < g_iRocketClassCount; iClassIndex++)
		{
			if (!(iClassIndex == Index))
			{
				Format(strBufferBlue, sizeof(strBufferBlue), "%s%%", g_strRocketClassName[iClassIndex]);
				SetArrayCell(g_hRocketSpawnersChancesTable[iSpawnerClassBlu], iClassIndex, 0);
			}
		}
	}
	
	strcopy(g_strSavedClassName, sizeof(g_strSavedClassName), g_strRocketClassLongName[iClass]);
	
	if (isVote)
		MC_PrintToChatAll("\x05[VRC]\01 Vote \x05finished\01! Rocket class changed to \x05%s\01.", g_strSavedClassName);
	else MC_PrintToChatAll("\x05%N\01 changed the rocket class to \x05%s\01.", client, g_strRocketClassLongName[iClass]);
}

float CalculateSpeed(float speed)
{
	return speed * (15.0 / 350.0);
}

stock void CreateTempParticle(char[] particle, int entity = -1, float origin[3] = NULL_VECTOR, float angles[3] =  { 0.0, 0.0, 0.0 }, bool resetparticles = false)
{
	int tblidx = FindStringTable("ParticleEffectNames");

	char tmp[256];
	int stridx = INVALID_STRING_INDEX;

	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, particle, false))
		{
			stridx = i;
			break;
		}
	}

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iAttachType", 1);
	TE_WriteNum("m_bResetParticles", resetparticles);
	TE_SendToAll();
}

stock void ClearTempParticles(int client)
{
	float empty[3];
	CreateTempParticle("sandwich_fx", client, empty, empty, true);
}

/*
** ------------------------------------------------------------------
**		__  ____           
**	   /  |/  (_)__________
**	  / /|_/ / // ___/ ___/
**	 / /  / / /(__  ) /__  
**	/_/  /_/_//____/\___/  
**						   
** ------------------------------------------------------------------
**/

/* TraceEntityFilterPlayer()
 *
 * Ignores players.
 * -------------------------------------------------------------------------- */
public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

/* TraceEntityPlayersOnly()
 *
 * Returns only players.
 * -------------------------------------------------------------------------- */
public bool TraceEntityPlayersOnly(int entity, int mask, int client)
{
	if (IsValidClient(entity) && entity != client)
	{
		PrintToChatAll("returning true for %d<%N>", entity, entity);
		return true;
	} else {
		PrintToChatAll("returning false for %d<%N>", entity, entity);
		return false;
	}
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * -------------------------------------------------------------------------- */
bool IsValidClient(int iClient, bool bIgnoreKickQueue = false)
{
	if (iClient < 1 || iClient > MaxClients)
		return false;
	if (!IsClientConnected(iClient))
		return false;
	if (!bIgnoreKickQueue && IsClientInKickQueue(iClient))
		return false;
	if (IsClientSourceTV(iClient))
		return false;
	return IsClientInGame(iClient);
}

/* FindEntityByClassname2()
 *
 * Finds entites, and won't error out when searching invalid entities.
 * -------------------------------------------------------------------------- */
stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt))startEnt--;
	
	return FindEntityByClassname(startEnt, classname);
}

/* getTeammate()
 * 
 * Gets a clients teammate if he's in a 4 player arena
 * This can actually be replaced by g_iArenaQueue[SLOT_X] but I didn't realize that array existed, so YOLO
 *---------------------------------------------------------------------*/
public int getTeammate(int myClient, int myClientSlot, int arena_index)
{
	
	int client_teammate_slot;
	
	if (myClientSlot == SLOT_ONE)
	{
		client_teammate_slot = SLOT_THREE;
	}
	else if (myClientSlot == SLOT_TWO)
	{
		client_teammate_slot = SLOT_FOUR;
	}
	else if (myClientSlot == SLOT_THREE)
	{
		client_teammate_slot = SLOT_ONE;
	}
	else
	{
		client_teammate_slot = SLOT_TWO;
	}
	
	int myClientTeammate = g_iArenaQueue[arena_index][client_teammate_slot];
	return myClientTeammate;
	
}

/* isPlayerWaiting()
 * 
 * Gets if a client is waiting
 *---------------------------------------------------------------------*/
bool isPlayerWaiting(int myClient)
{
	return g_iPlayerWaiting[myClient];
}

public void PlayEndgameSoundsToArena(any arena_index, any winner_team)
{
	int red_1 = g_iArenaQueue[arena_index][SLOT_ONE];
	int blu_1 = g_iArenaQueue[arena_index][SLOT_TWO];
	char SoundFileBlu[124];
	char SoundFileRed[124];
	
	//If the red team won
	if (winner_team == 1)
	{
		SoundFileRed = "vo/announcer_victory.wav";
		SoundFileBlu = "vo/announcer_you_failed.wav";
	}
	//Else the blu team won
	else
	{
		SoundFileBlu = "vo/announcer_victory.wav";
		SoundFileRed = "vo/announcer_you_failed.wav";
	}
	if (IsValidClient(red_1))
		EmitSoundToClient(red_1, SoundFileRed);
	
	if (IsValidClient(blu_1))
		EmitSoundToClient(blu_1, SoundFileBlu);
	
	if (g_bFourPersonArena[arena_index])
	{
		int red_2 = g_iArenaQueue[arena_index][SLOT_THREE];
		int blu_2 = g_iArenaQueue[arena_index][SLOT_FOUR];
		
		if (IsValidClient(red_2))
				EmitSoundToClient(red_2, SoundFileRed);
				
		if (IsValidClient(blu_2))
				EmitSoundToClient(blu_2, SoundFileBlu);
	}
}

// 
