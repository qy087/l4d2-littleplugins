#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <dhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_TAG "{O}[{D}AEM{O}] "
#define GAMEDATA "admin_extra_menu"

int
    g_iMaxClients,
    g_iMeleeRange[32],
    g_iFunction[33],
    g_iSelection[33],
    g_iOff_m_nFallenSurvivors,
	g_iOff_m_FallenSurvivorTimer;

bool
    g_bAuto[33],
    g_bGodMode[33],
    g_bIgnoreAbility[33];

char
    g_sNamedItem[33][64];

float
    g_fSpeedUp[33] = {1.0, ...};

static int
    g_iTempRef,
    g_DesertBurstOffset = -1,
    g_iMeleeTempVals[3];

static float
    g_fTempSpeed,
    g_fBurstEndTime[33],
    g_fBurstModifier;

static const char g_sZombieClass[][] = {
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger",
    "Tank",
};

static const char
    g_sTargetTeam[][] = {
    "闲置(仅生还)",
    "观众",
    "生还",
    "感染"
    },
    g_sUncommonModels[][] = {
    "models/infected/common_male_riot.mdl",
    "models/infected/common_male_ceda.mdl",
    "models/infected/common_male_clown.mdl",
    "models/infected/common_male_mud.mdl",
    "models/infected/common_male_roadcrew.mdl",
    "models/infected/common_male_jimmy.mdl",
    "models/infected/common_male_fallen_survivor.mdl",
    },
    g_sMeleeModels[][] = {
    "models/weapons/melee/v_fireaxe.mdl",
    "models/weapons/melee/w_fireaxe.mdl",
    "models/weapons/melee/v_frying_pan.mdl",
    "models/weapons/melee/w_frying_pan.mdl",
    "models/weapons/melee/v_machete.mdl",
    "models/weapons/melee/w_machete.mdl",
    "models/weapons/melee/v_bat.mdl",
    "models/weapons/melee/w_bat.mdl",
    "models/weapons/melee/v_crowbar.mdl",
    "models/weapons/melee/w_crowbar.mdl",
    "models/weapons/melee/v_cricket_bat.mdl",
    "models/weapons/melee/w_cricket_bat.mdl",
    "models/weapons/melee/v_tonfa.mdl",
    "models/weapons/melee/w_tonfa.mdl",
    "models/weapons/melee/v_katana.mdl",
    "models/weapons/melee/w_katana.mdl",
    "models/weapons/melee/v_electric_guitar.mdl",
    "models/weapons/melee/w_electric_guitar.mdl",
    "models/v_models/v_knife_t.mdl",
    "models/w_models/weapons/w_knife_t.mdl",
    "models/weapons/melee/v_golfclub.mdl",
    "models/weapons/melee/w_golfclub.mdl",
    "models/weapons/melee/v_shovel.mdl",
    "models/weapons/melee/w_shovel.mdl",
    "models/weapons/melee/v_pitchfork.mdl",
    "models/weapons/melee/w_pitchfork.mdl",
    "models/weapons/melee/v_riotshield.mdl",
    "models/weapons/melee/w_riotshield.mdl"
    },
    g_sSpecialModels[][] = {
    "models/infected/smoker.mdl",
    "models/infected/boomer.mdl",
    "models/infected/hunter.mdl",
    "models/infected/spitter.mdl",
    "models/infected/jockey.mdl",
    "models/infected/charger.mdl",
    "models/infected/hulk.mdl",
    "models/infected/witch.mdl",
    "models/infected/witch_bride.mdl"
    },
    g_sMeleeName[][] = {
    "fireaxe",
    "frying_pan",
    "machete",
    "baseball_bat",
    "crowbar",
    "cricket_bat",
    "tonfa",
    "katana",
    "electric_guitar",	
    "knife",
    "golfclub",
    "shovel",
    "pitchfork",
    "riotshield",
};

ArrayList
    g_aMeleeScripts;

StringMap
    g_smMeleeTrans;

TopMenu
    admin_menu;

Handle
    g_hSDK_TerrorNavMesh_GetLastCheckpoint,
    g_hSDK_Checkpoint_GetLargestArea,
    g_hSDK_NextBotCreatePlayerBot[7];

TopMenuObject
    TMO_DirectorMenu,       // 导演设置菜单
    TMO_WeaponMenu,         // 武器菜单
    TMO_ItemMenu,           // 物品菜单
    TMO_TeleportMenu,       // 传送菜单
    TMO_InfectedMenu,       // 特感菜单
    TMO_OtherMenu,          // 其他功能菜单
    TMO_WeaponHandlingMenu; // 武器操纵性菜单

Address
    g_pZombieManager,
    g_pStatsCondition,
    CTerrorGun__GetRateOfFire_byte_address,
    CPistol__GetRateOfFire_byte_address;

static L4D2WeaponType
    g_iWeaponType[2049];

static DynamicHook
    hReloadModifier,
    hRateOfFire,
    hItemUseDuration,
    hDeployModifier,
    hDeployGun,
    hGrenadePrimaryAttack,
    hStartThrow,
    hDesertBurstFire;

enum MeleeSwingInfo {
    MeleeSwingInfo_Entity = 0,
    MeleeSwingInfo_Client,
    MeleeSwingInfo_SwingType
}

static char g_sSpawnerModelName[4][] = {
    "models/props/terror/ammo_stack.mdl",
    "models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
    "models/w_models/weapons/w_eq_explosive_ammopack.mdl",
    "models/w_models/Weapons/w_laser_sights.mdl"
};

ConVar
    melee_range;

enum struct SDKCallParamsWrapper {
	SDKType type;
	SDKPassMethod pass;
	int decflags;
	int encflags;
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
		
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	
	public int GetOffset(const char[] key) {
		int offset = this.Super.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}

	public Address GetAddress(const char[] key) {
		Address ptr = this.Super.GetAddress(key);
		return ptr;
	}
	public DynamicDetour CreateDetourOrFail(
			const char[] name,
			DHookCallback preHook = INVALID_FUNCTION,
			DHookCallback postHook = INVALID_FUNCTION) {
		DynamicDetour hSetup = DynamicDetour.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing detour setup \"%s\"", name);
		if (preHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Pre, preHook))
			SetFailState("Failed to pre-detour \"%s\"", name);
		if (postHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Post, postHook))
			SetFailState("Failed to post-detour \"%s\"", name);
		return hSetup;
	}
	
	public DynamicHook CreateDHookOrFail(const char[] name) {
		DynamicHook hSetup = DynamicHook.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing dhook setup \"%s\"", name);
		return hSetup;
	}
	public Handle CreateSDKCallOrFail(
			SDKCallType type,
			SDKFuncConfSource src,
			const char[] name,
			const SDKCallParamsWrapper[] params = {},
			int numParams = 0,
			bool hasReturnValue = false,
			const SDKCallParamsWrapper ret = {}) {
		static const char k_sSDKFuncConfSource[SDKFuncConfSource][] = { "offset", "signature", "address" };
		Handle result;
		StartPrepSDKCall(type);
		if (!PrepSDKCall_SetFromConf(this, src, name))
			SetFailState("Missing %s \"%s\"", k_sSDKFuncConfSource[src], name);
		for (int i = 0; i < numParams; ++i)
			PrepSDKCall_AddParameter(params[i].type, params[i].pass, params[i].decflags, params[i].encflags);
		if (hasReturnValue)
			PrepSDKCall_SetReturnInfo(ret.type, ret.pass, ret.decflags, ret.encflags);
		if (!(result = EndPrepSDKCall()))
			SetFailState("Failed to prep sdkcall \"%s\"", name);
		return result;
	}
}

public Plugin myinfo =
{
    name = "L4D2 Admin Extra Menu",
    author = "Hitomi",
    description = "管理员菜单拓展",
    version = "1.2",
    url = "https://github.com/cy115/"
};

public void OnPluginStart()
{
    LoadGameData();

    melee_range = FindConVar("melee_range");

    g_iMaxClients = MaxClients;

    g_aMeleeScripts = new ArrayList(ByteCountToCells(64));
    g_smMeleeTrans = new StringMap();

    InitMeleeStringMap();

    RegAdminCmd("sm_meleerange", Cmd_MeleeRange, ADMFLAG_SLAY, "sm_meleerange <#userid|name> [range]");

    TopMenu hTopMenu;
    if (LibraryExists("adminmenu") && ((hTopMenu = GetAdminTopMenu()) != null)) {
        OnAdminMenuReady(hTopMenu);
    }
}

public void OnPluginEnd()
{
    int byte;
    if (CPistol__GetRateOfFire_byte_address != Address_Null) {
        byte = LoadFromAddress(CPistol__GetRateOfFire_byte_address, NumberType_Int8);
        if (byte == 0xEB) {
            StoreToAddress(CPistol__GetRateOfFire_byte_address, 0x74, NumberType_Int8);
        }
    }	

    if (CTerrorGun__GetRateOfFire_byte_address != Address_Null) {
        byte = LoadFromAddress(CTerrorGun__GetRateOfFire_byte_address, NumberType_Int8);
        if (byte == 0xEB) {
            StoreToAddress(CTerrorGun__GetRateOfFire_byte_address, 0x74, NumberType_Int8);
        }
    }
}

public void OnAllPluginsLoaded()
{
    g_pZombieManager = L4D_GetPointer(POINTER_ZOMBIEMANAGER);
}
// ------------------------------------------------------------ GameData ------------------------------------------------------------------------
void LoadGameData()
{
	GameDataWrapper gd = new GameDataWrapper(GAMEDATA);
	g_iOff_m_nFallenSurvivors = gd.GetOffset("m_nFallenSurvivors");
	g_iOff_m_FallenSurvivorTimer = gd.GetOffset("m_FallenSurvivorTimer");
	SDKCallParamsWrapper ret  = { SDKType_PlainOldData, SDKPass_Plain };
	g_hSDK_TerrorNavMesh_GetLastCheckpoint = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "TerrorNavMesh::GetLastCheckpoint", _, _, true, ret);

	g_hSDK_Checkpoint_GetLargestArea = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "Checkpoint::GetLargestArea", _, _, true, ret);
	
	Address pAddress = gd.GetAddress("NextBotCreatePlayerBot.jumptable");
	if (pAddress != Address_Null && LoadFromAddress(pAddress, NumberType_Int8) == 0x68)
		PrepWindowsCreateBotCalls(pAddress);
	else
		PrepLinuxCreateBotCalls(gd);
	InitPatchs(gd);
	LoadHookAndPatches(gd);
	delete gd;
}

void PrepWindowsCreateBotCalls(Address pBaseAddr)
{
	int iOffsets[7] = {48, 60, 0, 24, 12, 36, 72};
	for (int i = 0; i < 7; i++)
	{
		Address pJumpAddr	= pBaseAddr + view_as<Address>(iOffsets[i]);
		Address pFuncRefAddr	= pJumpAddr + view_as<Address>(6);
		int funcRelOffset	= LoadFromAddress(pFuncRefAddr, NumberType_Int32);
		Address pCallOffsetBase	= pJumpAddr + view_as<Address>(10);
		Address pNextBotCreatePlayerBotTAddr = pCallOffsetBase + view_as<Address>(funcRelOffset);

		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetAddress(pNextBotCreatePlayerBotTAddr))
			SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", g_sZombieClass[i]);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		g_hSDK_NextBotCreatePlayerBot[i] = EndPrepSDKCall();
    }
}

void PrepLinuxCreateBotCalls(GameDataWrapper hGameData)
{
	SDKCallParamsWrapper param1[] =
	{
		{SDKType_String, SDKPass_Pointer},
	};
	SDKCallParamsWrapper ret1 = { SDKType_CBasePlayer, SDKPass_Pointer };
	static char sSigName[32];
	for (int i = 0; i < 7; i++)
	{
		Format(sSigName, sizeof(sSigName), "NextBotCreatePlayerBot<%s>", g_sZombieClass[i]);
		g_hSDK_NextBotCreatePlayerBot[i] = hGameData.CreateSDKCallOrFail(SDKCall_Static, SDKConf_Signature, sSigName, param1, sizeof(param1), true, ret1);
	}
}

void InitPatchs(GameData hGameData = null)
{
    int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
    hGameData.GetOffset("RoundRespawn_Byte");
    g_pStatsCondition = hGameData.GetMemSig("CTerrorPlayer::RoundRespawn");
    g_pStatsCondition += view_as<Address>(iOffset);
    LoadFromAddress(g_pStatsCondition, NumberType_Int8);
}

