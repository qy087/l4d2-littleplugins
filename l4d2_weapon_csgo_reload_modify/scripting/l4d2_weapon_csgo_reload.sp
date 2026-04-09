#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sourcescramble>

#define PLUGIN_NAME		"l4d2_weapon_csgo_reload"
#define PLUGIN_VERSION	"2.4-2026/4/4"
#define CFG_FILE		"data/" ... PLUGIN_NAME ... ".cfg"

public Plugin myinfo = 
{
	name = "L4D2 weapon cs2 reload",
	author = "Harry Potter & qy087",
	description = "Reload like cs2 weapon",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
}

bool bLate;
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

enum WeaponID
{
	ID_NONE,
	ID_PISTOL,
	ID_DUAL_PISTOL,
	ID_SMG,
	ID_RIFLE,
	ID_HUNTING_RIFLE,
	ID_SMG_SILENCED,
	ID_SMG_MP5,
	ID_MAGNUM,
	ID_AK47,
	ID_RIFLE_DESERT,
	ID_SNIPER_MILITARY,
	ID_GRENADE,
	ID_SG552,
	ID_M60,
	ID_AWP,
	ID_SCOUT,
	ID_WEAPON_MAX
}

#define PISTOL_RELOAD_INCAP_MULTIPLY 1.25

StringMap g_smWeaponNameID;
int g_iWeaponMaxClip[view_as<int>(ID_WEAPON_MAX)];

ConVar g_hAmmoGL, g_hAmmoHunting, g_hAmmoM60, g_hAmmoRifle, g_hAmmoSmg, g_hAmmoSniper;
int g_iAmmoGL, g_iAmmoHunting, g_iAmmoM60, g_iAmmoRifle, g_iAmmoSmg, g_iAmmoSniper;

bool g_bEnable;

bool g_bWeaponEnable[view_as<int>(ID_WEAPON_MAX)];
float g_fWeaponReloadTime[view_as<int>(ID_WEAPON_MAX)];
bool g_bClearClipOnReload;

float g_fClientReloadTime[MAXPLAYERS+1] = {0.0};

MemoryPatch g_hPatchAddClip;
MemoryPatch g_hPatchClipToZero;

char g_sWeaponConfigName[ID_WEAPON_MAX][32];
// https://github.com/Target5150/MoYu_Server_Stupid_Plugins/blob/master/include/%40Forgetest/gamedatawrapper.inc
methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public MemoryPatch CreatePatchOrFail(const char[] name, bool enable = false) {
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(this, name);
		if (!(enable ? hPatch.Enable() : hPatch.Validate()))
			SetFailState("Failed to patch \"%s\"", name);
		return hPatch;
	}
}

public void OnPluginStart()
{
	vCheckAndCreatGameData();
	GameDataWrapper gd 		= new GameDataWrapper(PLUGIN_NAME);
	g_hPatchAddClip			= gd.CreatePatchOrFail("CTerrorGun::Reload__AddClip", false);
	g_hPatchClipToZero 		= gd.CreatePatchOrFail("CTerrorGun::Reload__ClipToZero", false);
	delete gd;

	g_hAmmoRifle =		FindConVar("ammo_assaultrifle_max");
	g_hAmmoSmg =		FindConVar("ammo_smg_max");
	g_hAmmoHunting =	FindConVar("ammo_huntingrifle_max");
	g_hAmmoGL =			FindConVar("ammo_grenadelauncher_max");
	g_hAmmoM60 =		FindConVar("ammo_m60_max");
	g_hAmmoSniper =		FindConVar("ammo_sniperrifle_max");
	
	ConVar cv 	= 		CreateConVar(PLUGIN_NAME ... "_allow", "1", "0=off plugin, 1=on plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	cv.AddChangeHook(ConVarChanged_Allow);
	
	GetAmmoCvars();
	g_hAmmoRifle.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoSmg.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoHunting.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoGL.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoM60.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoSniper.AddChangeHook(ConVarChanged_AmmoCvars);

	
	AutoExecConfig(true, PLUGIN_NAME);

	HookEvent("weapon_reload", OnWeaponReload_Event, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Event);
	AddCommandListener(CmdListen_weapon_reparse_server, "weapon_reparse_server");

	SetWeaponNameId();

	if (bLate)
		LateLoad();
}

void LateLoad()
{
	vLoadConfig();
}

void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bEnable != convar.BoolValue)
	{
		g_bEnable = convar.BoolValue;

		if (g_bEnable)
		{
			g_hPatchAddClip.Enable();
			g_hPatchClipToZero.Enable();
			vLoadConfig();
		}
		else
		{
			g_hPatchAddClip.Disable();
			g_hPatchClipToZero.Disable();
		}
	}
}

