#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <PhysHooks>
#include <SelectiveBhop>
#include <multicolors>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#define REQUIRE_PLUGIN

ConVar g_CVar_sv_enablebunnyhopping;
#if defined _zr_included
ConVar g_CVar_zr_disablebunnyhopping;
#endif

enum
{
	LIMITED_NONE = 0,
	LIMITED_GENERAL = 1,
	LIMITED_ZOMBIE = 2
}

bool g_bEnabled = false;
#if defined _zr_included
bool g_bZombieEnabled = false;
#endif
bool g_bInOnPlayerRunCmd = false;

int g_ClientLimited[MAXPLAYERS + 1] = {LIMITED_NONE, ...};
int g_ActiveLimitedFlags = LIMITED_GENERAL;

StringMap g_ClientLimitedCache;

public Plugin myinfo =
{
	name = "Selective Bunnyhop",
	author = "BotoX + .Rushaway",
	description = "Disables bunnyhop on certain players/groups",
	version = "1.1.1"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_CVar_sv_enablebunnyhopping = FindConVar("sv_enablebunnyhopping");
	g_CVar_sv_enablebunnyhopping.Flags &= ~FCVAR_REPLICATED;
	g_CVar_sv_enablebunnyhopping.AddChangeHook(OnConVarChanged);
	g_bEnabled = g_CVar_sv_enablebunnyhopping.BoolValue;

#if defined _zr_included
	g_CVar_zr_disablebunnyhopping = CreateConVar("zr_disablebunnyhopping", "0", "Disable bhop for zombies.", FCVAR_NOTIFY);
	g_CVar_zr_disablebunnyhopping.AddChangeHook(OnConVarChanged);
	g_bZombieEnabled = g_CVar_zr_disablebunnyhopping.BoolValue;
#endif

	g_ClientLimitedCache = new StringMap();

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_bhop", Command_Bhop, ADMFLAG_GENERIC, "sm_bhop <#userid|name> <0|1>");
	RegConsoleCmd("sm_bhopstatus", Command_Status, "sm_bhopstatus [#userid|name]");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;

#if defined _zr_included
		if(ZR_IsClientZombie(i))
			AddLimitedFlag(i, LIMITED_ZOMBIE);
#endif
	}

	UpdateLimitedFlags();
	UpdateClients();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("LimitBhop", Native_LimitBhop);
	CreateNative("IsBhopLimited", Native_IsBhopLimited);
	RegPluginLibrary("SelectiveBhop");

	return APLRes_Success;
}

public void OnPluginEnd()
{
	g_CVar_sv_enablebunnyhopping.BoolValue = g_bEnabled;
	g_CVar_sv_enablebunnyhopping.Flags |= FCVAR_REPLICATED|FCVAR_NOTIFY;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(g_CVar_sv_enablebunnyhopping.BoolValue)
				g_CVar_sv_enablebunnyhopping.ReplicateToClient(i, "1");
			else
				g_CVar_sv_enablebunnyhopping.ReplicateToClient(i, "0");
		}
	}
}

public void OnMapEnd()
{
	// .Clear() is creating a memory leak
	// g_ClientLimitedCache.Clear();
	delete g_ClientLimitedCache;
	g_ClientLimitedCache = new StringMap();
}

public void OnClientPutInServer(int client)
{
	TransmitConVar(client);
}

public void OnClientDisconnect(int client)
{
	int LimitedFlag = g_ClientLimited[client] & ~(LIMITED_ZOMBIE);

	if(LimitedFlag != LIMITED_NONE)
	{
		char sSteamID[64];
		if(GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID), false))
			g_ClientLimitedCache.SetValue(sSteamID, LimitedFlag, true);
	}

	g_ClientLimited[client] = LIMITED_NONE;
}

