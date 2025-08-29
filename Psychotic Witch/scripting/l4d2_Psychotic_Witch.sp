/*****************************************************************
 Original https://forums.alliedmods.net/showthread.php?t=236472
*****************************************************************/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1
#pragma newdecls required


#define PLUGIN_NAME		        	"[L4D2] Psychotic Witch"
#define PLUGIN_VERSION 	      	"1.3"
#define PLUGIN_AUTHOR	        	"Mortiegama"
#define PLUGIN_DESCRIPTION    	"Brining a new meaning of fear to the most dangerous infected."
#define PLUGIN_LINK		        	"https://forums.alliedmods.net/showthread.php?p=2107926#post2107926"


#define CVAR_FLAGS                    FCVAR_NOTIFY
#define MAXENTITIES                   2048
#define TEAM_SURVIVOR				          2
#define STRING_LENGHT			        	  56
#define MODEL_PROPANE				          "models/props_junk/propanecanister001a.mdl"

float SLAP_VERTICAL_MULTIPLIER		=	1.5;

// ===========================================
// Witch Setup
// ===========================================

//ConVar
ConVar 
	g_cvAssimilation,
	g_cvDeathHelmet,
	g_cvDeathHelmetAmount,
	g_cvLeechingClaw,
	g_cvLeechingClawAmount,
	g_cvMoodSwing,
	g_cvMoodSwingHPMin,
	g_cvMoodSwingHPMax,
	g_cvMoodSwingSpeedMin,
	g_cvMoodSwingSpeedMax,
	g_cvNightmareClaw,
	g_cvNightmareClawType,
	g_cvPsychoticCharge,
	g_cvPsychoticChargeDamage,
	g_cvPsychoticChargePower,
	g_cvPsychoticChargeRange,
	g_cvShamefulCloak,
	g_cvShamefulCloakChance,
	g_cvShamefulCloakVisibility,
	g_cvSlashingWind,
	g_cvSlashingWindDamage,
	g_cvSlashingWindRange,
	g_cvSorrowfulRemorse,
	g_cvSupportGroup,
	g_cvUnrelentingSpirit,
	g_cvUnrelentingSpiritAmount;

//Bool
bool 
	HeartSound[MAXPLAYERS + 1],
	g_bAssimilation,
	g_bDeathHelmet,
	g_bLeechingClaw,
	g_bMoodSwing,
	g_bNightmareClaw,
	g_bPsychoticCharge,
	g_bPsychoticWitch[MAXENTITIES+1],
	g_bShamefulCloak,
	g_bSlashingWind,
	g_bSorrowfulRemorse,
	g_bSupportGroup,
	g_bUnrelentingSpirit,
	g_bMapRunning;

//Handle
Handle 
	g_hOnStaggered,
	g_hPlayerFling,
	g_hResetMobTimer,
	g_hPsychoticChargeTimer[MAXENTITIES+1];

//Int
int 
	g_iLeechingClawAmount,
	g_iMoodSwingHPMin,
	g_iMoodSwingHPMax,
	g_iNightmareClawType,
	g_iPsychoticChargeDamage,
	g_iPsychoticChargePower,
	g_iPsychoticChargeRange,
	g_iShamefulCloakChance,
	g_iShamefulCloakVisibility,
	g_iSlashingWindDamage,
	g_iSlashingWindRange;

//Float
float 
	g_fDeathHelmetAmount,
	g_fMoodSwingSpeedMin,
	g_fMoodSwingSpeedMax,
	g_fUnrelentingSpiritAmount;


int hitgroup[MAXENTITIES+1];

Address
	g_pDirector;
// ===========================================
// Plugin Info
// ===========================================

public Plugin myinfo = {
	name =			PLUGIN_NAME,
	author =		PLUGIN_AUTHOR,
	description =	PLUGIN_DESCRIPTION,
	version =		PLUGIN_VERSION,
	url = 			PLUGIN_LINK
};

	//Special Thanks:
	//AtomicStryker - Boomer Bit** Slap:
	//https://forums.alliedmods.net/showthread.php?t=97952
	
	//AtomicStryker - Damage Mod (SDK Hooks):
	//https://forums.alliedmods.net/showthread.php?p=1184761


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 )
	{
			strcopy(error, err_max, "plugin " ... PLUGIN_NAME ... "only supports Left 4 Dead 2");
			return APLRes_Failure;
	}
	return APLRes_Success;
}

// ===========================================
// Plugin Start
// ===========================================

