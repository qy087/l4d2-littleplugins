/*****************************************************************
 Original https://forums.alliedmods.net/showthread.php?p=2092125
*****************************************************************/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#pragma semicolon 1
#pragma newdecls required
#define PLUGIN_VERSION "1.4"
#define CVAR_FLAGS                    FCVAR_NOTIFY

float SLAP_VERTICAL_MULTIPLIER			= 1.5;
int laggedMovementOffset = 0;
float countdown = 0.0;
float acceleration = 0.1;

bool isBrokenRibs = false;

ConVar 
	g_cvBrokenRibs,
	g_cvBrokenRibsChance,
	g_cvBrokenRibsDamage,
	g_cvBrokenRibsDuration,
	g_cvLocomotive,
	g_cvLocomotiveDuration,
	g_cvLocomotiveSpeed,
	g_cvMeteorFist,
	g_cvMeteorFistPower,
	g_cvMeteorFistCooldown,
	g_cvInertiaVault,
	g_cvInertiaVaultPower,
	g_cvExtinguishingWind,
	g_cvSnappedLeg,
	g_cvSnappedLegChance,
	g_cvSnappedLegDuration,
	g_cvSnappedLegSpeed,
	g_cvStowaway,
	g_cvStowawayDamage,
	g_cvSurvivorAegis,
	g_cvSurvivorAegisAmount,
	g_cvSurvivorAegisDamage,
	g_cvVoidChamber,
	g_cvVoidChamberPower,
	g_cvVoidChamberDamage,
	g_cvVoidChamberRange;
	
Handle 
	g_hStowawayTimer[MAXPLAYERS + 1],
	g_hLocomotiveTimer[MAXPLAYERS+1],
	g_hResetDelayTimer[MAXPLAYERS+1],
	g_hSnappedLegTimer[MAXPLAYERS + 1],
	g_hBrokenRibsTimer[MAXPLAYERS + 1];

bool 
	isCarried[MAXPLAYERS+1] = { false },
	isCharging[MAXPLAYERS+1] = { false },
	isSlowed[MAXPLAYERS+1] = { false },
	buttondelay[MAXPLAYERS+1] = { false },
	g_bVoidChamber,
	g_bSurvivorAegis,
	g_bStowAway,
	g_bSnappedLeg,
	g_bMeteorFist,
	g_bLocomotive,
	g_bExtinguishingWind,
	g_bInertiaVault;

int 
	g_iBrokenRibsChance,
	g_iBrokenRibsDuration,
	g_iBrokenRibsDamage,
	g_iSnappedLegChance,
	g_iStowawayDamage,
	g_iVoidChamberPower,
	g_iVoidChamberDamage,
	g_iSurvivorAegisDamage,
	stowaway[MAXPLAYERS+1],
	brokenribs[MAXPLAYERS+1];

float 
	g_fSurvivorAegisAmount,
	g_fInertiaVaultPower,
	g_fLocomotiveDuration,
	g_fLocomotiveSpeed,
	g_fMeteorFistPower,
	g_fSnappedLegSpeed,
	g_fSnappedLegDuration,
	g_fVoidChamberRange,
	g_fMeteorFistCooldown,
	lastMeteorFist[MAXPLAYERS+1] = { 0.0 };

//Handle sdkCallFling;

public Plugin myinfo = 
{
    name = "[L4D2] Unstoppable Charger",
    author = "Mortiegama",
    description = "Allows for unique Charger abilities to bring fear to this titan.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?p=2092125#post2092125"
}

	//Special Thanks:
	//AtomicStryker - Boomer Bit** Slap:
	//https://forums.alliedmods.net/showthread.php?t=97952
	
	//AtomicStryker - Damage Mod (SDK Hooks):
	//https://forums.alliedmods.net/showthread.php?p=1184761
	
	//Karma - Tank Skill Roar
	//https://forums.alliedmods.net/showthread.php?t=126919