void LoadHookAndPatches(GameDataWrapper hGameData)
{
	int iOffset = hGameData.GetOffset("CTerrorWeapon::GetReloadDurationModifier");
	hReloadModifier = new DynamicHook(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);

	iOffset = hGameData.GetOffset("CTerrorGun::GetRateOfFire");
	hRateOfFire = new DynamicHook(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);

	iOffset = hGameData.GetOffset("CBaseBeltItem::GetUseTimerDuration");
	hItemUseDuration = new DynamicHook(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);
    
	iOffset = hGameData.GetOffset("CRifle_Desert::PrimaryAttack");
	hDesertBurstFire = new DynamicHook(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
    
	g_DesertBurstOffset = hGameData.GetOffset("CRifle_Desert::BurstTimes_StartOffset");
    
	iOffset = hGameData.GetOffset("CTerrorWeapon::GetDeployDurationModifier");
	hDeployModifier = new DynamicHook(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);

	iOffset = hGameData.GetOffset("CTerrorWeapon::Deploy");
	hDeployGun = new DynamicHook(iOffset, HookType_Entity, ReturnType_Unknown, ThisPointer_CBaseEntity);

	iOffset = hGameData.GetOffset("CBaseCSGrenade::PrimaryAttack");
	hGrenadePrimaryAttack = new DynamicHook(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);

	iOffset = hGameData.GetOffset("CBaseCSGrenade::StartGrenadeThrow");
	hStartThrow = new DynamicHook(iOffset, HookType_Entity, ReturnType_Edict, ThisPointer_CBaseEntity);

	delete hGameData.CreateDetourOrFail("CTerrorMeleeWeapon::StartMeleeSwing", OnMeleeSwingPre, OnMeleeSwingpPost);
	delete hGameData.CreateDetourOrFail("CTerrorMeleeWeapon::TestMeleeSwingCollision", HookPre_TrySwing, HookPost_TrySwing);

	Address patch = hGameData.GetAddress("CTerrorGun::GetRateOfFire");
	if (patch) {
		int offset = hGameData.GetOffset("CTerrorGun::GetRateOfFire_patch");
		if (offset != -1) {
			if (LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8) == 0x74) {
				CTerrorGun__GetRateOfFire_byte_address = patch + view_as<Address>(offset);
				StoreToAddress(CTerrorGun__GetRateOfFire_byte_address, 0xEB, NumberType_Int8);
			}
		}
	}

	patch = hGameData.GetAddress("CPistol::GetRateOfFire");
	if (patch) {
		int offset = hGameData.GetOffset("CPistol::GetRateOfFire_patch");
		if (offset != -1) {
			if (LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8) == 0x74) {
				CPistol__GetRateOfFire_byte_address = patch + view_as<Address>(offset);
				StoreToAddress(CPistol__GetRateOfFire_byte_address, 0xEB, NumberType_Int8);
			}
		}
	}
}

void StatsConditionPatch(bool patch)
{
    static bool patched;
    if (!patched && patch) {
        patched = true;
        StoreToAddress(g_pStatsCondition, 0xEB, NumberType_Int8);
    }
    else if (patched && !patch) {
        patched = false;
        StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
    }
}
// ----------------------------------------------------------------------------------------------------------------------------------------------
public void OnMapStart()
{
    int i;
    for (; i < sizeof(g_sMeleeModels); i++) {
        if (!IsModelPrecached(g_sMeleeModels[i])) {
            PrecacheModel(g_sMeleeModels[i], true);
        }
    }

    for (i = 0; i < sizeof(g_sSpecialModels); i++) {
        if (!IsModelPrecached(g_sSpecialModels[i])) {
            PrecacheModel(g_sSpecialModels[i], true);
        }
    }

    for (i = 0; i < sizeof(g_sUncommonModels); i++) {
        if (!IsModelPrecached(g_sUncommonModels[i])) {
            PrecacheModel(g_sUncommonModels[i], true);
        }
    }

    char buffer[64];
    for (i = 0; i < sizeof(g_sMeleeName); i++) {
        FormatEx(buffer, sizeof(buffer), "scripts/melee/%s.txt", g_sMeleeName[i]);
        if (!IsGenericPrecached(buffer)) {
            PrecacheGeneric(buffer, true);
        }
    }

    GetMeleeStringTable();
}

void GetMeleeStringTable()
{
    g_aMeleeScripts.Clear();
    int table = FindStringTable("meleeweapons");
    if (table != INVALID_STRING_TABLE) {
        int num = GetStringTableNumStrings(table);
        char melee[64];
        for (int i; i < num; i++) {
            ReadStringTable(table, i, melee, sizeof(melee));
            g_aMeleeScripts.PushString(melee);
        }
    }
}

void InitMeleeStringMap()
{
    g_smMeleeTrans.SetString("fireaxe", "斧头");
    g_smMeleeTrans.SetString("frying_pan", "铁锅");
    g_smMeleeTrans.SetString("machete", "砍刀");
    g_smMeleeTrans.SetString("baseball_bat", "球棒");
    g_smMeleeTrans.SetString("crowbar", "撬棍");
    g_smMeleeTrans.SetString("cricket_bat", "球拍");
    g_smMeleeTrans.SetString("tonfa", "警棍");
    g_smMeleeTrans.SetString("katana", "武士");
    g_smMeleeTrans.SetString("electric_guitar", "吉他");
    g_smMeleeTrans.SetString("knife", "小刀");
    g_smMeleeTrans.SetString("golfclub", "球棍");
    g_smMeleeTrans.SetString("shovel", "铁铲");
    g_smMeleeTrans.SetString("pitchfork", "草叉");
    g_smMeleeTrans.SetString("riotshield", "盾牌");
    g_smMeleeTrans.SetString("riot_shield", "盾牌");
}

public void OnAdminMenuReady(Handle menu)
{
    TopMenu topmenu = TopMenu.FromHandle(menu);
    if (topmenu == admin_menu) {
        return;
    }

    admin_menu = topmenu;
    AddToTopMenu(admin_menu, "拓展功能", TopMenuObject_Category, Menu_CategoryHandler, INVALID_TOPMENUOBJECT);
    TopMenuObject AEM_Menu = FindTopMenuCategory(admin_menu, "拓展功能");
    if (AEM_Menu == INVALID_TOPMENUOBJECT) {
        return;
    }

    TMO_DirectorMenu = AddToTopMenu(admin_menu, "TMO_DirectorMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_DirectorMenu", ADMFLAG_CHEATS);
    TMO_WeaponMenu = AddToTopMenu(admin_menu, "TMO_WeaponMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_WeaponMenu", ADMFLAG_CHEATS);
    TMO_ItemMenu = AddToTopMenu(admin_menu, "TMO_ItemMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_ItemMenu", ADMFLAG_CHEATS);
    TMO_TeleportMenu = AddToTopMenu(admin_menu, "TMO_TeleportMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_TeleportMenu", ADMFLAG_CHEATS);
    TMO_InfectedMenu = AddToTopMenu(admin_menu, "TMO_InfectedMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_InfectedMenu", ADMFLAG_CHEATS);
    TMO_OtherMenu = AddToTopMenu(admin_menu, "TMO_OtherMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_OtherMenu", ADMFLAG_CHEATS);
    TMO_WeaponHandlingMenu = AddToTopMenu(admin_menu, "TMO_WeaponHandlingMenu", TopMenuObject_Item, Menu_TopItemHandler, AEM_Menu, "TMO_WeaponHandlingMenu", ADMFLAG_CHEATS);

    TopMenuObject player_commands = admin_menu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
    if (player_commands != INVALID_TOPMENUOBJECT) {
        admin_menu.AddItem("sm_meleerange", AdminMenu_MeleeRange, player_commands, "sm_meleerange", ADMFLAG_SLAY);
    }
}

void Menu_TopItemHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption) {
        if (topobj_id == TMO_DirectorMenu) {
            Format(buffer, maxlength, "导演指令");
        } else if (topobj_id == TMO_WeaponMenu) {
            Format(buffer, maxlength, "生成武器");
        } else if (topobj_id == TMO_ItemMenu) {
            Format(buffer, maxlength, "生成物品");
        } else if (topobj_id == TMO_TeleportMenu) {
            Format(buffer, maxlength, "传送指令");
        } else if (topobj_id == TMO_InfectedMenu) {
            Format(buffer, maxlength, "生成特感");
        } else if (topobj_id == TMO_OtherMenu) {
            Format(buffer, maxlength, "其他功能");
        } else if (topobj_id == TMO_WeaponHandlingMenu) {
            Format(buffer, maxlength, "武器操纵");
        }
    } else if (action == TopMenuAction_SelectOption) {
        if (topobj_id == TMO_DirectorMenu) {
            Menu_CreateDirectorMenu(client);
        } else if (topobj_id == TMO_WeaponMenu) {
            Menu_CreateWeaponMenu(client);
        } else if (topobj_id == TMO_ItemMenu) {
            Menu_CreateItemMenu(client, 0);
        } else if (topobj_id == TMO_TeleportMenu) {
            Menu_CreateTeleportMenu(client, 0);
        } else if (topobj_id == TMO_InfectedMenu) {
            Menu_CreateInfectedMenu(client);
        } else if (topobj_id == TMO_OtherMenu) {
            Menu_CreateOtherMenu(client, 0);
        } else if (topobj_id == TMO_WeaponHandlingMenu) {
            Menu_CreateWeaponHandlingMenu(client, 0);
        }
    }
}

void Menu_CategoryHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle) {
		FormatEx(buffer, maxlength, "拓展功能:");
    }
	else if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "拓展功能");
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    g_fSpeedUp[client] = 1.0;
    g_bGodMode[client] = false;
    g_bIgnoreAbility[client] = false;
}

Action OnTakeDamage(int victim)
{
    if (!g_bGodMode[victim]) {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}
// 具体菜单
// ---------------------------------------- DirectorMenu -------------------------
void Menu_CreateDirectorMenu(int client)
{
    Menu menu = CreateMenu(Director_MenuHandler);
    menu.SetTitle("导演指令");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);
    menu.AddItem("fp", "强制生成一次恐慌事件"); // panic event
    switch (FindConVar("director_panic_forever").IntValue) {
        case 0: menu.AddItem("pf", "启动无限尸潮事件");
        case 1: menu.AddItem("pf", "结束无限尸潮事件");
    }

    switch (FindConVar("director_force_tank").IntValue) {
        case 0: menu.AddItem("ft", "导演控制此轮不生成坦克");
        case 1: menu.AddItem("ft", "导演强制此轮生成坦克");
    }

    switch (FindConVar("director_force_witch").IntValue) {
        case 0: menu.AddItem("fw", "导演控制此轮不生成女巫");
        case 1: menu.AddItem("fw", "导演控制此轮生成女巫");
    }

    menu.AddItem("mz", "在尸潮事件中加入更多僵尸");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

int Director_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            switch (param2) {
                case 0: Do_ForcePanic(client);
                case 1: FindConVar("director_panic_forever").BoolValue ? Do_PanicForever(false) : Do_PanicForever(true);
                case 2: FindConVar("director_force_tank").BoolValue ? Do_ForceTank(false) : Do_ForceTank(true);
                case 3: FindConVar("director_force_witch").BoolValue ? Do_ForceWitch(false) : Do_ForceWitch(true);
                case 4: Do_AddZombies(10); 
            }

            Menu_CreateDirectorMenu(client); 
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void Do_ForcePanic(int client)
{
    L4D_ForcePanicEvent();
    CPrintToChatAll("%s{O}%N {R}生成了一波尸潮事件", PLUGIN_TAG, client);
}

void Do_PanicForever(bool value)
{
    StripAndChangeServerConVarBool("director_panic_forever", value);
    if (value) {
        L4D_ForcePanicEvent();
    }

    CPrintToChatAll("%s%s", PLUGIN_TAG, value ? "{G}无限尸潮事件已启动" : "{R}无限尸潮事件已停止");
}

void Do_ForceTank(bool value)
{
    StripAndChangeServerConVarBool("director_force_tank", value);
    CPrintToChatAll("%s%s", PLUGIN_TAG, value ? "{G}已允许导演克会在此回合生成" : "{R}已禁止导演克会在此回合生成");
}

void Do_ForceWitch( bool value)
{
    StripAndChangeServerConVarBool("director_force_witch", value);
    CPrintToChatAll("%s%s", PLUGIN_TAG, value ? "{G}已允许导演女巫会在此回合生成" : "{R}已禁止导演女巫会在此回合生成");
}

void Do_AddZombies(int zombies_to_add)
{
    int new_zombie_total = zombies_to_add + FindConVar("z_mega_mob_size").IntValue;
    StripAndChangeServerConVarInt("z_mega_mob_size", new_zombie_total);
    new_zombie_total = zombies_to_add + FindConVar("z_mob_spawn_max_size").IntValue;
    StripAndChangeServerConVarInt("z_mob_spawn_max_size", new_zombie_total);
    new_zombie_total = zombies_to_add + FindConVar("z_mob_spawn_min_size").IntValue;
    StripAndChangeServerConVarInt("z_mob_spawn_min_size", new_zombie_total);
    PrintToChatAll("%s{D}尸潮规模已扩大 {R}10{D}!", PLUGIN_TAG);
}
// -------------------------------------------------------------------------------
// --------------------------------------- WeaponMenu ----------------------------
void Menu_CreateWeaponMenu(int client)
{
    Menu menu = CreateMenu(Weapon_MenuHandler);
    menu.SetTitle("生成武器");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);
    menu.AddItem("", "Tier1武器");
    menu.AddItem("", "Tier2武器");
    menu.AddItem("", "近战武器");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

int Weapon_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            g_iSelection[client] = menu.Selection;
            switch (param2) {
                case 0: Tier1Gun(client, 0);
                case 1: Tier2Gun(client, 0);
                case 2: Melee(client, 0);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void Tier1Gun(int client, int item)
{
    Menu menu = new Menu(Tier1Weapon_MenuHandler);
    menu.SetTitle("Tier1武器");
    menu.AddItem("pistol", "手枪");
    menu.AddItem("pistol_magnum", "沙鹰");
    menu.AddItem("smg", "UZI");
    menu.AddItem("smg_mp5", "MP5");
    menu.AddItem("smg_silenced", "MAC");
    menu.AddItem("pumpshotgun", "木喷");
    menu.AddItem("shotgun_chrome", "铁喷");
    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Tier1Weapon_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[64];
            menu.GetItem(param2, item, sizeof(item));
            g_iFunction[client] = 1;
            g_iSelection[client] = menu.Selection;
            FormatEx(g_sNamedItem[client], sizeof(g_sNamedItem[]), "give %s", item);
            ShowAliveSur(client);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateWeaponMenu(client);
            }
        }
    }

    return 0;
}

