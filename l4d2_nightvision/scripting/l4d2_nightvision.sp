#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>

#define PLUGIN_NAME				"[L4D2] Nightvision"
#define PLUGIN_AUTHOR			"Pan Xiaohai, Mr. Zero, blueblur, qy087"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"2.0.0"
#define PLUGIN_URL				"https://github.com/blueblur0730/modified-plugins"

#define UseTeam2    			(1 << 0)
#define UseTeam3    			(1 << 1)
#define UseTeamBoth 			(UseTeam2 | UseTeam3)
#define IMPULS_FLASHLIGHT 		100
#define CONFIG_FILE 			"configs/nightvision.cfg"

#define NV_TYPE_DEFAULT    		1
#define NV_TYPE_SPOTLIGHT  		2
#define NV_TYPE_FILTER     		3

ConVar 
	g_hCvar_NightVisionToWhom,
	g_hCvar_NightVisionTypeDefault,
	g_hCvar_IntensityDelta;

int 
	g_iNightVisionToWhom;

enum struct Player
{
	float m_fPressTime;
	float m_fFilterIntensity;

	int m_iNightVisionType;
	int m_iLastUsedNightVision;
	int m_iBrightness;
	int m_iLightEntRef;
	int m_iSelectedFilter;
	int m_iFilterEntRef;

	bool m_bNightVisionEnabled;

	void Reset(){
		this.m_fPressTime = 0.0;
		this.m_fFilterIntensity = 0.0;
		this.m_iNightVisionType = 0;
		this.m_iLastUsedNightVision = 0;
		this.m_iBrightness = 0;
		this.m_iLightEntRef = INVALID_ENT_REFERENCE;
		this.m_iFilterEntRef = INVALID_ENT_REFERENCE;
		this.m_bNightVisionEnabled = false;
	}
}

Player 
	g_ePlayer[MAXPLAYERS+1];
	
enum struct FilterTemplate
{
	int  m_iId;
	char m_sDisplayName[128];
	char m_sRaw_file[PLATFORM_MAX_PATH];
}

ArrayList 
	g_aFilterTemplates;

Cookie 
	g_hNightVisionCookie;


public Plugin myinfo = {
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version 	= PLUGIN_VERSION,
	url 		= PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslation("l4d2_nightvision.phrases");
	
	g_aFilterTemplates = new ArrayList(sizeof(FilterTemplate));
	
	CreateConVar("l4d2_nightvision_version", PLUGIN_VERSION, "Version of Nightvision plugin", FCVAR_NOTIFY | FCVAR_REPLICATED);
	g_hCvar_NightVisionToWhom = CreateConVar("l4d2_nightvision_to_whom", "3", "0=off, 1=only survivor, 2=only infecteds, 3=both. Only when below is set to 1.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	g_hCvar_NightVisionTypeDefault = CreateConVar("l4d2_nightvision_type_default", "1", "Default nightvision type: 1=yellow, 2=spotlight, 3=filter", FCVAR_NOTIFY, true, 1.0, true, 3.0);
	g_hCvar_IntensityDelta = CreateConVar("l4d2_nightvision_intensity_delta", "0.05", "Delta value for intensity adjustment in filter mode", FCVAR_NOTIFY, true, 0.1, true, 1.0);
    
	GetConVar();
	g_hCvar_NightVisionToWhom.AddChangeHook(ConVarChange);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_team", Event_PlayerTeam);
	RegConsoleCmd("sm_nightvisionmenu", Command_NightVisionMenu, "Open nightvision settings menu");
	RegConsoleCmd("sm_nvmenu", Command_NightVisionMenu, "Open nightvision settings menu");
	RegConsoleCmd("sm_nvs", Command_NightVisionMenu, "Open nightvision settings menu");
	RegConsoleCmd("sm_nightvision", Command_ToggleNightVision, "Toggle nightvision");
	RegConsoleCmd("sm_nv", Command_ToggleNightVision, "Toggle nightvision");
	RegConsoleCmd("sm_nvbright", Command_BrightnessMenu, "Open brightness menu");

	g_hNightVisionCookie = new Cookie("qy_nv_settings", "All nightvision settings in one", CookieAccess_Protected);
	vParseFilterConfig();
	HookUserMessage(GetUserMessageId("Fade"), IsFadeMsg, true);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;

		OnClientCookiesCached(iClient);
	}
}

public void OnPluginEnd()
{
	delete g_hNightVisionCookie;
}

Action IsFadeMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) 
{
	int client = players[0];
	if (!(1 <= client <= MaxClients)) return Plugin_Continue;
	
	if (!g_ePlayer[client].m_bNightVisionEnabled) return Plugin_Continue;
	if (g_ePlayer[client].m_iNightVisionType != NV_TYPE_FILTER) return Plugin_Continue;
	return Plugin_Handled;
}

void ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetConVar();
}

void GetConVar()
{
	g_iNightVisionToWhom = g_hCvar_NightVisionToWhom.IntValue;
}

public void OnConfigsExecuted()
{
	GetConVar();
	vParseFilterConfig();
}

public void OnClientDisconnect(int client)
{
	vResetSpriteNormal(client);
	vRemoveFilterEntity(client);
	g_ePlayer[client].m_bNightVisionEnabled = false;
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;
    
	char sBuffer[96];
	g_hNightVisionCookie.Get(client, sBuffer, sizeof(sBuffer));

	if (sBuffer[0] != '\0')
	{
		char sParts[5][16];
		int iCount = ExplodeString(sBuffer, ";", sParts, sizeof(sParts), sizeof(sParts[]));

		if (iCount >= 1)
			g_ePlayer[client].m_iNightVisionType = StringToInt(sParts[0]);
        
		if (iCount >= 2)
			g_ePlayer[client].m_iSelectedFilter = StringToInt(sParts[1]);
        
		if (iCount >= 3)
			g_ePlayer[client].m_iLastUsedNightVision = StringToInt(sParts[2]);
		
		if (iCount >= 4)
			g_ePlayer[client].m_fFilterIntensity = StringToFloat(sParts[3]);
		
		if (iCount >= 5)
			g_ePlayer[client].m_iBrightness = StringToInt(sParts[4]);
        
		if (g_ePlayer[client].m_iNightVisionType < 1 || g_ePlayer[client].m_iNightVisionType > 3)
			g_ePlayer[client].m_iNightVisionType = g_hCvar_NightVisionTypeDefault.IntValue;
        
		if (g_ePlayer[client].m_iLastUsedNightVision < 1 || g_ePlayer[client].m_iLastUsedNightVision > 3)
			g_ePlayer[client].m_iLastUsedNightVision = g_ePlayer[client].m_iNightVisionType;

		if (g_ePlayer[client].m_iBrightness < -3)
			g_ePlayer[client].m_iBrightness = -3;
		else if (g_ePlayer[client].m_iBrightness > 3)
			g_ePlayer[client].m_iBrightness = 3;
	}
	else
	{
		g_ePlayer[client].m_iNightVisionType = g_hCvar_NightVisionTypeDefault.IntValue;
		g_ePlayer[client].m_iSelectedFilter = 0;
		g_ePlayer[client].m_iLastUsedNightVision = g_hCvar_NightVisionTypeDefault.IntValue;
		g_ePlayer[client].m_iBrightness = 0;
	}
	g_ePlayer[client].m_iFilterEntRef = INVALID_ENT_REFERENCE;
	g_ePlayer[client].m_iLightEntRef = INVALID_ENT_REFERENCE;
}

void vSaveAllSettings(int client)
{
	char sBuffer[96];
	Format(sBuffer, sizeof(sBuffer), "%d;%d;%d;%.2f;%d", g_ePlayer[client].m_iNightVisionType, g_ePlayer[client].m_iSelectedFilter, g_ePlayer[client].m_iLastUsedNightVision, g_ePlayer[client].m_fFilterIntensity, g_ePlayer[client].m_iBrightness);
	g_hNightVisionCookie.Set(client, sBuffer);
}

void vSaveLastUsedNightVision(int client)
{
	g_ePlayer[client].m_iLastUsedNightVision = g_ePlayer[client].m_iNightVisionType;
	vSaveAllSettings(client);
}

public void OnPlayerRunCmdPre(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (impulse == IMPULS_FLASHLIGHT)
	{
		if (((g_iNightVisionToWhom & UseTeam2) || (g_iNightVisionToWhom & UseTeamBoth)) && GetClientTeam(client) == 2)
		{
			float fTime = GetEngineTime();
			if (fTime - g_ePlayer[client].m_fPressTime < 0.3)
			{
				vSwitchNightVision(client);
			}
			else if (buttons & IN_SPEED)
			{
				vOpenNightVisionMenu(client);
			}
            
			g_ePlayer[client].m_fPressTime = fTime; 
		}
        
		if (((g_iNightVisionToWhom & UseTeam3) || (g_iNightVisionToWhom & UseTeamBoth)) && GetClientTeam(client) == 3)
		{
			vSwitchNightVision(client);
		}
	}
}

Action Command_NightVisionMenu(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
    
	vOpenNightVisionMenu(client);
	return Plugin_Handled;
}

