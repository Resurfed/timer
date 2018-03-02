#if defined _timer_main_methodmaps_included
 #endinput
#endif
#define _timer_main_methodmaps_included

#include <timer>
#include <ripext>

methodmap ServerInfo < JSONObject 
{
	public ServerInfo()
	{
		JSONObject obj = new JSONObject();
		return view_as<Server>(obj);
	}

    property int id
	{
		public get()
		{
			return this.GetInt("id");
		}
		public set(int value)
		{
			this.SetInt("id", value);
		}
	}

    public void GetAddress(char[] buffer, int size) 
	{
		this.GetString("address", buffer, size);
	}
	
	public void SetAddress(char[] buffer) 
	{
		this.SetString("address", buffer);
	}

    public void GetName(char[] buffer, int size) 
	{
		this.GetString("name", buffer, size);
	}
	
	public void SetName(char[] buffer) 
	{
		this.SetString("name", buffer);
	}

    public void GeCurrentMap(char[] buffer, int size) 
	{
		this.GetString("current_map", buffer, size);
	}
	
	public void SetCurrentMap(char[] buffer) 
	{
		this.SetString("current_map", buffer);
	}

    public void GeDateCreated(char[] buffer, int size) 
	{
		this.GetString("date_created", buffer, size);
	}
	
	public void SetDateCreated(char[] buffer) 
	{
		this.SetString("date_created", buffer);
	}
}

methodmap ClientInfo < JSONObject 
{
	public ClientInfo()
	{
		JSONObject obj = new JSONObject();
		return view_as<ClientInfo>(obj);
	}

    property int id
	{
		public get()
		{
			return this.GetInt("id");
		}
		public set(int value)
		{
			this.SetInt("id", value);
		}
	}

    public void GetAuth(char[] buffer, int size) 
	{
		this.GetString("steam_id", buffer, size);
	}
	
	public void SetAuth(char[] buffer) 
	{
		this.SetString("steam_id", buffer);
	}

    public void GetName(char[] buffer, int size) 
	{
		this.GetString("name", buffer, size);
	}
	
	public void SetName(char[] buffer) 
	{
		this.SetString("name", buffer);
	}

    public void GetAddress(char[] buffer, int size) 
	{
		this.GetString("ip", buffer, size);
	}
	
	public void SetAddress(char[] buffer) 
	{
		this.SetString("ip", buffer);
	}
}