void Tier2Gun(int client, int item)
{
    Menu menu = new Menu(Tier2Weapon_MenuHandler);
    menu.SetTitle("Tier2武器");
    menu.AddItem("chainsaw", "电锯");
    menu.AddItem("rifle", "M16");
    menu.AddItem("rifle_ak47", "AK47");
    menu.AddItem("rifle_sg552", "SG552");
    menu.AddItem("rifle_desert", "SCAR");
    menu.AddItem("autoshotgun", "一连");
    menu.AddItem("shotgun_spas", "二连");
    menu.AddItem("hunting_rifle", "木狙");
    menu.AddItem("sniper_military", "军狙");
    menu.AddItem("sniper_scout", "鸟狙");
    menu.AddItem("sniper_awp", "AWP");
    menu.AddItem("rifle_m60", "M60");
    menu.AddItem("grenade_launcher", "榴弹");
    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Tier2Weapon_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[64];
            menu.GetItem(param2, item, sizeof(item));
            g_iFunction[client] = 2;
            g_iSelection[client] = menu.Selection;
            FormatEx(g_sNamedItem[client], sizeof(g_sNamedItem[]), "give %s", item);
            ShowAliveSur(client);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateWeaponMenu(client);
            }
        }
    }

    return 0;
}

void Melee(int client, int item)
{
    Menu menu = new Menu(Melee_MenuHandler);
    menu.SetTitle("近战武器");
    char melee[64], trans[64];
    int count = g_aMeleeScripts.Length;
    for (int i; i < count; i++) {
        g_aMeleeScripts.GetString(i, melee, sizeof(melee));
        if (!g_smMeleeTrans.GetString(melee, trans, sizeof(trans))) {
            strcopy(trans, sizeof(trans), melee);
        }

        menu.AddItem(melee, trans);
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Melee_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[64];
            menu.GetItem(param2, item, sizeof(item));
            g_iFunction[client] = 3;
            g_iSelection[client] = menu.Selection;
            FormatEx(g_sNamedItem[client], sizeof(g_sNamedItem[]), "give %s", item);
            ShowAliveSur(client);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateWeaponMenu(client);
            }
        }
    }

    return 0;
}
// -------------------------------------------------------------------------------
// --------------------------------------- ItemnMenu -----------------------------
void Menu_CreateItemMenu(int client, int item)
{
    Menu menu = CreateMenu(Item_MenuHandler);
    menu.SetTitle("生成物品");
    menu.AddItem("health", "生命值");                   // 0
    menu.AddItem("molotov", "燃烧瓶");                  // 1
    menu.AddItem("pipe_bomb", "土质雷");
    menu.AddItem("vomitjar", "胆汁瓶");
    menu.AddItem("first_aid_kit", "医疗包");
    menu.AddItem("defibrillator", "电击器");
    menu.AddItem("adrenaline", "肾上腺");
    menu.AddItem("pain_pills", "止痛药");
    menu.AddItem("gascan", "汽油桶");
    menu.AddItem("propanetank", "煤气罐");
    menu.AddItem("oxygentank", "氧气瓶");
    menu.AddItem("fireworkcrate", "烟花箱");
    menu.AddItem("cola_bottles", "可乐瓶");
    menu.AddItem("gnome", "小侏儒");
    menu.AddItem("ammo", "补弹药");
    menu.AddItem("upgradepack_incendiary", "燃烧包");
    menu.AddItem("upgradepack_explosive", "高爆包");
    menu.AddItem("incendiary_ammo", "燃烧弹");          // 17
    menu.AddItem("explosive_ammo", "高爆弹");
    menu.AddItem("laser_sight", "镭射");
    menu.AddItem("weapon_ammo_spawn", "部署子弹堆");    // 20
    menu.AddItem("upgrade_ammo_incendiary", "部署燃烧弹包");
    menu.AddItem("upgrade_ammo_explosive", "部署高爆弹包");
    menu.AddItem("upgrade_laser_sight", "部署镭射盒");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Item_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[64], display[32];
            menu.GetItem(param2, item, sizeof(item), _, display, sizeof(display));
            g_iFunction[client] = 4;
            g_iSelection[client] = menu.Selection;

            if (param2 < 1) {
                Life(client, 0);
            } else if (param2 < 17) {
                FormatEx(g_sNamedItem[client], sizeof(g_sNamedItem[]), "give %s", item);
                ShowAliveSur(client);
            } else if (param2 < 20) {
                FormatEx(g_sNamedItem[client], sizeof(g_sNamedItem[]), "upgrade_add %s", item);
                ShowAliveSur(client);
            } else {
                float vOrigin[3];
                if (GetTeleportEndPoint(client, vOrigin)) {
                    int iSpawner = CreateEntityByName(item);
                    if (iSpawner < 1 || !IsValidEntity(iSpawner)) {
                        return 0;
                    }

                    TeleportEntity(iSpawner, vOrigin, {0.0, 0.0, 0.0}, NULL_VECTOR);
                    SetEntityModel(iSpawner, g_sSpawnerModelName[param2 - 20]);
                    DispatchSpawn(iSpawner);
                    CPrintToChatAll("%s{G}%N {D}生成了一个 {B}%s", PLUGIN_TAG, client, display);
                } else {
                    CPrintToChat(client, "%s{D}获取准心处位置{R}失败{D}! 请重新尝试.", PLUGIN_TAG);
                }

                PageExitBack(client, g_iFunction[client], g_iSelection[client]);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void Life(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(Life_MenuHandler);
    menu.SetTitle("给谁生命值");
    menu.AddItem("a", "所有生还特感");
    menu.AddItem("s", "所有生还者");
    menu.AddItem("i", "所有感染者");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
            FormatEx(disp, sizeof(disp), "%N", i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Life_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            switch (item[0]) {
                case 'a': {
                    for (int i = 1; i <= g_iMaxClients; i++) {
                        if (!IsClientInGame(i) || !IsPlayerAlive(i) || 
                            (GetClientTeam(i) != 2 && GetClientTeam(i) != 3)) {
                            continue;
                        }
            
                        CheatCommand(i, "give health");
                    }

                    CPrintToChatAll("%s{G}%N {D}给 {G}所有生还/特感 {D}刷了一份 {O}生命值{D}.", PLUGIN_TAG, client);
                    Menu_CreateItemMenu(client, 0);
                }
                case 'i': {
                    for (int i = 1; i <= g_iMaxClients; i++) {
                        if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i))
                            continue;
            
                        CheatCommand(i, "give health");
                    }

                    CPrintToChatAll("%s{G}%N {D}给 {R}所有特感 {D}刷了一份 {O}生命值{D}.", PLUGIN_TAG, client);
                    Menu_CreateItemMenu(client, 0);
                }
                case 's': {
                    for (int i = 1; i <= g_iMaxClients; i++) {
                        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) {
                            continue;
                        }
            
                        CheatCommand(i, "give health");
                    }

                    CPrintToChatAll("%s{G}%N {D}给 {B}所有生还 {D}刷了一份 {O}生命值{D}.", PLUGIN_TAG, client);
                    Menu_CreateItemMenu(client, 0);
                }
                default: {
                    int target = GetClientOfUserId(StringToInt(item));
                    if (IsValidClient(target) && IsPlayerAlive(target)) {
                        CheatCommand(target, "give health");
                        CPrintToChatAll("%s{G}%N {D}给 {G}%N {D}刷了一份 {O}生命值{D}.", PLUGIN_TAG, client, target);
                    }
                }
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}
// -------------------------------------------------------------------------------
// --------------------------------------- ItemnMenu -----------------------------
void Menu_CreateTeleportMenu(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(Teleport_MenuHandler);
    menu.SetTitle("传送指令");
    menu.AddItem("s", "所有生还者");
    menu.AddItem("i", "所有感染者");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
            FormatEx(disp, sizeof(disp), "%N", i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Teleport_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            g_iSelection[client] = menu.Selection;
            TeleportTarget(client, item);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void TeleportTarget(int client, const char[] sTarget)
{   // sTarget|c
    char info[32], str[2][16], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(TeleprotDestination_MenuHandler);
    menu.SetTitle("传送目的地/目标:");
    strcopy(str[0], sizeof(str[]), sTarget);
    strcopy(str[1], sizeof(str[]), "c");
    ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
    menu.AddItem(info, "鼠标指针处");
    strcopy(str[1], sizeof(str[]), "s");
    ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
    menu.AddItem(info, "起点安全屋/区");
    strcopy(str[1], sizeof(str[]), "e");
    ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
    menu.AddItem(info, "终点安全屋/区");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            FormatEx(str[1], sizeof(str[]), "%d", GetClientUserId(i));
            ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
            FormatEx(disp, sizeof(disp), "%N", i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int TeleprotDestination_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[32], info[2][16];
            bool allow;
            float vOrigin[3];
            menu.GetItem(param2, item,sizeof(item));
            ExplodeString(item, "|", info, sizeof(info), sizeof(info[]));
            int victim = GetClientOfUserId(StringToInt(info[0]));
            int targetTeam;
            switch (info[0][0]) {
                case 's': targetTeam = 2;
                case 'i': targetTeam = 3;
                default: {
                    if (IsValidClient(victim)) {
                        targetTeam = GetClientTeam(victim);
                    }
                }
            }
            // 准心传送
            if (info[1][0] == 'c') {
                allow = GetTeleportEndPoint(client, vOrigin);
            } else {
                int target = GetClientOfUserId(StringToInt(info[1]));
                if (IsValidClient(target)) {
                    GetClientAbsOrigin(target, vOrigin);
                    allow = true;
                    if(IsValidClient(victim))
                        CPrintToChatAll("%s{G}%N {D}将 %s%N {D}传送到 {G}%N{D}处.", PLUGIN_TAG, client, GetClientTeam(victim) == 2 ? "{B}" : "{R}", victim, target);
                    else
                        CPrintToChatAll("%s{G}%N {D}将 %s {D}传送到 {G}%N{D}处.", PLUGIN_TAG, client, targetTeam == 2 ? "{B}所有生还" : "{R}所有特感", target);
                }
            }

            if (allow) {
                if (IsValidClient(victim)) {
                    ForceCrouch(victim);
                    TeleportFix(victim);
                    TeleportEntity(victim, vOrigin, NULL_VECTOR, NULL_VECTOR);
                    if (info[1][0] == 'c') {
                        CPrintToChatAll("%s{G}%N {D}将 %s%N {D}传送到 {G}操作者的准心处{D}.", PLUGIN_TAG, client, GetClientTeam(victim) == 2 ? "{B}" : "{R}", victim);
                    }
                } else {
                    switch (targetTeam) {
                        case 2: {
                            for (int i = 1; i <= g_iMaxClients; i++) {
                                if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
                                    ForceCrouch(i);
                                    TeleportFix(i);
                                    TeleportEntity(i, vOrigin, NULL_VECTOR, NULL_VECTOR);
                                }
                            }
                            if (info[1][0] == 'c')
                                CPrintToChatAll("%s{G}%N {D}将 {B}所有生还 {D}传送到操作者的准心处.", PLUGIN_TAG, client);
                        }   
                        case 3: {
                            for (int i = 1; i <= g_iMaxClients; i++) {
                                if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) {
                                    ForceCrouch(i);
                                    TeleportEntity(i, vOrigin, NULL_VECTOR, NULL_VECTOR);
                                }
                            }
                            if (info[1][0] == 'c')
                                CPrintToChatAll("%s{G}%N {D}将 {R}所有特感 {D}传送到操作者的准心处.", PLUGIN_TAG, client);
                        }
                    }
                }
            } else if (info[1][0] == 'c') {
                CPrintToChat(client, "%s{D}获取准心处位置{R}失败{D}! 请重新尝试.", PLUGIN_TAG);
            }
            // 安全区传送
            if (info[1][0] == 's') {
                if (victim) {
                    WarpToStartArea(client, victim);
                }
                else {
                    WarpToStartArea(client, _, targetTeam);
                }
            }

            if (info[1][0] == 'e') {
                if (victim) {
                    WarpToCheckpoint(client, victim);
                }
                else {
                    WarpToCheckpoint(client, _, targetTeam);
                }
            }

            Menu_CreateTeleportMenu(client, 0);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                Menu_CreateTeleportMenu(client, 0);
            }
        }
    }

    return 0;
}

void TeleportFix(int client)
{
    if (GetClientTeam(client) != 2) {
        return;
    }

    SetEntityMoveType(client, MOVETYPE_WALK);
    SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);
    if (L4D_IsPlayerHangingFromLedge(client)) {
        L4D_ReviveSurvivor(client);
    }
    else {
        int attacker = L4D2_GetInfectedAttacker(client);
        if (attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
            L4D_CleanupPlayerState(attacker);
            ForcePlayerSuicide(attacker);
        }
    }
}