Action Command_ToggleNightVision(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
    
	vSwitchNightVision(client);
	return Plugin_Handled;
}

Action Command_BrightnessMenu(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (g_ePlayer[client].m_iNightVisionType != NV_TYPE_SPOTLIGHT || !g_ePlayer[client].m_bNightVisionEnabled)
	{
		PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_BrightnessMenuFail", client);
		return Plugin_Handled;
	}
	
	vOpenBrightnessMenu(client);
	return Plugin_Handled;
}

void vGetTypeNameTranslated(int client, int iType, char[] sBuffer, int iMaxLen)
{
	switch (iType)
	{
		case NV_TYPE_DEFAULT: Format(sBuffer, iMaxLen, "%T", "NV_TypeNameYellow", client);
		case NV_TYPE_SPOTLIGHT: Format(sBuffer, iMaxLen, "%T", "NV_TypeNameSpotlight", client);
		case NV_TYPE_FILTER: Format(sBuffer, iMaxLen, "%T", "NV_TypeNameFilter", client);
		default: Format(sBuffer, iMaxLen, "%T", "NV_TypeNameUnknown", client);
	}
}

void vAdjustBrightness(int client, int iDelta)
{
	g_ePlayer[client].m_iBrightness += iDelta;
	int iNewBright = g_ePlayer[client].m_iBrightness;
	
	if (iNewBright < -3)
	{
		g_ePlayer[client].m_iBrightness = -3;
		PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_BrightnessMinReached", client);
	}
	else if (iNewBright > 3)
	{
		g_ePlayer[client].m_iBrightness = 3;
		PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_BrightnessMaxReached", client);
	}
	else
	{
		if (g_ePlayer[client].m_bNightVisionEnabled && g_ePlayer[client].m_iNightVisionType == NV_TYPE_SPOTLIGHT)
		{
			vResetSpriteNormal(client);
			vCreateLight(client);
			PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, (iDelta > 0) ? "NV_BrightnessIncreased" : "NV_BrightnessDecreased", client, g_ePlayer[client].m_iBrightness + 4);
		}
	}
	vSaveAllSettings(client);
}

void vOpenNightVisionMenu(int client)
{
	Menu menu = new Menu(NightVisionMenuHandler);

	char sTypeName[32];
	vGetTypeNameTranslated(client, g_ePlayer[client].m_iNightVisionType, sTypeName, sizeof(sTypeName));
	
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "%T", "NV_MenuTitle", client, sTypeName);
	menu.SetTitle(sTitle);
	
	char sItem[128];
	Format(sItem, sizeof(sItem), "%T", "NV_TypeYellow", client);
	menu.AddItem("type_yellow", sItem);
	Format(sItem, sizeof(sItem), "%T", "NV_TypeSpotlight", client);
	menu.AddItem("type_spotlight", sItem);
	Format(sItem, sizeof(sItem), "%T", "NV_TypeFilter", client);
	menu.AddItem("type_filter", sItem);
	
	if (g_ePlayer[client].m_iNightVisionType == NV_TYPE_SPOTLIGHT)
	{
		Format(sItem, sizeof(sItem), "%T", "NV_BrightnessDisplay", client, g_ePlayer[client].m_iBrightness + 4, g_ePlayer[client].m_iBrightness + 4);
		menu.AddItem("brightness_display", sItem, ITEMDRAW_DISABLED);
		Format(sItem, sizeof(sItem), "%T", "NV_DecreaseBrightness", client);
		menu.AddItem("brightness_decrease", sItem);
		Format(sItem, sizeof(sItem), "%T", "NV_IncreaseBrightness", client);
		menu.AddItem("brightness_increase", sItem);
	}
	else if (g_ePlayer[client].m_iNightVisionType == NV_TYPE_FILTER && g_aFilterTemplates.Length > 0)
	{
		if (g_ePlayer[client].m_iSelectedFilter < g_aFilterTemplates.Length)
		{
			FilterTemplate eTemplate;
			g_aFilterTemplates.GetArray(g_ePlayer[client].m_iSelectedFilter, eTemplate);
			Format(sItem, sizeof(sItem), "%T", "NV_FilterCurrent", client, eTemplate.m_sDisplayName);
		}
		else
		{
			char sNone[32];
			Format(sNone, sizeof(sNone), "%T", "NV_None", client);
			Format(sItem, sizeof(sItem), "%T", "NV_FilterCurrent", client, sNone);
		}
		menu.AddItem("filter_select", sItem);

		Format(sItem, sizeof(sItem), "%T", "NV_FilterIntensity", client, g_ePlayer[client].m_fFilterIntensity);
		menu.AddItem("intensity", sItem, ITEMDRAW_DISABLED);
		Format(sItem, sizeof(sItem), "%T", "NV_IncreaseIntensity", client);
		menu.AddItem("intensity_increase", sItem);
		Format(sItem, sizeof(sItem), "%T", "NV_DecreaseIntensity", client);
		menu.AddItem("intensity_decrease", sItem);
	}
    
	Format(sItem, sizeof(sItem), "%T", g_ePlayer[client].m_bNightVisionEnabled ? "NV_ToggleOff" : "NV_ToggleOn", client);
	menu.AddItem("toggle", sItem);
	Format(sItem, sizeof(sItem), "%T", "NV_QuickToggle", client);
	menu.AddItem("quick_toggle", sItem);
	menu.ExitButton = true;
    
	menu.Display(client, 20);
}

