global function discordlogger_init

void function discordlogger_init() 
{
#if SERVER
if ( IsSingleplayer() )
return
AddCallback_OnReceivedSayTextMessage( LogMessage )
AddCallback_OnClientConnected( LogJoin )
AddCallback_OnClientDisconnected( LogDisconnect )
MapChange()
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
    mp_wargames = "Wargames"
}

array<string> SUPPORTED_MAP_NAMES = [
"mp_wargames",
"mp_thaw",
"mp_rise",
"mp_relic02",
"mp_lf_uma",
"mp_lf_traffic",
"mp_lf_township",
"mp_lf_stacks",
"mp_lf_meadow",
"mp_lf_deck",
"mp_homestead",
"mp_grave",
"mp_glitch",
"mp_forwardbase_kodai",
"mp_eden",
"mp_drydock",
"mp_crashsite3",
"mp_complex3",
"mp_colony02",
"mp_coliseum_column",
"mp_coliseum",
"mp_black_water_canal",
"mp_angel_city",
"mp_lobby"
]

#if SERVER
ClServer_MessageStruct function LogMessage(ClServer_MessageStruct message) 
{
    string msg = message.message
    if (msg.len() == 0)
    return message
    if (format("%c", msg[0]) == "!" )
    return message
    msg = StringReplace( msg, "\"", "''", true )
    msg = StringReplace( msg, "\\", "\\\\", true )
    msg = StringReplace( msg, "\\", "\\\\", true )
    string playername = "Someone Said" // If Player Is Invalid Do This
    string newmessage = ""
    if( IsValid( message.player ) )
    {
    if( message.player.IsPlayer() )
    playername = message.player.GetPlayerName()
    }
    newmessage = playername
    newmessage = newmessage + ": " + msg
    SendMessageToDiscord( newmessage, false )
    newmessage = "**" + playername + "**"
    newmessage = newmessage + ": " + msg
    SendMessageToDiscord( newmessage, true, false )
    return message
}

void function LogJoin( entity player )
{
if( !IsValid( player ) )
return
string playername = player.GetPlayerName()
string message = playername + " Has Joined The Server [Players On The Server " + GetPlayerArray().len() + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}

void function LogDisconnect( entity player )
{
if( !IsValid( player ) )
return
string playername = player.GetPlayerName()
int playerarray = GetPlayerArray().len() - 1
string message = playername + " Has Left The Server [Players On The Server " + playerarray + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}

void function SendMessageToDiscord( string message, bool sendmessage = true, bool printmessage = true )
{
if( printmessage == true )
print( "[DiscordLogger] Sending [" + message + "] To Discord" )
if( sendmessage == false )
return // Anything Past This Is Sending The Message To Discord
HttpRequest request
request.method = HttpRequestMethod.POST
request.url = GetConVarString( "discordlogger_webhook" )
request.body = "{ " +
        "\"content\": \"" + message + "\", " +
        "\"allowed_mentions\": { \"parse\": [] }" +
    " }"
request.headers = {
    ["Content-Type"] = ["application/json"]
}
NSHttpRequest( request )
}

void function MapChange()
{
string message = "Map Changed To [" + GetMapName() + "]"
if( SUPPORTED_MAP_NAMES.contains( GetMapName() ) )
message = "Map Changed To " + MAP_NAME_TABLE[GetMapName()] + " [" + GetMapName() + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}
#endif