public void OnPluginStart()
{
	CreateConVar("l4d_ucm_version", PLUGIN_VERSION, "Unstoppable Charger Version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

	g_cvBrokenRibs = CreateConVar("l4d_ucm_brokenribs", "1", "Enables Broken Ribs ability: Due to the Charger's crushing grip, Survivors may have their ribs broken as a result of pummeling.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvBrokenRibsChance = CreateConVar("l4d_ucm_brokenribschance", "100", "Chance that after a pummel ends the Survivor takes damage over time (100 = 100%).", CVAR_FLAGS, true, 0.0);
	g_cvBrokenRibsDuration = CreateConVar("l4d_ucm_brokenribsduration", "10", "For how many seconds should the Broken Ribs cause damage.", CVAR_FLAGS, true, 0.0);
	g_cvBrokenRibsDamage = CreateConVar("l4d_ucm_brokenribsdamage", "1", "How much damage is inflicted by Broken Ribs each second.", CVAR_FLAGS, true, 0.0);

	g_cvExtinguishingWind = CreateConVar("l4d_ucm_extinguishingwind", "0", "Enables Extinguish Wind ability: The force of wind the Charger creates while charging is capable of extinguishing flames on his body."), CVAR_FLAGS, true, 0.0, true, 1.0;

	g_cvInertiaVault = CreateConVar("l4d_ucm_inertiavault", "1", "Enables Inertia Vault ability: While charging the Charger has the ability to leap into the air and travel a short distance.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvInertiaVaultPower = CreateConVar("l4d_ucm_inertiavaultpower", "400.0", "Power behind the Charger's jump.", CVAR_FLAGS, true, 0.0);

	g_cvLocomotive = CreateConVar("l4d_ucm_locomotive", "1", "Enables Locomotive ability: While charging, the Charger is able to increase speed and duration the longer it doesn't hit anything.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvLocomotiveSpeed = CreateConVar("l4d_ucm_locomotivespeed", "1.4", "Multiplier for increase in Charger speed.", CVAR_FLAGS, true, 0.0);
	g_cvLocomotiveDuration = CreateConVar("l4d_ucm_locomotiveduration", "4.0", "Amount of time for which the Charger continues to run.", CVAR_FLAGS, true, 0.0);

	g_cvMeteorFist = CreateConVar("l4d_ucm_meteorfist", "1", "Enables Meteor Fist ability: Utilizing his overally muscular arm, when the Charger strikes a Survivor while charging or with his fist, they are sent flying.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvMeteorFistPower = CreateConVar("l4d_ucm_meteorfistpower", "200.0", "Power behind the Charger's Meteor Fist", CVAR_FLAGS);
	g_cvMeteorFistCooldown = CreateConVar("l4d_ucm_meteorfistcooldown", "10.0", "Amount of time between Meteor Fists", CVAR_FLAGS);

	g_cvSnappedLeg = CreateConVar("l4d_ucm_snappedleg", "1", "Enables Snapped Leg ability: When the Charger collides with a Survivor, it snaps their leg causing them to move slower.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvSnappedLegChance = CreateConVar("l4d_ucm_snappedlegchance", "100", "Chance that after a charger collision movement speed is reduced.", CVAR_FLAGS);
	g_cvSnappedLegDuration = CreateConVar("l4d_ucm_snappedlegduration", "5", "For how many seconds will the Snapped Leg reduce movement speed (100 = 100%).", CVAR_FLAGS);
	g_cvSnappedLegSpeed = CreateConVar("l4d_ucm_snappedlegspeed", "0.5", "How much does Snapped Leg reduce movement speed.", CVAR_FLAGS);

	g_cvStowaway = CreateConVar("l4d_ucm_stowaway", "0", "Enables Stowaway ability: The longer the Charger has a Survivor, the more damage adds the Charger will deal when the charge comes to an end.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvStowawayDamage = CreateConVar("l4d_ucm_stowawaydamage", "5", "How much damage is inflicted by Stowaway for each second carried.", CVAR_FLAGS);

	g_cvSurvivorAegis = CreateConVar("l4d_ucm_survivoraegis", "1", "Enables Survivor Aegis ability: While charging, the Charger will use the Survivor as an Aegis to absorb damage it would receive.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvSurvivorAegisAmount = CreateConVar("l4d_ucm_survivoraegisamount", "0.2", "Percent of damage the Charger avoids using a Survivor as an Aegis.", CVAR_FLAGS);
	g_cvSurvivorAegisDamage = CreateConVar("l4d_ucm_survivoraegisdamage", "5", "How much damage is inflicted to the Survivor being used as an Aegis.", CVAR_FLAGS);

	g_cvVoidChamber = CreateConVar("l4d_ucm_voidchamber", "1", "Enables Void Chamber ability: When starting a charge, the force is so powerful it sucks nearby Survivors in the void left behind.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_cvVoidChamberPower = CreateConVar("l4d_ucm_voidchamberpower", "150.0", "Power behind the inner range of Methane Blast.", CVAR_FLAGS);
	g_cvVoidChamberDamage = CreateConVar("l4d_ucm_voidchamberdamage", "10", "Damage the force of the roar causes to nearby survivors.", CVAR_FLAGS);
	g_cvVoidChamberRange = CreateConVar("l4d_ucm_voidchamberrange", "200.0", "Area around the Tank the bellow will reach", CVAR_FLAGS);

	//AutoExecConfig(true, "L4D2_UnstoppableCharger");

	GetCvars_Allow();
	GetCvars();
	g_cvBrokenRibs.AddChangeHook(ConVarChanged_Allow);
	g_cvExtinguishingWind.AddChangeHook(ConVarChanged_Allow);
	g_cvInertiaVault.AddChangeHook(ConVarChanged_Allow);
	g_cvLocomotive.AddChangeHook(ConVarChanged_Allow);
	g_cvMeteorFist.AddChangeHook(ConVarChanged_Allow);
	g_cvSnappedLeg.AddChangeHook(ConVarChanged_Allow);
	g_cvStowaway.AddChangeHook(ConVarChanged_Allow);
	g_cvSurvivorAegis.AddChangeHook(ConVarChanged_Allow);
	g_cvVoidChamber.AddChangeHook(ConVarChanged_Allow);
	
	g_cvBrokenRibsChance.AddChangeHook(ConVarChanged_Cvars);
	g_cvBrokenRibsDuration.AddChangeHook(ConVarChanged_Cvars);
	g_cvBrokenRibsDamage.AddChangeHook(ConVarChanged_Cvars);
	g_cvSnappedLegChance.AddChangeHook(ConVarChanged_Cvars);
	g_cvStowawayDamage.AddChangeHook(ConVarChanged_Cvars);
	g_cvVoidChamberPower.AddChangeHook(ConVarChanged_Cvars);
	g_cvVoidChamberDamage.AddChangeHook(ConVarChanged_Cvars);
	g_cvSurvivorAegisDamage.AddChangeHook(ConVarChanged_Cvars);
	g_cvSurvivorAegisAmount.AddChangeHook(ConVarChanged_Cvars);
	g_cvInertiaVaultPower.AddChangeHook(ConVarChanged_Cvars);
	g_cvLocomotiveDuration.AddChangeHook(ConVarChanged_Cvars);
	g_cvLocomotiveSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_cvMeteorFistPower.AddChangeHook(ConVarChanged_Cvars);
	g_cvSnappedLegSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_cvSnappedLegDuration.AddChangeHook(ConVarChanged_Cvars);
	g_cvVoidChamberRange.AddChangeHook(ConVarChanged_Cvars);
	g_cvMeteorFistCooldown.AddChangeHook(ConVarChanged_Cvars);
	
	HookEvent("charger_pummel_end", Event_ChargerPummelEnd);
	HookEvent("charger_impact", Event_ChargerImpact);
	HookEvent("charger_carry_start", Event_ChargerCarryStart);
	HookEvent("charger_carry_end", Event_ChargerCarryEnd);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("charger_charge_end", Event_ChargeEnd);	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");

}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars_Allow();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars_Allow()
{
	isBrokenRibs 		= 		g_cvBrokenRibs.BoolValue;
	g_bExtinguishingWind = 		g_cvExtinguishingWind.BoolValue;
	g_bInertiaVault 		= 		g_cvInertiaVault.BoolValue;
	g_bLocomotive		= 		g_cvLocomotive.BoolValue;
	g_bMeteorFist		= 		g_cvMeteorFist.BoolValue;
	g_bSnappedLeg		= 		g_cvSnappedLeg.BoolValue;
	g_bStowAway			= 		g_cvStowaway.BoolValue;
	g_bSurvivorAegis		= 		g_cvSurvivorAegis.BoolValue;
	g_bVoidChamber		= 		g_cvVoidChamber.BoolValue;
	
}

void GetCvars()
{
	g_iBrokenRibsChance 		= 		g_cvBrokenRibsChance.IntValue;
	g_iBrokenRibsDuration 		= 		g_cvBrokenRibsDuration.IntValue;
	g_iBrokenRibsDamage 		= 		g_cvBrokenRibsDamage.IntValue;
	g_iSnappedLegChance			= 		g_cvSnappedLegChance.IntValue;
	g_iStowawayDamage			= 		g_cvStowawayDamage.IntValue;
	g_iVoidChamberPower			= 		g_cvVoidChamberPower.IntValue;
	g_iVoidChamberDamage		= 		g_cvVoidChamberDamage.IntValue;
	g_iSurvivorAegisDamage		= 		g_cvSurvivorAegisDamage.IntValue;
	
	g_fSurvivorAegisAmount		= 		g_cvSurvivorAegisAmount.FloatValue;
	g_fInertiaVaultPower		= 		g_cvInertiaVaultPower.FloatValue;
	g_fLocomotiveDuration		= 		g_cvLocomotiveDuration.FloatValue;
	g_fLocomotiveSpeed			= 		g_cvLocomotiveSpeed.FloatValue;
	g_fMeteorFistPower			= 		g_cvMeteorFistPower.FloatValue;
	g_fSnappedLegSpeed			= 		g_cvSnappedLegSpeed.FloatValue;
	g_fSnappedLegDuration		= 		g_cvSnappedLegDuration.FloatValue;
	g_fVoidChamberRange			= 		g_cvVoidChamberRange.FloatValue;
	g_fMeteorFistCooldown		= 		g_cvMeteorFistCooldown.FloatValue;
	FindConVar("z_charge_duration").SetFloat(g_fLocomotiveDuration);
	
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnConfigsExecuted()
{
	GetCvars_Allow();
	GetCvars();
}

public void OnMapEnd()
{
    for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			isCharging[i] = false;
		}
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client)) return;
	isCharging[client] = false;
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || !IsValidCharger(client)) return;

	if (g_bExtinguishingWind)
	{
		ChargerAbility_ExtinguishingWind(client);
	}
	if (g_bLocomotive)
	{
		ChargerAbility_LocomotiveStart(client);
	}
	if (g_bVoidChamber)
	{
		ChargerAbility_VoidChamber(client);
	}
	if (IsValidClient(client))
	{
		isCharging[client] = true;
	}
}

void Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(!victim || !IsClientInGame(victim)) return;
	if (g_bStowAway)
	{
		ChargerAbility_StowawayStart(victim);
	}	
}

void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	int victim =  GetClientOfUserId(event.GetInt("victim"));
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || !attacker || !IsClientInGame(attacker))
		return;

	if (g_bMeteorFist)
	{
		ChargerAbility_MeteorFist(victim, attacker);
	}

	if (g_bSnappedLeg)
	{
		ChargerAbility_SnappedLeg(victim);
	}
	
	if(g_bLocomotive)
	{
	    ChargerAbility_LocomotiveFinish(attacker);
	}
}

void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	SetEntDataFloat(client, laggedMovementOffset, 1.0, true);

	if (g_bLocomotive)
	{
		ChargerAbility_LocomotiveFinish(client);
	}
	if (IsValidClient(client))
	{
		isCharging[client] = false;
	}
}

void Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int victim =  GetClientOfUserId(event.GetInt("victim"));
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || !attacker || !IsClientInGame(attacker))
		return;

	if (g_bStowAway)
	{
		ChargerAbility_StowawayFinish(victim, attacker);
	}
}