public void OnPluginStart()
{
	InitData();
	CreateConVar("l4d_pwm_version", PLUGIN_VERSION, "Pscyhotic Witch Version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

	// ======================================
	// Witch Ability: Assimilation
	// ======================================
	g_cvAssimilation 			= CreateConVar("l4d_pwm_assimilation",		"1",	"Enables Assimilation Ability: When a Survivor is killed by the Witch, she raises them in her image, creating another Witch. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	// ======================================
	// Witch Ability: Death Helmet
	// ======================================
	g_cvDeathHelmet 			= CreateConVar("l4d_pwm_deathhelmet",		"1",	"Enables Death Helmet Ability: The Witch places a hollowed out propane tank on her head to reduce damage to her brain. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvDeathHelmetAmount 		= CreateConVar("l4d_pwm_deathhelmetamount",	"0.3",	"Percentage that damage to Witch's head is reduced. (Def 0.3)", CVAR_FLAGS, true, 0.1);

	// ======================================
	// Witch Ability: Leeching Claw
	// ======================================
	g_cvLeechingClaw 			= CreateConVar("l4d_pwm_leechingclaw",		"1", 	"Enables Leeching Claw ability: When the Witch incaps a Survivor, she heals herself with some of their stolen life force. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvLeechingClawAmount 		= CreateConVar("l4d_pwm_leechingclawamount","500", 	"Amount of health to restore to the Witch after Leeching Claw. (Def 500)", CVAR_FLAGS, true, 0.0);

	// ======================================
	// Witch Ability: Mood Swing
	// ======================================
	g_cvMoodSwing				= CreateConVar("l4d_pwm_moodswing", 		"1", 	"Enables Mood Swing ability: With her mood changes, the Witch also has a varied health and speed factor. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvMoodSwingHPMin			= CreateConVar("l4d_pwm_moodswinghpmin", 	"1000", "Minimum HP for the Witch. (Def 1000)", CVAR_FLAGS, true, 1.0);
	g_cvMoodSwingHPMax			= CreateConVar("l4d_pwm_moodswinghpmax", 	"2000", "Maximum HP for the Witch. (Def 2000)", CVAR_FLAGS, true, 1.0);
	g_cvMoodSwingSpeedMin		= CreateConVar("l4d_pwm_moodswingspeedmin", "0.8", 	"Minimum speed adjustment for the Witch. (Def 0.8)", CVAR_FLAGS, true, 0.1);
	g_cvMoodSwingSpeedMax		= CreateConVar("l4d_pwm_moodswingspeedmax", "1.6", 	"Maximum speed adjustment for the Witch. (Def 1.6)", CVAR_FLAGS, true, 0.2);
	
	// ======================================
	// Witch Ability: Nightmare Claw
	// ======================================
	g_cvNightmareClaw 			= CreateConVar("l4d_pwm_nightmareclaw",		"1", 	"Enables Nightmare Claw ability: When incapped by an enraged Witch the Survivor is either set to B&W or killed. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvNightmareClawType 		= CreateConVar("l4d_pwm_nightmareclawtype", "1", 	"Type of Nightmare Claw: 1 = Survivor is set to B&W, 2 = Survivor is killed.", CVAR_FLAGS, true, 1.0, true, 2.0);

	// ======================================
	// Witch Ability: Psychotic Charge
	// ======================================
	g_cvPsychoticCharge 		= CreateConVar("l4d_pwm_psychoticcharge",	"1",	"Enables Psychotic Charge ability: The Witch will knock back any Survivors in her path while pursuing her victim. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvPsychoticChargeDamage 	= CreateConVar("l4d_pwm_psychoticchargedamage", "10", "Amount of damage the Witch causes when she hits a Survivor. (Def 10)", CVAR_FLAGS, true, 0.0);
	g_cvPsychoticChargePower 	= CreateConVar("l4d_pwm_psychoticchargepower", "300", "Power a Survivor is hit with during Psychotic Charge. (Def 300)", CVAR_FLAGS, true, 0.0);
	g_cvPsychoticChargeRange 	= CreateConVar("l4d_pwm_psychoticchargerange", "200", "How close a Survivor has to be to be hit by the Psychotic Charge. (Def 200)", CVAR_FLAGS, true, 0.0);

	// ======================================
	// Witch Ability: Shameful Cloak
	// ======================================
	g_cvShamefulCloak 			= CreateConVar("l4d_pwm_shamefulcloak", "1", "Enables Shameful Cloak ability: Distraught by what she has become, the Witch will try to hide her form from the world. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvShamefulCloakChance 	= CreateConVar("l4d_pwm_shamefulcloakchance", "20", "Chance the Witch will use Shameful Cloak when spawned. (Def 20)", CVAR_FLAGS, true, 0.0);
	g_cvShamefulCloakVisibility = CreateConVar("l4d_pwm_shamefulcloakvisibility", "0", "Modifies the visibility of the Witch while using Shameful Cloak. (0-255) (Def 0)", CVAR_FLAGS, true, 0.0, true, 255.0);

	// ======================================
	// Witch Ability: Slashing Wind
	// ======================================
	g_cvSlashingWind 			= CreateConVar("l4d_pwm_slashingwind", "1", "Enables Slashing Wind ability: When the Witch incaps a Survivor it sends out a shockwave damaging and knocking back all Survivors. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvSlashingWindDamage 		= CreateConVar("l4d_pwm_slashingwinddamage", "5", "Amount of damage the Witch caused to Survivors within Slashing Wind range. (Def 5)", CVAR_FLAGS, true, 0.0);
	g_cvSlashingWindRange 		= CreateConVar("l4d_pwm_slashingwindrange", "500", "How close a Survivor has to be to be hit by the Slashing Wind. (Def 600)", CVAR_FLAGS, true, 1.0);

	// ======================================
	// Witch Ability: Sorrowful Remorse
	// ======================================
	g_cvSorrowfulRemorse 		= CreateConVar("l4d_pwm_sorrowfulremorse", "0", "Enables Sorrowful Remorse ability: When a Witch is killed, she leaves behind a Medkit and Defib as repetance for her actions. (Def 0)", CVAR_FLAGS, true, 0.0, true, 1.0);

	// ======================================
	// Witch Ability: Support Group
	// ======================================
	g_cvSupportGroup 			= CreateConVar("l4d_pwm_supportgroup", "1", "Enables Support Group ability: When the Witch is angered, her hateful shriek calls down a panic event. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	// ======================================
	// Witch Ability: Unrelenting Spirit
	// ======================================
	g_cvUnrelentingSpirit 		= CreateConVar("l4d_pwm_unrelentingspirit", "1", "Enables Unrelenting Spirit ability: The Witch's spirit allows her to keep attacking despite damage. (Def 1)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvUnrelentingSpiritAmount = CreateConVar("l4d_pwm_unrelentingspiritamount", "0.7", "Percent of damage to the Witch reduced by Unrelenting Spirit. (Def 0.7)", CVAR_FLAGS, true, 0.1);
	
	// ======================================
	// Hook Events
	// ======================================
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("player_incapacitated", Event_PlayerIncapped);
	HookEvent("witch_harasser_set", Event_WitchHarasserSet);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("player_death", Event_PlayerDeath);
	
	AutoExecConfig(true, "l4d2_Psychotic_Witch");
	
	GetCvars();
	g_cvAssimilation.AddChangeHook(ConVarChanged_Cvars);
	g_cvLeechingClaw.AddChangeHook(ConVarChanged_Cvars);
	g_cvMoodSwing.AddChangeHook(ConVarChanged_Cvars);
	g_cvNightmareClaw.AddChangeHook(ConVarChanged_Cvars);
	g_cvPsychoticCharge.AddChangeHook(ConVarChanged_Cvars);
	g_cvShamefulCloak.AddChangeHook(ConVarChanged_Cvars);
	g_cvSlashingWind.AddChangeHook(ConVarChanged_Cvars);
	g_cvSorrowfulRemorse.AddChangeHook(ConVarChanged_Cvars);
	g_cvSupportGroup.AddChangeHook(ConVarChanged_Cvars);
	g_cvUnrelentingSpirit.AddChangeHook(ConVarChanged_Cvars);
	
	g_cvDeathHelmetAmount.AddChangeHook(ConVarChanged_Cvars);
	g_cvLeechingClawAmount.AddChangeHook(ConVarChanged_Cvars);
	g_cvMoodSwingHPMin.AddChangeHook(ConVarChanged_Cvars);
	g_cvMoodSwingHPMax.AddChangeHook(ConVarChanged_Cvars);
	g_cvMoodSwingSpeedMin.AddChangeHook(ConVarChanged_Cvars);
	g_cvMoodSwingSpeedMax.AddChangeHook(ConVarChanged_Cvars);
	g_cvNightmareClawType.AddChangeHook(ConVarChanged_Cvars);
	g_cvPsychoticChargeDamage.AddChangeHook(ConVarChanged_Cvars);
	g_cvPsychoticChargePower.AddChangeHook(ConVarChanged_Cvars);
	g_cvPsychoticChargeRange.AddChangeHook(ConVarChanged_Cvars);
	g_cvShamefulCloakChance.AddChangeHook(ConVarChanged_Cvars);
	g_cvShamefulCloakVisibility.AddChangeHook(ConVarChanged_Cvars);
	g_cvSlashingWindDamage.AddChangeHook(ConVarChanged_Cvars);
	g_cvSlashingWindRange.AddChangeHook(ConVarChanged_Cvars);
	g_cvUnrelentingSpiritAmount.AddChangeHook(ConVarChanged_Cvars);
	
}


void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bAssimilation 			= 		g_cvAssimilation.BoolValue;
	g_bDeathHelmet				= 		g_cvDeathHelmet.BoolValue;
	g_bLeechingClaw				= 		g_cvLeechingClaw.BoolValue;
	g_bMoodSwing 				= 		g_cvMoodSwing.BoolValue;
	g_bNightmareClaw			= 		g_cvNightmareClaw.BoolValue;
	g_bPsychoticCharge			= 		g_cvPsychoticCharge.BoolValue;
	g_bShamefulCloak			= 		g_cvShamefulCloak.BoolValue;
	g_bSlashingWind				= 		g_cvSlashingWind.BoolValue;
	g_bSorrowfulRemorse			= 		g_cvSorrowfulRemorse.BoolValue;
	g_bSupportGroup				= 		g_cvSupportGroup.BoolValue;
	g_bUnrelentingSpirit		= 		g_cvUnrelentingSpirit.BoolValue;
	
	g_iLeechingClawAmount 		= 		g_cvLeechingClawAmount.IntValue;
	g_iMoodSwingHPMin 			= 		g_cvMoodSwingHPMin.IntValue;
	g_iMoodSwingHPMax 			= 		g_cvMoodSwingHPMax.IntValue;
	g_iNightmareClawType		= 		g_cvNightmareClawType.IntValue;
	g_iPsychoticChargeDamage	= 		g_cvPsychoticChargeDamage.IntValue;
	g_iPsychoticChargePower		= 		g_cvPsychoticChargePower.IntValue;
	g_iPsychoticChargeRange		= 		g_cvPsychoticChargeRange.IntValue;
	g_iShamefulCloakChance		= 		g_cvShamefulCloakChance.IntValue;
	g_iShamefulCloakVisibility	= 		g_cvShamefulCloakVisibility.IntValue;
	g_iSlashingWindDamage		= 		g_cvSlashingWindDamage.IntValue;
	g_iSlashingWindRange		= 		g_cvSlashingWindRange.IntValue;
	
	g_fDeathHelmetAmount		= 		g_cvDeathHelmetAmount.FloatValue;
	g_fMoodSwingSpeedMin		= 		g_cvMoodSwingSpeedMin.FloatValue;
	g_fMoodSwingSpeedMax		= 		g_cvMoodSwingSpeedMax.FloatValue;
	g_fUnrelentingSpiritAmount	= 		g_cvUnrelentingSpiritAmount.FloatValue;
}

public void OnConfigsExecuted()
{
	GetCvars();
}

// ===========================================
// Sourcemod Forward
// ===========================================

public void OnMapStart()
{
	PrecacheModel(MODEL_PROPANE, true);
	g_bMapRunning = true;
}

public void OnMapEnd()
{
	g_bMapRunning = false;
}


public void OnEntityCreated(int entity, const char[] classname) 
{
	if (!g_bMapRunning || IsServerProcessing() == false) return;
	
	if (IsValidWitch(entity))
	{
		CreateTimer(0.5, Timer_WitchSpawn, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(entity, SDKHook_TraceAttack, OnHitPoint);
	}
}

Action Timer_WitchSpawn(Handle timer, int ref)
{
	int witch = EntRefToEntIndex(ref);

	if(!IsValidWitch(witch) || witch <= MaxClients) return Plugin_Stop;

	if (!g_bMapRunning || IsServerProcessing() == false) return Plugin_Stop;
	
	// =====================================
	// Witch Ability: Death Helmet
	// =====================================
	if (g_bDeathHelmet)
	{
		WitchAbility_DeathHelmet(witch);
	}

	// =====================================
	// Witch Ability: Mood Swing
	// =====================================	
	if (g_bMoodSwing)
	{
		WitchAbility_MoodSwing(witch);
	}
	
	// =====================================
	// Witch Ability: Shameful Cloak
	// =====================================
	if (g_bShamefulCloak)
	{
		WitchAbility_ShamefulCloak(witch);
	}
	
	return Plugin_Continue;
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!g_bMapRunning || IsServerProcessing() == false) return Plugin_Continue;
	
	if (IsValidWitch(victim) && IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
	{
		// =====================================
		// Witch Ability: Death Helmet
		// =====================================
		if (hitgroup[victim] == 1 && g_bDeathHelmet)
		{
			float damagemod = g_fDeathHelmetAmount;
			//PrintToChatAll("Head shot: %f damage times %f mod.", damage, damagemod);
			
			if (FloatCompare(damagemod, 1.0) != 0)
			{
				damage = damage * damagemod;
			}
		}

		// =====================================
		// Witch Ability: Unrelenting Spirit
		// =====================================
		if (hitgroup[victim] != 1 && g_bUnrelentingSpirit)
		{
			float damagemod = g_fUnrelentingSpiritAmount;
			//PrintToChatAll("Body shot: %f damage times %f mod.", damage, damagemod);
			if (FloatCompare(damagemod, 1.0) != 0)
			{
				damage = damage * damagemod;
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

Action OnHitPoint(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup1)
{
	if (!IsValidClient(attacker) && GetClientTeam(attacker) != TEAM_SURVIVOR) {
		return Plugin_Continue;
	}
	
	hitgroup[victim] = hitgroup1;
	
	return Plugin_Continue;
}

void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast) {

 	int harasser = GetClientOfUserId(event.GetInt("userid"));
	int witch =  event.GetInt("witchid");
	
	if (!IsValidClient(harasser) || GetClientTeam(harasser) != TEAM_SURVIVOR || !IsValidWitch(witch)) return;
	
	static char classname[64];
	GetEdictClassname(witch, classname, sizeof(classname));
	if (strcmp(classname, "terror_player_manager") == 0) return;
	if (strcmp(classname, "instanced_scripted_scene") == 0) return;
	
	g_bPsychoticWitch[witch] = true;
	
	// =====================================
	// Witch Ability: Psychotic Charge
	// =====================================
	if (g_bPsychoticCharge)
		WitchAbility_PsychoticCharge(harasser, witch);
	// =====================================
	// Witch Ability: Support Group
	// =====================================
	if (g_bSupportGroup)
		WitchAbility_SupportGroup(harasser);

}

void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast) {

	int client = GetClientOfUserId(event.GetInt("subject"));

	if (!IsValidClient(client) && GetClientTeam(client) != TEAM_SURVIVOR) return;

	StopBeat(client);
}

void Event_PlayerIncapped(Event event, const char[] name, bool dontBroadcast) {

 	int client = GetClientOfUserId(event.GetInt("userid"));  
	int witch =  event.GetInt("attackerentid");  
	
	if (!IsValidWitch(witch)) return;
	
	g_bPsychoticWitch[witch] = false;
	
	// =====================================
	// Witch Ability: Leeching Claw
	// =====================================	
	if (g_bLeechingClaw)
		WitchAbility_LeechingClaw(client, witch);

	// =====================================
	// Witch Ability: Nightmare Claw
	// =====================================
	if (g_bNightmareClaw)
		WitchAbility_NightmareClaw(client, witch);
		
	// =====================================
	// Witch Ability: Slashing Wind
	// =====================================
	if (g_bSlashingWind)
		WitchAbility_SlashingWind(client, witch);
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {

	int witch =  event.GetInt("witchid");
	
	g_bPsychoticWitch[witch] = false;

	// =====================================
	// Witch Ability: Sorrowful Remorse
	// =====================================	
	if (g_bSorrowfulRemorse)
		WitchAbility_SorrowfulRemorse(witch);
}


void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {

	if (!g_bAssimilation) return;
	
	int victim = GetClientOfUserId(event.GetInt("userid")); 
	int witch =  event.GetInt("attackerentid");
	
	if (!IsValidClient(victim) || GetClientTeam(victim) != TEAM_SURVIVOR || !IsValidWitch(witch)) return;

	// =====================================
	// Witch Ability: Assimilation
	// =====================================	
	WitchAbility_Assimilation(victim, witch);
}



// ===========================================
// Witch Ability: Assimilation
// ===========================================
// Description: When a Survivor is killed by the Witch, she raises them in her image, creating another Witch.

void WitchAbility_Assimilation(int victim, int witch)
{
	if (!IsValidClient(victim) || !IsValidWitch(witch) || GetClientTeam(victim) != TEAM_SURVIVOR || IsPlayerAlive(victim)) return;
	
	float vOrigin[3], vAngles[3];
	GetClientAbsOrigin(victim, vOrigin);
	GetClientAbsAngles(victim, vAngles);
	// L4D2_SpawnWitch(vOrigin, vAngles);
	int ent = CreateEntityByName("witch");
	if (ent <= 0)
		return;
	TeleportEntity(ent, vOrigin, vAngles, NULL_VECTOR);
	DispatchSpawn(ent);
}
	
	

	
// ===========================================
// Witch Ability: Death Helmet
// ===========================================
// Description: The Witch places a hollowed out propane tank on her head to reduce damage to her brain.

void WitchAbility_DeathHelmet(int witch)
{
	if (!IsValidWitch(witch)) return;

	int propane = CreateEntityByName("prop_dynamic_override");
	SetEntityModel(propane, MODEL_PROPANE);
	DispatchSpawn(propane);
	SetEntPropFloat(propane, Prop_Data, "m_flModelScale", 0.60);

	int random = GetRandomInt(0, 1);
	if( random == 0 )
		SetEntityRenderColor(propane, 0, 0, 0, 255);
		
	// Parent attachment
	SetVariantString("!activator"); 
	AcceptEntityInput(propane, "SetParent", witch);
	SetVariantString("forward");
	AcceptEntityInput(propane, "SetParentAttachment");

	TeleportEntity(propane, {-5.0, -4.5, -2.0}, {110.0, -10.0, 0.0}, NULL_VECTOR);
}




// ===========================================
// Witch Ability: Leeching Claw
// ===========================================
// Description: When the Witch incaps a Survivor, she heals herself with some of their stolen life force.

void WitchAbility_LeechingClaw(int client, int witch)
{
	if (!IsValidClient(client) || !IsValidWitch(witch)) return;

	int iHPRegen = g_iLeechingClawAmount;
	int iHP = GetEntProp(witch, Prop_Data, "m_iHealth");
	int iMaxHP = GetEntProp(witch, Prop_Data, "m_iMaxHealth");
				
	//PrintToChatAll("%i and %i to %i.", iHP, iHPRegen, iMaxHP);
	if ((iHPRegen + iHP) <= iMaxHP)
	{
		SetEntProp(witch, Prop_Data, "m_iHealth", iHPRegen + iHP);
	}
	else if ((iHP < iMaxHP) && (iMaxHP < (iHPRegen + iHP)) )
	{
		SetEntProp(witch, Prop_Data, "m_iHealth", iMaxHP);
	}
}




// ===========================================
// Witch Ability: Mood Swing
// ===========================================
// Description: With her mood changes, the Witch also has a varied health and speed factor.

void WitchAbility_MoodSwing(int witch)
{
	if (!IsValidWitch(witch)) return;

	//int wHPMin = g_iMoodSwingHPMin;
	//int wHPMax = g_iMoodSwingHPMax;
	int wHP = GetRandomInt(g_iMoodSwingHPMin, g_iMoodSwingHPMax);
	SetEntProp(witch, Prop_Data, "m_iMaxHealth", wHP);//Set max and 
	SetEntProp(witch, Prop_Data, "m_iHealth", wHP); //current health of witch to defined health.
		
	//new Float:wSpeedMin = GetConVarFloat(cvarMoodSwingSpeedMin);
	//new Float:wSpeedMax = GetConVarFloat(cvarMoodSwingSpeedMax);
	float wSpeed = GetRandomFloat(g_fMoodSwingSpeedMin, g_fMoodSwingSpeedMax);
	AcceptEntityInput(witch, "Disable"); 
	SetEntPropFloat(witch, Prop_Data, "m_flSpeed", 1.0*wSpeed);
	AcceptEntityInput(witch, "Enable");
}

// ===========================================
// Witch Ability: Nightmare Claw
// ===========================================
// Description: When incapped by an enraged Witch the Survivor is either set to B&W or killed.

void WitchAbility_NightmareClaw(int client, int witch)
{
	if (!IsValidClient(client) || !IsValidWitch(witch)) return;
	
	switch (g_iNightmareClawType)
	{
		case 1:
		{
			int revivemax = FindConVar("survivor_max_incapacitated_count").IntValue;
			SetEntProp(client, Prop_Send, "m_currentReviveCount", revivemax);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1);
			EmitSoundToClient(client, "player/heartbeatloop.wav");
			HeartSound[client] = true;
		}
		
		case 2:
		{
			ForcePlayerSuicide(client);
			if (g_bAssimilation)
				WitchAbility_Assimilation(client, witch);
		}
		
		default:
		{
			ForcePlayerSuicide(client);
			if (g_bAssimilation)
				WitchAbility_Assimilation(client, witch);
		}
	}
}

// ===========================================
// Witch Ability: Psychotic Charge
// ===========================================
// Description: The Witch will knock back any Survivors in her path while pursuing her victim.

void WitchAbility_PsychoticCharge(int harasser, int witch)
{
	DataPack dPack = new DataPack();
	delete g_hPsychoticChargeTimer[witch];
	g_hPsychoticChargeTimer[witch] = CreateDataTimer(2.0, Timer_PsychoticCharge, dPack, TIMER_REPEAT);
	dPack.WriteCell(harasser);
	dPack.WriteCell(witch);
}

Action Timer_PsychoticCharge(Handle timer, DataPack dPack)
{
	dPack.Reset();
	int harasser = dPack.ReadCell();
	int witch = dPack.ReadCell();
	if (!g_bPsychoticWitch[witch] || !IsValidWitch(witch))
	{
		g_hPsychoticChargeTimer[witch] = null;
		return Plugin_Stop;
	}
	
	if (IsValidClient(harasser) && GetClientTeam(harasser) == TEAM_SURVIVOR)
	{
		for (int victim = 1; victim <= MaxClients; victim++)
		{
			if (victim == harasser || !IsValidClient(victim) || GetClientTeam(victim) != TEAM_SURVIVOR) continue;
			
			float witchPos[3], survivorPos[3], distance;

			//new Float:range = GetConVarFloat(cvarPsychoticChargeRange);
			GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
			GetClientEyePosition(victim, survivorPos);
			distance = GetVectorDistance(survivorPos, witchPos);
											
			if (distance < g_iPsychoticChargeRange)
			{
				static char sRadius[256], sPower[256];

				//new magnitude = GetConVarInt(cvarPsychoticChargePower);
				IntToString(g_iPsychoticChargeRange, sRadius, sizeof(sRadius));
				IntToString(g_iPsychoticChargePower, sPower, sizeof(sPower));
				int exPhys = CreateEntityByName("env_physexplosion");
					
				if(exPhys != -1)
				{
					//Set up physics movement explosion
					DispatchKeyValue(exPhys, "radius", sRadius);
					DispatchKeyValue(exPhys, "magnitude", sPower);
					DispatchSpawn(exPhys);
					TeleportEntity(exPhys, witchPos, NULL_VECTOR, NULL_VECTOR);
									
					//BOOM!
					AcceptEntityInput(exPhys, "Explode");
				}
				float traceVec[3], resultingVec[3], currentVelVec[3];
				MakeVectorFromPoints(witchPos, survivorPos, traceVec);				// draw a line from car to Survivor
				GetVectorAngles(traceVec, resultingVec);							// get the angles of that line
								
				resultingVec[0] = Cosine(DegToRad(resultingVec[1])) * g_iPsychoticChargePower;	// use trigonometric magic
				resultingVec[1] = Sine(DegToRad(resultingVec[1])) * g_iPsychoticChargePower;
				resultingVec[2] = g_iPsychoticChargePower * SLAP_VERTICAL_MULTIPLIER;
							
				GetEntPropVector(victim, Prop_Data, "m_vecVelocity", currentVelVec);		// add whatever the Survivor had before
				resultingVec[0] += currentVelVec[0];
				resultingVec[1] += currentVelVec[1];
				resultingVec[2] += currentVelVec[2];

				DamageHook(victim, witch, g_iPsychoticChargeDamage);

				SDKCall(g_hPlayerFling, victim, resultingVec, 76, harasser, 3.0); //76 is the 'got bounced' animation in L4D2
			}
		}
	}
	return Plugin_Continue;
}




// ===========================================
// Witch Ability: Shameful Cloak
// ===========================================
// Description: Distraught by what she has become, the Witch will try to hide her form from the world.

void WitchAbility_ShamefulCloak(int witch)
{
	if (!IsValidWitch(witch)) return;

	int ShamefulCloakChance = GetRandomInt(0, 99);

	if (ShamefulCloakChance < g_iShamefulCloakChance)
	{
		SetEntityRenderFx(witch, RENDERFX_HOLOGRAM);
		SetEntityRenderColor(witch, 255, 255, 255, g_iShamefulCloakVisibility);
	}
}




// ===========================================
// Witch Ability: Slashing Wind
// ===========================================
// Description: When the Witch incaps a Survivor it sends out a shockwave damaging and knocking back all Survivors.

void WitchAbility_SlashingWind(int client, int witch)
{
	for (int victim = 1; victim <= MaxClients; victim++)
	{
		if (victim == client || !IsValidClient(victim) || GetClientTeam(victim) != TEAM_SURVIVOR) continue;

		float witchPos[3], survivorPos[3], distance;

		GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
		GetClientEyePosition(victim, survivorPos);
		distance = GetVectorDistance(survivorPos, witchPos);
									
		if (distance < g_iSlashingWindRange)
		{
			float vecOrigin[3];
			GetClientAbsOrigin(client, vecOrigin);
			SDKCall(g_hOnStaggered, victim, client, witchPos); 
			DamageHook(victim, witch, g_iSlashingWindDamage);
		}
	}
}

// ===========================================
// Witch Ability: Sorrowful Remorse
// ===========================================
// Description: When a Witch is killed, she leaves behind a Medkit and Defib as repetance for her actions.

void WitchAbility_SorrowfulRemorse(int witch)
{
	float entityPos[3], entityAng[3];
	int item1 = CreateEntityByName("weapon_first_aid_kit");
	int item2 = CreateEntityByName("weapon_defibrillator"); 
	GetEntPropVector(witch, Prop_Send, "m_vecOrigin", entityPos);
	GetEntPropVector(witch, Prop_Send, "m_angRotation", entityAng);
	
	if (item1 != -1)
	{
		TeleportEntity(item1, entityPos, entityAng, NULL_VECTOR );
		DispatchSpawn(item1);
	}
	
	if (item2 != -1)
	{
		TeleportEntity(item2, entityPos, entityAng, NULL_VECTOR );
		DispatchSpawn(item2);
	}
}




// ===========================================
// Witch Ability: Support Group
// ===========================================
// Description: When the Witch is angered, her hateful shriek calls down a panic event.

void WitchAbility_SupportGroup(int harasser)
{
	if (!IsValidClient(harasser) || GetClientTeam(harasser) != TEAM_SURVIVOR ) return;
	
	SDKCall(g_hResetMobTimer, g_pDirector);
	ExecuteCheatCommand("director_force_panic_event");
	//L4D_ResetMobTimer();	
}

// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================        GENERIC CALLS         =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

void DamageHook(int victim, int attacker, int damage)
{
	float victimPos[3];
	char strDamage[16], strDamageTarget[16];
			
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	int entPointHurt = CreateEntityByName("point_hurt");
	
	if(!entPointHurt) return;

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	//RemoveEdict(entPointHurt);
	AcceptEntityInput(entPointHurt, "Kill");
}

void ExecuteCheatCommand(const char[] sCommand, const char[] sValue = "") {
	int iCmdFlags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", sCommand, sValue);
	ServerExecute();
	SetCommandFlags(sCommand, iCmdFlags);
}

void StopBeat(int client)
{
	if (HeartSound[client])
	{
		StopSound(client, SNDCHAN_AUTO, "player/heartbeatloop.wav");
		HeartSound[client] = false;
	}
}

// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================          Sightings          =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

GameData FetchGameData(const char[] file)
{
	char sFilePath[128];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", file);
	if (!FileExists(sFilePath))
	{
		File fileTemp = OpenFile(sFilePath, "w");
		if (fileTemp == null)
		{
			SetFailState("Something went wrong while creating the game data file!");
		}
		
		fileTemp.WriteLine("\"Games\"");
		fileTemp.WriteLine("{");
		fileTemp.WriteLine("	\"left4dead2\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Addresses\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"CDirector\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"linux\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"signature\"		\"TheDirector\"");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("				\"windows\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"signature\"		\"CDirectorMusicBanks::OnRoundStart\"");
		fileTemp.WriteLine("					\"read\"		\"12\"");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("				\"read\"	\"0\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("		\"Signatures\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"CTerrorPlayer::OnStaggered\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZN13CTerrorPlayer11OnStaggeredEP11CBaseEntityPK6Vector\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\\x2A\\x2A\\x83\\x2A\\x2A\\x55\\x8B\\x2A\\x2A\\x89\\x2A\\x2A\\x2A\\x8B\\x2A\\x83\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\x2A\\x0F\\x85\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\x8B\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 83 ? ? 83 ? ? 55 8B ? ? 89 ? ? ? 8B ? 83 ? ? 56 57 8B ? E8 ? ? ? ? 84 ? 0F 85 ? ? ? ? 8B ? 8B */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTerrorPlayer::Fling\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZN13CTerrorPlayer5FlingERK6Vector17PlayerAnimEvent_tP20CBaseCombatCharacterf\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\\xE4\\x2A\\x83\\xC4\\x2A\\x55\\x8B\\x6B\\x2A\\x89\\x6C\\x2A\\x2A\\x8B\\xEC\\x81\\x2A\\x2A\\x2A\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\xC5\\x89\\x45\\x2A\\x8B\\x43\\x2A\\x56\\x8B\\x73\\x2A\\x57\\x6A\\x2A\\x8B\\xF9\\x89\\x45\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 83 E4 ? 83 C4 ? 55 8B 6B ? 89 6C ? ? 8B EC 81 ? ? ? ? ? A1 ? ? ? ? 33 C5 89 45 ? 8B 43 ? 56 8B 73 ? 57 6A ? 8B F9 89 45 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CDirector::ResetMobTimer\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZN9CDirector13ResetMobTimerEv\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x55\\x8B\\xEC\\x51\\x56\\x57\\x8D\\xB9\\x2A\\x2A\\x2A\\x2A\\x8B\\xCF\\xE8\\x2A\\x2A\\x2A\\x2A\\xD9\"");
		fileTemp.WriteLine("				/* 55 8B EC 51 56 57 8D B9 ? ? ? ? 8B CF E8 ? ? ? ? D9 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"TheDirector\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@TheDirector\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CDirectorMusicBanks::OnRoundStart\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"		\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x8B\\x0D\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\x2A\\x0F\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 56 57 8B ? 8B 0D ? ? ? ? E8 ? ? ? ? 84 ? 0F */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("}");
		
		fileTemp.Close();
	}
	
	return new GameData(file);
}

void InitData() 
{
	GameData hTemp = FetchGameData("l4d2_Psychotic_Witch");
	if (hTemp == null)
	{
		SetFailState("Psychotic_Witch: signature file not found!");
		delete hTemp;
		return;
	}
	g_pDirector = hTemp.GetAddress("CDirector");
	if (!g_pDirector)
	{
		SetFailState("Failed to find address: \"CDirector\"");
	}
	StartPrepSDKCall(SDKCall_Player);
	// PrepSDKCall_SetFromConf(hTemp, SDKConf_Signature, "CTerrorPlayer::Fling");
	if(PrepSDKCall_SetFromConf(hTemp, SDKConf_Signature, "CTerrorPlayer::Fling") == false )
	{
		SetFailState("Failed to find signature: \"CTerrorPlayer::Fling\"");
	}
	else
	{
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hPlayerFling = EndPrepSDKCall();
		if (g_hPlayerFling == null)
		{
			SetFailState("Cant initialize Fling SDKCall");
		}
	}
	
	StartPrepSDKCall(SDKCall_Player);
	// PrepSDKCall_SetFromConf(hTemp, SDKConf_Signature, "CTerrorPlayer::OnStaggered");
	if(PrepSDKCall_SetFromConf(hTemp, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
	{
		SetFailState("Failed to find signature: \"CTerrorPlayer::OnStaggered\"");
	}
	else
	{
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
		g_hOnStaggered = EndPrepSDKCall();
		if (g_hOnStaggered == null)
		{
			SetFailState("Unable to find the \"CTerrorPlayer::OnStaggered(CBaseEntity *, Vector  const*)\" signature, check the file version!");
		}
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hTemp, SDKConf_Signature, "CDirector::ResetMobTimer") == false )
	{
		SetFailState("Failed to find signature: \"CDirector::ResetMobTimer\"");
	} 
	else 
	{
		g_hResetMobTimer = EndPrepSDKCall();
		if(g_hResetMobTimer == null )
			SetFailState("Unable to find the \"CDirector::ResetMobTimer\" signature, check the file version!");
	}
	delete hTemp;
}
// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================          BOOL CALLS          =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

bool IsValidWitch(int witch)
{
	if(witch > MaxClients && IsValidEdict(witch) && IsValidEntity(witch))
	{
		static char classname[32];
		GetEdictClassname(witch, classname, sizeof(classname));
		return strcmp(classname, "witch", false) == 0;
	}
	
	return false;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
