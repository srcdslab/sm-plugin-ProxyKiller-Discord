# Copilot Instructions for sm-plugin-ProxyKiller-Discord

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod that integrates ProxyKiller (VPN/proxy detection) with Discord webhooks. When a player using a VPN/proxy is detected, the plugin sends detailed information to a configured Discord channel or thread.

**Main Plugin**: `ProxyKillerDiscord.sp` - Sends VPN flagged player information to Discord webhooks
**Version**: 1.2.1
**Dependencies**: ProxyKiller, DiscordWebhookAPI, ExtendedDiscord (optional)

## Technical Environment

- **Language**: SourcePawn
- **Platform**: SourceMod 1.12+
- **Build System**: Native GitHub Actions workflow (rumblefrog/setup-sp)
- **Compiler**: SourceMod compiler (spcomp) via setup-sp
- **CI/CD**: GitHub Actions with automated build, tag, and release

## Project Structure

```
/
├── .github/
│   ├── workflows/ci.yml          # CI/CD pipeline
│   └── dependabot.yml            # Dependency updates
├── addons/sourcemod/scripting/
│   └── ProxyKillerDiscord.sp     # Main plugin source
├── README.md                     # Basic project description
└── .gitignore                    # Git ignore rules
```

## Build System (GitHub Actions)

This project uses a native GitHub Actions workflow for dependency management and compilation:

### Dependencies (cloned in CI):
- **sourcemod**: Base SourceMod framework, installed via `rumblefrog/setup-sp` (1.12.x)
- **proxyKiller**: Core VPN/proxy detection plugin (srcdslab/sm-plugin-ProxyKiller)
- **discordwebapi**: Discord webhook API integration (srcdslab/sm-plugin-DiscordWebhookAPI)
- **Extended-Discord**: Enhanced Discord logging, optional (srcdslab/sm-plugin-Extended-Discord)

### Build Commands:
```bash
# CI installs the compiler via rumblefrog/setup-sp, clones dependency
# include files into addons/sourcemod/scripting/include, then runs:
spcomp -i include -o ../plugins/ProxyKillerDiscord.smx ProxyKillerDiscord.sp

# Output location: addons/sourcemod/plugins
```

### CI/CD Pipeline (.github/workflows/ci.yml):
- **Build**: Installs spcomp via `rumblefrog/setup-sp`, clones dependencies, compiles the plugin
- **Dependencies**: Shallow-cloned directly from their GitHub repos in the build step
- **Artifacts**: Creates package in `/tmp/package` directory
- **Releases**: Tags and releases automatically on main/master branch
- **Output**: Compiled plugins uploaded as GitHub artifacts for download

## Code Style & Standards

Follow these SourcePawn-specific conventions used in this project:

### Naming Conventions:
- **Global variables**: Prefix with `g_` (e.g., `g_cSteamProfileURLPrefix`)
- **ConVars**: Use descriptive names with plugin prefix (e.g., `sm_proxykiller_discord_webhook`)
- **Functions**: PascalCase for public functions
- **Variables**: camelCase for local variables

### Code Structure:
```sourcepawn
#pragma newdecls required  // Always use new syntax
#pragma semicolon 1        // Require semicolons

// Standard includes
#include <sourcemod>
#include <ProxyKiller>
#include <discordWebhookAPI>

// Optional includes
#undef REQUIRE_PLUGIN
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN
```

### Memory Management:
- Use `delete` for cleanup (no null check needed in SourceMod)
- Prefer StringMap/ArrayList over arrays when appropriate
- Always handle DataPack cleanup in callbacks

### Best Practices Used:
- All ConVars created in `OnPluginStart()`
- AutoExecConfig for automatic config file generation
- Library detection for optional dependencies
- Proper webhook retry mechanism
- Thread-safe Discord messaging

## Plugin Functionality

### Core Features:
1. **ProxyKiller Integration**: Listens for `ProxyKiller_OnClientResult` callback
2. **Discord Webhooks**: Sends notifications when VPN/proxy users are detected
3. **Thread Support**: Can send to regular channels or forum threads
4. **Retry Logic**: Automatic retry mechanism for failed webhooks
5. **Extended Logging**: Optional ExtendedDiscord integration for enhanced error logging

### Key Functions:

#### `ProxyKiller_OnClientResult(ProxyUser pUser, bool result, bool fromCache)`
- **Purpose**: Main callback triggered when ProxyKiller detects a user
- **Filters**: Only processes positive results that aren't from cache
- **Action**: Gathers player data and triggers Discord notification

#### `SendWebHook(char sMessage[], char sWebhookURL[])`
- **Purpose**: Handles Discord webhook transmission
- **Features**: Thread support, avatar configuration, error handling
- **Memory**: Creates and properly deletes Webhook objects

#### `OnWebHookExecuted(HTTPResponse response, DataPack pack)`
- **Purpose**: Webhook response handler with retry logic
- **Retry Logic**: Configurable retry attempts with ExtendedDiscord fallback
- **Thread Handling**: Different status codes for regular vs thread messages