void WarpToStartArea(int client, int target = 0, int team = 0)
{
    if (IsValidClient(target)) {
        CheatCommand(target, "warp_to_start_area");
        CPrintToChatAll("%s{G}%N {D}将 %s%N {D}传送到起点安全区/屋.", PLUGIN_TAG, client, GetClientTeam(target) == 2 ? "{B}" : "{R}", target);
    } else {
        for (int i = 1; i <= g_iMaxClients; i++) {
            if (IsClientInGame(i) && GetClientTeam(i) == team && IsPlayerAlive(i)) {
                CheatCommand(i, "warp_to_start_area");
            }
        }

        CPrintToChatAll("%s{G}%N {D}将 %s {D}传送到起点安全区/屋.", PLUGIN_TAG, client, team == 2 ? "{B}所有生还" : "{R}所有特感");
    }

    Menu_CreateTeleportMenu(client, 0);
}

void WarpToCheckpoint(int client, int target = 0, int team = 0)
{
    if (g_hSDK_TerrorNavMesh_GetLastCheckpoint && g_hSDK_Checkpoint_GetLargestArea) {
        Address pLastCheckpoint = SDKCall(g_hSDK_TerrorNavMesh_GetLastCheckpoint, L4D_GetPointer(POINTER_NAVMESH));
        if (pLastCheckpoint) {
            int navArea = SDKCall(g_hSDK_Checkpoint_GetLargestArea, pLastCheckpoint);
            if (navArea) {
                float vPos[3];
                if (IsValidClient(target)) {
                    L4D_FindRandomSpot(navArea, vPos);
                    TeleportEntity(target, vPos, NULL_VECTOR, NULL_VECTOR);
                    CPrintToChatAll("%s{G}%N {D}将 %s%N {D}传送到终点安全区/屋.", PLUGIN_TAG, client, GetClientTeam(target) == 2 ? "{B}" : "{R}", target);
                } else {
                    for (int i = 1; i <= g_iMaxClients; i++) {
                        if (IsClientInGame(i) && GetClientTeam(i) == team && IsPlayerAlive(i)) {
                            L4D_FindRandomSpot(navArea, vPos);
                            TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
                        }
                    }

                    CPrintToChatAll("%s{G}%N {D}将 %s {D}传送到终点安全区/屋.", PLUGIN_TAG, client, team == 2 ? "{B}所有生还" : "{R}所有特感");
                }

                Menu_CreateTeleportMenu(client, 0);

                return;
            }
        }
    }

    ExecuteCommand("warp_all_survivors_to_checkpoint");
    Menu_CreateTeleportMenu(client, 0);
}
// -------------------------------------------------------------------------------
// --------------------------------------- ItemnMenu -----------------------------
void Menu_CreateInfectedMenu(int client)
{
    Menu menu = CreateMenu(Infected_MenuHandler);
    menu.SetTitle("生成特感");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);
    menu.AddItem("", "可接管特感");
    menu.AddItem("", "AI接管特感");
    menu.AddItem("", "非特殊感染者");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

int Infected_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            switch (param2) {
                case 0: PlayerSI(client, 0);
                case 1: AISI(client, 0);
                case 2: CommonInfected(client, 0);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void PlayerSI(int client, int item)
{
    Menu menu = new Menu(PlayerSI_MenuHandler);
    menu.SetTitle("生成可接管特感:");
    char sSpawnMode[32];
    FormatEx(sSpawnMode, sizeof(sSpawnMode), "生成模式: [%s]", g_bAuto[client] ? "自动" : "默认");
    menu.AddItem("", sSpawnMode);
    menu.AddItem("", "Smoker|舌头");
    menu.AddItem("", "Boomer|胖子");
    menu.AddItem("", "Hunter|猎人");
    menu.AddItem("", "Spitter|口水");
    menu.AddItem("", "Jockey|猴子");
    menu.AddItem("", "Charger|牛牛");
    menu.AddItem("", "Tank|坦克");
    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int PlayerSI_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            switch (param2) {
                case 0: {
                    g_bAuto[client] = !g_bAuto[client];
                    PlayerSI(client, 0);
                }
                case 1: SpawnPlayerSI(client, "smoker", g_bAuto[client]);
                case 2: SpawnPlayerSI(client, "boomer", g_bAuto[client]);
                case 3: SpawnPlayerSI(client, "hunter", g_bAuto[client]);
                case 4: SpawnPlayerSI(client, "spitter", g_bAuto[client]);
                case 5: SpawnPlayerSI(client, "jockey", g_bAuto[client]);
                case 6: SpawnPlayerSI(client, "charger", g_bAuto[client]);
                case 7: SpawnPlayerSI(client, "tank", g_bAuto[client]);
            }

            PlayerSI(client, menu.Selection);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateInfectedMenu(client);
            }
        }
    }

    return 0;
}

void AISI(int client, int item)
{
    Menu menu = new Menu(AISI_MenuHandler);
    menu.SetTitle("生成AI特感:");
    menu.AddItem("", "Smoker|舌头");
    menu.AddItem("", "Boomer|胖子");
    menu.AddItem("", "Hunter|猎人");
    menu.AddItem("", "Spitter|口水");
    menu.AddItem("", "Jockey|猴子");
    menu.AddItem("", "Charger|牛牛");
    menu.AddItem("", "Tank|坦克");
    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int AISI_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            int iKickTarget;
            if (GetClientCount(false) >= g_iMaxClients - 1) {
                CPrintToChat(client, "%s{D}槽位已满, 正在尝试{G}踢出死亡的特感AI{D}... ...", PLUGIN_TAG);
                iKickTarget = KickDeadInfectedBots(client);
            }

            if (!iKickTarget) {
                switch (param2) {
                    case 0: CreateInfectedBot(client, 1);
                    case 1: CreateInfectedBot(client, 2);
                    case 2: CreateInfectedBot(client, 3);
                    case 3: CreateInfectedBot(client, 4);
                    case 4: CreateInfectedBot(client, 5);
                    case 5: CreateInfectedBot(client, 6);
                    case 6: CreateInfectedBot(client, 8);
                }
            }
            else {
                DataPack pack = new DataPack();
                pack.WriteCell(client);
                pack.WriteCell(param2 + 1);
                RequestFrame(NextFrame_CreateInfectedBot, pack);
            }

            AISI(client, menu.Selection);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateInfectedMenu(client);
            }
        }
    }

    return 0;
}

void CommonInfected(int client, int item)
{
    Menu menu = new Menu(CommonInfected_MenuHandler);
    menu.SetTitle("生成非特殊感染者:");
    menu.AddItem("Witch", "普通女巫");
    menu.AddItem("Witch_Bride", "婚纱女巫");
    menu.AddItem("7", "普通僵尸");
    menu.AddItem("0", "防爆僵尸");
    menu.AddItem("1", "Ceda僵尸");
    menu.AddItem("2", "小丑僵尸");
    menu.AddItem("3", "泥人僵尸");
    menu.AddItem("4", "工人僵尸");
    menu.AddItem("5", "赛车僵尸");
    menu.AddItem("6", "堕落生还");
    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int CommonInfected_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[32];
            menu.GetItem(param2, item, sizeof(item));
            SpawnCommonInfected(client, item);
            CommonInfected(client, menu.Selection);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateInfectedMenu(client);
            }
        }
    }

    return 0;
}

void SpawnPlayerSI(int client, const char[] type, bool auto = false)
{
    char sSpawnArg[16];
    FormatEx(sSpawnArg, sizeof(sSpawnArg), "%s%s", type, auto ? " auto" : "");
    StripAndExecuteClientCommand(client, "z_spawn", sSpawnArg);
    CPrintToChatAll("%s{G}%N {D}生成一个可供接管的[{R}%s{D}]", PLUGIN_TAG, client, type);
}

int KickDeadInfectedBots(int client)
{
    int iKickedBot;
    for (int loopClient = 1; loopClient <= g_iMaxClients; loopClient++) {
        if (!IsClientInGame(loopClient) || GetClientTeam(client) != 3 || 
            !IsFakeClient(loopClient) || IsPlayerAlive(loopClient)) {
            continue;
        }

        KickClient(loopClient);
        iKickedBot++;
    }

    return iKickedBot;
}

void NextFrame_CreateInfectedBot(DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell(), type = pack.ReadCell();
    delete pack;
    CreateInfectedBot(client, type);
}

int CreateInfectedBot(int client, int type)
{
    float vPos[3];
    if (!GetTeleportEndPoint(client, vPos)) {
        return -1;
    }

    int ent = -1;
    switch (type) {
        case 1: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[0], "Smoker");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Smoker{D}]", PLUGIN_TAG, client);
        }
        case 2: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[1], "Boomer");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Boomer{D}]", PLUGIN_TAG, client);
        }
        case 3: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[2], "Hunter");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Hunter{D}]", PLUGIN_TAG, client);
        }
        case 4: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[3], "Spitter");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Spitter{D}]", PLUGIN_TAG, client);
        }
        case 5: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[4], "Jockey");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Jockey{D}]", PLUGIN_TAG, client);
        }
        case 6: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[5], "Charger");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Charger{D}]", PLUGIN_TAG, client);
        }
        case 8: {
            ent = SDKCall(g_hSDK_NextBotCreatePlayerBot[6], "Tank");
            if (ent == -1) {
                return -1;
            }
            
            InitializeSpecial(ent, vPos, NULL_VECTOR);
            CPrintToChatAll("%s{G}%N {D}生成了一个AI的[{R}Tank{D}]", PLUGIN_TAG, client);
        }
    }

    return ent;
}

int SpawnCommonInfected(int client, const char[] zombie)
{
    float vPos[3];
    if (!GetTeleportEndPoint(client, vPos)) {
        return -1;
    }

    int ent = -1;
    if (!strncmp(zombie, "Witch", 5, false)) {
        ent = CreateEntityByName("witch");
        if (ent == -1) {
            return -1;
        }

        TeleportEntity(ent, vPos);
        DispatchSpawn(ent);
        if (strlen(zombie) > 5) {
            SetEntityModel(ent, "models/infected/witch_bride.mdl");
            CPrintToChatAll("%s{G}%N {D}生成了一个[{R}Bride Witch{D}]", PLUGIN_TAG, client);
        } else {
            CPrintToChatAll("%s{G}%N {D}生成了一个[{R}Witch{D}]", PLUGIN_TAG, client);
        }
    } else {
        ent = CreateEntityByName("infected");
        if (ent == -1) {
            return -1;
        }
        
        int pos = StringToInt(zombie);
        if (pos < 7) {
            SetEntityModel(ent, g_sUncommonModels[pos]);
        }

        char Inf[16];
        switch (pos) {
            case 0: Inf = "防爆僵尸";
            case 1: Inf = "Ceda僵尸";
            case 2: Inf = "小丑僵尸";
            case 3: Inf = "泥人僵尸";
            case 4: Inf = "工人僵尸";
            case 5: Inf = "赛车僵尸";
            case 7: Inf = "普通僵尸";
        }
        SetEntProp(ent, Prop_Data, "m_nNextThinkTick", RoundToNearest(GetGameTime() / GetTickInterval()) + 5);
        TeleportEntity(ent, vPos);
        if (pos != 6) {
            DispatchSpawn(ent);
            ActivateEntity(ent);
            CPrintToChatAll("%s{G}%N {D}生成了一个[{R}%s{D}]", PLUGIN_TAG, client, Inf);
        } else {
            int m_nFallenSurvivor = LoadFromAddress(g_pZombieManager + view_as<Address>(g_iOff_m_nFallenSurvivors), NumberType_Int32);
            float m_timestamp = view_as<float>(LoadFromAddress(g_pZombieManager + view_as<Address>(g_iOff_m_FallenSurvivorTimer) + view_as<Address>(8), NumberType_Int32));
            StoreToAddress(g_pZombieManager + view_as<Address>(g_iOff_m_nFallenSurvivors), 0, NumberType_Int32);
            StoreToAddress(g_pZombieManager + view_as<Address>(g_iOff_m_FallenSurvivorTimer) + view_as<Address>(8), view_as<int>(0.0), NumberType_Int32);
            DispatchSpawn(ent);
            ActivateEntity(ent);
            StoreToAddress(g_pZombieManager + view_as<Address>(g_iOff_m_nFallenSurvivors), m_nFallenSurvivor + LoadFromAddress(g_pZombieManager + view_as<Address>(g_iOff_m_nFallenSurvivors), NumberType_Int32), NumberType_Int32);
            StoreToAddress(g_pZombieManager + view_as<Address>(g_iOff_m_FallenSurvivorTimer) + view_as<Address>(8), view_as<int>(m_timestamp), NumberType_Int32);
            CPrintToChatAll("%s{G}%N {D}生成了一个[{R}堕落生还者{D}]", PLUGIN_TAG, client);
        }
    }

    return ent;
}

