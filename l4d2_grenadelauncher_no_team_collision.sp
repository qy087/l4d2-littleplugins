
//Special Thanks: blueblur0730
//https://github.com/blueblur0730
	
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <collisionhook>

#define PLUGIN_NAME			"l4d2_genade_launcher_no_collision"
#define PLUGIN_VERSION 	"1.0"

ConVar 
	g_cvEnable;

bool 
	g_bEnable;

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
	author = "qy087, blueblur",
	description = "Pass your grenade launcher projectile through teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/blueblur0730/modified-plugins"
};

public void OnPluginStart()
{ 
	CreateConVar( PLUGIN_NAME ... "_version", PLUGIN_VERSION, "L4D2 Genade Launcher No Team Collision Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	g_cvEnable = CreateConVar( PLUGIN_NAME ... "_enable","1", "Enable/Disable the Genade Launcher Team Collision", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, PLUGIN_NAME);
	
	GetCvars();
	g_cvEnable.AddChangeHook(ConVarChanged_Cvars);
}

public void OnConfigsExecuted() 
{
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnable = g_cvEnable.BoolValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnable) return;
	if(strncmp(classname, "grenade_launcher_projectile", 27) == 0)
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
		SDKHook(entity, SDKHook_EndTouchPost, OnEndTouchPost);
	}
}

// @blueblur0730: 榴弹爆炸受touch控制. 榴弹的touch事件回调函数为CGrenadeLauncher_Projectile::ExplodeTouch.
Action OnTouch(int entity, int other)
{
	if (!IsValidClient(other))
        return Plugin_Continue;

	if (GetClientTeam(other) != 2)
		return Plugin_Continue;
    
	return Plugin_Handled; 
}

void OnEndTouchPost(int entity, int other)
{
    if (!IsValidClient(other))
        return;

    if (GetClientTeam(other) != 2)
        return;
        
    RequestFrame(NextFrame_OnEndTouchPost, entity);
}

void NextFrame_OnEndTouchPost(int entity)
{
    SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
}

// @qy087: CH_ShouldCollide测试多次无效只能用CH_PassFilter较消耗性能方式
// @blueblur0730: (to do) 能否寻求更好的监测碰撞前的hook? 这里使用collison hook实在是太小题大作了.
// @blueblur0730: 能否穿透生还者身上的物品? 
public Action CH_PassFilter(int entity1, int entity2, bool &result)
{
	if (!IsValidGLPJEntityIndex(entity1) || !g_bEnable) return Plugin_Continue;

	if(!IsValidClient(entity2)) return Plugin_Continue;
	
	if(GetClientTeam(entity2) == 3)
	{
		SetEntProp(entity1, Prop_Data, "m_CollisionGroup", 0);
		return Plugin_Continue;
	}
	
	SetEntProp(entity1, Prop_Data, "m_CollisionGroup", 1);
	//result = false; // @qy087: 此处更改无效只能通过改属性解决
	//return Plugin_Changed; // @qy087: 此处更改无效只能通过改属性解决
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}

bool IsValidGLPJEntityIndex(int entity)
{
	char classname[48];
	return IsValidEntityIndex(entity) && GetEdictClassname(entity, classname, sizeof(classname)) && strncmp(classname, "grenade_launcher_projectile", 27) == 0;
}
