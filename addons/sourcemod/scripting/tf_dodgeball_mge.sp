#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required

// ====[ INCLUDES ]====================================================
#include <sourcemod>
#include <tf2_stocks>
#include <entity_prop_stocks>
#include <sdkhooks>
#include <morecolors> 
// ====[ CONSTANTS ]===================================================
#define PL_VERSION "2.2.4-tfdb"
#define MAX_FILE_LEN 80
#define MAXARENAS 31
#define MAXSPAWNS 15
#define HUDFADEOUTTIME 120.0
#define SLOT_ONE 1 //arena slot 1
#define SLOT_TWO 2 //arena slot 2
#define SLOT_THREE 3 //arena slot 3
#define SLOT_FOUR 4 //arena slot 4
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

//#define DEBUG_LOG

// ====[ VARIABLES ]===================================================
// Handle, String, Float, Bool, NUM, TFCT

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
	author = "Lange, Cprice, and soul; based on kAmmomod by Krolus - maintained by sappho.io",
	description = "Duel mod with realistic game situations from the TF2 gamemode Dodgeball.",
	version = PL_VERSION
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
	
	//ConVars
	CreateConVar("tfdbmge_version", PL_VERSION, "TFDBMGE version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
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
	RegAdminCmd("loc", Command_Loc, ADMFLAG_BAN, "Shows client origin and angle vectors");
	RegAdminCmd("botme", Command_AddBot, ADMFLAG_BAN, "Add bot to your arena");
	
	// Create the HUD text handles for later use.
	hm_HP = CreateHudSynchronizer();
	hm_Score = CreateHudSynchronizer();
	hm_TeammateHP = CreateHudSynchronizer();
	
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
 * "Team Fortress 2" to "MGEMod vx.x.x"
 * -------------------------------------------------------------------------- */
public Action OnGetGameDescription(char gameDesc[64])
{
	Format(gameDesc, sizeof(gameDesc), "MGEMod v%s", PL_VERSION);
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
	int isMapAm = LoadSpawnPoints();
	if (isMapAm)
	{
		CreateTimer(1.0, Timer_SpecHudToAllArenas, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		
		if (g_bAutoCvar)
		{
			/*	MGEMod often creates situtations where the number of players on RED and BLU will be uneven.
			If the server tries to force a player to a different team due to autobalance being on, it will interfere with MGEMod's queue system.
			These cvar settings are considered mandatory for MGEMod. */
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
	UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	UnhookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	UnhookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
	
	for (int arena_index = 1; arena_index < g_iArenaCount; arena_index++)
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
			float enginetime = GetGameTime();
			
			for (int i = 0; i <= 2; i++)
			{
				int ent = GetPlayerWeaponSlot(red_f1, i);
				
				if (IsValidEntity(ent))
					SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
				
				ent = GetPlayerWeaponSlot(blu_f1, i);
				
				if (IsValidEntity(ent))
					SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
				
				ent = GetPlayerWeaponSlot(red_f2, i);
				
				if (IsValidEntity(ent))
					SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
				
				ent = GetPlayerWeaponSlot(blu_f2, i);
				
				if (IsValidEntity(ent))
					SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
			}
			
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
			float enginetime = GetGameTime();
			
			for (int i = 0; i <= 2; i++)
			{
				int ent = GetPlayerWeaponSlot(red_f1, i);
				
				if (IsValidEntity(ent))
					SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
				
				ent = GetPlayerWeaponSlot(blu_f1, i);
				
				if (IsValidEntity(ent))
					SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
			}
			
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
bool LoadSpawnPoints()
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
				LogMessage("Loaded %d arenas. MGEMod enabled.", g_iArenaCount);
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
	} else {
		TF2_RegeneratePlayer(client);
		ExtinguishEntity(client);
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

// ====[ CVARS ]====================================================
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
		LoadSpawnPoints();
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
		return Plugin_Continue;
	
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
	PrintToConsole(client, "%t", "Cmd_MGEMod");
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
	int client = GetClientOfUserId(event.GetInt("userid"));
	int arena_index = g_iPlayerArena[client];
	
	if (!g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] != SLOT_ONE && g_iPlayerSlot[client] != SLOT_TWO)
		ChangeClientTeam(client, TEAM_SPEC);
	
	else if (g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] != SLOT_ONE && g_iPlayerSlot[client] != SLOT_TWO && (g_iPlayerSlot[client] != SLOT_THREE && g_iPlayerSlot[client] != SLOT_FOUR))
		ChangeClientTeam(client, TEAM_SPEC);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int arena_index = g_iPlayerArena[victim];
	int victim_slot = g_iPlayerSlot[victim];
	
	
	int killer_slot = (victim_slot == SLOT_ONE || victim_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
	int killer = g_iArenaQueue[arena_index][killer_slot];
	int killer_teammate;
	int victim_teammate;
	
	//gets the killer and victims team slot (red 1, blu 2)
	int killer_team_slot = (killer_slot > 2) ? (killer_slot - 2) : killer_slot;
	int victim_team_slot = (victim_slot > 2) ? (victim_slot - 2) : victim_slot;
	
	// don't detect dead ringer deaths
	int victim_deathflags = event.GetInt("death_flags");
	if (victim_deathflags & 32)
	{
		return Plugin_Continue;
	}
	
	if (g_bFourPersonArena[arena_index])
	{
		victim_teammate = getTeammate(victim, victim_slot, arena_index);
		killer_teammate = getTeammate(killer, killer_slot, arena_index);
	}
	
	if (!arena_index)
		ChangeClientTeam(victim, TEAM_SPEC);
	
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
	
	if (!g_bFourPersonArena[arena_index] || 
		(g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate)))
	g_iArenaStatus[arena_index] = AS_AFTERFIGHT;
	
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
		if (!g_bFourPersonArena[arena_index])
		{
			ResetKiller(killer, arena_index);
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
			//CreateTimer(g_fArenaRespawnTime[arena_index],Timer_ResetPlayer,GetClientUserId(victim));
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
	} else if (IsValidClient(client)) {  // this code fixing spawn exploit
		int arena_index = g_iPlayerArena[client];
		
		if (arena_index == 0)
		{
			TF2_SetPlayerClass(client, view_as<TFClassType>(0));
		}
	}
	
	event.SetInt("silent", true);
	return Plugin_Changed;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	gcvar_WfP.SetInt(1); //cancel waiting for players
	
	return Plugin_Continue;
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
	
	MC_PrintToChat(client, "%t", "Welcome1", PL_VERSION);
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
	ShowSpecHudToArena(i);
	
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
			
			if (g_iArenaCd[arena_index] > 0)
			{  // blocking +attack
				float enginetime = GetGameTime();
				
				for (int i = 0; i <= 2; i++)
				{
					int ent = GetPlayerWeaponSlot(red_f1, i);
					
					if (IsValidEntity(ent))
						SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
					
					ent = GetPlayerWeaponSlot(blu_f1, i);
					
					if (IsValidEntity(ent))
						SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
					
					ent = GetPlayerWeaponSlot(red_f2, i);
					
					if (IsValidEntity(ent))
						SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
					
					ent = GetPlayerWeaponSlot(blu_f2, i);
					
					if (IsValidEntity(ent))
						SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
				}
			}
			
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
			} else if (g_iArenaCd[arena_index] <= 0) {
				g_iArenaStatus[arena_index] = AS_FIGHT;
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
			
			if (g_iArenaCd[arena_index] > 0)
			{  // blocking +attack
				float enginetime = GetGameTime();
				
				for (int i = 0; i <= 2; i++)
				{
					int ent = GetPlayerWeaponSlot(red_f1, i);
					
					if (IsValidEntity(ent))
						SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
					
					ent = GetPlayerWeaponSlot(blu_f1, i);
					
					if (IsValidEntity(ent))
						SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
				}
			}
			
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
	StartCountDown(arena_index);
}

public Action Timer_StartDuel(Handle timer, any arena_index)
{
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

/* DistanceAboveGround()
 *
 * How high off the ground is the player?
 * -------------------------------------------------------------------------- */
float DistanceAboveGround(int victim)
{
	float vStart[3];
	float vEnd[3];
	float vAngles[3] =  { 90.0, 0.0, 0.0 };
	GetClientAbsOrigin(victim, vStart);
	Handle trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	float distance = -1.0;
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(vEnd, trace);
		distance = GetVectorDistance(vStart, vEnd, false);
	} else {
		LogError("trace error. victim %N(%d)", victim, victim);
	}
	
	delete trace;
	return distance;
}

/* DistanceAboveGroundAroundUser()
 *
 * How high off the ground is the player?
 *This is used for dropping
 * -------------------------------------------------------------------------- */
 
 // i highly suspect this also needs a switch case rewrite lol
 
float DistanceAboveGroundAroundPlayer(int victim)
{
	float vStart[3];
	float vEnd[3];
	float vAngles[3] =  { 90.0, 0.0, 0.0 };
	GetClientAbsOrigin(victim, vStart);
	float minDist;
	
	for (int i = 0; i < 5; ++i)
	{
		float tvStart[3];
		tvStart = vStart;
		float tempDist = -1.0;
		if (i == 0)
		{
			Handle trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);
			
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(vEnd, trace);
				minDist = GetVectorDistance(vStart, vEnd, false);
			} else {
				LogError("trace error. victim %N(%d)", victim, victim);
			}
			delete trace;
		}
		else if (i == 1)
		{
			tvStart[0] = tvStart[0] + 10;
			Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);
			
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(vEnd, trace);
				tempDist = GetVectorDistance(tvStart, vEnd, false);
			} else {
				LogError("trace error. victim %N(%d)", victim, victim);
			}
			delete trace;
		}
		else if (i == 2)
		{
			tvStart[0] = tvStart[0] - 10;
			Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);
			
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(vEnd, trace);
				tempDist = GetVectorDistance(tvStart, vEnd, false);
			} else {
				LogError("trace error. victim %N(%d)", victim, victim);
			}
			delete trace;
		}
		else if (i == 3)
		{
			tvStart[1] = vStart[1] + 10;
			Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);
			
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(vEnd, trace);
				tempDist = GetVectorDistance(tvStart, vEnd, false);
			} else {
				LogError("trace error. victim %N(%d)", victim, victim);
			}
			delete trace;
		}
		else if (i == 4)
		{
			tvStart[1] = vStart[1] - 10;
			Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);
			
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(vEnd, trace);
				tempDist = GetVectorDistance(tvStart, vEnd, false);
			} else {
				LogError("trace error. victim %N(%d)", victim, victim);
			}
			delete trace;
		}
		
		if ((tempDist > -1 && tempDist < minDist) || minDist == -1)
		{
			minDist = tempDist;
		}
	}
	
	return minDist;
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
