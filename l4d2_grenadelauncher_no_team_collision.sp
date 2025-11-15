#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
// #include <sdkhooks>
#include <dhooks>

#define PLUGIN_NAME			"l4d2_genade_launcher_no_collision"
#define PLUGIN_VERSION 	"1.2"

bool 
	// g_bLinuxOS,
	g_bEnable;

DynamicDetour g_hGLPJCollideWithTeammatesThink;
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
	// g_bLinuxOS = gd.GetOffset("OS") == 1;
	
	// delete gd.CreateDetourOrFail("CGrenadeLauncher_Projectile::ExplodeTouch", DTR_GrenadeLauncher_Projectile_ExplodeTouch_Pre);

	g_hGLPJCollideWithTeammatesThink = gd.CreateDetourOrFail("CGrenadeLauncher_Projectile::CollideWithTeammatesThink", DTR_CGrenadeLauncher_Projectile_CollideWithTeammatesThink_Pre);
	delete gd;
	CreateConVar( PLUGIN_NAME ... "_version", PLUGIN_VERSION, "L4D2 Genade Launcher No Team Collision Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);

	CreateConVarHook(
		PLUGIN_NAME ... "_enable",
		"1",
		"Enable/Disable The Genade Launcher Team Collision",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		ConVarChanged_Cvars);
		
	//AutoExecConfig(true, PLUGIN_NAME);
}

public void OnPluginEnd()
{
	DHookCallback preHook = INVALID_FUNCTION;
	g_hGLPJCollideWithTeammatesThink.Disable(Hook_Pre, preHook);
	delete g_hGLPJCollideWithTeammatesThink;
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnable = convar.BoolValue;
}

/*
public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnable) return;
	if(strncmp(classname, "grenade_launcher_projectile", 27) == 0)
		RequestFrame(NextFrame_GLPJ_Spawn, EntIndexToEntRef(entity));
}

void NextFrame_GLPJ_Spawn(int entity)
{
	entity = EntRefToEntIndex(entity);
	if (entity == INVALID_ENT_REFERENCE) return;
	
	
	//  Linux ((_BYTE *)this + 6784) 
	//  Windows((_BYTE *)this + 6792) 
	// SetEntData(entity, 6784 + (view_as<int>(!g_bLinuxOS) << 3), 1, 1, true);
	
}
*/

MRESReturn DTR_CGrenadeLauncher_Projectile_CollideWithTeammatesThink_Pre(int pThis, DHookReturn hReturn)
{
	if(g_bEnable)
	{
		hReturn.Value = pThis;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

void vCreatGameData()
{
	char sFilePath[128];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", PLUGIN_NAME);
	if (!FileExists(sFilePath))
	{
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
		hTemp.WriteLine("			\"OS\"");
		hTemp.WriteLine("			{");
		hTemp.WriteLine("				\"windows\"		\"0\"");
		hTemp.WriteLine("				\"linux\"		\"1\"");
		hTemp.WriteLine("			}");
		hTemp.WriteLine("		}");
		hTemp.WriteLine("		\"Functions\"");
		hTemp.WriteLine("		{");
		hTemp.WriteLine("			\"CGrenadeLauncher_Projectile::CollideWithTeammatesThink\"");
		hTemp.WriteLine("			{");
		hTemp.WriteLine("				\"signature\"		\"CGrenadeLauncher_Projectile::CollideWithTeammatesThink\"");
		hTemp.WriteLine("				\"callconv\"		\"thiscall\"");
		hTemp.WriteLine("				\"return\"			\"int\"");
		hTemp.WriteLine("				\"this\"			\"entity\"");
		hTemp.WriteLine("			}");
		hTemp.WriteLine("		}");
		hTemp.WriteLine("		\"Signatures\"");
		hTemp.WriteLine("		{");
		hTemp.WriteLine("			\"CGrenadeLauncher_Projectile::CollideWithTeammatesThink\"");
		hTemp.WriteLine("			{");
		hTemp.WriteLine("				\"library\"	\"server\"");
		hTemp.WriteLine("				\"linux\"	\"@_ZN27CGrenadeLauncher_Projectile25CollideWithTeammatesThinkEv\"");
		hTemp.WriteLine("				\"windows\"	\"\\xC6\\x81\\x88\\x1A\\x00\\x00\\x01\"");
		hTemp.WriteLine("				/* Thanks 洛琪 Find Windows Signature */");
		hTemp.WriteLine("			}");
		hTemp.WriteLine("		}");
		hTemp.WriteLine("	}");
		hTemp.WriteLine("}");
		delete hTemp;
	}
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