public void OnClientPostAdminCheck(int client)
{
	char sSteamID[64];
	if(GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID), false))
	{
		int LimitedFlag;
		if(g_ClientLimitedCache.GetValue(sSteamID, LimitedFlag))
		{
			AddLimitedFlag(client, LimitedFlag);
			g_ClientLimitedCache.Remove(sSteamID);
		}
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_CVar_sv_enablebunnyhopping)
	{
		if(g_bInOnPlayerRunCmd)
			return;

		g_bEnabled = convar.BoolValue;
		UpdateClients();
	}
#if defined _zr_included
	else if(convar == g_CVar_zr_disablebunnyhopping)
	{
		g_bZombieEnabled = convar.BoolValue;
		UpdateLimitedFlags();
	}
#endif
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!g_bEnabled)
		return Plugin_Continue;

	bool bEnableBunnyhopping = !(g_ClientLimited[client] & g_ActiveLimitedFlags);
	if(bEnableBunnyhopping == g_CVar_sv_enablebunnyhopping.BoolValue)
		return Plugin_Continue;

	if(!g_bInOnPlayerRunCmd)
	{
		g_CVar_sv_enablebunnyhopping.Flags &= ~FCVAR_NOTIFY;
		g_bInOnPlayerRunCmd = true;
	}

	g_CVar_sv_enablebunnyhopping.BoolValue = bEnableBunnyhopping;

	return Plugin_Continue;
}

public void OnRunThinkFunctionsPost(bool simulating)
{
	if(g_bInOnPlayerRunCmd)
	{
		g_CVar_sv_enablebunnyhopping.BoolValue = g_bEnabled;
		g_CVar_sv_enablebunnyhopping.Flags |= FCVAR_NOTIFY;
		g_bInOnPlayerRunCmd = false;
	}
}

#if defined _zr_included
public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	AddLimitedFlag(client, LIMITED_ZOMBIE);
}

public void ZR_OnClientHumanPost(int client, bool respawn, bool protect)
{
	RemoveLimitedFlag(client, LIMITED_ZOMBIE);
}

public void ZR_OnClientRespawned(int client, ZR_RespawnCondition condition)
{
	if(condition == ZR_Respawn_Human)
		RemoveLimitedFlag(client, LIMITED_ZOMBIE);
	else
		AddLimitedFlag(client, LIMITED_ZOMBIE);
}
#endif

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RemoveLimitedFlag(-1, LIMITED_ZOMBIE);
}

void UpdateLimitedFlags()
{
	int Flags = LIMITED_GENERAL;

	if(g_bZombieEnabled)
		Flags |= LIMITED_ZOMBIE;

	if(g_ActiveLimitedFlags != Flags)
	{
		g_ActiveLimitedFlags = Flags;
		UpdateClients();
	}
	g_ActiveLimitedFlags = Flags;
}

stock void AddLimitedFlag(int client, int Flag)
{
	if(client == -1)
	{
		for(int i = 1; i <= MaxClients; i++)
			_AddLimitedFlag(i, Flag);
	}
	else
		_AddLimitedFlag(client, Flag);
}

stock void _AddLimitedFlag(int client, int Flag)
{
	bool bWasLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);
	g_ClientLimited[client] |= Flag;
	bool bIsLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);

	if(bIsLimited != bWasLimited)
		TransmitConVar(client);
}

stock void RemoveLimitedFlag(int client, int Flag)
{
	if(client == -1)
	{
		for(int i = 1; i <= MaxClients; i++)
			_RemoveLimitedFlag(i, Flag);
	}
	else
		_RemoveLimitedFlag(client, Flag);
}

stock void _RemoveLimitedFlag(int client, int Flag)
{
	bool bWasLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);
	g_ClientLimited[client] &= ~Flag;
	bool bIsLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);

	if(bIsLimited != bWasLimited)
		TransmitConVar(client);
}

stock void UpdateClients()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			TransmitConVar(i);
	}
}

stock void TransmitConVar(int client)
{
	if(!IsClientInGame(client) || IsFakeClient(client))
		return;

	bool bIsLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);

	if(g_bEnabled && !bIsLimited)
		g_CVar_sv_enablebunnyhopping.ReplicateToClient(client, "1");
	else
		g_CVar_sv_enablebunnyhopping.ReplicateToClient(client, "0");
}