void vOpenBrightnessMenu(int client)
{
	Menu menu = new Menu(BrightnessMenuHandler);
    
	char sTitle[128];
	Format(sTitle, sizeof(sTitle), "%T", "NV_BrightnessMenuTitle", client, g_ePlayer[client].m_iBrightness + 4);
	menu.SetTitle(sTitle);
	
	char sItem[128];
	if (g_ePlayer[client].m_iBrightness == -3)
	{
		Format(sItem, sizeof(sItem), "%T", "NV_BrightnessMinOption", client);
	}
	else
	{
		Format(sItem, sizeof(sItem), "%T", "NV_BrightnessDecreaseOption", client);
	}
	menu.AddItem("decrease", sItem);
	
	if (g_ePlayer[client].m_iBrightness == 3)
	{
		Format(sItem, sizeof(sItem), "%T", "NV_BrightnessMaxOption", client);
	}
	else
	{
		Format(sItem, sizeof(sItem), "%T", "NV_BrightnessIncreaseOption", client);
	}
	menu.AddItem("increase", sItem);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

int BrightnessMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "decrease"))
			{
				vAdjustBrightness(client, -1);
				vOpenBrightnessMenu(client);
			}
			else if (StrEqual(sInfo, "increase"))
			{
				vAdjustBrightness(client, 1);
				vOpenBrightnessMenu(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				vOpenNightVisionMenu(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void vChangeNightVisionType(int client, int iNewType)
{
	if (g_ePlayer[client].m_iNightVisionType == iNewType)
		return;

	bool bEnabled = g_ePlayer[client].m_bNightVisionEnabled;

	if (bEnabled)
		vCloseCurrentNightVision(client);
	g_ePlayer[client].m_iNightVisionType = iNewType;
	vSaveAllSettings(client);

	char sTypeName[32];
	vGetTypeNameTranslated(client, iNewType, sTypeName, sizeof(sTypeName));
	PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_TypeSwitched", client, sTypeName);

	if (bEnabled)
	{
		g_ePlayer[client].m_bNightVisionEnabled = true;
		vSwitchNightVision(client);
	}
}

int NightVisionMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
            
			if (StrEqual(sInfo, "type_yellow"))
			{
				vChangeNightVisionType(client, NV_TYPE_DEFAULT);
				vOpenNightVisionMenu(client);
			}
			else if (StrEqual(sInfo, "type_spotlight"))
			{
				vChangeNightVisionType(client, NV_TYPE_SPOTLIGHT);
				vOpenNightVisionMenu(client);
			}
			else if (StrEqual(sInfo, "type_filter"))
			{
				vChangeNightVisionType(client, NV_TYPE_FILTER);

				if (g_ePlayer[client].m_iSelectedFilter == 0 && g_aFilterTemplates.Length > 0)
				{
					OpenFilterMenu(client);
					delete menu;
					return 0;
				}
				vOpenNightVisionMenu(client);
			}
			else if (StrEqual(sInfo, "filter_select"))
			{
				OpenFilterMenu(client);
				delete menu;
				return 0;
			}
			else if (StrEqual(sInfo, "intensity_increase"))
			{
				float fNewIntensity = g_ePlayer[client].m_fFilterIntensity + g_hCvar_IntensityDelta.FloatValue;
				if (fNewIntensity > 2.0) fNewIntensity = 2.0;
				g_ePlayer[client].m_fFilterIntensity = fNewIntensity;
				vSaveAllSettings(client);

				if (g_ePlayer[client].m_bNightVisionEnabled && g_ePlayer[client].m_iNightVisionType == NV_TYPE_FILTER)
				{
					vUpdateFilterIntensity(client);
				}

				vOpenNightVisionMenu(client);
				return 0;
			}
			else if (StrEqual(sInfo, "intensity_decrease"))
			{
				float fNewIntensity = g_ePlayer[client].m_fFilterIntensity - g_hCvar_IntensityDelta.FloatValue;
				if (fNewIntensity < 0.1) fNewIntensity = 0.1;
				g_ePlayer[client].m_fFilterIntensity = fNewIntensity;
				vSaveAllSettings(client);

				if (g_ePlayer[client].m_bNightVisionEnabled && g_ePlayer[client].m_iNightVisionType == NV_TYPE_FILTER)
				{
					vUpdateFilterIntensity(client);
				}

				vOpenNightVisionMenu(client);
				return 0;
			}
			else if (StrEqual(sInfo, "brightness_increase"))
			{
				vAdjustBrightness(client, 1);
				vOpenNightVisionMenu(client);
				return 0;
			}
			else if (StrEqual(sInfo, "brightness_decrease"))
			{
				vAdjustBrightness(client, -1);
				vOpenNightVisionMenu(client);
				return 0;
			}
			else if (StrEqual(sInfo, "toggle"))
			{
				vSwitchNightVision(client);
				vOpenNightVisionMenu(client);
			}
			else if (StrEqual(sInfo, "quick_toggle"))
			{
				if (g_ePlayer[client].m_iLastUsedNightVision > 0 && g_ePlayer[client].m_iLastUsedNightVision != g_ePlayer[client].m_iNightVisionType)
				{
					int iOldType = g_ePlayer[client].m_iNightVisionType;
					vChangeNightVisionType(client, g_ePlayer[client].m_iLastUsedNightVision);
                    
					char sOldName[32], sNewName[32];
					vGetTypeNameTranslated(client, iOldType, sOldName, sizeof(sOldName));
					vGetTypeNameTranslated(client, g_ePlayer[client].m_iNightVisionType, sNewName, sizeof(sNewName));
                    
					PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_SwitchedFromTo", client, sOldName, sNewName);
				}
				else
				{
					PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_LastUsedSame", client);
				}
				vOpenNightVisionMenu(client);
			}
		}
		case MenuAction_End:
		{
			if (client != MenuEnd_Selected)
				delete menu;
		}
	}
	return 0;
}

