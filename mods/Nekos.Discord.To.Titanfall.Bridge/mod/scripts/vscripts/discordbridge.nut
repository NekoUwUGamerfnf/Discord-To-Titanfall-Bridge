global function discordbridge_init

void function discordbridge_init()
{
    if ( GetConVarInt( "discordbridge_shouldsendmessageifservercrashandorrestart" ) == 1 )
    {
        thread SendServerCrashedAndOrRestartedMessage()
        SetConVarInt( "discordbridge_shouldsendmessageifservercrashandorrestart", 0 )
    }
    AddCallback_OnReceivedSayTextMessage( LogMessage )
    AddCallback_OnClientConnected( LogJoin )
    AddCallback_OnClientDisconnected( LogDisconnect )
    thread MapChange()
    
    thread DiscordMessagePoller()
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
    table<string, string> namelist
    bool firsttime = true
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

    string playername = message.player.GetPlayerName()
    int playerteam = message.player.GetTeam()
    
    string prefix = ""
    if ( !message.isTeam )
        prefix = playername
    else
    {
        string teamstr = ""
        if ( playerteam <= 0 )
            teamstr = "Spec"
        else if ( playerteam == 1 )
            teamstr = "None"
        else if ( playerteam == 2 )
            teamstr = "IMC"
        else if ( playerteam == 3 )
            teamstr = "Militia"
        else
            teamstr = "Both"
        prefix = "[TEAM (" + teamstr + ")] " + playername
    }
    
    string console_message = prefix + ": " + msg
    SendMessageToDiscord( console_message, false )
    
    string discord_message = "**" + prefix + ":** " + msg
    SendMessageToDiscord( discord_message, true, false )
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
    int playercount = GetPlayerArray().len() - 1
    string message = playername + " Has Left The Server [Players On The Server " + playercount + "]"
    MessageQueue()
    SendMessageToDiscord( message, false )
    message = "```" + message + "```"
    SendMessageToDiscord( message, true, false )
}