void InitializeSpecial(int ent, const float vPos[3], const float vAng[3])
{
    ChangeClientTeam(ent, 3);
    SetEntProp(ent, Prop_Send, "m_usSolidFlags", 16);
    SetEntProp(ent, Prop_Send, "movetype", 2);
    SetEntProp(ent, Prop_Send, "deadflag", 0);
    SetEntProp(ent, Prop_Send, "m_lifeState", 0);
    SetEntProp(ent, Prop_Send, "m_iObserverMode", 0);
    SetEntProp(ent, Prop_Send, "m_iPlayerState", 0);
    SetEntProp(ent, Prop_Send, "m_zombieState", 0);
    DispatchSpawn(ent);
    TeleportEntity(ent, vPos, vAng, NULL_VECTOR);
}
// -------------------------------------------------------------------------------
// ---------------------------------------- DirectorMenu -------------------------
void Menu_CreateOtherMenu(int client, int item)
{
    Menu menu = CreateMenu(Other_MenuHandler);
    menu.SetTitle("其他功能");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);
    menu.AddItem("a", "团队更改");
    menu.AddItem("b", "倒地玩家");
    menu.AddItem("c", "剥夺玩家");
    menu.AddItem("d", "复活生还");
    menu.AddItem("e", "友伤控制");
    menu.AddItem("f", "伤害免疫");
    menu.AddItem("g", "处死特感");
    menu.AddItem("h", "处死生还");
    menu.AddItem("i", "控制免疫");
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int Other_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[2];
            menu.GetItem(param2, item, sizeof(item));
            g_iSelection[client] = menu.Selection;
            switch (item[0]) {
                case 'a': SwitchTeam(client, 0);
                case 'b': IncapSur(client, 0);
                case 'c': StripSlot(client, 0);
                case 'd': RespawnPlayer(client, 0);
                case 'e': SetFriendlyFire(client);
                case 'f': GodMode(client, 0);
                case 'g': SlayAllSI(client);
                case 'h': SlayAllSur(client);
                case 'i': IgnoreAbility(client, 7);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void StripSlot(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(StripSlot_MenuHandler);
    menu.SetTitle("选择剥夺目标玩家:");
    menu.AddItem("a", "所有玩家的所有装备");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) {
            continue;
        }

        FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
        FormatEx(disp, sizeof(disp), "%N", i);
        menu.AddItem(info, disp);
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int StripSlot_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            if (item[0] == 'a') {
                for (int i = 1; i <= g_iMaxClients; i++) {
                    if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
                        L4D_RemoveAllWeapons(i);
                    }
                }
                
                CPrintToChatAll("%s{G}%N {D}已经剥夺所有生还的装备.", PLUGIN_TAG, client);
                Menu_CreateOtherMenu(client, 0);
            } else {
                int target = GetClientOfUserId(StringToInt(item));
                if (target > 0 && target <= g_iMaxClients && IsClientInGame(target)) {
                    SlotSelect(client, target);
                    g_iSelection[client] = menu.Selection;
                }
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 0);
            }
        }
    }

    return 0;
}

void SlotSelect(int client, int target)
{
    char cls[32], info[32], str[2][16];
    Menu menu = new Menu(SlotSelect_MenuHandler);
    menu.SetTitle("剥夺目标装备:");
    FormatEx(str[0], sizeof(str[]), "%d", GetClientUserId(target));
    strcopy(str[1], sizeof(str[]), "a");
    ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
    menu.AddItem(info, "所有装备");
    int ent;
    for (int i; i < 5; i++) {
        if ((ent = GetPlayerWeaponSlot(target, i)) == -1) {
            continue;
        }

        FormatEx(str[1], sizeof(str[]), "%d", i);
        ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
        GetEntityClassname(ent, cls, sizeof(cls));
        if (strcmp(cls, "weapon_melee") == 0) {
            GetEntPropString(ent, Prop_Data, "m_strMapSetScriptName", cls, sizeof(cls));
            if (cls[0] == '\0') {
                char ModelName[128];
                GetEntPropString(ent, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
                if (strcmp(ModelName, "models/weapons/melee/v_tonfa.mdl") == 0) {
                    strcopy(cls, sizeof(cls), "tonfa");
                }
            }

            g_smMeleeTrans.GetString(cls, cls, sizeof(cls));
        }

        menu.AddItem(info, cls);
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int SlotSelect_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[32], info[2][16];
            menu.GetItem(param2, item, sizeof(item));
            ExplodeString(item, "|", info, sizeof(info), sizeof(info[]));
            int target = GetClientOfUserId(StringToInt(info[0]));
            if (IsValidClient(target)) {
                if (info[1][0] == 'a') {
                    L4D_RemoveAllWeapons(target);
                    CPrintToChatAll("%s{G}%N {D}已经剥夺 {G}%N {D}的所有的装备.", PLUGIN_TAG, client, target);
                    StripSlot(client, g_iSelection[client]);
                } else {
                    L4D_RemoveWeaponSlot(target, view_as<L4DWeaponSlot>(StringToInt(info[1])));
                    CPrintToChatAll("%s{G}%N {D}已经剥夺 {G}%N {D}的第 {B}%i {D}槽位的装备.", PLUGIN_TAG, client, target, StringToInt(info[1]));
                    SlotSelect(client, target);
                }
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                StripSlot(client, 0);
            }
        }
    }

    return 0;
}

void IncapSur(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(IncapSur_MenuHandler);
    menu.SetTitle("倒地目标玩家:");
    menu.AddItem("a", "所有");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) {
            continue;
        }

        FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
        FormatEx(disp, sizeof(disp), "%N", i);
        menu.AddItem(info, disp);
    }
    
    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int IncapSur_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            if (item[0] == 'a') {
                for (int i = 1; i <= g_iMaxClients; i++) {
                    Incap(i);
                }
                        
                CPrintToChatAll("%s{G}%N {D}强制 {G}所有生还 {D}倒地.", PLUGIN_TAG, client);
                Menu_CreateOtherMenu(client, 0);
            } else {
                int target = GetClientOfUserId(StringToInt(item));
                if (IsValidClient(target)) {
                    CPrintToChatAll("%s{G}%N {D}强制 {G}%N {D}倒地.", PLUGIN_TAG, client, target);
                    Incap(target);
                }

                IncapSur(client, menu.Selection);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 0);
            }
        }
    }

    return 0;
}

void GodMode(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(GodMode_MenuHandler);
    menu.SetTitle("设置玩家无敌:");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2) {
            FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
            FormatEx(disp, sizeof(disp), "[%s]#%N", g_bGodMode[i] ? "●" : "○", i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int GodMode_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            int target = GetClientOfUserId(StringToInt(item));
            if (IsValidClient(target)) {
                g_bGodMode[target] = !g_bGodMode[target];
                CPrintToChat(client, "%s{G}%N %s {D}了 {G}%N {D}的伤害免疫", PLUGIN_TAG, client, g_bGodMode[target] ? "{B}启用" : "{R}禁用", target);
            } else {
                CPrintToChat(client, "%s{D}目标玩家已{R}失效{D}!", PLUGIN_TAG);
            }

            GodMode(client, menu.Selection);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 0);
            }
        }
    }

    return 0;
}

void Incap(int client)
{
    if (IsClientInGame(client) && GetClientTeam(client) == 2 && 
        IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client)) {
        static ConVar cv;
        if (!cv) {
            cv = FindConVar("survivor_max_incapacitated_count");
        }

        int val = cv.IntValue;
        if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= val) {
            SetEntProp(client, Prop_Send, "m_currentReviveCount", val - 1);
            SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
            StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
        }

        IncapPlayer(client);
    }
}

void IncapPlayer(int client)
{
    bool last = g_bGodMode[client];
    g_bGodMode[client] = false;
    Vulnerable(client);
    SetEntityHealth(client, 1);
    L4D_SetPlayerTempHealth(client, 0);
    SDKHooks_TakeDamage(client, 0, 0, 100.0);
    g_bGodMode[client] = last;
}

void SwitchTeam(int client, int item)
{
    char info[12], disp[PLATFORM_MAX_PATH];
    Menu menu = new Menu(SwitchTeam_MenuHandler);
    menu.SetTitle("选择目标玩家:");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i)) {
            continue;
        }

        FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
        FormatEx(disp, sizeof(disp), "%N", i);
        switch (GetClientTeam(i)) {
            case 1: Format(disp, sizeof(disp), "%s#%s", GetBotOfIdlePlayer(i) ? "闲置" : "旁观", disp);
            case 2: Format(disp, sizeof(disp), "生还#%s", disp);
            case 3: Format(disp, sizeof(disp), "感染#%s", disp);
        }

        menu.AddItem(info, disp);
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int SwitchTeam_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            g_iSelection[client] = menu.Selection;
            int target = GetClientOfUserId(StringToInt(item));
            if (IsValidClient(target)) {
                SwitchPlayerTeam(client, target);
            } else {
                CPrintToChat(client, "%s{D}目标玩家已{R}失效{D}!", PLUGIN_TAG);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 0);
            }
        }
    }

    return 0;
}

void SwitchPlayerTeam(int client, int target)
{
    char info[32], str[2][16];
    Menu menu = new Menu(SwitchPlayerTeam_MenuHandler);
    menu.SetTitle("选择要转移到的队伍:");
    FormatEx(str[0], sizeof(str[]), "%d", GetClientUserId(target));
    int team;
    if (!GetBotOfIdlePlayer(target)) {
        team = GetClientTeam(target);
    }

    for (int i; i < 4; i++) {
        if (team == i || (team != 2 && i == 0)) {
            continue;
        }

        IntToString(i, str[1], sizeof(str[]));
        ImplodeStrings(str, sizeof(str), "|", info, sizeof(info));
        menu.AddItem(info, g_sTargetTeam[i]);
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int SwitchPlayerTeam_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12], info[2][16];
            menu.GetItem(param2, item, sizeof(item));
            ExplodeString(item, "|", info, sizeof(info), sizeof(info[]));
            int target = GetClientOfUserId(StringToInt(info[0]));
            if (IsValidClient(target)) {
                int team;
                if (!GetBotOfIdlePlayer(target)) {
                    team = GetClientTeam(target);
                }

                int targetTeam = StringToInt(info[1]);
                if (team != targetTeam) {
                    switch (targetTeam) {
                        case 0: {
                            if (team == 2) {
                                GoAFKTimer(target, 0.0);
                            } else {
                                CPrintToChat(client, "%s{D}仅生还支持闲置!", PLUGIN_TAG);
                            }
                        }
                        case 1: {
                            if (team == 0) {
                                L4D_TakeOverBot(target);
                            }

                            ChangeClientTeam(target, targetTeam);
                        }
                        case 2: ChangeTeamToSurvivor(target, team);
                        case 3: ChangeClientTeam(target, targetTeam);
                    }
                } else {
                    CPrintToChat(client, "%s{D}目标玩家已在目标队伍中!", PLUGIN_TAG);
                }
                        
                SwitchTeam(client, g_iSelection[client]);
            } else {
                CPrintToChat(client, "%s{D}目标玩家已失效!", PLUGIN_TAG);
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                SwitchTeam(client, menu.Selection);
            }
        }
    }

    return 0;
}

void ChangeTeamToSurvivor(int client, int team)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost")) {
		SetEntProp(client, Prop_Send, "m_isGhost", 0);
    }

	if (team != 1) {
		ChangeClientTeam(client, 1);
    }

	if (GetBotOfIdlePlayer(client)) {
		L4D_TakeOverBot(client);

		return;
	}

	int bot = FindAliveSurBot();
	if (bot) {
		L4D_SetHumanSpec(bot, client);
		L4D_TakeOverBot(client);
	}
	else {
		ChangeClientTeam(client, 2);
    }
}

void GoAFKTimer(int client, float flDuration)
{
    static int m_GoAFKTimer = -1;
    if (m_GoAFKTimer == -1) {
        m_GoAFKTimer = FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") - 12;
    }

    SetEntDataFloat(client, m_GoAFKTimer + 4, flDuration);
    SetEntDataFloat(client, m_GoAFKTimer + 8, GetGameTime() + flDuration);
}

void RespawnPlayer(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(RespawnPlayer_MenuHandler);
    menu.SetTitle("复活目标玩家:");
    menu.AddItem("s", "所有生还者");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i)) {
            FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
            FormatEx(disp, sizeof(disp), "%s - %N", g_sTargetTeam[2], i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int RespawnPlayer_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            if (item[0] == 's') {
                    for (int i = 1; i <= g_iMaxClients; i++) {
                        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || IsPlayerAlive(i)) {
                            continue;
                        }
            
                        StatsConditionPatch(true);
                        L4D_RespawnPlayer(i);
                        StatsConditionPatch(false);
                        TeleportToSurvivor(i);
                    }

                    CPrintToChatAll("%s{G}%N {O}复活所有了生还{D}.", PLUGIN_TAG, client);
                    Menu_CreateOtherMenu(client, 0);
            }
            else {
                int target = GetClientOfUserId(StringToInt(item));
                if (IsValidClient(target) && !IsPlayerAlive(target)) {
                    StatsConditionPatch(true);
                    L4D_RespawnPlayer(target);
                    StatsConditionPatch(false);
                    TeleportToSurvivor(target);
                    RespawnPlayer(client, menu.Selection);
                    CPrintToChatAll("%s{G}%N {O}复活了 {B}%N{D}.", PLUGIN_TAG, client, target);
                }
            }
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 0);
            }
        }
    }

    return 0;
}

void TeleportToSurvivor(int client)
{
    int target = 1;
    ArrayList al_clients = new ArrayList(2);
    for (; target <= g_iMaxClients; target++) {
        if (target == client || !IsClientInGame(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target)) {
            continue;
        }

        al_clients.Set(al_clients.Push(!L4D_IsPlayerIncapacitated(target) ? 0 : !L4D_IsPlayerHangingFromLedge(target) ? 1 : 2), target, 1);
    }

    if (!al_clients.Length) {
        target = 0;
    }
    else {
        al_clients.Sort(Sort_Descending, Sort_Integer);
        target = al_clients.Length - 1;
        target = al_clients.Get(GetRandomInt(al_clients.FindValue(al_clients.Get(target, 0)), target), 1);
    }

    delete al_clients;
    if (target) {
        ForceCrouch(client);
        float vPos[3];
        GetClientAbsOrigin(target, vPos);
        TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
    }

    CheatCommand(client, "give pistol");
}

