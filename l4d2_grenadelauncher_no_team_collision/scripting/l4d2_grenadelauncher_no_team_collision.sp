//  Linux ((_BYTE *)this + 6784) 
//  Windows((_BYTE *)this + 6792) 
#pragma semicolon 1
#pragma newdecls required

#include <sdktools>

#define PLUGIN_NAME    "l4d2_genade_launcher_no_team_collision"
#define PLUGIN_VERSION "1.4"

bool      g_bEnable;
ArrayList g_aProjectiles;

public Plugin myinfo =
{
    name        = "[L4D2] Genade Launcher No Team Collision",
    author      = "qy087, blueblur, 洛琪",
    description = "Pass your grenade launcher projectile through teammates.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/qy087/l4d2-littleplugins/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_aProjectiles = new ArrayList();
    CreateConVar(PLUGIN_NAME... "_version", PLUGIN_VERSION, "Version", FCVAR_DONTRECORD | FCVAR_NOTIFY);
    ConVar cvEnable = CreateConVar(PLUGIN_NAME... "_enable", "1", "Enable/Disable", FCVAR_NONE, true, 0.0, true, 1.0);
    g_bEnable       = cvEnable.BoolValue;
    cvEnable.AddChangeHook(OnEnableChanged);
    // AutoExecConfig(true, PLUGIN_NAME);
}

void OnEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_bEnable = convar.BoolValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (g_bEnable && strcmp(classname, "grenade_launcher_projectile") == 0)
    {
        RequestFrame(NF_DisableCollision, EntIndexToEntRef(entity));
    }
}

void NF_DisableCollision(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (IsValidEntity(entity))
    {
        g_aProjectiles.Push(EntIndexToEntRef(entity));
        SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
    }
}

// 最原始的暴力美学...dhook、内存补丁都不如这个...去他妈的用dhook修改v社碰撞系统，我掀桌子了
public void OnGameFrame()
{
    if (!IsServerProcessing() || g_aProjectiles.Length == 0) return;

    float deltaTime = GetTickInterval() * 3.0;
    for (int i = g_aProjectiles.Length - 1; i >= 0; i--)
    {
        int entity = EntRefToEntIndex(g_aProjectiles.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
        {
            g_aProjectiles.Erase(i);
            continue;
        }

        float speed[3], pos[3], endPos[3];
        GetEntPropVector(entity, Prop_Data, "m_vecVelocity", speed);
        GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

        endPos[0]     = pos[0] + speed[0] * deltaTime;
        endPos[1]     = pos[1] + speed[1] * deltaTime;
        endPos[2]     = pos[2] + speed[2] * deltaTime;

        float mins[3] = { -2.0, -2.0, -2.0 };
        float maxs[3] = { 2.0, 2.0, 2.0 };

        TR_TraceHullFilter(pos, endPos, mins, maxs, MASK_SHOT_HULL, TraceFilter, entity);

        if (TR_DidHit())
        {
            int other = TR_GetEntityIndex();
            if (other > 0 && !IsSameTeam(entity, other))
            {
                SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
                g_aProjectiles.Erase(i);
            }
        }
    }
}

bool TraceFilter(int entity, int contentsMask, any data)
{
    return entity != data;
}

bool IsSameTeam(int projectile, int target)
{
    int owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");
    if (owner <= 0 || owner > MaxClients || !IsClientInGame(owner)) return false;

    int client = (target > MaxClients) ? GetEntPropEnt(target, Prop_Send, "m_hOwnerEntity") : target;

    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(owner) == GetClientTeam(client);
}