void Event_ChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	int victim =  GetClientOfUserId(event.GetInt("victim"));
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || !attacker || !IsClientInGame(attacker))
		return;

	if (isBrokenRibs)
	{
		ChargerAbility_BrokenRibs(victim, attacker);
	}
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{

	if (g_bSurvivorAegis && IsValidCharger(victim) && IsValidClient(attacker) && isCharging[victim])
	{
		if (FloatCompare(g_fSurvivorAegisAmount, 1.0) != 0)
		{
			damage = damage * g_fSurvivorAegisAmount;
		}
		ChargerAbility_SurvivorAegis(victim);
	}

	if (IsValidCharger(attacker))
	{
		int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		if (g_bMeteorFist && L4D2_GetWeaponId(weapon) == L4D2WeaponId_ChargerClaw)
		{
			ChargerAbility_MeteorFist(victim, attacker);
			lastMeteorFist[attacker] = GetEngineTime();
		}
	}
	return Plugin_Changed;
}

Action ChargerAbility_BrokenRibs(int victim, int attacker)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR)
	{
		int BrokenRibsChance = GetRandomInt(0, 99);
		if (BrokenRibsChance < g_iBrokenRibsChance)
		{
			PrintHintText(victim, "The Charger broke your ribs!");
			if (brokenribs[victim] <= 0)
			{
				brokenribs[victim] = g_iBrokenRibsDuration;
				DataPack dataPack = new DataPack();
				g_hBrokenRibsTimer[victim] = CreateDataTimer(1.0, Timer_BrokenRibs, dataPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dataPack.WriteCell(attacker);
				dataPack.WriteCell(victim);
			}
		}
	}
	return Plugin_Continue;
}

