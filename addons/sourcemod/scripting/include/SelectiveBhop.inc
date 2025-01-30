#if defined _SelectiveBhop_Included
	#endinput
#endif
#define _SelectiveBhop_Included

#define SelectiveBhop_V_MAJOR   "1"
#define SelectiveBhop_V_MINOR   "2"
#define SelectiveBhop_V_PATCH   "0"

#define SelectiveBhop_VERSION   SelectiveBhop_V_MAJOR..."."...SelectiveBhop_V_MINOR..."."...SelectiveBhop_V_PATCH

/**
 * Sets whether bunnyhopping is limited for a client.
 *
 * @param client        Client index
 * @param bLimited      True to limit bunnyhopping, false to allow it
 * @return             0 on success, -1 on failure
 * @error              Invalid client index or client not in game
 */
native int LimitBhop(int client, bool bLimited);

/**
 * Checks if bunnyhopping is limited for a client.
 *
 * @param client        Client index
 * @return             True if bunnyhopping is limited, false otherwise
 * @error              Invalid client index or client not in game
 */
native int IsBhopLimited(int client);

public SharedPlugin __pl_SelectiveBhop =
{
	name = "SelectiveBhop",
	file = "SelectiveBhop.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_SelectiveBhop_SetNTVOptional()
{
	MarkNativeAsOptional("LimitBhop");
	MarkNativeAsOptional("IsBhopLimited");
}
#endif
