#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME			"l4d_who_kill_boomer"
#define PLUGIN_VERSION 		"1.0"

bool 
	g_bEnable;
	
enum struct Player
{
	int m_iAttacker;
	int m_iBoomer;
	Handle m_hTimer;
	void Clear(){
		this.m_iAttacker = 0;
		this.m_iBoomer = 0;
		delete this.m_hTimer;
	}
}

Player 
	g_ePlayer[33];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2 && test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin " ... PLUGIN_NAME ... "only supports Left 4 Dead 1 & 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "L4D Who Kill the boomer",
	author = "qy087",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://github.com/qy087/l4d2-littleplugins"
};

public void OnPluginStart()
{ 
	CreateConVar( PLUGIN_NAME ... "_version", PLUGIN_VERSION, "Who Kill Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	CreateConVarHook(
		PLUGIN_NAME ... "_enable",
		"1",
		"Enable/Disable.",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		ConVarChanged_Cvars);
	
	//AutoExecConfig(true, PLUGIN_NAME);
	
}

public void OnClientDisconnect(int client)
{
	g_ePlayer[client].Clear();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bEnable && convar.BoolValue) {
		g_bEnable = true;
		HookEvent("player_death", Event_Player_Death);
		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("round_end",	  Event_RoundEnd, EventHookMode_PostNoCopy); 
		HookEvent("map_transition", Event_RoundEnd,	EventHookMode_PostNoCopy);
		HookEvent("mission_lost", 	Event_RoundEnd,		EventHookMode_PostNoCopy);
	}
	else if (g_bEnable && !convar.BoolValue) 
	{
		g_bEnable = false;
		UnhookEvent("player_death", Event_Player_Death);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("round_end",	Event_RoundEnd, EventHookMode_PostNoCopy); 
		UnhookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("mission_lost", Event_RoundEnd,		EventHookMode_PostNoCopy);
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{ 
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client)) return;
	g_ePlayer[client].Clear();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	vDeleteTimer();
}

void Event_Player_Death(Event event, const char[] name, bool dontBroadcast) 
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidClient(victim) || GetClientTeam(victim) != L4D_TEAM_INFECTED || !IsValidClient(attacker) || GetClientTeam(attacker) != L4D_TEAM_SURVIVOR) return;
	
	if (iGetPlayerZombieClass(victim) != 2) return; 
	g_ePlayer[victim].m_iAttacker = attacker;
	
}

void vDeleteTimer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) 
			delete g_ePlayer[i].m_hTimer;
	}
}

public void L4D2_OnStagger_Post(int client, int source)
{
	if (!g_bEnable || !IsValidClient(source) || GetClientTeam(source) != L4D_TEAM_INFECTED || !IsValidClient(client) || GetClientTeam(client) != L4D_TEAM_SURVIVOR || L4D_IsPlayerIncapacitated(client) || L4D_IsPlayerHangingFromLedge(client)) return;
	
	if (iGetPlayerZombieClass(source) != 2) return; 
	int attacker = g_ePlayer[source].m_iAttacker;
	if (!IsValidClient(attacker) || GetClientTeam(attacker) != L4D_TEAM_SURVIVOR) return; 

	g_ePlayer[client].m_iBoomer = source;
	delete g_ePlayer[attacker].m_hTimer;
	vAnnounceTimer(source, attacker, 1.5);

}

void vAnnounceTimer(int client, int attacker, float timer)
{
	if (!IsValidClient(attacker)) return;
	DataPack hPack;
	g_ePlayer[attacker].m_hTimer = CreateDataTimer(timer, AnnounceMsg, hPack, TIMER_FLAG_NO_MAPCHANGE);
	hPack.WriteCell(client);
	hPack.WriteCell(attacker);
}

Action AnnounceMsg(Handle timer, DataPack hPack) 
{
	hPack.Reset();
	int victim = hPack.ReadCell();
	int attacker = hPack.ReadCell();
	// delete hPack;
	
	g_ePlayer[attacker].m_hTimer = null;
	if (!IsValidClient(attacker))
		return Plugin_Stop;
		
	int iTotalVictims = 0;
	char sVictimNames[33][MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || g_ePlayer[i].m_iBoomer != victim || GetClientTeam(i) != L4D_TEAM_SURVIVOR || i == attacker)
			continue;
			
		GetClientName(i, sVictimNames[iTotalVictims], MAX_NAME_LENGTH);
		if (!IsFakeClient(i))
			PrintToChat(i, "\x03Ema̲\x01: \x04%N\x01 打胖子炸到了\x04你", attacker);
		// g_ePlayer[i].Clear();
		iTotalVictims++;
	}
	
	if (iTotalVictims > 0)
	{
		char sLine[254];
		char sEntry[64];
		if (iTotalVictims <= 4)
		{
			strcopy(sLine, sizeof(sLine), "\x03Ema̲̲\x01: 你击杀胖子炸到 ");
			
			for (int j = 0; j < iTotalVictims; ++j)
			{
				if (j > 0)
					StrCat(sLine, sizeof(sLine), ", ");

				FormatEx(sEntry, sizeof(sEntry), "\x05%s\x01", sVictimNames[j]);
				StrCat(sLine, sizeof(sLine), sEntry);
			}
			
			char sSur[32];
			FormatEx(sSur, sizeof(sSur), " \x04%d \x01位队友", iTotalVictims);
			StrCat(sLine, sizeof(sLine), sSur);
			
			PrintToChat(attacker, "%s", sLine);
		}
		else
		{
			PrintToChat(attacker, "\x03Ema̲̲\x01: 你击杀胖子炸到 \x04%d\x01 位队友:", iTotalVictims);
			int iLength = 0, iCount = 0;
			sLine[0] = '\0';
			
			for (int j = 0; j < iTotalVictims; ++j)
			{
				FormatEx(sEntry, sizeof(sEntry), "\x05%s\x01", sVictimNames[j]);
				int iEntryLen = strlen(sEntry);

				if (iLength + iEntryLen + (iCount > 0 ? 2 : 0) > sizeof(sLine) - 1)
				{
					if (sLine[0] != '\0')
						PrintToChat(attacker, "%s", sLine);
					sLine[0] = '\0';
					iLength = 0;
					iCount = 0;
				}
				
				if (iCount > 0)
				{
					StrCat(sLine, sizeof(sLine), ", ");
					iLength += 2;
				}
				StrCat(sLine, sizeof(sLine), sEntry);
				iLength += iEntryLen;
				iCount++;
			}
			
			if (sLine[0] != '\0')
				PrintToChat(attacker, "%s", sLine);
		}
	}
	g_ePlayer[victim].Clear();
	g_ePlayer[attacker].Clear();
	return Plugin_Stop;
}

//https://github.com/Target5150/MoYu_Server_Stupid_Plugins
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

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

int iGetPlayerZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}