void ConVarChanged_AmmoCvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetAmmoCvars();
}

void GetAmmoCvars()
{
	g_iAmmoRifle = g_hAmmoRifle.IntValue;
	g_iAmmoSmg = g_hAmmoSmg.IntValue;
	g_iAmmoHunting = g_hAmmoHunting.IntValue;
	g_iAmmoGL = g_hAmmoGL.IntValue;
	g_iAmmoM60 = g_hAmmoM60.IntValue;
	g_iAmmoSniper = g_hAmmoSniper.IntValue;
}

void SetWeaponNameId()
{
	g_smWeaponNameID = new StringMap();
	g_smWeaponNameID.SetValue("", ID_NONE);
	g_smWeaponNameID.SetValue("weapon_pistol", ID_PISTOL);
	g_smWeaponNameID.SetValue("weapon_smg", ID_SMG);
	g_smWeaponNameID.SetValue("weapon_rifle", ID_RIFLE);
	g_smWeaponNameID.SetValue("weapon_hunting_rifle", ID_HUNTING_RIFLE);
	g_smWeaponNameID.SetValue("weapon_smg_silenced", ID_SMG_SILENCED);
	g_smWeaponNameID.SetValue("weapon_smg_mp5", ID_SMG_MP5);
	g_smWeaponNameID.SetValue("weapon_pistol_magnum", ID_MAGNUM);
	g_smWeaponNameID.SetValue("weapon_rifle_ak47", ID_AK47);
	g_smWeaponNameID.SetValue("weapon_rifle_desert", ID_RIFLE_DESERT);
	g_smWeaponNameID.SetValue("weapon_sniper_military", ID_SNIPER_MILITARY);
	g_smWeaponNameID.SetValue("weapon_grenade_launcher", ID_GRENADE);
	g_smWeaponNameID.SetValue("weapon_rifle_sg552", ID_SG552);
	g_smWeaponNameID.SetValue("weapon_rifle_m60", ID_M60);
	g_smWeaponNameID.SetValue("weapon_sniper_awp", ID_AWP);
	g_smWeaponNameID.SetValue("weapon_sniper_scout", ID_SCOUT);

	strcopy(g_sWeaponConfigName[ID_NONE], 32, "");
	strcopy(g_sWeaponConfigName[ID_PISTOL], 32, "weapon_pistol");
	strcopy(g_sWeaponConfigName[ID_DUAL_PISTOL], 32, "weapon_dualpistol");
	strcopy(g_sWeaponConfigName[ID_SMG], 32, "weapon_smg");
	strcopy(g_sWeaponConfigName[ID_RIFLE], 32, "weapon_rifle");
	strcopy(g_sWeaponConfigName[ID_HUNTING_RIFLE], 32, "weapon_hunting_rifle");
	strcopy(g_sWeaponConfigName[ID_SMG_SILENCED], 32, "weapon_smg_silenced");
	strcopy(g_sWeaponConfigName[ID_SMG_MP5], 32, "weapon_smg_mp5");
	strcopy(g_sWeaponConfigName[ID_MAGNUM], 32, "weapon_pistol_magnum");
	strcopy(g_sWeaponConfigName[ID_AK47], 32, "weapon_rifle_ak47");
	strcopy(g_sWeaponConfigName[ID_RIFLE_DESERT], 32, "weapon_rifle_desert");
	strcopy(g_sWeaponConfigName[ID_SNIPER_MILITARY], 32, "weapon_sniper_military");
	strcopy(g_sWeaponConfigName[ID_GRENADE], 32, "weapon_grenade_launcher");
	strcopy(g_sWeaponConfigName[ID_SG552], 32, "weapon_rifle_sg552");
	strcopy(g_sWeaponConfigName[ID_M60], 32, "weapon_rifle_m60");
	strcopy(g_sWeaponConfigName[ID_AWP], 32, "weapon_sniper_awp");
	strcopy(g_sWeaponConfigName[ID_SCOUT], 32, "weapon_sniper_scout");
}