void function SendMessageToDiscord( string message, bool sendmessage = true, bool printmessage = true )
{
    if ( GetConVarString( "discordbridge_webhook" ) == "" )
        return

    if ( printmessage )
        print( "[discordbridge] Sending [" + message + "] To Discord" )

    if ( !sendmessage || GetConVarString( "discordbridge_webhook" ) == "" )
        return

    table payload = {
        content = message
        allowed_mentions = {
            parse = []
        }
    }
    HttpRequest request
    request.method = HttpRequestMethod.POST
    request.url = GetConVarString( "discordbridge_webhook" )
    request.body = EncodeJSON( payload )
    request.headers = {
        [ "Content-Type" ] = [ "application/json" ],
        [ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
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
    file.queuetime = Time() + 0.25
    file.realqueue += 1
}

void function DiscordMessagePoller()
{
    WaitFrame()
    while ( true )
    {
        if ( GetConVarString( "discordbridge_bottoken" ) != "" && GetConVarString( "discordbridge_channelid" ) != "" && GetConVarString( "discordbridge_serverid" ) != "" )
        {
            MessageQueue()
            PollDiscordMessages()
        }
        wait 1.25
    }
}

int last_discord_timestamp = 2147483647

void function PollDiscordMessages()
{
    string bottoken = GetConVarString( "discordbridge_bottoken" )
    string channelid = GetConVarString( "discordbridge_channelid" )
    HttpRequest request
    request.method = HttpRequestMethod.GET
    string url = "https://discord.com/api/v10/channels/" + channelid + "/messages?limit=5"
    request.url = url
    request.headers = {
        [ "Authorization" ] = [ "Bot " + bottoken ],
        [ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
    }
    
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if ( file.firsttime && response.statusCode == 200 )
        {
            string responsebody = response.body
            responsebody = StringReplace( responsebody, "\"mentions\"", "mentions\"", true )
            responsebody = StringReplace( responsebody, "\"timestamp\":\"", "\"timestamp\":", true )
            responsebody = StringReplace( responsebody, "\",\"edited_timestamp\"", ",\"edited_timestamp\"", true )
            array<string> newresponse = split( responsebody, "" )
            if ( newresponse.len() >= 2 )
            {
                last_discord_timestamp = StringReplaceTime( newresponse[2] )
                file.firsttime = false
            }
        }
        else
            thread ThreadDiscordToTitanfallBridge( response )
    }
    
    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print( "[Discord] Poll failed: " + failure.errorMessage )
    }
    
    NSHttpRequest( request, onSuccess, onFailure )
}

void function ThreadDiscordToTitanfallBridge( HttpRequestResponse response )
{
    if ( response.statusCode == 200 )
    {
        string responsebody = response.body
        responsebody = StringReplace( responsebody, "\"message_reference\"", "\"message_reference\"", true )
        array<string> arrayresponse = split( responsebody, "" )
        array<string> fixedresponse = []
        for ( int i = 0; i < arrayresponse.len(); i++ )
            if ( arrayresponse[i].find( "\"message_reference\"" ) == null )
                fixedresponse.append( arrayresponse[i] )
        responsebody = ""
        for ( int i = 0; i < fixedresponse.len(); i++ )
            responsebody += fixedresponse[i]
        responsebody = StringReplace( responsebody, "\"author\"", "author\"", true )
        responsebody = StringReplace( responsebody, "\"pinned\"", "pinned\"", true )
        responsebody = StringReplace( responsebody, "\"mentions\"", "mentions\"", true )
        responsebody = StringReplace( responsebody, "\"channel_id\"", "channel_id\"", true )
        responsebody = StringReplace( responsebody, "},{", "[{", true )
        responsebody = StringReplace( responsebody, "\"timestamp\":\"", "\"timestamp\":", true )
        responsebody = StringReplace( responsebody, "\",\"edited_timestamp\"", ",\"edited_timestamp\"", true )
        array<string> newresponse = split( responsebody, "" )
        if ( newresponse.len() < 6 || StringReplaceTime( newresponse[2] ) == last_discord_timestamp )
            return
        for ( int i = 0; i < newresponse.len(); i++ )
        {
            if ( StringReplaceTime( newresponse[ i + 2 ] ) <= last_discord_timestamp )
                break
            string meow = newresponse[i]
            // 0 for content
            // 1 for nothing
            // 2 for time
            // 3 for nothing
            // 4 for global name
            // 5 for nothing
            // 6 for nothing
            // 7 for next row of messages
            if ( i < 7 )
            {
                if ( newresponse[ 5 ].find( "\"bot\"" ) )
                    continue
            }
            else if ( i >= 7 && i < 14 )
            {
                if ( newresponse[ 12 ].find( "\"bot\"" ) )
                    continue
            }
            else if ( i >= 14 && i < 21 )
            {
                if ( newresponse[ 19 ].find( "\"bot\"" ) )
                    continue
            }
            else if ( i >= 21 && i < 28 )
            {
                if ( newresponse[ 26 ].find( "\"bot\"" ) )
                    continue
            }
            else if ( i >= 28 && i < 35 )
            {
                if ( newresponse[ 33 ].find( "\"bot\"" ) )
                    continue
            } 
            if ( i == 0 || i == 7 || i == 14 || i == 21 || i == 28 )
            {
                meow = meow.slice( 0, -2 )
                while ( meow.find( ":\"" ) )
                    meow = meow.slice( 1 )
                meow = meow.slice( 2 )
                string meower = newresponse[ i + 5 ]
                meower = meower.slice( 15 )
                while ( meower.find( "\"" ) )
                    meower = meower.slice( 0, -1 )
                string meowest = newresponse[ i + 3 ]
                meowest = meowest.slice( 0, -2 )
                while ( meowest.find( "id" ) )
                    meowest = meowest.slice( 1 )
                meowest = meowest.slice( 5 )
                if ( meow.len() >= 5 && meow.slice( 0, 5 - meow.len() ).tolower() == "?rcon" )
                {
                    array<string> rconusers = split( GetConVarString( "discordbridge_rconusers" ), "," )
                    bool shouldruncommand = false
                    for ( int i = 0; i < rconusers.len(); i++ )
                        if ( rconusers[i] == meower )
                            shouldruncommand = true
                    if ( shouldruncommand )
                    {
                        GreenCircleDiscordToTitanfallBridge( meowest )
                        ServerCommand( StringReplace( meow.slice( 5 ), "\\", "", true ) )
                    }
                    else
                        RedCircleDiscordToTitanfallBridge( meowest )
                }
                if ( meow.tolower() == "?rcon" || (meow.len() >= 5 && meow.slice( 0, 5 - meow.len() ).tolower() == "?rcon") )
                    continue
                if ( meow.len() > 200 || meow.len() <= 0 )
                {
                    RedCircleDiscordToTitanfallBridge( meowest )
                    continue
                }
                thread EndThreadDiscordToTitanfallBridge( meow, meower, meowest )
                wait 0.25
            }
        }
        last_discord_timestamp = StringReplaceTime( newresponse[2] )
    }
    else
    {
        print( "[Discord] Poll failed with status: " + response.statusCode.tostring() )
        print( "[Discord] Response Body: " + response.body )
    }
}

int function StringReplaceTime( string time )
{
    string returntime = time
    returntime = StringReplace( returntime, "-", "", true )
    returntime = StringReplace( returntime, ":", "", true )
    returntime = StringReplace( returntime, ".", "", true )
    returntime = StringReplace( returntime, "+", "", true )
    returntime = StringReplace( returntime, "T", "", true )
    
    if ( returntime.len() >= 14 )
        returntime = returntime.slice( 10, -5 )
    return returntime.tointeger()
}

void function GetUserNickname( string userid )
{
    string bottoken = GetConVarString( "discordbridge_bottoken" )
    string guildid = GetConVarString( "discordbridge_serverid" )
    HttpRequest request
    request.method = HttpRequestMethod.GET
    string url = "https://discord.com/api/v10/guilds/" + guildid + "/members/" + userid
    request.url = url
    request.headers = {
        [ "Authorization" ] = [ "Bot " + bottoken ],
        [ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
    }
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response ) : ( userid )
    {
        if ( response.statusCode == 200 )
        {
            string responsebody = response.body
            responsebody = StringReplace( responsebody, "\"nick\"", "nick\"", true )
            responsebody = StringReplace( responsebody, "\"pending\"", "pending\"", true )
            responsebody = StringReplace( responsebody, "\"global_name\"", "global_name\"", true )
            responsebody = StringReplace( responsebody, "\"avatar_decoration_data\"", "avatar_decoration_data\"", true )
            array<string> newresponse = split( responsebody, "" )
            string meow = newresponse[1]
            meow = StringReplace( meow, "nick\":", "" )
            if ( meow.find( "\"," ) )
                file.namelist[ userid ] <- meow.slice( 1, -2 )
            else if ( newresponse[3].find( "name" ) )
                file.namelist[ userid ] <- newresponse[3].slice( 14, -2 )
        }
        else
        {
            print( "[Discord] Poll failed with status: " + response.statusCode.tostring() )
            print( "[Discord] Response Body: " + response.body )
        }
    }
    
    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print( "[Discord] Poll failed: " + failure.errorMessage )
    }

    NSHttpRequest( request, onSuccess, onFailure )
}