### Message Format Example:
```
John_Doe [STEAM_1:0:12345678] 
Detected IP : 192.168.1.100 
Current map : de_dust2 
Date : 10/09/2024 @ 15:30:25 
Players : 15/32
**Steam Profile :** <https://steamcommunity.com/profiles/76561198012345678>
**IP Details :** <http://geoiplookup.net/ip/192.168.1.100>
```

### Discord Integration Details:
- **Regular Channels**: Uses standard webhook POST with status code 200
- **Forum Threads**: 
  - New threads: Created with `SetThreadName()`, status code 200
  - Existing threads: Uses thread ID, status code 204 (No Content)
- **Retry Logic**: Configurable retries (default 3) for failed webhook deliveries
- **Avatar Support**: Custom avatar URL for webhook messages
- **Extended Logging**: Fallback to ExtendedDiscord for error reporting
- `sm_proxykiller_discord_webhook`: Discord webhook URL (protected)
- `sm_proxykiller_discord_webhook_retry`: Number of retry attempts
- `sm_proxykiller_discord_avatar`: Custom avatar URL
- `sm_proxykiller_discord_channel_type`: Channel vs thread mode
- `sm_proxykiller_discord_threadname`: Thread name for new threads
- `sm_proxykiller_discord_threadid`: Existing thread ID
- `sm_proxykiller_discord_steam_profile_url`: Steam profile URL prefix
- `sm_proxykiller_discord_ip_details_url`: IP lookup service URL
- `sm_proxykiller_discord_count_bots`: Include bots in player count

## Development Guidelines

### Making Changes:
1. **Test Dependencies**: Ensure ProxyKiller and DiscordWebhookAPI are available
2. **Build Testing**: Push/PR to trigger the GitHub Actions CI build, or compile locally with `spcomp`
3. **Memory Safety**: Always pair allocations with proper cleanup
4. **Error Handling**: Use both LogError and ExtendedDiscord logging when available
5. **Thread Safety**: Handle both regular Discord channels and forum threads

### Common Patterns:

#### ConVar Management:
```sourcepawn
// Create in OnPluginStart()
g_cvWebhook = CreateConVar("sm_proxykiller_discord_webhook", "", "Description", FCVAR_PROTECTED);

// Read values
char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
```

#### Memory Management:
```sourcepawn
// Webhook creation and cleanup
Webhook webhook = new Webhook(sMessage);
// ... use webhook
delete webhook;  // Always cleanup

// DataPack handling
DataPack pack = new DataPack();
// ... write data
// In callback: delete pack;
```

#### Optional Plugin Integration:
```sourcepawn
#undef REQUIRE_PLUGIN
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN

// Runtime detection
public void OnAllPluginsLoaded() {
    g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
}

// Conditional usage
#if defined _extendeddiscord_included
if (g_Plugin_ExtDiscord) {
    ExtendedDiscord_LogError("Error message");
}
#endif
```

### Testing:
1. **Build Test**: GitHub Actions CI should complete without errors
2. **Syntax Check**: SourcePawn compiler should accept all code without warnings
3. **Dependency Check**: All includes should resolve correctly during build
4. **Runtime Test**: Test with actual ProxyKiller detections on a test server
5. **Webhook Test**: Verify Discord message formatting and delivery
6. **Thread Test**: Test both regular channel and thread messaging
7. **Configuration Test**: Verify all ConVars work as expected

### Local Testing (if spcomp is available):
```bash
# Check for syntax errors in SourcePawn code
grep -E "(#include|#pragma|public Plugin)" addons/sourcemod/scripting/ProxyKillerDiscord.sp

# Build test (if spcomp is installed and include dependencies are present)
spcomp -i addons/sourcemod/scripting/include -o ProxyKillerDiscord.smx addons/sourcemod/scripting/ProxyKillerDiscord.sp
```

### Error Handling:
- Always check webhook URL configuration before attempting to send
- Implement retry logic for network failures
- Use ExtendedDiscord for enhanced error logging when available
- Log meaningful error messages with plugin name prefix

## Common Tasks

### Adding New Configuration Options:
1. Create ConVar in `OnPluginStart()`
2. Add to AutoExecConfig system
3. Document in plugin description or comments

### Modifying Discord Message Format:
1. Edit the Format() call in `ProxyKiller_OnClientResult`
2. Ensure proper escaping for Discord markdown
3. Test message length limits (WEBHOOK_MSG_MAX_SIZE)

### Adding New Dependencies:
1. Update the "Install dependencies" step in `.github/workflows/ci.yml` (clone + copy include files)
2. Add appropriate #include statements
3. Update CI/CD if needed

### Debugging Issues:
1. Check SourceMod logs for compilation errors
2. Verify webhook URL configuration
3. Test with ExtendedDiscord logging enabled
4. Use PrintToServer for debugging output

## Security Considerations

- Webhook URLs are marked as FCVAR_PROTECTED (not visible to clients)
- No sensitive data should be logged in plain text
- IP addresses are only sent to configured Discord webhooks
- Steam profile links use public Steam64 IDs

## Performance Notes

- Plugin only activates on positive ProxyKiller detections
- Webhook sending is asynchronous (non-blocking)
- Minimal impact on server performance
- Efficient player counting with optional bot inclusion

This plugin follows SourceMod best practices and integrates seamlessly with existing ProxyKiller and Discord webhook infrastructure.