void SetWeaponMaxClip()
{
	g_iWeaponMaxClip[ID_NONE] = 0;
	g_iWeaponMaxClip[ID_PISTOL] = L4D2_GetIntWeaponAttribute("weapon_pistol", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_DUAL_PISTOL] = L4D2_GetIntWeaponAttribute("weapon_pistol", L4D2IWA_ClipSize) * 2;
	g_iWeaponMaxClip[ID_SMG] = L4D2_GetIntWeaponAttribute("weapon_smg", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_RIFLE] = L4D2_GetIntWeaponAttribute("weapon_rifle", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_HUNTING_RIFLE] = L4D2_GetIntWeaponAttribute("weapon_hunting_rifle", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_SMG_SILENCED] = L4D2_GetIntWeaponAttribute("weapon_smg_silenced", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_SMG_MP5] = L4D2_GetIntWeaponAttribute("weapon_smg_mp5", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_MAGNUM] = L4D2_GetIntWeaponAttribute("weapon_pistol_magnum", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_AK47] = L4D2_GetIntWeaponAttribute("weapon_rifle_ak47", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_RIFLE_DESERT] = L4D2_GetIntWeaponAttribute("weapon_rifle_desert", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_SNIPER_MILITARY] = L4D2_GetIntWeaponAttribute("weapon_sniper_military", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_GRENADE] = L4D2_GetIntWeaponAttribute("weapon_grenade_launcher", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_SG552] = L4D2_GetIntWeaponAttribute("weapon_rifle_sg552", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_M60] = L4D2_GetIntWeaponAttribute("weapon_rifle_m60", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_AWP] = L4D2_GetIntWeaponAttribute("weapon_sniper_awp", L4D2IWA_ClipSize);
	g_iWeaponMaxClip[ID_SCOUT] = L4D2_GetIntWeaponAttribute("weapon_sniper_scout", L4D2IWA_ClipSize);
}

public void OnConfigsExecuted()
{
	GetAmmoCvars();
	SetWeaponMaxClip();
	vLoadConfig();
}

void vLoadConfig()
{
	if (!g_bEnable) return;
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_FILE);
	KeyValues hKV = new KeyValues(PLUGIN_NAME);
	if(!FileExists(sPath))
	{
		LogError("File Not Found: %s", sPath);
		return;
	}
	if (!hKV.ImportFromFile(sPath))
	{
		LogError("Failed to load config file %s, using defaults", sPath);
		vSetDefaultConfig();
		delete hKV;
		return;
	}
	
	if (!hKV.GotoFirstSubKey())
	{
		LogError("Config file %s missing weapon sections, using defaults", sPath);
		vSetDefaultConfig();
		delete hKV;
		return;
	}
	vSetDefaultConfig();
	g_bClearClipOnReload = view_as<bool>(hKV.GetNum("clear_clip_on_reload", 0));
	if (g_bClearClipOnReload || !g_bEnable)
	{
		g_hPatchAddClip.Disable();
		g_hPatchClipToZero.Disable();
	}
	else
	{
		g_hPatchAddClip.Enable();
		g_hPatchClipToZero.Enable();
	}
	do
	{
		char sWeaponName[32];
		hKV.GetSectionName(sWeaponName, sizeof(sWeaponName));
		WeaponID index = ID_NONE;
		for (WeaponID i = ID_PISTOL; i < ID_WEAPON_MAX; i++)
		{
			if (strcmp(g_sWeaponConfigName[i], sWeaponName, false) == 0)
			{
				index = i;
				break;
			}
		}
		if (index == ID_NONE)
			continue;

		float fReloadtime = hKV.GetFloat("reload_clip_time", 1.0);
		
		g_bWeaponEnable[view_as<int>(index)] = view_as<bool>(hKV.GetNum("enable", 1));
		if (fReloadtime >= 0.1)
			g_fWeaponReloadTime[view_as<int>(index)] = fReloadtime;
	} 
	while (hKV.GotoNextKey());

	delete hKV;
}

