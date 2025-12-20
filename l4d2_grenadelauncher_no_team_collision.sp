//  Linux ((_BYTE *)this + 6784) 
//  Windows((_BYTE *)this + 6792) 
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_NAME			"l4d2_genade_launcher_no_collision"
#define PLUGIN_VERSION 		"1.3"

MemoryPatch g_patchCollideWithTeammatesThink;
bool g_bEnable;
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
	g_patchCollideWithTeammatesThink = gd.CreatePatchOrFail("CGrenadeLauncher_Projectile::CollideWithTeammatesThink", true);
	
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
	if (g_bEnable != convar.BoolValue)
	{
		g_bEnable = convar.BoolValue;

		if (g_bEnable)
			g_patchCollideWithTeammatesThink.Enable();
		else
			g_patchCollideWithTeammatesThink.Disable();
	}
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
	hTemp.WriteLine("		\"MemPatches\"");
	hTemp.WriteLine("		{");
	hTemp.WriteLine("			\"CGrenadeLauncher_Projectile::CollideWithTeammatesThink\"");
	hTemp.WriteLine("			{");
	hTemp.WriteLine("				\"signature\"		\"CGrenadeLauncher_Projectile::CollideWithTeammatesThink\"");
	hTemp.WriteLine("				\"linux\"");
	hTemp.WriteLine("				{");
	hTemp.WriteLine("					\"offset\"	\"6h\"");
	hTemp.WriteLine("					\"verify\"	\"\\xC6\\x80\\x80\\x1A\\x00\\x00\\x01\"");
	hTemp.WriteLine("					\"patch\"	\"\\xC6\\x80\\x80\\x1A\\x00\\x00\\x00\"");
	hTemp.WriteLine("				}");
	hTemp.WriteLine("				\"windows\"");
	hTemp.WriteLine("				{");
	hTemp.WriteLine("					\"offset\"	\"0h\"");
	hTemp.WriteLine("					\"verify\"	\"\\xC6\\x81\\x88\\x1A\\x00\\x00\\x01\"");
	hTemp.WriteLine("					\"patch\"	\"\\xC6\\x81\\x88\\x1A\\x00\\x00\\x00\"");
	hTemp.WriteLine("				}");
	hTemp.WriteLine("			}");
	hTemp.WriteLine("		}");
	hTemp.WriteLine("		\"Signatures\"");
	hTemp.WriteLine("		{");
	hTemp.WriteLine("			\"CGrenadeLauncher_Projectile::CollideWithTeammatesThink\"");
	hTemp.WriteLine("			{");
	hTemp.WriteLine("				\"library\"		\"server\"");
	hTemp.WriteLine("				\"linux\"		\"@_ZN27CGrenadeLauncher_Projectile25CollideWithTeammatesThinkEv\"");
	hTemp.WriteLine("				\"windows\"		\"\\xC6\\x81\\x88\\x1A\\x00\\x00\\x01\"");
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