void vCloseCurrentNightVision(int client)
{
	g_ePlayer[client].m_bNightVisionEnabled = false;
	switch (g_ePlayer[client].m_iNightVisionType)
	{
		case NV_TYPE_DEFAULT:
		{
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
		}
		case NV_TYPE_SPOTLIGHT:
		{
			vResetSpriteNormal(client);
			g_ePlayer[client].m_iLightEntRef = INVALID_ENT_REFERENCE;
		}
		case NV_TYPE_FILTER:
		{
			vRemoveFilterEntity(client);
		}
	}
}

void vUpdateFilterIntensity(int client)
{
	int iEntity = EntRefToEntIndex(g_ePlayer[client].m_iFilterEntRef);
	if (iEntity != -1 && IsValidEntity(iEntity))
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flCurWeight", g_ePlayer[client].m_fFilterIntensity);
		SetEdictFlags(iEntity, GetEdictFlags(iEntity) & ~FL_EDICT_ALWAYS);
	}
}

void OpenFilterMenu(int client)
{
	if (g_aFilterTemplates.Length == 0)
	{
		PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_NoFilters", client);
		return;
	}

	Menu menu = new Menu(FilterMenuHandler);
	
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "%T", "NV_FilterMenuTitle", client);
	menu.SetTitle(sTitle);

	FilterTemplate eTemplate;
	char sItem[64], sDisplay[128];

	for (int i = 0; i < g_aFilterTemplates.Length; i++)
	{
		g_aFilterTemplates.GetArray(i, eTemplate);
		IntToString(eTemplate.m_iId, sItem, sizeof(sItem));
		Format(sDisplay, sizeof(sDisplay), "%s %s", eTemplate.m_sDisplayName, g_ePlayer[client].m_iSelectedFilter == eTemplate.m_iId ? "✓" : "");
		menu.AddItem(sItem, sDisplay);
	}
    
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

int FilterMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
            
			int iFilterId = StringToInt(sInfo);

			int iFilterIndex = -1;
			FilterTemplate eTemplate;
			for (int i = 0; i < g_aFilterTemplates.Length; i++)
			{
				g_aFilterTemplates.GetArray(i, eTemplate);
				if (eTemplate.m_iId == iFilterId)
				{
					iFilterIndex = i;
					break;
				}
			}
			if (iFilterIndex != -1)
			{
				g_ePlayer[client].m_iSelectedFilter = iFilterId;

				vSaveAllSettings(client);

				g_aFilterTemplates.GetArray(iFilterIndex, eTemplate);
				PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_FilterSelected", client, eTemplate.m_sDisplayName);

				if (g_ePlayer[client].m_bNightVisionEnabled && g_ePlayer[client].m_iNightVisionType == NV_TYPE_FILTER)
				{
					vRemoveFilterEntity(client);
					vApplyFilterEffect(client);
				}
			}
			OpenFilterMenu(client);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				vOpenNightVisionMenu(client);
			}
		}
		case MenuAction_End:
		{
			if (client != MenuEnd_Selected)
				delete menu;
		}
	}
	return 0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		vResetSpriteNormal(i);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
    
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) 
		return;
    
	int iTeam = event.GetInt("team");
    
	switch (g_iNightVisionToWhom)
	{
		case 1:
		{
			if (iTeam == 1 || iTeam == 2)
				return;
		}
		case 2:
		{
			if (iTeam == 3)
			return;
		}
		case 3: {}
	}
    
	vResetSpriteNormal(client);
	vRemoveFilterEntity(client);
	g_ePlayer[client].m_bNightVisionEnabled = false;
}

void vSwitchNightVision(int client)
{
	if (!IsValidClient(client))
		return;
    
	g_ePlayer[client].m_bNightVisionEnabled = !g_ePlayer[client].m_bNightVisionEnabled;

	if (g_ePlayer[client].m_bNightVisionEnabled)
	{
		vSaveLastUsedNightVision(client);

		if (g_ePlayer[client].m_iNightVisionType == NV_TYPE_SPOTLIGHT)
		{
			CreateTimer(0.1, Timer_vOpenBrightnessMenu, GetClientUserId(client));
		}
	}

	switch (g_ePlayer[client].m_iNightVisionType)
	{
		case NV_TYPE_DEFAULT:
			vClassicNightVision(client);

		case NV_TYPE_SPOTLIGHT:
			vSpotlightNightVision(client);
        
		case NV_TYPE_FILTER:
			vFilterNightVision(client);
        
		default:
			vClassicNightVision(client);
	}
}

Action Timer_vOpenBrightnessMenu(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && g_ePlayer[client].m_bNightVisionEnabled && 
		g_ePlayer[client].m_iNightVisionType == NV_TYPE_SPOTLIGHT)
	{
		vOpenBrightnessMenu(client);
	}
	return Plugin_Stop;
}

void vClassicNightVision(int client)
{
	SetEntProp(client, Prop_Send, "m_bNightVisionOn", g_ePlayer[client].m_bNightVisionEnabled ? 1 : 0); 
	PrintHintText(client, "%T", g_ePlayer[client].m_bNightVisionEnabled ? "NightVisionOn" : "NightVisionOff", client);
}

void vSpotlightNightVision(int client)
{
	if (g_ePlayer[client].m_bNightVisionEnabled)
	{
		if (g_ePlayer[client].m_iLightEntRef == INVALID_ENT_REFERENCE)
		{
			vCreateLight(client);
		}
		PrintHintText(client, "%T", "NightVisionOn", client);
	}
	else
	{
		vResetSpriteNormal(client);
		PrintHintText(client, "%T", "NightVisionOff", client);
		g_ePlayer[client].m_iLightEntRef = INVALID_ENT_REFERENCE;
	}
}

void vFilterNightVision(int client)
{
	if (g_ePlayer[client].m_bNightVisionEnabled)
	{
		if (g_ePlayer[client].m_iSelectedFilter < 0 && g_aFilterTemplates.Length > 0)
		{
			PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_FilterSelectFirst", client);
			g_ePlayer[client].m_bNightVisionEnabled = false;
			return;
		}
        
		vApplyFilterEffect(client);
		PrintHintText(client, "%T", "NightVisionOn", client);
	}
	else
	{
		vRemoveFilterEntity(client);
		PrintHintText(client, "%T", "NightVisionOff", client);
	}
}