void vSetDefaultConfig()
{
	g_bWeaponEnable[ID_SMG] = true; g_fWeaponReloadTime[ID_SMG] = 1.04;
	g_bWeaponEnable[ID_RIFLE] = true; g_fWeaponReloadTime[ID_RIFLE] = 1.2;
	g_bWeaponEnable[ID_HUNTING_RIFLE] = true; g_fWeaponReloadTime[ID_HUNTING_RIFLE] = 2.6;
	g_bWeaponEnable[ID_PISTOL] = true; g_fWeaponReloadTime[ID_PISTOL] = 1.2;
	g_bWeaponEnable[ID_DUAL_PISTOL] = true; g_fWeaponReloadTime[ID_DUAL_PISTOL] = 1.75;
	g_bWeaponEnable[ID_SMG_SILENCED] = true; g_fWeaponReloadTime[ID_SMG_SILENCED] = 1.05;
	g_bWeaponEnable[ID_SMG_MP5] = true; g_fWeaponReloadTime[ID_SMG_MP5] = 1.7;
	g_bWeaponEnable[ID_AK47] = true; g_fWeaponReloadTime[ID_AK47] = 1.2;
	g_bWeaponEnable[ID_RIFLE_DESERT] = true; g_fWeaponReloadTime[ID_RIFLE_DESERT] = 1.8;
	g_bWeaponEnable[ID_SNIPER_MILITARY] = true; g_fWeaponReloadTime[ID_SNIPER_MILITARY] = 1.8;
	g_bWeaponEnable[ID_GRENADE] = true; g_fWeaponReloadTime[ID_GRENADE] = 2.5;
	g_bWeaponEnable[ID_SG552] = true; g_fWeaponReloadTime[ID_SG552] = 1.6;
	g_bWeaponEnable[ID_M60] = true; g_fWeaponReloadTime[ID_M60] = 1.2;
	g_bWeaponEnable[ID_AWP] = true; g_fWeaponReloadTime[ID_AWP] = 2.0;
	g_bWeaponEnable[ID_SCOUT] = true; g_fWeaponReloadTime[ID_SCOUT] = 1.45;
	g_bWeaponEnable[ID_MAGNUM] = true; g_fWeaponReloadTime[ID_MAGNUM] = 1.18;
	
	g_bClearClipOnReload = false;
}

Action CmdListen_weapon_reparse_server(int client, const char[] command, int argc)
{
	if (!g_bEnable) return Plugin_Continue;
	RequestFrame(OnNextFrame_weapon_reparse_server);
	return Plugin_Continue;
}

void OnNextFrame_weapon_reparse_server()
{
	SetWeaponMaxClip();
}

void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		g_fClientReloadTime[i] = 0.0;
}

void OnWeaponReload_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnable) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAliveSurvivor(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= 0 || !IsValidEntity(weapon))
		return;

	char sWeaponName[32];
	GetEntityClassname(weapon, sWeaponName, sizeof(sWeaponName));
	WeaponID weaponid = GetWeaponID(weapon, sWeaponName);
	if (weaponid == ID_NONE)
		return;

	if (!g_bWeaponEnable[weaponid])
		return;

	float fReloadTime = g_fWeaponReloadTime[weaponid];

	if ((weaponid == ID_PISTOL || weaponid == ID_DUAL_PISTOL || weaponid == ID_MAGNUM) && L4D_IsPlayerIncapacitated(client))
		fReloadTime *= PISTOL_RELOAD_INCAP_MULTIPLY;

	g_fClientReloadTime[client] = GetEngineTime();
	DataPack hPack = null;
	CreateDataTimer(fReloadTime, WeaponReloadClip, hPack, TIMER_FLAG_NO_MAPCHANGE);
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteCell(EntIndexToEntRef(weapon));
	hPack.WriteCell(weaponid);
	hPack.WriteCell(g_fClientReloadTime[client]);
}