string function GetUserTrueNickname( string userid )
{
    wait 0.75
    if ( userid in file.namelist )
        return file.namelist[ userid ]
    
    return "Unknown"
}


void function SendMessageToPlayers( string message )
{
    for ( int i = 0; i < GetPlayerArray().len(); i++ )
        thread ActuallySendMessageToPlayers( GetPlayerArray()[i], message )
}

void function ActuallySendMessageToPlayers( entity player, string message )
{
    player.EndSignal( "OnDestroy" )
    while ( !IsAlive( player ) && !IsLobby() )
        WaitFrame()
    Chat_ServerPrivateMessage( player, message, false, false )
}

void function EndThreadDiscordToTitanfallBridge( string meow, string meower, string meowest )
{
    GetUserNickname( meower )
    meower = GetUserTrueNickname( meower )
    SendMessageToPlayers( "[38;2;88;101;242m" + "[Discord] " + meower + ": \x1b[0m" + StringReplace( meow, "\\", "", true ) )
    GreenCircleDiscordToTitanfallBridge( meowest )
}

void function GreenCircleDiscordToTitanfallBridge( string meowest )
{
    string bottoken = GetConVarString( "discordbridge_bottoken" )
    string channelid = GetConVarString( "discordbridge_channelid" )
    HttpRequest request
    request.method = HttpRequestMethod.PUT
    string url = "https://discord.com/api/v10/channels/" + channelid + "/messages/" + meowest + "/reactions/%F0%9F%9F%A2/@me"
    request.url = url
    request.headers = {
        [ "Authorization" ] = [ "Bot " + bottoken ],
        [ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
    }
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if ( response.statusCode != 204 )
        {
            print( "[Discord] Poll failed with status: " + response.statusCode.tostring() )
            print( "[Discord] Response Body: " + response.body )
        }
    }
    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print( "[Discord] Poll failed: " + failure.errorMessage )
    }
    NSHttpRequest( request, onSuccess, onFailure )
}

void function RedCircleDiscordToTitanfallBridge( string meowest )
{
    string bottoken = GetConVarString( "discordbridge_bottoken" )
    string channelid = GetConVarString( "discordbridge_channelid" )
    HttpRequest request
    request.method = HttpRequestMethod.PUT
    string url = "https://discord.com/api/v10/channels/" + channelid + "/messages/" + meowest + "/reactions/%F0%9F%94%B4/@me"
    request.url = url
    request.headers = {
        [ "Authorization" ] = [ "Bot " + bottoken ],
        [ "User-Agent" ] = [ "DiscordToTitanfallBridge" ]
    }
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if ( response.statusCode != 204 )
        {
            print( "[Discord] Poll failed with status: " + response.statusCode.tostring() )
            print( "[Discord] Response Body: " + response.body )
        }
    }
    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print( "[Discord] Poll failed: " + failure.errorMessage )
    }
    NSHttpRequest( request, onSuccess, onFailure )
}

void function SendServerCrashedAndOrRestartedMessage()
{
    MessageQueue()
    SendMessageToDiscord( "```Server Has Crashed And Or Restarted```" )
}
