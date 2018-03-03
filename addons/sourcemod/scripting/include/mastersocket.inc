/*
**
*/
#if defined _mastersocket_included
#endinput
#endif
#define _mastersocket_included

#include <smjansson>

native bool Socket_SendData(char[] Data);

native int Socket_IsConnected();

forward Socket_DataReceived( StringMap dataTable ); 


methodmap GlobalMsg < Handle 
{
	
	public GlobalMsg()
	{
		return view_as<GlobalMsg>(json_object());
	}
	
	public void GlobalMsgSetType(char[] type)
	{
		json_object_set_new(this, "Type", json_string(type));
	}
	
	public void AddString(char[] key, char[] value)
	{
		json_object_set_new(this, key, json_string(value));
	}
	
	public void AddInt(char[] key, int value)
	{
		json_object_set_new(this, key, json_integer(value));
	}
	
	public bool Send()
	{
		char sJSON[4096];
		json_dump(this, sJSON, sizeof sJSON, 0);
		delete this;
		return Socket_SendData(sJSON);
	}
	
}