Action WeaponReloadClip(Handle timer, DataPack hPack)
{
	hPack.Reset();
	int client = GetClientOfUserId(hPack.ReadCell());
	int weapon = EntRefToEntIndex(hPack.ReadCell());
	WeaponID weaponid = hPack.ReadCell();
	float fReloadtime = hPack.ReadCell();

	if (fReloadtime != g_fClientReloadTime[client] ||
		!IsValidAliveSurvivor(client) ||
		weapon == INVALID_ENT_REFERENCE ||
		!HasEntProp(weapon, Prop_Send, "m_bInReload") || GetEntProp(weapon, Prop_Send, "m_bInReload") == 0)
	{
		return Plugin_Continue;
	}

	int clip = GetWeaponClip(weapon);
	if (clip >= g_iWeaponMaxClip[weaponid])
		return Plugin_Continue;

	bool bIsInfiniteAmmo;
	switch (weaponid)
	{
		case ID_SMG, ID_SMG_SILENCED, ID_SMG_MP5:
			bIsInfiniteAmmo = (g_iAmmoSmg == -2);
		case ID_RIFLE, ID_AK47, ID_RIFLE_DESERT, ID_SG552:
			bIsInfiniteAmmo = (g_iAmmoRifle == -2);
		case ID_HUNTING_RIFLE:
			bIsInfiniteAmmo = (g_iAmmoHunting == -2);
		case ID_AWP, ID_SCOUT, ID_SNIPER_MILITARY:
			bIsInfiniteAmmo = (g_iAmmoSniper == -2);
		case ID_M60:
			bIsInfiniteAmmo = (g_iAmmoM60 == -2);
		case ID_GRENADE:
			bIsInfiniteAmmo = (g_iAmmoGL == -2);
		case ID_PISTOL, ID_DUAL_PISTOL, ID_MAGNUM:
			bIsInfiniteAmmo = true;
	}

	if (!bIsInfiniteAmmo)
	{
		int ammo = L4D_GetReserveAmmo(client, weapon);
		int needed = g_iWeaponMaxClip[weaponid] - clip;
		if (ammo <= needed)
		{
			clip += ammo;
			ammo = 0;
		}
		else
		{
			clip = g_iWeaponMaxClip[weaponid];
			ammo -= needed;
		}
		L4D_SetReserveAmmo(client, weapon, ammo);
		SetWeaponClip(weapon, clip);
	}
	else
	{
		SetWeaponClip(weapon, g_iWeaponMaxClip[weaponid]);
	}

	return Plugin_Continue;
}

int GetWeaponClip(int weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_iClip1");
}

void SetWeaponClip(int weapon, int clip)
{
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
}

WeaponID GetWeaponID(int weapon, const char[] weapon_name)
{
	WeaponID index = ID_NONE;
	if (g_smWeaponNameID.GetValue(weapon_name, index))
	{
		if (index == ID_PISTOL)
		{
			if (GetEntProp(weapon, Prop_Send, "m_isDualWielding") > 0)
				return ID_DUAL_PISTOL;
			return ID_PISTOL;
		}
		return index;
	}
	return ID_NONE;
}

bool IsValidAliveSurvivor(int client)
{
	return (1 <= client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR && IsPlayerAlive(client));
}