Action Timer_BrokenRibs(Handle timer, DataPack dataPack) 
{
	dataPack.Reset();
	int attacker = dataPack.ReadCell();
	int victim = dataPack.ReadCell();
	if (IsValidClient(victim))
	{
		if (brokenribs[victim] <= 0)
		{
			if (g_hBrokenRibsTimer[victim] != null)
			{
				g_hBrokenRibsTimer[victim] = null;
			}
			return Plugin_Stop;
		}
		DamageHook(victim, attacker, g_iBrokenRibsDamage);
		if (brokenribs[victim] > 0) 
		{
			brokenribs[victim] -= 1;
		}
	}
	return Plugin_Continue;
}

void ChargerAbility_ExtinguishingWind(int client)
{
	if (IsPlayerOnFire(client))
	{
		ExtinguishEntity(client);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (buttons & IN_JUMP && IsValidClient(client) && isCharging[client])
	{
		if (g_bInertiaVault && !buttondelay[client] && IsPlayerOnGround(client))
		{
			buttondelay[client] = true;
			float vec[3];
			vec[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
			vec[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
			vec[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]") + g_fInertiaVaultPower;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vec);
			g_hResetDelayTimer[client] = CreateTimer(1.0, ResetDelay, client);
		}
	}
	return Plugin_Continue;
}

Action ResetDelay(Handle timer, int client)
{
	buttondelay[client] = false;
	if (g_hResetDelayTimer[client] != null)
	{
		KillTimer(g_hResetDelayTimer[client]);
		g_hResetDelayTimer[client] = null;
	}
	return Plugin_Stop;
}

Action ChargerAbility_LocomotiveStart(int client)
{
	if (IsValidCharger(client))
	{
		g_hLocomotiveTimer[client] = CreateTimer(0.5, Timer_LocomotiveStart, client, TIMER_REPEAT);
// 		SetEntDataFloat(client, laggedMovementOffset, 1.0*GetConVarFloat(g_cvLocomotiveSpeed), true);
	}
	return Plugin_Continue;
}

Action Timer_LocomotiveStart(Handle timer, int client)
{
	if(!IsValidClient(client))
	    return Plugin_Continue;
		
	if(countdown >= g_fLocomotiveDuration)
	{
	    g_hLocomotiveTimer[client] = null;
	    countdown = 0.0;
	    acceleration = 0.1;
	    return Plugin_Stop;
	}
	
	SetEntDataFloat(client, laggedMovementOffset, acceleration + g_fLocomotiveSpeed, true);
	
	countdown+=0.5;
	acceleration+=0.1;
	
	return Plugin_Continue;
}

Action ChargerAbility_LocomotiveFinish(int client)
{
	if (IsValidCharger(client))
	{
		delete g_hLocomotiveTimer[client];
		countdown = 0.0;
		acceleration = 0.1;
		SetEntDataFloat(client, laggedMovementOffset, 1.0, true);
	}
	return Plugin_Continue;
}

Action ChargerAbility_MeteorFist(int victim, int attacker)
{
	if (IsValidCharger(attacker) && MeteorFist(attacker) && IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR && !IsSurvivorPinned(victim))
	{
		FlingHook(victim, attacker, g_fMeteorFistPower);
	}
	return Plugin_Continue;
}

Action ChargerAbility_SnappedLeg(int victim)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR && !isSlowed[victim])
	{
		int SnappedLegChance = GetRandomInt(0, 99);
		if (SnappedLegChance < g_iSnappedLegChance)
		{
			isSlowed[victim] = true;
			PrintHintText(victim, "The Charger's impact has broken your leg!");
			SetEntDataFloat(victim, laggedMovementOffset, g_fSnappedLegSpeed, true);
			g_hSnappedLegTimer[victim] = CreateTimer(g_fSnappedLegDuration, Timer_SnappedLeg, victim);
		}
	}
	return Plugin_Continue;
}

Action Timer_SnappedLeg(Handle timer, int victim)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR)
	{
		SetEntDataFloat(victim, laggedMovementOffset, 1.0, true);
		PrintHintText(victim, "Your leg is starting to feel better.");
		isSlowed[victim] = false;
	}
	if (g_hSnappedLegTimer[victim] != null)
	{
		KillTimer(g_hSnappedLegTimer[victim]);
		g_hSnappedLegTimer[victim] = null;
	}		
	return Plugin_Stop;	
}

