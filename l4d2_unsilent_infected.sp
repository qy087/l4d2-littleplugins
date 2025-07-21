#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "L4D2-Unsilent-Infected",
	author = "HoongDou",
	description = "Makes Infected emit a sound to all players upon spawning, to nerf wallkicks a bit more.",
	version = "1.0.0",
	url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

static char g_sSpecialSounds[35][] = {
    "player/boomer/voice/alert/female_boomer_alert_04.wav",
    "player/boomer/voice/alert/female_boomer_alert_05.wav",
    "player/boomer/voice/alert/female_boomer_alert_07.wav",
    "player/boomer/voice/alert/female_boomer_alert_10.wav",
    "player/boomer/voice/alert/female_boomer_alert_11.wav",
    "player/boomer/voice/alert/female_boomer_alert_12.wav",
    "player/boomer/voice/alert/female_boomer_alert_13.wav",
    "player/boomer/voice/alert/female_boomer_alert_14.wav",
    "player/boomer/voice/alert/female_boomer_alert_15.wav",
    "player/boomer/voice/alert/male_boomer_alert_04.wav",
    "player/boomer/voice/alert/male_boomer_alert_05.wav",
    "player/boomer/voice/alert/male_boomer_alert_07.wav",
    "player/boomer/voice/alert/male_boomer_alert_10.wav",
    "player/boomer/voice/alert/male_boomer_alert_11.wav",
    "player/boomer/voice/alert/male_boomer_alert_12.wav",
    "player/boomer/voice/alert/male_boomer_alert_13.wav",
    "player/boomer/voice/alert/male_boomer_alert_14.wav",
    "player/boomer/voice/alert/male_boomer_alert_15.wav",
    "player/charger/voice/alert/charger_alert_01.wav",
    "player/charger/voice/alert/charger_alert_02.wav",
    "player/jockey/voice/alert/jockey_02.wav",
	"player/jockey/voice/alert/jockey_04.wav",
    "player/hunter/voice/alert/hunter_alert_01.wav",
    "player/hunter/voice/alert/hunter_alert_02.wav",
    "player/hunter/voice/alert/hunter_alert_03.wav",
    "player/hunter/voice/alert/hunter_alert_04.wav",
    "player/hunter/voice/alert/hunter_alert_05.wav",
    "player/smoker/voice/alert/smoker_alert_01.wav",
    "player/smoker/voice/alert/smoker_alert_02.wav",
    "player/smoker/voice/alert/smoker_alert_03.wav",
    "player/smoker/voice/alert/smoker_alert_04.wav",
    "player/smoker/voice/alert/smoker_alert_05.wav",
    "player/smoker/voice/alert/smoker_alert_06.wav",
    "player/spitter/voice/alert/spitter_alert_01.wav",
    "player/spitter/voice/alert/spitter_alert_02.wav"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	for (int i = 0; i < 35; i++)
    {
        PrefetchSound(g_sSpecialSounds[i]);
        PrecacheSound(g_sSpecialSounds[i], true);
    }
}

void Event_PlayerSpawn(Event event, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidSpecialInfected(client))
		RequestFrame(NextFrame_PlayerSpawnSound, EntIndexToEntRef(client));
}

void NextFrame_PlayerSpawnSound(int client)
{
    client = EntRefToEntIndex(client);
    int szClass = GetZombieClass(client), Random_min = -1, Random_max = -1;
    if(szClass > 6 || szClass < 1) return;
    switch (szClass)
    {
        case 1:
        {
            Random_min = 27;
            Random_max = 32;
        }
        case 2:
        {
            Random_min = 0;
            Random_max = 17;
        }
        case 3:
        {
            Random_min = 22;
            Random_max = 26;
        }
        case 4:
        {
            Random_min = 33;
            Random_max = 34;
        }
        case 5:
        {
            Random_min = 20;
            Random_max = 21;
        }
        case 6:
        {
            Random_min = 18;
            Random_max = 19;
        }
    }
    int randomSound = GetRandomInt(Random_min, Random_max);
    EmitSoundToAll(g_sSpecialSounds[randomSound], client, SNDCHAN_VOICE, SNDLEVEL_HELICOPTER);
}

bool IsValidSpecialInfected(int client)
{
	if (!client || !IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost") == 1) 
		return false;
	return true;
}

int GetZombieClass(int client)
{
    if (!IsValidSpecialInfected(client)) return -1;
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}