void vCheckAndCreatGameData()
{
	char sFilePath[128];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", PLUGIN_NAME);
	File hTemp;
	bool bNeedUpdate;
	if (FileExists(sFilePath))
    {
		char sFirst[64], sExpectedVersion[64];
		hTemp = OpenFile(sFilePath, "r", false);
		if (hTemp != null)
		{
			if (hTemp.ReadLine(sFirst, sizeof(sFirst)))
			{
				FormatEx(sExpectedVersion, sizeof(sExpectedVersion), "//%s\n", PLUGIN_VERSION);
				if (!StrEqual(sFirst, sExpectedVersion, false))
					bNeedUpdate = true;
			}
			else
			{
				bNeedUpdate = true;
			}
			delete hTemp;
		}
	}
	else
	{
		bNeedUpdate = true;
	}
	if (bNeedUpdate)
    {
		hTemp = OpenFile(sFilePath, "w");
		if (hTemp == null)
		{
			SetFailState("Plugin " ... PLUGIN_NAME ... "Something went wrong while creating the game data file!");
		}
		hTemp.WriteLine("//%s", PLUGIN_VERSION);
		hTemp.WriteLine("//windows signature credit: blueblur0730 https://github.com/blueblur0730/modified-plugins/blob/main/source/l4d2_cs_style_reload/gamedata/l4d2_cs_style_reload.txt", PLUGIN_VERSION);
		hTemp.WriteLine("\"Games\"");
		hTemp.WriteLine("{");
		hTemp.WriteLine("	\"left4dead2\"");
		hTemp.WriteLine("	{");
		hTemp.WriteLine("		\"MemPatches\"");
		hTemp.WriteLine("		{");
		hTemp.WriteLine("			\"CTerrorGun::Reload__ClipToZero\"");
		hTemp.WriteLine("			{");
		hTemp.WriteLine("				\"signature\"		\"CTerrorGun::Reload\"");
		hTemp.WriteLine("				\"linux\"");
		hTemp.WriteLine("				{");
		hTemp.WriteLine("					\"offset\"	\"342h\"");
		hTemp.WriteLine("					\"verify\"	\"\\xC7\\x83\\x20\\x14\\x00\\x00\\x00\\x00\\x00\\x00\"");
		hTemp.WriteLine("					\"patch\"	\"\\x90\\x90\\x90\\x90\\x90\\x90\\x90\\x90\\x90\\x90\"");
		hTemp.WriteLine("				}");
		hTemp.WriteLine("				\"windows\"");
		hTemp.WriteLine("				{");
		hTemp.WriteLine("					\"offset\"	\"24Eh\"");
		hTemp.WriteLine("					\"verify\"	\"\\xC7\\x86\\x14\\x14\\x00\\x00\\x00\\x00\\x00\\x00\"");
		hTemp.WriteLine("					\"patch\"	\"\\x90\\x90\\x90\\x90\\x90\\x90\\x90\\x90\\x90\\x90\"");
		hTemp.WriteLine("				}");
		hTemp.WriteLine("			}");
		hTemp.WriteLine("			\"CTerrorGun::Reload__AddClip\"");
		hTemp.WriteLine("			{");
		hTemp.WriteLine("				\"signature\"		\"CTerrorGun::Reload\"");
		hTemp.WriteLine("				\"linux\"");
		hTemp.WriteLine("				{");
		hTemp.WriteLine("					\"offset\"	\"1DDh\"");
		hTemp.WriteLine("					\"verify\"	\"\\x03\\x83\\x20\\x14\\x00\\x00\"");
		hTemp.WriteLine("					\"patch\"	\"\\x90\\x90\\x90\\x90\\x90\\x90\"");
		hTemp.WriteLine("				}");
		hTemp.WriteLine("				\"windows\"");
		hTemp.WriteLine("				{");
		hTemp.WriteLine("					\"offset\"	\"217h\"");
		hTemp.WriteLine("					\"verify\"	\"\\x03\\xD0\"");
		hTemp.WriteLine("					\"patch\"	\"\\x8B\\xD0\"");
		hTemp.WriteLine("				}");
		hTemp.WriteLine("			}");
		hTemp.WriteLine("		}");
		hTemp.WriteLine("		\"Signatures\"");
		hTemp.WriteLine("		{");
		hTemp.WriteLine("			\"CTerrorGun::Reload\"");
		hTemp.WriteLine("			{");
		hTemp.WriteLine("				\"library\"		\"server\"");
		hTemp.WriteLine("				\"linux\"		\"@_ZN10CTerrorGun6ReloadEv\"");
		hTemp.WriteLine("				\"windows\"		\"\\x55\\x8B\\xEC\\x83\\xEC\\x2A\\x53\\x56\\x8B\\xF1\\xE8\\x2A\\x2A\\x2A\\x2A\\x8B\\xD8\\x85\\xDB\\x0F\\x84\\x2A\\x2A\\x2A\\x2A\\x8B\\x83\"");
		hTemp.WriteLine("				/* 55 8B EC 83 EC ? 53 56 8B F1 E8 ? ? ? ? 8B D8 85 DB 0F 84 ? ? ? ? 8B 83 */");
		hTemp.WriteLine("			}");
		hTemp.WriteLine("		}");
		hTemp.WriteLine("	}");
		hTemp.WriteLine("}");
		FlushFile(hTemp);
	}
	delete hTemp;
}