void vCreateLight(int client)
{
	int iLight = CreateEntityByName("light_dynamic");
	if (IsValidEntity(iLight))
	{
		g_ePlayer[client].m_iLightEntRef = EntIndexToEntRef(iLight);

		DispatchKeyValue(iLight, "_light", "255 255 255 255");

		char sItem[4];
		Format(sItem, sizeof(sItem), "%d", g_ePlayer[client].m_iBrightness + 4);
		DispatchKeyValue(iLight, "brightness", sItem);

		DispatchKeyValueFloat(iLight, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(iLight, "distance", 750.0);
		DispatchKeyValue(iLight, "style", "0");
		DispatchSpawn(iLight);
		AcceptEntityInput(iLight, "TurnOn");
		SetVariantString("!activator");
		AcceptEntityInput(iLight, "SetParent", client);
		TeleportEntity(iLight, view_as<float>({0.0, 0.0, 20.0}), view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR);
		SDKHook(iLight, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

Action Hook_SetTransmit(int entity, int client)
{
	int iRef = EntIndexToEntRef(entity);

	if (g_ePlayer[client].m_iLightEntRef == iRef)
		return Plugin_Continue;

	return Plugin_Handled;
}

void vResetSpriteNormal(int client)
{
	if (g_ePlayer[client].m_iLightEntRef == INVALID_ENT_REFERENCE) return;
	int iEntity = EntRefToEntIndex(g_ePlayer[client].m_iLightEntRef);
	if (iEntity <= MaxClients || !IsValidEntity(iEntity)) return;
	RemoveEdict(iEntity);
}

void vParseFilterConfig()
{
	delete g_aFilterTemplates;
	g_aFilterTemplates = new ArrayList(sizeof(FilterTemplate));
    
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_FILE);
    
	if (!FileExists(sPath))
	{
		vCreateDefaultFilterConfig(sPath);
		LogMessage("Created default config file: %s", sPath);
	}
    
	KeyValues hKv = new KeyValues("NightVision");
	if (!hKv.ImportFromFile(sPath))
	{
		LogError("Failed to import config file: %s", sPath);
		delete hKv;
		return;
	}
    
	if (!hKv.GotoFirstSubKey())
	{
		LogError("No filter templates found in config file: %s", sPath);
		delete hKv;
		return;
	}
    
	FilterTemplate eTemplate;
	char sSectionName[64];
    
	do
	{
		hKv.GetSectionName(sSectionName, sizeof(sSectionName));
        
		eTemplate.m_iId = hKv.GetNum("id", -1);
		if (eTemplate.m_iId == -1)
		{
			LogError("Invalid or missing id for \"%s\" section in nightvision.cfg, skipping...", sSectionName);
			continue;
		}
        
		hKv.GetString("display_name", eTemplate.m_sDisplayName, sizeof(FilterTemplate::m_sDisplayName));
		if (eTemplate.m_sDisplayName[0] == '\0')
		{
			LogError("Invalid or missing display_name for \"%s\" section in nightvision.cfg, skipping...", sSectionName);
			continue;
		}
        
		hKv.GetString("raw_file", eTemplate.m_sRaw_file, sizeof(FilterTemplate::m_sRaw_file));
		if (eTemplate.m_sRaw_file[0] == '\0')
		{
			LogError("Invalid or missing raw_file for \"%s\" section in nightvision.cfg, skipping...", sSectionName);
			continue;
		}
      
		g_aFilterTemplates.PushArray(eTemplate);
		LogMessage("Loaded filter template: %s (id: %d, file: %s)", eTemplate.m_sDisplayName, eTemplate.m_iId, eTemplate.m_sRaw_file);
        
	} while (hKv.GotoNextKey());

	delete hKv;

	if (g_aFilterTemplates.Length == 0)
	{
		LogError("No valid filter templates found in %s, creating default ones", sPath);
		vAddDefaultFilters();
	}
	else
	{
		LogMessage("Successfully loaded %d filter templates", g_aFilterTemplates.Length);
	}
}

void vCreateDefaultFilterConfig(const char[] sPath)
{
	KeyValues hKv = new KeyValues("NightVision");
    
	hKv.JumpToKey("nv1", true);
	hKv.SetNum("id", 1);
	hKv.SetString("display_name", "滤镜1");
	hKv.SetString("raw_file", "materials/gammacase/nightvision/nv1.raw");
	hKv.GoBack();
    
	hKv.JumpToKey("nv2", true);
	hKv.SetNum("id", 2);
	hKv.SetString("display_name", "滤镜2");
	hKv.SetString("raw_file", "materials/gammacase/nightvision/nv2.raw");
	hKv.GoBack();
    
	hKv.JumpToKey("nv3", true);
	hKv.SetNum("id", 3);
	hKv.SetString("display_name", "滤镜3");
	hKv.SetString("raw_file", "materials/gammacase/nightvision/nv3.raw");
	hKv.GoBack();
    
	hKv.JumpToKey("nv4", true);
	hKv.SetNum("id", 4);
	hKv.SetString("display_name", "滤镜4");
	hKv.SetString("raw_file", "materials/gammacase/nightvision/nv4.raw");
	hKv.GoBack();
    
	hKv.ExportToFile(sPath);
	delete hKv;
}

void vAddDefaultFilters()
{
	FilterTemplate eTemplate;

	eTemplate.m_iId = 1;
	strcopy(eTemplate.m_sDisplayName, sizeof(eTemplate.m_sDisplayName), "滤镜1");
	strcopy(eTemplate.m_sRaw_file, sizeof(eTemplate.m_sRaw_file), "materials/gammacase/nightvision/nv1.raw");
	g_aFilterTemplates.PushArray(eTemplate);
    
	eTemplate.m_iId = 2;
	strcopy(eTemplate.m_sDisplayName, sizeof(eTemplate.m_sDisplayName), "滤镜2");
	strcopy(eTemplate.m_sRaw_file, sizeof(eTemplate.m_sRaw_file), "materials/gammacase/nightvision/nv2.raw");
	g_aFilterTemplates.PushArray(eTemplate);

	eTemplate.m_iId = 3;
	strcopy(eTemplate.m_sDisplayName, sizeof(eTemplate.m_sDisplayName), "滤镜3");
	strcopy(eTemplate.m_sRaw_file, sizeof(eTemplate.m_sRaw_file), "materials/gammacase/nightvision/nv3.raw");
	g_aFilterTemplates.PushArray(eTemplate);

	eTemplate.m_iId = 4;
	strcopy(eTemplate.m_sDisplayName, sizeof(eTemplate.m_sDisplayName), "滤镜4");
	strcopy(eTemplate.m_sRaw_file, sizeof(eTemplate.m_sRaw_file), "materials/gammacase/nightvision/nv4.raw");
	g_aFilterTemplates.PushArray(eTemplate);
}

void vApplyFilterEffect(int client)
{
	FilterTemplate eTemplate;
	int iTemplateIndex = -1;
    
	for (int i = 0; i < g_aFilterTemplates.Length; i++)
	{
		g_aFilterTemplates.GetArray(i, eTemplate);
		if (eTemplate.m_iId == g_ePlayer[client].m_iSelectedFilter)
		{
			iTemplateIndex = i;
			break;
		}
	}
	
	if (iTemplateIndex == -1)
	{
		PrintToChat(client, "[\x04%T\x01] %T", "NV_Prefix", client, "NV_FilterNotFound", client);
		return;
	}
    
	g_aFilterTemplates.GetArray(iTemplateIndex, eTemplate);
	
	int iEntity = CreateEntityByName("color_correction");
	if (iEntity != -1)
	{
		DispatchKeyValue(iEntity, "StartDisabled", "0");
		DispatchKeyValue(iEntity, "maxweight", "1.0");
		DispatchKeyValue(iEntity, "maxfalloff", "-1.0");
		DispatchKeyValue(iEntity, "minfalloff", "0.0");
		DispatchKeyValue(iEntity, "filename", eTemplate.m_sRaw_file);

		DispatchSpawn(iEntity);
		ActivateEntity(iEntity);

		SetEntPropFloat(iEntity, Prop_Send, "m_flCurWeight", g_ePlayer[client].m_fFilterIntensity);
		SetEdictFlags(iEntity, GetEdictFlags(iEntity) & ~FL_EDICT_ALWAYS);
		SDKHook(iEntity, SDKHook_SetTransmit, Filter_SetTransmit);

		g_ePlayer[client].m_iFilterEntRef = EntIndexToEntRef(iEntity);

		TeleportEntity(iEntity, view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		LogError("Failed to create color_correction entity for player %N", client);
	}
}

Action Filter_SetTransmit(int entity, int client)
{
	SetEdictFlags(entity, GetEdictFlags(entity) & ~FL_EDICT_ALWAYS);
	if (EntRefToEntIndex(g_ePlayer[client].m_iFilterEntRef) != entity)
		return Plugin_Handled;
	else
	{
		SetEdictFlags(entity, GetEdictFlags(entity) | FL_EDICT_DONTSEND);
		SetEntPropFloat(entity, Prop_Send, "m_flCurWeight", g_ePlayer[client].m_fFilterIntensity);
		return Plugin_Continue;
	}
}

void vRemoveFilterEntity(int client)
{
	if (g_ePlayer[client].m_iFilterEntRef == INVALID_ENT_REFERENCE) return;
	int iEntity = EntRefToEntIndex(g_ePlayer[client].m_iFilterEntRef);
	if (iEntity <= MaxClients || !IsValidEntity(iEntity)) return;
	if (iEntity != INVALID_ENT_REFERENCE && IsValidEntity(iEntity))
	{
		RemoveEntity(iEntity);
		g_ePlayer[client].m_iFilterEntRef = INVALID_ENT_REFERENCE;
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock void LoadTranslation(const char[] translation)
{
	char sPath[PLATFORM_MAX_PATH], sName[PLATFORM_MAX_PATH];
	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);
	LoadTranslations(translation);
}