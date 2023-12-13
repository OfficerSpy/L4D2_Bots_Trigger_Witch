#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1

bool g_bIsAttackingWitch[MAXPLAYERS + 1];

DynamicHook g_DHookIsBot;

public Plugin myinfo = 
{
	name = "[L4D2] Bots Startle Witch",
	author = "Officer Spy",
	description = "Lets bots startle the wandering witch.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	GameData hGamedata = new GameData("l4d2.botswitchtrigger");
	
	if (hGamedata == null)
		SetFailState("Could not find gamedata file: l4d2.botswitchtrigger");
	
	int offset = hGamedata.GetOffset("CBasePlayer::IsBot");
	
	if (offset == -1)
		SetFailState("Failed to retrieve offset for CBasePlayer::IsBot!");
	
	delete hGamedata;
	
	g_DHookIsBot = new DynamicHook(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "witch"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Witch_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, Witch_OnTakeDamagePost);
	}
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		DHookEntity(g_DHookIsBot, true, client, _, DHookCallback_IsBot_Post);
}

public Action Witch_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker == 0 || attacker > MaxClients)
		return Plugin_Continue;
	
	if (GetEntPropFloat(victim, Prop_Send, "m_rage") >= 1.0)
		return Plugin_Continue;
	
	if (GetClientTeam(attacker) != 2) //Survivor team only
		return Plugin_Continue;
	
	if (!IsFakeClient(attacker))
		return Plugin_Continue;
	
	g_bIsAttackingWitch[attacker] = true;
	
	return Plugin_Continue;
}

public void Witch_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (attacker == 0 || attacker > MaxClients)
		return;
	
	if (GetEntPropFloat(victim, Prop_Send, "m_rage") >= 1.0)
		return;
	
	if (GetClientTeam(attacker) != 2)
		return;
	
	if (!IsFakeClient(attacker))
		return;
	
	g_bIsAttackingWitch[attacker] = false;
}

public MRESReturn DHookCallback_IsBot_Post(int pThis, DHookReturn hReturn)
{
	if (g_bIsAttackingWitch[pThis])
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

/* NOTE: I actually suspect that the CBasePlayer::IsBot check is done
in WitchWander::OnInjured, but this method seems to work as well,
probably because they are fired on the same frame or close to it */