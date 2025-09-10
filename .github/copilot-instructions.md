# Copilot Instructions for SelectiveBhop Plugin

## Repository Overview

This repository contains **SelectiveBhop**, a SourcePawn plugin for SourceMod that provides selective bunnyhopping control for Source engine game servers. The plugin allows administrators to disable bunnyhopping for specific players or groups while maintaining normal bhop functionality for others.

### Key Features
- Selective bunnyhop limiting for individual players
- Integration with ZombieReloaded plugin (zombies can have bhop disabled)
- Native API for other plugins to control bhop limits
- Admin commands for managing bhop restrictions
- Client state persistence across map changes
- Per-client ConVar replication for smooth gameplay

## Project Structure

```
/addons/sourcemod/scripting/
├── SelectiveBhop.sp              # Main plugin source code
└── include/
    └── SelectiveBhop.inc         # Native function definitions and API

/.github/
├── workflows/
│   └── ci.yml                    # GitHub Actions CI/CD pipeline
└── dependabot.yml               # Dependency management

/sourceknight.yaml               # Build system configuration
```

## Technical Environment

- **Language**: SourcePawn
- **Platform**: SourceMod 1.11+ (latest stable)
- **Build System**: SourceKnight 0.1
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **CI/CD**: GitHub Actions with automated builds and releases

## Dependencies

The plugin requires these dependencies (managed by SourceKnight):

1. **SourceMod Base** (1.11.0-git6917+)
2. **MultiColors** - For colored chat messages
3. **ZombieReloaded** - Optional integration for zombie-specific bhop control
4. **PhysHooks Extension** - For physics-related hooks

## Build System (SourceKnight)

### Configuration
The build is configured via `sourceknight.yaml`:
- Dependencies are automatically downloaded and linked
- Output goes to `/addons/sourcemod/plugins`
- Target: `SelectiveBhop.smx`

### Build Commands
```bash
# Install SourceKnight (if not available)
pip install sourceknight

# Build the plugin
sourceknight build

# The compiled plugin will be in .sourceknight/package/addons/sourcemod/plugins/
# Build artifacts are automatically excluded via .gitignore
```

### Local Development
For local development without SourceKnight installation:
- Use the GitHub Actions CI for builds (push to branch)
- The CI uses `maxime1907/action-sourceknight@v1` action
- Compiled artifacts are available as GitHub Actions artifacts

### CI/CD Pipeline
- **Trigger**: Push, PR, or manual dispatch
- **Build**: Ubuntu 24.04 with SourceKnight
- **Artifacts**: Compiled plugin package
- **Release**: Automatic releases on tags and main branch updates

## Code Standards & Conventions

### SourcePawn Style
```sourcepawn
#pragma semicolon 1
#pragma newdecls required

// Global variables use g_ prefix
bool g_bEnabled = false;
int g_ClientLimited[MAXPLAYERS + 1] = {LIMITED_NONE, ...};

// Use PascalCase for functions
void UpdateLimitedFlags()
{
    // Use tabs (4 spaces) for indentation
    int Flags = LIMITED_GENERAL;
    
    if(g_bZombieEnabled)
        Flags |= LIMITED_ZOMBIE;
}

// Use camelCase for local variables
void SomeFunction()
{
    int targetCount = 0;
    bool isLimited = false;
}
```

### Memory Management
```sourcepawn
// CORRECT: Use delete directly, don't check for null
delete g_ClientLimitedCache;
g_ClientLimitedCache = new StringMap();

// INCORRECT: Don't use .Clear() - causes memory leaks
// g_ClientLimitedCache.Clear(); // DON'T DO THIS
```

### Native Function Documentation
Always document native functions in the `.inc` file:
```sourcepawn
/**
 * Sets whether bunnyhopping is limited for a client.
 *
 * @param client        Client index
 * @param bLimited      True to limit bunnyhopping, false to allow it
 * @return             0 on success, -1 on failure
 * @error              Invalid client index or client not in game
 */
native int LimitBhop(int client, bool bLimited);
```

## Development Workflow

### Common Tasks

1. **Adding New Features**:
   - Modify `SelectiveBhop.sp` for implementation
   - Update `SelectiveBhop.inc` if adding new natives
   - Test with both ZombieReloaded enabled and disabled
   - Ensure proper client state handling

2. **Modifying Native Functions**:
   - Update function signature in `.inc` file
   - Update implementation in `.sp` file
   - Maintain backward compatibility when possible
   - Document all parameters and return values

3. **Adding Commands**:
   - Use `RegAdminCmd` for admin commands
   - Use `RegConsoleCmd` for player commands
   - Include proper permission checks
   - Use MultiColors for consistent messaging

### Key Plugin Patterns

#### Client State Management
```sourcepawn
// The plugin uses bitwise flags for client limitations
enum
{
    LIMITED_NONE = 0,
    LIMITED_GENERAL = 1,
    LIMITED_ZOMBIE = 2
}

// Adding limitations
AddLimitedFlag(client, LIMITED_GENERAL);

// Removing limitations  
RemoveLimitedFlag(client, LIMITED_ZOMBIE);

// Checking limitations
bool isLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);
```

#### ConVar Manipulation
```sourcepawn
// The plugin temporarily modifies sv_enablebunnyhopping per-client
// This requires careful flag management to avoid notification spam
g_CVar_sv_enablebunnyhopping.Flags &= ~FCVAR_NOTIFY;
g_CVar_sv_enablebunnyhopping.BoolValue = bEnableBunnyhopping;
g_CVar_sv_enablebunnyhopping.Flags |= FCVAR_NOTIFY;
```

