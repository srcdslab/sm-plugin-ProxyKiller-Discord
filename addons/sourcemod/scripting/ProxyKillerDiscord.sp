#pragma newdecls required

#include <sourcemod>
#include <ProxyKiller>
#include <discordWebhookAPI>

#undef REQUIRE_PLUGIN
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "ProxyKiller Discord"
#define WEBHOOK_URL_MAX_SIZE			1000
#define WEBHOOK_THREAD_NAME_MAX_SIZE	100

ConVar g_cSteamProfileURLPrefix, g_cIPDetailURLPrefix, g_cCountBots;
ConVar g_cvWebhook, g_cvWebhookRetry, g_cvAvatar;
ConVar g_cvChannelType, g_cvThreadName, g_cvThreadID;

char g_sCurrentMap[PLATFORM_MAX_PATH];
bool g_Plugin_ExtDiscord = false;

public Plugin myinfo = 
{
    name = PLUGIN_NAME,
    author = "maxime1907, Sikari, .Rushaway",
    description = "Sends detected vpn players info to discord",
    version = "1.2",
    url = "https://github.com/srcdslab/sm-plugin-ProxyKiller-Discord"
};

public void OnPluginStart()
{
    g_cSteamProfileURLPrefix = CreateConVar("sm_proxykiller_discord_steam_profile_url", "https://steamcommunity.com/profiles/", "URL of the steam profile");
    g_cIPDetailURLPrefix = CreateConVar("sm_proxykiller_discord_ip_details_url", "http://geoiplookup.net/ip/", "URL of the website that analyses the IP");
    g_cCountBots = CreateConVar("sm_proxykiller_discord_count_bots", "1", "Should we count bots as players ?[0 = No, 1 = Yes]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvWebhook = CreateConVar("sm_proxykiller_discord_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
    g_cvWebhookRetry = CreateConVar("sm_proxykiller_discord_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
    g_cvAvatar = CreateConVar("sm_proxykiller_discord_avatar", "https://avatars.githubusercontent.com/u/110772618?s=200&v=4", "URL to Avatar image.");
    g_cvChannelType = CreateConVar("sm_proxykiller_discord_channel_type", "0", "Type of your channel: (1 = Thread, 0 = Classic Text channel");

    /* Thread config */
    g_cvThreadName = CreateConVar("sm_proxykiller_discord_threadname", "", "The Thread Name of your Discord forums. (If not empty, will create a new thread)", FCVAR_PROTECTED);
    g_cvThreadID = CreateConVar("sm_proxykiller_discord_threadid", "0", "If thread_id is provided, the message will send in that thread.", FCVAR_PROTECTED);

    AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
    g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
}

public void OnLibraryAdded(const char[] sName)
{
    if (strcmp(sName, "ExtendedDiscord", false) == 0)
        g_Plugin_ExtDiscord = true;
}

public void OnLibraryRemoved(const char[] sName)
{
    if (strcmp(sName, "ExtendedDiscord", false) == 0)
        g_Plugin_ExtDiscord = false;
}

public void OnMapInit(const char[] mapName)
{
    FormatEx(g_sCurrentMap, sizeof(g_sCurrentMap), mapName);
}

public void ProxyKiller_OnClientResult(ProxyUser pUser, bool result, bool fromCache)
{
    char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
    g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);

    if(!sWebhookURL[0])
    {
        LogError("[%s] No webhook found or specified.", PLUGIN_NAME);
        return;
    }

    if (!result) return;
    if (fromCache) return;

    char sPlayerName[MAX_NAME_LENGTH];
    pUser.GetName(sPlayerName, sizeof(sPlayerName));

    char sSteamID2[32];
    pUser.GetSteamId2(sSteamID2, sizeof(sSteamID2));

    char sSteamID64[24];
    pUser.GetSteamId64(sSteamID64, sizeof(sSteamID64));

    char sIP[16];
    pUser.GetIPAddress(sIP, sizeof(sIP));

    char sSteamProfileURLPrefix[256];
    g_cSteamProfileURLPrefix.GetString(sSteamProfileURLPrefix, sizeof(sSteamProfileURLPrefix));
    char sIPDetailsURLPrefix[256];
    g_cIPDetailURLPrefix.GetString(sIPDetailsURLPrefix, sizeof(sIPDetailsURLPrefix));

    char sSteamProfileURL[256];
    Format(sSteamProfileURL, sizeof(sSteamProfileURL), "**Steam Profile :** <%s%s>", sSteamProfileURLPrefix, sSteamID64);

    char sIPLocationURL[256];
    Format(sIPLocationURL, sizeof(sIPLocationURL), "**IP Details :** <%s%s>", sIPDetailsURLPrefix, sIP);

    char sTimeFormatted[64];
    char sTime[128];
    int iTime = GetTime();
    FormatTime(sTimeFormatted, sizeof(sTimeFormatted), "%d/%m/%Y @ %H:%M:%S", iTime);
    Format(sTime, sizeof(sTime), "Date : %s", sTimeFormatted);

    char sCount[64];
    int iMaxPlayers = MaxClients;
    int iConnected = GetClientCountEx(g_cCountBots.BoolValue);
    Format(sCount, sizeof(sCount), "Players : %d/%d", iConnected, iMaxPlayers);

    char sMessage[4096];
    Format(sMessage, sizeof(sMessage), "```%s [%s] \nDetected IP : %s \nCurrent map : %s \n%s \n%s```%s \n%s", sPlayerName, sSteamID2, sIP, g_sCurrentMap, sTime, sCount, sSteamProfileURL, sIPLocationURL);
    ReplaceString(sMessage, sizeof(sMessage), "\\n", "\n");

    SendWebHook(sMessage, sWebhookURL);
}

stock void SendWebHook(char sMessage[4096], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
    Webhook webhook = new Webhook(sMessage);

    char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
    g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
    g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

    bool IsThread = g_cvChannelType.BoolValue;

    if (IsThread) {
        if (!sThreadName[0] && !sThreadID[0]) {
            LogError("[%s] Thread Name or ThreadID not found or specified.", PLUGIN_NAME);
            delete webhook;
            return;
        } else {
            if (strlen(sThreadName) > 0) {
                webhook.SetThreadName(sThreadName);
                sThreadID[0] = '\0';
            }
        }
    }

    /* Webhook Avatar */
    char sAvatar[256];
    g_cvAvatar.GetString(sAvatar, sizeof(sAvatar));

    if (strlen(sAvatar) > 0)
        webhook.SetAvatarURL(sAvatar);

    DataPack pack = new DataPack();

    if (IsThread && strlen(sThreadName) <= 0 && strlen(sThreadID) > 0)
        pack.WriteCell(1);
    else
        pack.WriteCell(0);

    pack.WriteString(sMessage);
    pack.WriteString(sWebhookURL);

    webhook.Execute(sWebhookURL, OnWebHookExecuted, pack, sThreadID);
    delete webhook;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
    static int retries = 0;
    pack.Reset();

    bool IsThreadReply = pack.ReadCell();

    char sMessage[4096], sWebhookURL[WEBHOOK_URL_MAX_SIZE];
    pack.ReadString(sMessage, sizeof(sMessage));
    pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

    delete pack;
    
    if ((!IsThreadReply && response.Status != HTTPStatus_OK) || (IsThreadReply && response.Status != HTTPStatus_NoContent))
    {
        if (retries < g_cvWebhookRetry.IntValue)
        {
            PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
            SendWebHook(sMessage, sWebhookURL);
            retries++;
            return;
        } else {
            if (!g_Plugin_ExtDiscord)
            {
                LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
                LogError("[%s] Failed message : %s", PLUGIN_NAME, sMessage);
            }
        #if defined _extendeddiscord_included
            else
            {
                ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
                ExtendedDiscord_LogError("[%s] Failed message : %s", PLUGIN_NAME, sMessage);
            }
        #endif
        }
    }

    retries = 0;
}

stock int GetClientCountEx(bool countBots)
{
    int iRealClients = 0;
    int iFakeClients = 0;

    for(int player = 1; player <= MaxClients; player++)
    {
        if(IsClientConnected(player))
        {
            if(IsFakeClient(player))
                iFakeClients++;
            else
                iRealClients++;
        }
    }
    return countBots ? iFakeClients + iRealClients : iRealClients;
}