void Vulnerable(int client)
{
    static int m_invulnerabilityTimer = -1;
    if (m_invulnerabilityTimer == -1) {
        m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;
    }

    SetEntDataFloat(client, m_invulnerabilityTimer + 4, 0.0);
    SetEntDataFloat(client, m_invulnerabilityTimer + 8, 0.0);
}

void SetFriendlyFire(int client)
{
    Menu menu = new Menu(SetFriendlyFire_MenuHandler);
    menu.SetTitle("设置生还友伤:");
    menu.AddItem("999", "恢复默认");
    menu.AddItem("0.0", "0.0(简单)");
    menu.AddItem("0.1", "0.1(普通)");
    menu.AddItem("0.2", "0.2");
    menu.AddItem("0.3", "0.3(困难)");
    menu.AddItem("0.4", "0.4");
    menu.AddItem("0.5", "0.5(专家)");
    menu.AddItem("0.6", "0.6");
    menu.AddItem("0.7", "0.7");
    menu.AddItem("0.8", "0.8");
    menu.AddItem("0.9", "0.9");
    menu.AddItem("1.0", "1.0");
    menu.AddItem("1.5", "1.5");
    menu.AddItem("1.0", "2.0");
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int SetFriendlyFire_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            switch (param2) {
                case 0: {
                    FindConVar("survivor_friendly_fire_factor_easy").RestoreDefault();
                    FindConVar("survivor_friendly_fire_factor_normal").RestoreDefault();
                    FindConVar("survivor_friendly_fire_factor_hard").RestoreDefault();
                    FindConVar("survivor_friendly_fire_factor_expert").RestoreDefault();
                    CPrintToChatAll("%s{D}友伤系数已被 {G}%N {D}重置为{R}默认值{D}!", PLUGIN_TAG, client);
                }
                default: {
                    float fPercent = StringToFloat(item);
                    FindConVar("survivor_friendly_fire_factor_easy").SetFloat(fPercent);
                    FindConVar("survivor_friendly_fire_factor_normal").SetFloat(fPercent);
                    FindConVar("survivor_friendly_fire_factor_hard").SetFloat(fPercent);
                    FindConVar("survivor_friendly_fire_factor_expert").SetFloat(fPercent);
                    CPrintToChatAll("%s{D}友伤系数已被 {G}%N {D}设置为 {R}%.1f{D}.", PLUGIN_TAG, client, fPercent);
                }
            }

            Menu_CreateOtherMenu(client, 0);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 0);
            }
        }
    }

    return 0;
}

void SlayAllSI(int client)
{
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) {
            ForcePlayerSuicide(i);
        }
    }

    CPrintToChatAll("%s{G}%N {O}处死所有特感{D}.", PLUGIN_TAG, client);
    Menu_CreateOtherMenu(client, 0);
}

void SlayAllSur(int client)
{
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
            ForcePlayerSuicide(i);
        }
    }

    CPrintToChatAll("%s{G}%N {O}处死所有生还{D}.", PLUGIN_TAG, client);
    Menu_CreateOtherMenu(client, 7);
}

void IgnoreAbility(int client, int item)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(IgnoreAbility_MenuHandler);
    menu.SetTitle("设置玩家免控:");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2) {
            FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
            FormatEx(disp, sizeof(disp), "[%s]#%N", g_bIgnoreAbility[i] ? "●" : "○", i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int IgnoreAbility_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            int target = GetClientOfUserId(StringToInt(item));
            if (target > 0 && target <= g_iMaxClients && IsClientInGame(target)) {
                g_bIgnoreAbility[target] = !g_bIgnoreAbility[target];
                CPrintToChatAll("%s{G}%N {D}已 {G}%s {G}%N {D}的特感控制免疫.", PLUGIN_TAG, client, g_bIgnoreAbility[target] ? "{B}启用" : "{R}禁用", target);
            }
            else {
                CPrintToChatAll("%s{D}目标玩家已失效!", PLUGIN_TAG);
            }

            IgnoreAbility(client, menu.Selection);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateOtherMenu(client, 7);
            }
        }
    }

    return 0;
}

public Action L4D_OnGrabWithTongue(int victim, int attacker)
{
    if (!g_bIgnoreAbility[victim]) {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}

public Action L4D_OnPouncedOnSurvivor(int victim, int attacker)
{
    if (!g_bIgnoreAbility[victim]) {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}

public Action L4D2_OnJockeyRide(int victim, int attacker)
{
    if (!g_bIgnoreAbility[victim]) {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}

public Action L4D2_OnStartCarryingVictim(int victim, int attacker)
{
    if (!g_bIgnoreAbility[victim]) {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}

public Action L4D2_OnPummelVictim(int attacker, int victim)
{
    if (!g_bIgnoreAbility[victim]) {
        return Plugin_Continue;
    }

    DataPack pack = new DataPack();
    RequestFrame(OnPummelTeleport, pack);
    pack.WriteCell(GetClientUserId(victim));
    pack.WriteCell(GetClientUserId(attacker));
    AnimHookEnable(victim, OnPummelOnAnimPre, INVALID_FUNCTION);
    CreateTimer(0.3, Timer_OnPummelResetAnim, GetClientUserId(victim));

    return Plugin_Handled;
}

void OnPummelTeleport(DataPack pack)
{
    pack.Reset();
    int victim = pack.ReadCell(), attacker = pack.ReadCell();
    delete pack;
    victim = GetClientOfUserId(victim);
    if (!victim || !IsClientInGame(victim)) {
        return;
    }

    attacker = GetClientOfUserId(attacker);
    if (!attacker || !IsClientInGame(attacker)) {
        return;
    }

    SetVariantString("!activator");
    AcceptEntityInput(victim, "SetParent", attacker);
    TeleportEntity(victim, view_as<float>({50.0, 0.0, 0.0}), NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(victim, "ClearParent");
}

Action OnPummelOnAnimPre(int client, int &anim)
{
    if (anim == L4D2_ACT_TERROR_SLAMMED_WALL || 
        anim == L4D2_ACT_TERROR_SLAMMED_GROUND) {
        anim = L4D2_ACT_STAND;

        return Plugin_Changed;
    }

    return Plugin_Continue;
}

Action Timer_OnPummelResetAnim(Handle timer, int client)
{
    if ((client = GetClientOfUserId(client))) {
        AnimHookDisable(client, OnPummelOnAnimPre);
    }

    return Plugin_Continue;
}
// -------------------------------------------------------------------------------
// 工具函数
// ---------------------------------------- Tools ------------------------------------------
void StripAndExecuteClientCommand(int client, const char[] command, const char[] arguments)
{
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
}

void StripAndChangeServerConVarBool(const char[] command, bool value)
{
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    SetConVarBool(FindConVar(command), value, false, false);
    SetCommandFlags(command, flags);
}

void StripAndChangeServerConVarInt(char[] command, int value)
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	SetConVarInt(FindConVar(command), value, false, false);
	SetCommandFlags(command, flags);
}

void CheatCommand(int client, const char[] command)
{
    if (!client || !IsClientInGame(client)) {
        return;
    }

    char cmd[32];
    if (SplitString(command, " ", cmd, sizeof(cmd)) == -1) {
        strcopy(cmd, sizeof(cmd), command);
    }

    if (strcmp(cmd, "give") == 0 && strcmp(command[5], "health") == 0) {
        int attacker = L4D2_GetInfectedAttacker(client);
        if (attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
            L4D_CleanupPlayerState(attacker);
            ForcePlayerSuicide(attacker);
        }
    }

    int bits = GetUserFlagBits(client), flags = GetCommandFlags(cmd);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    SetCommandFlags(cmd, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, command);
    SetUserFlagBits(client, bits);
    SetCommandFlags(cmd, flags);

    if (strcmp(cmd, "give") == 0) {
        if (strcmp(command[5], "health") == 0) {
            L4D_SetPlayerTempHealth(client, 0);
        }
        else if (strcmp(command[5], "ammo") == 0) {
            ReloadAmmo(client);
        }
    }
}

void ShowAliveSur(int client)
{
    char info[12], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(ShowAliveSur_MenuHandler);
    menu.SetTitle("目标玩家");
    menu.AddItem("a", "所有");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
            FormatEx(info, sizeof(info), "%d", GetClientUserId(i));
            FormatEx(disp, sizeof(disp), "%N", i);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int ShowAliveSur_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            if (item[0] == 'a') {
                for (int i = 1; i <= g_iMaxClients; i++) {
                    if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
                        CheatCommand(i, g_sNamedItem[client]);
                    }
                }

                if (StrContains(g_sNamedItem[client], "give ")) {
                    char sItem[2][32];
                    ExplodeString(g_sNamedItem[client], " ", sItem, sizeof(sItem), sizeof(sItem[]));
                    CPrintToChatAll("%s{G}%N {D}给 {G}所有人 {D}刷了一份 {B}%s", PLUGIN_TAG, client, sItem[1]);
                }
                else if (StrContains(g_sNamedItem[client], "upgrade_add ")) {
                    char sItem[2][32];
                    ExplodeString(g_sNamedItem[client], " ", sItem, sizeof(sItem), sizeof(sItem[]));
                    CPrintToChatAll("%s{G}%N {D}给 {G}所有人 {D}刷了一份 {B}%s", PLUGIN_TAG, client, sItem[1]);
                }
            }
            else {
                CheatCommand(GetClientOfUserId(StringToInt(item)), g_sNamedItem[client]);
                if (StrContains(g_sNamedItem[client], "give ")) {
                    char sItem[2][32];
                    ExplodeString(g_sNamedItem[client], " ", sItem, sizeof(sItem), sizeof(sItem[]));
                    CPrintToChatAll("%s{G}%N {D}给 {G}%N {D}刷了一份 {B}%s", PLUGIN_TAG, client, GetClientOfUserId(StringToInt(item)), sItem[1]);
                }
                else if (StrContains(g_sNamedItem[client], "upgrade_add ")) {
                    char sItem[2][32];
                    ExplodeString(g_sNamedItem[client], " ", sItem, sizeof(sItem), sizeof(sItem[]));
                    CPrintToChatAll("%s{G}%N {D}给 {G}%N {D}刷了一份 {B}%s", PLUGIN_TAG, client, GetClientOfUserId(StringToInt(item)), sItem[1]);
                }
            }

            PageExitBack(client, g_iFunction[client], g_iSelection[client]);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                PageExitBack(client, g_iFunction[client], g_iSelection[client]);
            }
        }
    }

    return 0;
}

void ReloadAmmo(int client)
{
    int weapon = GetPlayerWeaponSlot(client, 0);
    if (weapon <= g_iMaxClients || !IsValidEntity(weapon)) {
        return;
    }

    int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (m_iPrimaryAmmoType == -1) {
        return;
    }

    char cls[32];
    GetEntityClassname(weapon, cls, sizeof(cls));
    if (strcmp(cls, "weapon_rifle_m60") == 0) {
        static ConVar cM60;
        if (!cM60) {
            cM60 = FindConVar("ammo_m60_max");
        }

        SetEntProp(weapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(cls, L4D2IWA_ClipSize));
        SetEntProp(client, Prop_Send, "m_iAmmo", cM60.IntValue, _, m_iPrimaryAmmoType);
    }
    else if (strcmp(cls, "weapon_grenade_launcher") == 0) {
        static ConVar cGrenadelau;
        if (!cGrenadelau) {
            cGrenadelau = FindConVar("ammo_grenadelauncher_max");
        }

        SetEntProp(weapon, Prop_Send, "m_iClip1", L4D2_GetIntWeaponAttribute(cls, L4D2IWA_ClipSize));
        SetEntProp(client, Prop_Send, "m_iAmmo", cGrenadelau.IntValue, _, m_iPrimaryAmmoType);
    }
}

void PageExitBack(int client, int func, int item)
{
    switch (func) {
        case 1: Tier1Gun(client, item);
        case 2: Tier2Gun(client, item);
        case 3: Melee(client, item);
        case 4: Menu_CreateItemMenu(client, item);
    }
}

void ForceCrouch(int client)
{
    SetEntProp(client, Prop_Send, "m_bDucked", 1);
    SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_DUCKING);
}
// 获取准心
bool GetTeleportEndPoint(int client, float vPos[3])
{
    float vAng[3];
    GetClientEyeAngles(client, vAng);
    GetClientEyePosition(client, vPos);
    Handle hndl = TR_TraceRayFilterEx(vPos, vAng, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilter);
    if (TR_DidHit(hndl)) {
        float vEnd[3];
        TR_GetEndPosition(vEnd, hndl);
        delete hndl;
        float vVec[3];
        MakeVectorFromPoints(vPos, vEnd, vVec);
        float vDown[3], dist = GetVectorLength(vVec);
        while (dist > 0.0) {
            hndl = TR_TraceHullFilterEx(vEnd, vEnd, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 72.0}), MASK_PLAYERSOLID, TraceEntityFilter);
            if (!TR_DidHit(hndl)) {
                delete hndl;
                vPos = vEnd;

                return true;
            }

            delete hndl;

            dist -= 35.0;
            if (dist <= 0.0) {
                break;
            }

            NormalizeVector(vVec, vVec);
            ScaleVector(vVec, dist);
            AddVectors(vPos, vVec, vEnd);
            vDown[0] = vEnd[0];
            vDown[1] = vEnd[1];
            vDown[2] = vEnd[2] - 100000.0;
            hndl = TR_TraceHullFilterEx(vEnd, vDown, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 72.0}), MASK_PLAYERSOLID, TraceEntityFilter);
            if (TR_DidHit(hndl)) {
                TR_GetEndPosition(vEnd, hndl);
            }
            else {
                dist -= 35.0;
                if (dist <= 0.0) {
                    delete hndl;
                    break;
                }

                NormalizeVector(vVec, vVec);
                ScaleVector(vVec, dist);
                AddVectors(vPos, vVec, vEnd);
            }

            delete hndl;
        }
    }

    delete hndl;
    GetClientAbsOrigin(client, vPos);

    return true;
}

