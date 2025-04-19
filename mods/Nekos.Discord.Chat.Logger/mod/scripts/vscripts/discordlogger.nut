global function discordlogger_init

struct
{
int howmanytimesmapchanged = 0
}file

void function discordlogger_init() 
{
#if SERVER
AddCallback_OnReceivedSayTextMessage( LogMessage )
AddCallback_OnClientConnected( LogJoin )
AddCallback_OnClientDisconnected( LogDisconnect )
AddCallback_GameStateEnter( eGameState.Prematch, MapChange )
#endif
}

table<string, string> MAP_NAME_TABLE = {
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

#if SERVER
ClServer_MessageStruct function LogMessage(ClServer_MessageStruct message) 
{
    string msg = message.message.tolower()
    if (msg.len() == 0)
    return message
    if (format("%c", msg[0]) == "!" )
    return message
    string playername = "Someone Said" // If Player Is Invalid Do This
    string newmessage = ""
    if( IsValid( message.player ) )
    playername = message.player.GetPlayerName()
    newmessage = playername
    newmessage = newmessage + ": " + message.message
    SendMessageToDiscord( newmessage, false )
    newmessage = "**" + playername + "**"
    newmessage = newmessage + ": " + message.message
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
if( file.howmanytimesmapchanged != 0 )
return
file.howmanytimesmapchanged = 1
string message = "Map Changed To " + MAP_NAME_TABLE[GetMapName()] + " [" + GetMapName() + "]"
SendMessageToDiscord( message, false )
message = "```" + message + "```"
SendMessageToDiscord( message, true, false )
}
#endif