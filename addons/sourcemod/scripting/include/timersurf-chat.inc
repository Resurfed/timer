#if defined _timersurf_chat_included_
#endinput
#endif
#define _timersurf_chat_included_

#define MAX_CHATNAME_LENGTH 128
#define MAX_CHATMESSAGE_LENGTH 256

forward OnChatMessageSent( int author, char[] name, char[] message );
forward OnColorSchemesLoaded( ArrayList schemes, int size );

native bool PrintTimerMessage( int client, char[] message, any ... );
native bool PrintTimerMessageAll( int client, char[] message, any ... );
native bool PrintTimerMessageSpecs( int client, char[] message, any ... );
native bool SetUserColorScheme( int client, int scheme );

public SharedPlugin:__pl_timersurf_chat = 
{
	name = "timersurf-chat",
	file = "timersurf-chat.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_timersurf_chat_SetNTVOptional()
{
	MarkNativeAsOptional( "PrintTimerMessage" );
	MarkNativeAsOptional( "PrintTimerMessageAll" );
	MarkNativeAsOptional( "PrintTimerMessageSpecs" );

}