Action ChargerAbility_StowawayStart(int victim)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR)
	{
		stowaway[victim] = 1;
		isCarried[victim] = true;
		g_hStowawayTimer[victim] = CreateTimer(0.5, Timer_Stowaway, victim, TIMER_REPEAT);
	}
	return Plugin_Continue;
}

Action Timer_Stowaway(Handle timer, int client) 
{
	if (IsValidClient(client))
	{
		if (isCarried[client])
		{
			stowaway[client] += 1;
		}
		if (!isCarried[client])
		{
			if (g_hStowawayTimer[client] != null)
			{
				KillTimer(g_hStowawayTimer[client]);
				g_hStowawayTimer[client] = null;
			}
			return Plugin_Stop;	
		}
	}
	return Plugin_Continue;	
}

Action ChargerAbility_StowawayFinish(int victim, int attacker)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR)
	{
		isCarried[victim] = false;
		DamageHook(victim, attacker, g_iStowawayDamage);
	}
	return Plugin_Continue;
}

Action ChargerAbility_SurvivorAegis(int victim)
{
	int aegis = GetEntPropEnt(victim, Prop_Send, "m_carryVictim");
	if (IsValidClient(aegis))
	{
		DamageHook(aegis, victim, g_iSurvivorAegisDamage);
	}
	return Plugin_Continue;
}