bool TraceEntityFilter(int entity, int contentsMask)
{
    if (!entity || entity > g_iMaxClients) {
        static char cls[5];
        GetEdictClassname(entity, cls, sizeof(cls));
        return cls[3] != 'e' && cls[3] != 'c';
    }

    return false;
}

void ExecuteCommand(const char[] command, const char[] value = "")
{
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    ServerCommand("%s %s", command, value);
    ServerExecute();
    SetCommandFlags(command, flags);
}

int FindAliveSurBot()
{
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsAliveSurBot(i)) {
            return i;
        }
    }

    return 0;
}

bool IsAliveSurBot(int client)
{
    return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && 
        GetClientTeam(client) == 2 && IsPlayerAlive(client) && !GetIdlePlayerOfBot(client);
}

int GetBotOfIdlePlayer(int client)
{
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i) && IsFakeClient(i) && 
            GetClientTeam(i) == 2 && GetIdlePlayerOfBot(i) == client) {
            return i;
        }
    }

    return 0;
}

int GetIdlePlayerOfBot(int client)
{
    if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID")) {
        return 0;
    }
    return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= g_iMaxClients && IsClientInGame(client));
}
// Weapon Handling API
enum L4D2WeaponType {
    L4D2WeaponType_Unknown = 0,
    L4D2WeaponType_Pistol,
    L4D2WeaponType_Magnum,
    L4D2WeaponType_Rifle,
    L4D2WeaponType_RifleAk47,
    L4D2WeaponType_RifleDesert,
    L4D2WeaponType_RifleM60,
    L4D2WeaponType_RifleSg552,
    L4D2WeaponType_HuntingRifle,
    L4D2WeaponType_SniperAwp,
    L4D2WeaponType_SniperMilitary,
    L4D2WeaponType_SniperScout,
    L4D2WeaponType_SMG,
    L4D2WeaponType_SMGSilenced,
    L4D2WeaponType_SMGMp5,
    L4D2WeaponType_Autoshotgun,
    L4D2WeaponType_AutoshotgunSpas,
    L4D2WeaponType_Pumpshotgun,
    L4D2WeaponType_PumpshotgunChrome,
    L4D2WeaponType_Molotov,
    L4D2WeaponType_Pipebomb,
    L4D2WeaponType_FirstAid,
    L4D2WeaponType_Pills,
    L4D2WeaponType_Gascan,
    L4D2WeaponType_Oxygentank,
    L4D2WeaponType_Propanetank,
    L4D2WeaponType_Vomitjar,
    L4D2WeaponType_Adrenaline,
    L4D2WeaponType_Chainsaw,
    L4D2WeaponType_Defibrilator,
    L4D2WeaponType_GrenadeLauncher,
    L4D2WeaponType_Melee,
    L4D2WeaponType_UpgradeFire,
    L4D2WeaponType_UpgradeExplosive,
    L4D2WeaponType_BoomerClaw,
    L4D2WeaponType_ChargerClaw,
    L4D2WeaponType_HunterClaw,
    L4D2WeaponType_JockeyClaw,
    L4D2WeaponType_SmokerClaw,
    L4D2WeaponType_SpitterClaw,
    L4D2WeaponType_TankClaw,
    L4D2WeaponType_Gnome
}

StringMap CreateWeaponClassnameHashMap(StringMap hWeaponClassnameHashMap)
{
    hWeaponClassnameHashMap = CreateTrie();
    hWeaponClassnameHashMap.SetValue("weapon_pistol", L4D2WeaponType_Pistol);
    hWeaponClassnameHashMap.SetValue("weapon_pistol_magnum", L4D2WeaponType_Magnum);
    hWeaponClassnameHashMap.SetValue("weapon_rifle", L4D2WeaponType_Rifle);
    hWeaponClassnameHashMap.SetValue("weapon_rifle_ak47", L4D2WeaponType_RifleAk47);
    hWeaponClassnameHashMap.SetValue("weapon_rifle_desert", L4D2WeaponType_RifleDesert);
    hWeaponClassnameHashMap.SetValue("weapon_rifle_m60", L4D2WeaponType_RifleM60);
    hWeaponClassnameHashMap.SetValue("weapon_rifle_sg552", L4D2WeaponType_RifleSg552);
    hWeaponClassnameHashMap.SetValue("weapon_hunting_rifle", L4D2WeaponType_HuntingRifle);
    hWeaponClassnameHashMap.SetValue("weapon_sniper_awp", L4D2WeaponType_SniperAwp);
    hWeaponClassnameHashMap.SetValue("weapon_sniper_military", L4D2WeaponType_SniperMilitary);
    hWeaponClassnameHashMap.SetValue("weapon_sniper_scout", L4D2WeaponType_SniperScout);
    hWeaponClassnameHashMap.SetValue("weapon_smg", L4D2WeaponType_SMG);
    hWeaponClassnameHashMap.SetValue("weapon_smg_silenced", L4D2WeaponType_SMGSilenced);
    hWeaponClassnameHashMap.SetValue("weapon_smg_mp5", L4D2WeaponType_SMGMp5);
    hWeaponClassnameHashMap.SetValue("weapon_autoshotgun", L4D2WeaponType_Autoshotgun);
    hWeaponClassnameHashMap.SetValue("weapon_shotgun_spas", L4D2WeaponType_AutoshotgunSpas);
    hWeaponClassnameHashMap.SetValue("weapon_pumpshotgun", L4D2WeaponType_Pumpshotgun);
    hWeaponClassnameHashMap.SetValue("weapon_shotgun_chrome", L4D2WeaponType_PumpshotgunChrome);
    hWeaponClassnameHashMap.SetValue("weapon_molotov", L4D2WeaponType_Molotov);
    hWeaponClassnameHashMap.SetValue("weapon_pipe_bomb", L4D2WeaponType_Pipebomb);
    hWeaponClassnameHashMap.SetValue("weapon_first_aid_kit", L4D2WeaponType_FirstAid);
    hWeaponClassnameHashMap.SetValue("weapon_pain_pills", L4D2WeaponType_Pills);
    hWeaponClassnameHashMap.SetValue("weapon_gascan", L4D2WeaponType_Gascan);
    hWeaponClassnameHashMap.SetValue("weapon_oxygentank", L4D2WeaponType_Oxygentank);
    hWeaponClassnameHashMap.SetValue("weapon_propanetank", L4D2WeaponType_Propanetank);
    hWeaponClassnameHashMap.SetValue("weapon_vomitjar", L4D2WeaponType_Vomitjar);
    hWeaponClassnameHashMap.SetValue("weapon_adrenaline", L4D2WeaponType_Adrenaline);
    hWeaponClassnameHashMap.SetValue("weapon_chainsaw", L4D2WeaponType_Chainsaw);
    hWeaponClassnameHashMap.SetValue("weapon_defibrillator", L4D2WeaponType_Defibrilator);
    hWeaponClassnameHashMap.SetValue("weapon_grenade_launcher", L4D2WeaponType_GrenadeLauncher);
    hWeaponClassnameHashMap.SetValue("weapon_melee", L4D2WeaponType_Melee);
    hWeaponClassnameHashMap.SetValue("weapon_upgradepack_incendiary", L4D2WeaponType_UpgradeFire);
    hWeaponClassnameHashMap.SetValue("weapon_upgradepack_explosive", L4D2WeaponType_UpgradeExplosive);
    hWeaponClassnameHashMap.SetValue("weapon_boomer_claw", L4D2WeaponType_BoomerClaw);
    hWeaponClassnameHashMap.SetValue("weapon_charger_claw", L4D2WeaponType_ChargerClaw);
    hWeaponClassnameHashMap.SetValue("weapon_hunter_claw", L4D2WeaponType_HunterClaw);
    hWeaponClassnameHashMap.SetValue("weapon_jockey_claw", L4D2WeaponType_JockeyClaw);
    hWeaponClassnameHashMap.SetValue("weapon_smoker_claw", L4D2WeaponType_SmokerClaw);
    hWeaponClassnameHashMap.SetValue("weapon_spitter_claw", L4D2WeaponType_SpitterClaw);
    hWeaponClassnameHashMap.SetValue("weapon_tank_claw", L4D2WeaponType_TankClaw);
    hWeaponClassnameHashMap.SetValue("weapon_gnome", L4D2WeaponType_Gnome);

    return hWeaponClassnameHashMap;
}

L4D2WeaponType GetWeaponTypeFromClassname(const char[] classname)
{
    static StringMap hWeaponClassnameHashMap;
    if (hWeaponClassnameHashMap == INVALID_HANDLE) {
        hWeaponClassnameHashMap = CreateWeaponClassnameHashMap(hWeaponClassnameHashMap);
    }

    static L4D2WeaponType eWeaponType;
    if (!hWeaponClassnameHashMap.GetValue(classname, eWeaponType)) {
        return L4D2WeaponType_Unknown;
    }

    return eWeaponType;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 1 || classname[0] != 'w') {
        return;
    }

    g_iWeaponType[entity] = GetWeaponTypeFromClassname(classname);
    switch (g_iWeaponType[entity]) {
        case L4D2WeaponType_AutoshotgunSpas, L4D2WeaponType_PumpshotgunChrome, 
            L4D2WeaponType_Autoshotgun, L4D2WeaponType_Pumpshotgun, L4D2WeaponType_GrenadeLauncher, 
            L4D2WeaponType_HuntingRifle, L4D2WeaponType_Magnum, L4D2WeaponType_Rifle, 
            L4D2WeaponType_SMG, L4D2WeaponType_RifleSg552, L4D2WeaponType_Pistol, 
            L4D2WeaponType_RifleAk47, L4D2WeaponType_SMGMp5, 
            L4D2WeaponType_SMGSilenced, L4D2WeaponType_SniperAwp, L4D2WeaponType_SniperMilitary, 
            L4D2WeaponType_SniperScout, L4D2WeaponType_RifleM60: {
            hReloadModifier.HookEntity(Hook_Post, entity, OnReloadModifier);
            hRateOfFire.HookEntity(Hook_Post, entity, OnGetRateOfFire);
            hDeployModifier.HookEntity(Hook_Post, entity, OnDeployModifier);
            hDeployGun.HookEntity(Hook_Post, entity, OnDeployGun);
        }
        case L4D2WeaponType_RifleDesert: {
            hReloadModifier.HookEntity(Hook_Post, entity, OnReloadModifier);
            hRateOfFire.HookEntity(Hook_Post, entity, OnGetRateOfFire);
            hDeployModifier.HookEntity(Hook_Post, entity, OnDeployModifier);
            hDeployGun.HookEntity(Hook_Post, entity, OnDeployGun);
            hDesertBurstFire.HookEntity(Hook_Post, entity, OnGetRateOfFireBurst);
        }
        case L4D2WeaponType_Pills, L4D2WeaponType_Adrenaline: {
            hItemUseDuration.HookEntity(Hook_Post, entity, OnGetRateOfFire);
            hDeployModifier.HookEntity(Hook_Post, entity, OnDeployModifier);
            hDeployGun.HookEntity(Hook_Post, entity, OnDeployGun);
        }
        case L4D2WeaponType_Melee, L4D2WeaponType_Defibrilator, L4D2WeaponType_FirstAid, L4D2WeaponType_UpgradeFire, L4D2WeaponType_UpgradeExplosive: {
            hDeployModifier.HookEntity(Hook_Post, entity, OnDeployModifier);
            hDeployGun.HookEntity(Hook_Post, entity, OnDeployGun);
        }
        case L4D2WeaponType_Molotov, L4D2WeaponType_Pipebomb, L4D2WeaponType_Vomitjar: {
            hGrenadePrimaryAttack.HookEntity(Hook_Post, entity, OnReadyingThrow);
            hStartThrow.HookEntity(Hook_Post, entity, OnStartThrow);
            hDeployModifier.HookEntity(Hook_Post, entity, OnDeployModifier);
            hDeployGun.HookEntity(Hook_Post, entity, OnDeployGun);
        }
    }
}
// MRESReturn
MRESReturn OnMeleeSwingPre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
    g_iMeleeTempVals[MeleeSwingInfo_Entity] = pThis;
    g_iMeleeTempVals[MeleeSwingInfo_Client] = hParams.Get(1);
    g_iMeleeTempVals[MeleeSwingInfo_SwingType] = hParams.Get(2);

    return MRES_Ignored;
}

