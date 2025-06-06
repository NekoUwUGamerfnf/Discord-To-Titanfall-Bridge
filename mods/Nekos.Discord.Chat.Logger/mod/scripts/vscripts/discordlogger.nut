global function discordlogger_init

void function discordlogger_init() 
{
#if SERVER
if ( IsSingleplayer() )
return
AddCallback_OnReceivedSayTextMessage( LogMessage )
AddCallback_OnClientConnected( LogJoin )
AddCallback_OnClientDisconnected( LogDisconnect )
thread LastLoggedMessage()
#endif
}

table<string, string> MAP_NAME_TABLE = {
    mp_lobby = "Lobby",
    mp_angel_city = "Angel City",
    mp_black_water_canal = "Black Water Canal",
    mp_coliseum = "Coliseum",
    mp_coliseum_column = "Pillars",
    mp_colony02 = "Colony",
    mp_complex3 = "Complex",
    mp_crashsite3 = "Crash Site",
    mp_drydock = "Drydock",
    mp_eden = "Eden",
    mp_forwardbase_kodai = "Forwardbase Kodai",
    mp_glitch = "Glitch",
    mp_grave = "Boomtown",
    mp_homestead = "Homestead",
    mp_lf_deck = "Deck",
    mp_lf_meadow = "Meadow",
    mp_lf_stacks = "Stacks",
    mp_lf_township = "Township",
    mp_lf_traffic = "Traffic",
    mp_lf_uma = "UMA",
    mp_relic02 = "Relic",
    mp_rise = "Rise",
    mp_thaw = "Exoplanet",
    mp_wargames = "Wargames",
}

#if SERVER
ClServer_MessageStruct function LogMessage(ClServer_MessageStruct message) 
{
    string msg = message.message
    if ( msg.len() == 0 )
    return message
    if ( message.shouldBlock )
    return message
    msg = StringReplace( msg, "\"", "''", true )
    msg = StringReplace( msg, "\\", "\\\\", true )
    msg = StringReplace( msg, "\\", "\\\\", true )
    string newmessage = ""
    string playername = message.player.GetPlayerName()
    int playerteam = message.player.GetTeam()
    if ( !message.isTeam )
    newmessage = playername
    else
    {
    if ( playerteam <= 0 ) // Because A Table Doesn't Work We Are Gonna Try This
    newmessage = "Spec"
    if ( playerteam == 1 )
    newmessage = "None"
    if ( playerteam == 2 )
    newmessage = "IMC"
    if ( playerteam == 3 )
    newmessage = "Militia"
    if ( playerteam >= 4 )
    newmessage = "Both"
    newmessage = "[TEAM (" + newmessage + ")]" + playername
    }
    newmessage = newmessage + ": " + msg
    SendMessageToDiscord( newmessage, false )
    if ( !message.isTeam )
    newmessage = "**" + playername + "**"
    else
    {
    if ( playerteam <= 0 )
    newmessage = "Spec"
    if ( playerteam == 1 )
    newmessage = "None"
    if ( playerteam == 2 )
    newmessage = "IMC"
    if ( playerteam == 3 )
    newmessage = "Militia"
    if ( playerteam >= 4 )
    newmessage = "Both"
    newmessage = "**[TEAM (" + newmessage + ")]" + playername + "**"
    }
    newmessage = newmessage + ": " + msg
    SendMessageToDiscord( newmessage, true, false )
    return message
}

void function LogJoin( entity player )
{
string playername = "Someone"
if ( IsValid( player ) && player.IsPlayer() )
playername = player.GetPlayerName()
string message = playername + " Has Joined The Server [Players On The Server " + GetPlayerArray().len() + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}

void function LogDisconnect( entity player )
{
string playername = "Someone"
if ( IsValid( player ) && player.IsPlayer() )
playername = player.GetPlayerName()
int playerarray = GetPlayerArray().len() - 1
string message = playername + " Has Left The Server [Players On The Server " + playerarray + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}

void function LastLoggedMessage()
{
array<string> messages = split( GetConVarString( "discordlogger_last_log_of_chat" ), "\"" )
SetConVarString( "discordlogger_last_log_of_chat", "" )
foreach( string message in messages )
{
 WaitFrame()
 SendMessageToDiscord( message, true, false )
}
WaitFrame()
MapChange()
}

void function SendMessageToDiscord( string message, bool sendmessage = true, bool printmessage = true )
{
thread SendMessageToDiscord_thread( message, sendmessage, printmessage )
}

void function SendMessageToDiscord_thread( string message, bool sendmessage = true, bool printmessage = true )
{
if ( printmessage )
print( "[DiscordLogger] Sending [" + message + "] To Discord" )
if ( !sendmessage )
return // Anything Past This Is Sending The Message To Discord
 if ( GetGameState() == eGameState.Postmatch && GetConVarString( "discordlogger_localurl" ) == "" )
 {
 string messagetolog = GetConVarString( "discordlogger_last_log_of_chat" ) + "\"" + message
 SetConVarString( "discordlogger_last_log_of_chat", messagetolog )
 return
 }
HttpRequest request
request.method = HttpRequestMethod.POST
request.url = GetConVarString( "discordlogger_webhook" )
if ( GetConVarString( "discordlogger_localurl" ) != "" )
request.url = GetConVarString( "discordlogger_localurl" )
request.body = "{ " +
        "\"content\": \"" + message + "\", " +
        "\"allowed_mentions\": { \"parse\": [] }" +
    " }"
if ( GetConVarString( "discordlogger_localurl" ) != "" )
request.body = "{ " +
        "\"forward_request\": \"" + GetConVarString( "discordlogger_webhook" ) + "\", " +
        "\"content\": \"" + message + "\", " +
        "\"allowed_mentions\": { \"parse\": [] }" +
    " }"
request.headers = {
    ["Content-Type"] = ["application/json"]
}
if ( GetConVarString( "discordlogger_localurl" ) == "" )
wait RandomFloatRange( 0.15, 0.20 )
 if ( GetGameState() == eGameState.Postmatch && GetConVarString( "discordlogger_localurl" ) == "" )
 {
 string messagetolog = GetConVarString( "discordlogger_last_log_of_chat" ) + "\"" + message
 SetConVarString( "discordlogger_last_log_of_chat", messagetolog )
 return
 }
NSHttpRequest( request )
}

void function MapChange()
{
string message = "Map Changed To [" + GetMapName() + "]"
if ( GetMapName() in MAP_NAME_TABLE )
message = "Map Changed To " + MAP_NAME_TABLE[GetMapName()] + " [" + GetMapName() + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}
#endif