Action ChargerAbility_VoidChamber(int attacker)
{
	if (IsValidCharger(attacker))
	{
		for (int victim = 1; victim <= MaxClients; victim++)
		if (IsValidClient(victim) && GetClientTeam(victim) == L4D_TEAM_SURVIVOR  && !IsSurvivorPinned(victim))
		{
			float chargerPos[3];
			float survivorPos[3];
			float distance;
			GetClientEyePosition(attacker, chargerPos);
			GetClientEyePosition(victim, survivorPos);
			distance = GetVectorDistance(survivorPos, chargerPos);
			if (distance < g_fVoidChamberRange)
			{
				char sRadius[256];
				char sPower[256];
				int magnitude;
				magnitude = g_iVoidChamberPower * -1;
				IntToString(RoundToCeil(g_fVoidChamberRange), sRadius, sizeof(sRadius));
				IntToString(magnitude, sPower, sizeof(sPower));
				int exPhys = CreateEntityByName("env_physexplosion");
				DispatchKeyValue(exPhys, "radius", sRadius);
				DispatchKeyValue(exPhys, "magnitude", sPower);
				DispatchSpawn(exPhys);
				TeleportEntity(exPhys, chargerPos, NULL_VECTOR, NULL_VECTOR);
				AcceptEntityInput(exPhys, "Explode");
				float traceVec[3];
				float resultingVec[3];
				float currentVelVec[3];
				float power = float(g_iVoidChamberPower);
				MakeVectorFromPoints(chargerPos, survivorPos, traceVec);
				GetVectorAngles(traceVec, resultingVec);
				resultingVec[0] = Cosine(DegToRad(resultingVec[1])) * power;
				resultingVec[1] = Sine(DegToRad(resultingVec[1])) * power;
				resultingVec[2] = power * SLAP_VERTICAL_MULTIPLIER;
				GetEntPropVector(victim, Prop_Data, "m_vecVelocity", currentVelVec);
				resultingVec[0] += currentVelVec[0];
				resultingVec[1] += currentVelVec[1];
				resultingVec[2] += currentVelVec[2];
				resultingVec[0] = resultingVec[0] * -1;
				resultingVec[1] = resultingVec[1] * -1;
				//SDKCall(sdkCallFling, victim, resultingVec, 76, attacker, incaptime);
				L4D2_CTerrorPlayer_Fling(victim, attacker, resultingVec);
				DamageHook(victim, attacker, g_iVoidChamberDamage);
			}
		}
	}
	return Plugin_Continue;
}

