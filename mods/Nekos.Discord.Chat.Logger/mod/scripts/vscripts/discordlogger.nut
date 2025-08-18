global function discordlogger_init

void function discordlogger_init()
{
    if ( GetConVarInt( "discordlogger_shouldsendmessageifservercrashandorrestart" ) == 1 )
    {
        SendMessageToDiscord( "```Server Has Crashed And Or Restarted```" )
        SetConVarInt( "discordlogger_shouldsendmessageifservercrashandorrestart", 0 )
    }
    AddCallback_OnReceivedSayTextMessage( LogMessage )
    AddCallback_OnClientConnected( LogJoin )
    AddCallback_OnClientDisconnected( LogDisconnect )
    thread MapChange()
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

struct
{
    int queue = 0
    int realqueue = 0
    float queuetime = 0
} file

ClServer_MessageStruct function LogMessage( ClServer_MessageStruct message )
{
    if ( !IsNewThread() )
    {
        thread LogMessage( message )
        return message
    }
    MessageQueue()
    string msg = message.message
    if ( msg.len() == 0 )
        return message

    if ( format( "%c", msg[0] ) == "!" && message.shouldBlock )
        return message

    msg = StringReplace( msg, "\"", "''", true )
    msg = StringReplace( msg, "\\", "\\\\", true )
    msg = StringReplace( msg, "\\", "\\\\", true )
    msg = StringReplace( msg, "", "ESC", true )
    string newmessage = ""
    string playername = message.player.GetPlayerName()
    int playerteam = message.player.GetTeam()
    if ( !message.isTeam )
        newmessage = playername
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
        newmessage = "[TEAM (" + newmessage + ")]" + playername
    }
    newmessage = newmessage + "**:** " + msg
    SendMessageToDiscord( newmessage, false )
    if ( !message.isTeam )
        newmessage = "**" + playername
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
        newmessage = "**[TEAM (" + newmessage + ")]" + playername
    }
    newmessage = newmessage + ":** " + msg
    SendMessageToDiscord( newmessage, true, false )
    return message
}

void function LogJoin( entity player )
{
    if ( !IsNewThread() )
    {
        thread LogJoin( player )
        return
    }
    string playername = "Someone"
    if ( IsValid( player ) && player.IsPlayer() )
        playername = player.GetPlayerName()
    string message = playername + " Has Joined The Server [Players On The Server " + GetPlayerArray().len() + "]"
    MessageQueue()
    SendMessageToDiscord( message, false )
    message = "```" + message + "```"
    SendMessageToDiscord( message, true, false )
}

void function LogDisconnect( entity player )
{
    if ( !IsNewThread() )
    {
        thread LogDisconnect( player )
        return
    }
    string playername = "Someone"
    if ( IsValid( player ) && player.IsPlayer() )
        playername = player.GetPlayerName()
    int playerarray = GetPlayerArray().len() - 1
    string message = playername + " Has Left The Server [Players On The Server " + playerarray + "]"
    MessageQueue()
    SendMessageToDiscord( message, false )
    message = "```" + message + "```"
    SendMessageToDiscord( message, true, false )
}

void function SendMessageToDiscord( string message, bool sendmessage = true, bool printmessage = true )
{
    if ( printmessage )
        print( "[DiscordLogger] Sending [" + message + "] To Discord" )

    if ( !sendmessage || GetConVarString( "discordlogger_webhook" ) == "" )
        return

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
    MessageQueue()
    string message = "Map Changed To [" + GetMapName() + "]"
    if ( GetMapName() in MAP_NAME_TABLE )
        message = "Map Changed To " + MAP_NAME_TABLE[ GetMapName() ] + " [" + GetMapName() + "]"
    SendMessageToDiscord( message, false )
    message = "```" + message + "```"
    SendMessageToDiscord( message, true, false )
}

void function MessageQueue()
{
    int queue = file.queue
    file.queue += 1
    while ( file.realqueue < queue || file.queuetime > Time() )
        WaitFrame()
    file.queuetime = Time() + 0.20
    file.realqueue += 1
}
