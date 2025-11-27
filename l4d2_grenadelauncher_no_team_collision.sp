#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_NAME			"l4d2_genade_launcher_no_collision"
#define PLUGIN_VERSION 		"1.2"

bool 
	g_bEnable;
int g_iOff_m_bCollideWithTeammates = -1;

// https://github.com/Target5150/MoYu_Server_Stupid_Plugins/blob/master/include/%40Forgetest/gamedatawrapper.inc
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
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin " ... PLUGIN_NAME ... "only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2] Genade Launcher No Team Collision",
	author = "qy087, blueblur, 洛琪",
	description = "Pass your grenade launcher projectile through teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/qy087/l4d2-littleplugins/"
};
	// Thanks: @blueblur0730, @Mineralcr
	// https://github.com/blueblur0730  https://github.com/Mineralcr
	
public void OnPluginStart()
{ 
	vCreatGameData();
	
	GameDataWrapper gd = new GameDataWrapper(PLUGIN_NAME);
	g_iOff_m_bCollideWithTeammates = gd.GetOffset("CGrenadeLauncher_Projectile->m_bCollideWithTeammates");
	// g_hGLPJCollideWithTeammatesThink = gd.CreateDetourOrFail("CGrenadeLauncher_Projectile::CollideWithTeammatesThink", DTR_CGrenadeLauncher_Projectile_CollideWithTeammatesThink_Pre);
	delete gd;

	CreateConVar( PLUGIN_NAME ... "_version", PLUGIN_VERSION, "L4D2 Genade Launcher No Team Collision Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	CreateConVarHook(
		PLUGIN_NAME ... "_enable",
		"1",
		"Enable/Disable The Genade Launcher Team Collision",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		ConVarChanged_Cvars);
		
	AutoExecConfig(true, PLUGIN_NAME);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnable = convar.BoolValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnable) return;
	if(strncmp(classname, "grenade_launcher_projectile", 27) == 0)
		SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
}

void OnThinkPost(int entity)
{
	if (!g_bEnable || entity <= MaxClients || !IsValidEntity(entity)) return;
	//  Linux ((_BYTE *)this + 6784) 
	//  Windows((_BYTE *)this + 6792) 
	SetEntData(entity, g_iOff_m_bCollideWithTeammates, false, 1, true);
}

void vCreatGameData()
{
	char sFilePath[128];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", PLUGIN_NAME);
	if (FileExists(sFilePath)) return;

	File hTemp = OpenFile(sFilePath, "w");
	if (hTemp == null)
	{
		SetFailState("Plugin " ... PLUGIN_NAME ... "Something went wrong while creating the game data file!");
	}
	hTemp.WriteLine("\"Games\"");
	hTemp.WriteLine("{");
	hTemp.WriteLine("	\"left4dead2\"");
	hTemp.WriteLine("	{");
	hTemp.WriteLine("		\"Offsets\"");
	hTemp.WriteLine("		{");
	hTemp.WriteLine("			\"CGrenadeLauncher_Projectile->m_bCollideWithTeammates\"");
	hTemp.WriteLine("			{");
	hTemp.WriteLine("				\"windows\"		\"6792\"");
	hTemp.WriteLine("				\"linux\"		\"6784\"");
	hTemp.WriteLine("			}");
	hTemp.WriteLine("		}");
	hTemp.WriteLine("	}");
	hTemp.WriteLine("}");
	delete hTemp;
}

stock ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
