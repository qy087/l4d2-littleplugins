#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>

#define PLUGIN_VERSION "2026/7/18"
#define PLUGIN_NAME	   "l4d2_chainsaw_canpickup"

public Plugin myinfo =
{
	name		= "[L4D2] 允许电锯攻击中拾取",
	author		= "qy087",
	description = "允许电锯攻击中拾取物品，武器等",
	version		= PLUGIN_VERSION,
	url			= ""
};

bool bLate;

int g_iOffsetState, g_iOffsetActiveWp;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_iOffsetState	  = FindSendPropInfo("CChainsaw", "m_bHitting") - 4;
	g_iOffsetActiveWp = FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
	if (bLate)
	{
		vLateLoad();
	}
}

void vLateLoad()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		OnClientPutInServer(client);
	}
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) return;
	//Post太晚了效果不佳
	SDKUnhook(client, SDKHook_WeaponCanUse, SDKWeaponCanUse);
	SDKHook(client, SDKHook_WeaponCanUse, SDKWeaponCanUse);
}

Action SDKWeaponCanUse(int client, int weapon)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return Plugin_Continue;

	if (weapon <= MaxClients || !IsValidEntity(weapon))
		return Plugin_Continue;
		
	int iActiveWeapon = GetEntDataEnt2(client, g_iOffsetActiveWp);
	if (iActiveWeapon <= MaxClients || !IsValidEntity(iActiveWeapon))
		return Plugin_Continue;
	static char sWeaponName[32];
	GetEntityClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
	if(strcmp(sWeaponName, "weapon_chainsaw", false) == 0)
	{
		if (GetEntData(iActiveWeapon, g_iOffsetState) != 3) return Plugin_Continue;
		SetEntData(iActiveWeapon, g_iOffsetState, 2, true);
	}
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