MRESReturn OnMeleeSwingpPost()
{
    if (!g_iMeleeTempVals[MeleeSwingInfo_SwingType]) {
        return MRES_Ignored;
    }

    int iWeapon = g_iMeleeTempVals[MeleeSwingInfo_Entity];
    float fSpeed = SpeedModifier(g_iMeleeTempVals[MeleeSwingInfo_Client], 1.0);
    fSpeed = ClampFloatAboveZero(fSpeed);
    float flGameTime, flNextTimeCalc;
    flGameTime = GetGameTime();
    flNextTimeCalc = (((GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack") - flGameTime) / fSpeed) + flGameTime);
    SetEntPropFloat(iWeapon, Prop_Send, "m_flPlaybackRate", fSpeed);
    SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", flNextTimeCalc);

    return MRES_Ignored;
}

MRESReturn HookPre_TrySwing(int pThis, Handle hReturn)
{
    if (IsValidEntity(pThis)) {
        int client = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
        if (client && g_iMeleeRange[client]) {
            melee_range.SetInt(g_iMeleeRange[client]);

            return MRES_Ignored;
        }
    }

    return MRES_Ignored;
}

MRESReturn HookPost_TrySwing(int pThis, Handle hReturn)
{
    melee_range.SetInt(70);

    return MRES_Ignored;
}

void PostThinkOnce(int iClient)
{
	SDKUnhook(iClient, SDKHook_PostThink, PostThinkOnce);
	int iWeapon = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
	if (!IsValidEntRef(g_iTempRef) || iWeapon != EntRefToEntIndex(g_iTempRef)) {
		return;
    }
	
	SetEntPropFloat(iWeapon, Prop_Send, "m_flPlaybackRate", g_fTempSpeed);
}

MRESReturn OnStartThrow(int pThis, DHookReturn hReturn)
{
    int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
    if (iClient < 1) {
        return MRES_Ignored;
    }

    float fSpeed = SpeedModifier(iClient, 1.0);
    fSpeed = ClampFloatAboveZero(fSpeed);
    float flGameTime, flNextTimeCalc;
    flGameTime = GetGameTime();
    flNextTimeCalc = (((GetEntPropFloat(pThis, Prop_Send, "m_fThrowTime") - flGameTime) / fSpeed) + flGameTime);
    SetEntPropFloat(pThis, Prop_Send, "m_fThrowTime", flNextTimeCalc);
    g_iTempRef = EntIndexToEntRef(pThis);
    g_fTempSpeed = fSpeed;
    SDKHook(iClient, SDKHook_PostThink, PostThinkOnce);

    return MRES_Ignored;
}

MRESReturn OnReadyingThrow(int pThis)
{
    static int iClient;
    iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
    if (iClient < 1) {
        return MRES_Ignored;
    }

    static float fSpeed;
    fSpeed = SpeedModifier(iClient, 1.0);
    fSpeed = ClampFloatAboveZero(fSpeed);
    static float flGameTime;
    static float flNextTimeCalc;
    flGameTime = GetGameTime();
    flNextTimeCalc = (((GetEntPropFloat(pThis, Prop_Send, "m_flNextPrimaryAttack") - flGameTime) / fSpeed) + flGameTime);
    SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", fSpeed);
    SetEntPropFloat(pThis, Prop_Send, "m_flNextPrimaryAttack", flNextTimeCalc);
    SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", flNextTimeCalc);

    return MRES_Ignored;
}

MRESReturn OnReloadModifier(int pThis, DHookReturn hReturn)
{
    int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
    if (iClient < 1) {
        return MRES_Ignored;
    }

    float fSpeed = SpeedModifier(iClient, 1.0);
    float fReloadSpeed = hReturn.Value;
    fReloadSpeed = ClampFloatAboveZero(fReloadSpeed / fSpeed);
    hReturn.Value = fReloadSpeed;

    return MRES_Override;
}

MRESReturn OnGetRateOfFire(int pThis, DHookReturn hReturn)
{
    static float fRateOfFire, fRateOfFireModifier;
    static int iClient;
    iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
    if (iClient < 1) {
        return MRES_Ignored;
    }
        
    fRateOfFireModifier = SpeedModifier(iClient, 1.0);
    fRateOfFire = hReturn.Value;

    if (g_iWeaponType[pThis] == L4D2WeaponType_Pistol) {
        if (GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1)) {
            hReturn.Value = 0.3;
        } else if (GetEntProp(pThis, Prop_Send, "m_isDualWielding", 1)) {
            hReturn.Value = 0.075000003;
        } else {
            hReturn.Value = 0.175;
        }

        return MRES_Override;
    }

    fRateOfFire = ClampFloatAboveZero(fRateOfFire / fRateOfFireModifier);
    if (g_iWeaponType[pThis] == L4D2WeaponType_RifleDesert) {
        g_fBurstModifier = fRateOfFireModifier;
    }

    hReturn.Value = fRateOfFire;
    SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", fRateOfFireModifier);

    return MRES_Override;
}

MRESReturn OnGetRateOfFireBurst(int pThis, DHookReturn hReturn)
{
    static int iClient;
    iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
    if (iClient < 1) {
        return MRES_Ignored;
    }

    float flValveBurstData = GetEntDataFloat(pThis, g_DesertBurstOffset + 8);
    if (flValveBurstData == g_fBurstEndTime[iClient]) {
        return MRES_Ignored;
    }

    float fTime = GetGameTime();
    flValveBurstData = flValveBurstData - fTime;
    flValveBurstData = ClampFloatAboveZero(flValveBurstData / g_fBurstModifier);
    g_fBurstEndTime[iClient] = flValveBurstData + fTime;
    SetEntDataFloat(pThis, g_DesertBurstOffset + 8, g_fBurstEndTime[iClient]);

    return MRES_Ignored;
}

MRESReturn OnDeployModifier(int pThis, DHookReturn hReturn)
{
    g_fTempSpeed = 1.0;
    int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
    if (iClient < 1) {
        return MRES_Ignored;
    }

    float fCurrentSpeed = hReturn.Value, fSpeed = SpeedModifier(iClient, 1.0);
    fSpeed = ClampFloatAboveZero(fSpeed);
    g_fTempSpeed = g_fTempSpeed * fSpeed;
    hReturn.Value = ClampFloatAboveZero(fCurrentSpeed / fSpeed);
    return MRES_Override;
}

MRESReturn OnDeployGun(int pThis)
{
    SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", g_fTempSpeed);
    return MRES_Ignored;
}

static float ClampFloatAboveZero(float fSpeed)
{
    return fSpeed <= 0.0 ? 0.00001 : fSpeed;
}

static bool IsValidEntRef(int iEntRef)
{
    return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}

float SpeedModifier(int client, float speedmodifier)
{
	if (g_fSpeedUp[client] > 1.0) {
		speedmodifier *= g_fSpeedUp[client];
    }

	return speedmodifier;
}

void Menu_CreateWeaponHandlingMenu(int client, int item)
{
    Menu menu = new Menu(WeaponHandling_MenuHandler);
    menu.SetTitle("武器操纵倍率");
    menu.AddItem("1.0", "1.0[默认]");
    menu.AddItem("1.1", "1.1x");
    menu.AddItem("1.2", "1.2x");
    menu.AddItem("1.3", "1.3x");
    menu.AddItem("1.4", "1.4x");
    menu.AddItem("1.5", "1.5x");
    menu.AddItem("1.6", "1.6x");
    menu.AddItem("1.7", "1.7x");
    menu.AddItem("1.8", "1.8x");
    menu.AddItem("1.9", "1.9x");
    menu.AddItem("2.0", "2.0x");
    menu.AddItem("2.1", "2.1x");
    menu.AddItem("2.2", "2.2x");
    menu.AddItem("2.3", "2.3x");
    menu.AddItem("2.4", "2.4x");
    menu.AddItem("2.5", "2.5x");
    menu.AddItem("2.6", "2.6x");
    menu.AddItem("2.7", "2.7x");
    menu.AddItem("2.8", "2.8x");
    menu.AddItem("2.9", "2.9x");
    menu.AddItem("3.0", "3.0x");
    menu.AddItem("3.1", "3.1x");
    menu.AddItem("3.2", "3.2x");
    menu.AddItem("3.3", "3.3x");
    menu.AddItem("3.4", "3.4x");
    menu.AddItem("3.5", "3.5x");

    menu.ExitBackButton = true;
    menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int WeaponHandling_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            g_iSelection[client] = menu.Selection;
            HandlingWeapon(client, item);
        }
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) {
                DisplayTopMenu(admin_menu, client, TopMenuPosition_LastCategory);
            }
        }
    }

    return 0;
}

void HandlingWeapon(int client, const char[] speedUp)
{
    char info[32],str[2][16], disp[MAX_NAME_LENGTH];
    Menu menu = new Menu(WeaponEnhanced_MenuHandler);
    menu.SetTitle("目标玩家");
    strcopy(str[0], sizeof(str[]), speedUp);
    strcopy(str[1], sizeof(str[]), "a");
    ImplodeStrings(str, sizeof str, "|", info, sizeof info);
    menu.AddItem(info, "所有");
    for (int i = 1; i <= g_iMaxClients; i++) {
        if (IsClientInGame(i)) {
            FormatEx(str[1], sizeof str[], "%d", GetClientUserId(i));
            FormatEx(disp, sizeof disp, "[%.1fx] - %N", g_fSpeedUp[i], i);
            ImplodeStrings(str, sizeof str, "|", info, sizeof info);
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int WeaponEnhanced_MenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    switch (action) {
        case MenuAction_Select: {
            char item[12], info[2][16];
            menu.GetItem(param2, item, sizeof(item));
            ExplodeString(item, "|", info, sizeof(info), sizeof(info[]));
            float fSpeedUp = StringToFloat(info[0]);
            if (info[1][0] == 'a') {
                for (int i = 1; i <= g_iMaxClients; i++) {
                    if (IsClientInGame(i)) {
                        g_fSpeedUp[i] = fSpeedUp;
                    }
                }

                CPrintToChatAll("%s{G}%N {D}将 {G}所有玩家 {D}的武器操纵性设置为 {B}%.1f {D}x", PLUGIN_TAG, client, fSpeedUp);
            } else {
                int target = GetClientOfUserId(StringToInt(info[1]));
                if (target && IsClientInGame(target)) {
                    g_fSpeedUp[target] = fSpeedUp;
                    CPrintToChatAll("%s{G}%N {D}将 {G}%N {D}的武器操纵性设置为 {B}%.1f {D}x", PLUGIN_TAG, client, target, fSpeedUp);
                } else {
                    CPrintToChatAll("%s{D}目标玩家已失效!", PLUGIN_TAG);
                }
            }

            Menu_CreateWeaponHandlingMenu(client, g_iSelection[client]);
        }
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_CreateWeaponHandlingMenu(client, g_iSelection[client]);
            }
        }
        case MenuAction_End: delete menu;
    }

    return 0;
}

Action Cmd_MeleeRange(int client, int args)
{
    if (args < 2) {
        CReplyToCommand(client, "%s{R}Usage{D}: {O}sm_meleerange {D}<{O}#userid{D}|{O}name{D}> [{O}range{D}]", PLUGIN_TAG);
        
        return Plugin_Handled;
    }

    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
            arg,
            client,
            target_list,
            MAXPLAYERS,
            COMMAND_FILTER_ALIVE,
            target_name,
            sizeof(target_name),
            tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++) {
        g_iMeleeRange[target_list[i]] = GetCmdArgInt(2);
    }

    return Plugin_Handled;
}

void AdminMenu_MeleeRange(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
    if (action == TopMenuAction_DisplayOption) {
        Format(buffer, maxlength, "更改玩家近战距离");
    } else if (action == TopMenuAction_SelectOption) {
        DisplayMeleeRangeMenu(param);
    }
}

void DisplayMeleeRangeMenu(int client)
{
    Menu menu = new Menu(MenuHandler_MeleeRange);
    menu.SetTitle("更改玩家近战距离:");
    menu.ExitBackButton = true;
    AddTargetsToMenu(menu, client, true, true);

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_MeleeRange(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action) {
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu) {
                admin_menu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_Select: {
            char info[32];
            int userid, target;
            menu.GetItem(param2, info, sizeof(info));
            userid = StringToInt(info);
            if (!(target = GetClientOfUserId(userid))) {
                PrintToChat(param1, "[SM] %t", "Player no longer available");
            } else if (!CanUserTarget(param1, target)) {
                PrintToChat(param1, "[SM] %t", "Unable to target");
            } else {
                Menu new_menu = new Menu(MeleeRange_MenuHandler);
                new_menu.SetTitle("设置近战距离:");
                FormatEx(info, sizeof(info), "%i|70", userid);
                new_menu.AddItem(info, "默认(70)");
                FormatEx(info, sizeof(info), "%i|140", userid);
                new_menu.AddItem(info, "140");
                FormatEx(info, sizeof(info), "%i|210", userid);
                new_menu.AddItem(info, "210");
                new_menu.ExitBackButton = true;
                new_menu.Display(param1, MENU_TIME_FOREVER);
            }
        }
    }

    return 0;
}

int MeleeRange_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action) {
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack && admin_menu) {
                admin_menu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_Select: {
            char info[32], info2[2][16];
            int userid, target;
            menu.GetItem(param2, info, sizeof(info));
            ExplodeString(info, "|", info2, 2, sizeof(info2[]));
            userid = StringToInt(info2[0]);
            if (!(target = GetClientOfUserId(userid))) {
                PrintToChat(param1, "[SM] %t", "Player no longer available");
            } else if (!CanUserTarget(param1, target)) {
                PrintToChat(param1, "[SM] %t", "Unable to target");
            } else {
                g_iMeleeRange[target] = StringToInt(info2[1]);
            }
        }
    }

    return 0;
}