## Integration Points

### ZombieReloaded Integration
```sourcepawn
#if defined _zr_included
// Conditional compilation for ZR features
public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
    AddLimitedFlag(client, LIMITED_ZOMBIE);
}
#endif
```

### Native API Usage
Other plugins can integrate using:
```sourcepawn
#include <SelectiveBhop>

// Limit a player's bhop
LimitBhop(client, true);

// Check if bhop is limited
if(IsBhopLimited(client))
{
    // Player has bhop restrictions
}
```

## Testing Approaches

### Manual Testing
1. **Basic Functionality**:
   - Test `sm_bhop` command with various targets
   - Verify `sm_bhopstatus` shows correct states
   - Test bhop behavior with restricted/unrestricted players

2. **ZombieReloaded Integration**:
   - Test zombie infection limiting bhop
   - Test human respawn removing bhop limits
   - Verify round restart clears zombie flags

3. **Edge Cases**:
   - Client disconnect/reconnect state persistence
   - Map changes preserving client states
   - ConVar changes during gameplay

### Build Verification
```bash
# Verify clean build
sourceknight build

# Check for warnings or errors in compilation
# The plugin should compile without warnings
```

## Performance Considerations

### Critical Performance Areas
1. **OnPlayerRunCmd**: Executed every game tick per player
   - Minimize operations in this callback
   - Current implementation efficiently checks flags before ConVar changes

2. **StringMap Operations**: Used for client state caching
   - Delete and recreate instead of using .Clear()
   - Cache Steam IDs efficiently for reconnection handling

3. **ConVar Replication**: 
   - Only replicate when client state actually changes
   - Use efficient bitwise operations for flag checking

## Common Issues & Solutions

### Build Issues
- **Missing Dependencies**: Ensure all dependencies in `sourceknight.yaml` are accessible
- **Include Errors**: Verify include paths and dependency order
- **Compilation Warnings**: Address all warnings as they often indicate logical errors

### Runtime Issues
- **ConVar Conflicts**: The plugin modifies `sv_enablebunnyhopping` - ensure no other plugins conflict
- **Memory Leaks**: Always use `delete` for StringMap/ArrayList cleanup
- **Client State Desync**: Ensure `TransmitConVar` is called when client states change

## File Modification Guidelines

### When Modifying SelectiveBhop.sp
- Maintain the existing event hook structure
- Preserve client state management patterns
- Test both with and without ZombieReloaded
- Ensure ConVar flag management remains intact
- Be careful with the `OnPlayerRunCmd` callback - it's performance critical
- Always call `TransmitConVar(client)` when client limitation state changes

### When Modifying SelectiveBhop.inc
- Update version numbers appropriately (lines 6-8)
- Maintain native function signatures for compatibility
- Document all new natives thoroughly with `/** */` comment blocks
- Test with example integration code
- Use the `SharedPlugin` pattern for optional dependency support

## Plugin-Specific Patterns

### Understanding the Core Logic
The plugin works by manipulating the `sv_enablebunnyhopping` ConVar on a per-client basis:

1. **Global State**: `g_bEnabled` tracks the original server setting
2. **Client Flags**: Each client has limitation flags stored in `g_ClientLimited[]`
3. **Active Flags**: `g_ActiveLimitedFlags` determines which limitations are currently enforced
4. **ConVar Manipulation**: In `OnPlayerRunCmd`, the plugin temporarily changes the ConVar for each client

### Flag System Architecture
```sourcepawn
// Base limitation types
LIMITED_NONE = 0      // No limitations
LIMITED_GENERAL = 1   // Admin-imposed limitation
LIMITED_ZOMBIE = 2    // ZombieReloaded automatic limitation

// Bitwise operations for multiple flags
g_ClientLimited[client] |= LIMITED_GENERAL;   // Add flag
g_ClientLimited[client] &= ~LIMITED_ZOMBIE;   // Remove flag
bool isLimited = view_as<bool>(g_ClientLimited[client] & g_ActiveLimitedFlags);
```

### State Persistence System
```sourcepawn
// On disconnect, cache non-temporary limitations
char sSteamID[64];
GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID), false);
g_ClientLimitedCache.SetValue(sSteamID, LimitedFlag, true);

// On reconnect, restore cached state
if(g_ClientLimitedCache.GetValue(sSteamID, LimitedFlag))
{
    AddLimitedFlag(client, LimitedFlag);
    g_ClientLimitedCache.Remove(sSteamID);
}
```

## Deployment Considerations

### Server Requirements
- SourceMod 1.11+ installation
- PhysHooks extension loaded
- Optional: ZombieReloaded plugin for zombie integration

### Configuration
- No additional configuration files required
- Plugin auto-configures based on available dependencies
- ConVar `zr_disablebunnyhopping` created when ZombieReloaded is present

### Installation
1. Place `SelectiveBhop.smx` in `addons/sourcemod/plugins/`
2. Place `SelectiveBhop.inc` in `addons/sourcemod/scripting/include/` (for developers)
3. Restart server or use `sm plugins load SelectiveBhop`

## Version Management

- Plugin version defined in `SelectiveBhop.inc` using semantic versioning
- Version format: `MAJOR.MINOR.PATCH`
- CI automatically creates releases from tags and main branch
- Version should be updated in `.inc` file when making releases

This plugin demonstrates advanced SourcePawn techniques including conditional compilation, native API design, client state management, and performance optimization. When working on this codebase, prioritize maintaining the existing architectural patterns and performance characteristics.