public Action Command_Bhop(int client, int argc)
{
	if (!client)
	{
		CPrintToServer("{green}[SM] {default}Cannot use command from server console.");
		return Plugin_Handled;
	}

	if(argc < 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_bhop <#userid|name> <0|1>");
		return Plugin_Handled;
	}

	char sArg[64];
	char sArg2[2];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;
	bool bValue;

	GetCmdArg(1, sArg, sizeof(sArg));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	bValue = sArg2[0] == '1' ? true : false;

	if((iTargetCount = ProcessTargetString(sArg, client, iTargets, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		if(bValue)
		{
			if(!IsBhopLimited(iTargets[i]))
			{
				if(iTargetCount == 1)
				{
					CReplyToCommand(client, "{green}[SM]{olive} %N {default}is already {green}Un-Restricted.", iTargets[i]);
					return Plugin_Handled;
				}
				continue;
			}

			RemoveLimitedFlag(iTargets[i], LIMITED_GENERAL);
		}
		else
		{
			if(IsBhopLimited(iTargets[i]))
			{
				if(iTargetCount == 1)
				{
					CReplyToCommand(client, "{green}[SM]{olive} %N {default}is already {green}Restricted.", iTargets[i]);
					return Plugin_Handled;
				}
				continue;
			}

			AddLimitedFlag(iTargets[i], LIMITED_GENERAL);
		}
	}

	CShowActivity2(client, "{green}[SM]{olive} ", "{default}Bunnyhop on target {olive}%s {default}has been {green}%s", sTargetName, bValue ? "Un-Restricted" : "Limited");

	if(iTargetCount > 1)
		LogAction(client, -1, "\"%L\" %s bunnyhop on target \"%s\"", client, bValue ? "Un-Restricted" : "Limited", sTargetName);
	else
		LogAction(client, iTargets[0], "\"%L\" %s bunnyhop on target \"%L\"", client, bValue ? "Un-Restricted" : "Limited", iTargets[0]);

	return Plugin_Handled;
}

public Action Command_Status(int client, int argc)
{
	if (!client)
	{
		CPrintToServer("{green}[SM] {default}Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc && CheckCommandAccess(client, "sm_bhop", ADMFLAG_BAN))
	{
		char sArgument[64];
		GetCmdArg(1, sArgument, sizeof(sArgument));

		int target = -1;
		if((target = FindTarget(client, sArgument, true, false)) == -1)
			return Plugin_Handled;

		if(IsBhopLimited(target))
		{
			CReplyToCommand(client, "{green}[SM] {olive}%N {default}bhop is currently : {red}Limited", target);
			return Plugin_Handled;
		}
		else
		{
			CReplyToCommand(client, "{green}[SM] {olive}%N {default}bhop is currently : {green}Not Restricted", target);
			return Plugin_Handled;
		}
	}
	else
	{
		if(IsBhopLimited(client))
		{
			CReplyToCommand(client, "{green}[SM] {default}Your bhop is currently : {red}Limited");
			return Plugin_Handled;
		}
		else
		{
			CReplyToCommand(client, "{green}[SM] {default}Your bhop is currently : {green}Not restricted");
			return Plugin_Handled;
		}
	}
}

public int Native_LimitBhop(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool bLimited = view_as<bool>(GetNativeCell(2));

	if(client > MaxClients || client <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not valid.");
		return -1;
	}

	if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not in-game.");
		return -1;
	}

	if(bLimited)
		AddLimitedFlag(client, LIMITED_GENERAL);
	else
		RemoveLimitedFlag(client, LIMITED_GENERAL);

	return 0;
}

public int Native_IsBhopLimited(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(client > MaxClients || client <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not valid.");
		return -1;
	}

	if(!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not in-game.");
		return -1;
	}

	int LimitedFlag = g_ClientLimited[client] & ~(LIMITED_ZOMBIE);

	return LimitedFlag != LIMITED_NONE;
}