void DamageHook(int victim, int attacker, int damage)
{
	float victimPos[3];
	char strDamage[16];
	char strDamageTarget[16];	
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	int entPointHurt = CreateEntityByName("point_hurt");
	if (!entPointHurt)

	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0");
	DispatchSpawn(entPointHurt);
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	AcceptEntityInput(entPointHurt, "kill");
}

void FlingHook(int victim, int attacker, float power)
{
	float HeadingVector[3];
	float AimVector[3];
	GetClientEyeAngles(attacker, HeadingVector);	
	AimVector[0] = Cosine(DegToRad(HeadingVector[1]) * power);
	AimVector[1] = Sine(DegToRad(HeadingVector[1]) * power);	
	float current[3];
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", current);		
	float resulting[3];
	resulting[0] = current[0] + AimVector[0];	
	resulting[1] = current[1] + AimVector[1];
	resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
	//SDKCall(sdkCallFling, victim, resulting, 76, attacker, incaptime);
	L4D2_CTerrorPlayer_Fling(victim, attacker, resulting);
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}

bool MeteorFist(int slapper)
{
	return ((GetEngineTime() - lastMeteorFist[slapper]) > g_fMeteorFistCooldown);
}

bool IsPlayerOnGround(int client)
{
	if (GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND)
	{
		return true;
	}
	return false;
}

bool IsValidCharger(int client)
{
	if (IsValidClient(client))
	{
		if (L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Charger)
		{
			return true;
		}
	}
	return false;
}

bool IsPlayerOnFire(int client)
{
	if (IsValidClient(client))
	{
		if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE)
		{
			return true;
		}
	}
	return false;
}

bool IsSurvivorPinned(int client)
{
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}
