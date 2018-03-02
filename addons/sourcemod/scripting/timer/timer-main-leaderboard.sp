#define MAX_RANKS 5

ArrayList g_Leaderboard_clients;
ArrayList g_Leaderboard_times;
ArrayList g_Leaderboard_names;

void PushToLeaderboard(int client, float time)
{
	InsertTime(client, time);
}

void InsertTime(int client, float newTime)
{
	char auth[32], name[30];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof auth);

	int Rank = GetLeaderboardRank(auth);

	for (new x = 0; x < MAX_RANKS; x++)
	{
		float time = g_Leaderboard_times.Get(x);

		if (time == 0.0 || time > newTime)
		{
			if (Rank != -1 && x > Rank)
				return;

			if (x < Rank)
			{
				g_Leaderboard_times.Erase(Rank);
				g_Leaderboard_clients.Erase(Rank);
				g_Leaderboard_names.Erase(Rank);
			}

			if (x != Rank && x < MAX_RANKS)
			{
				g_Leaderboard_times.ShiftUp(x);
				g_Leaderboard_clients.ShiftUp(x);
				g_Leaderboard_names.ShiftUp(x);
			}

			GetClientName(client, name, sizeof name);

			g_Leaderboard_times.Set(x, newTime);
			g_Leaderboard_clients.SetString(x, auth);
			g_Leaderboard_names.SetString(x, name);

			g_Leaderboard_times.Resize(MAX_RANKS);
			g_Leaderboard_clients.Resize(MAX_RANKS);
			g_Leaderboard_names.Resize(MAX_RANKS);
		}
	}
}

int GetLeaderboardRank(char[] steamID)
{
	return g_Leaderboard_clients.FindString(steamID);
}

public Action Command_Leaderboard(int client, int args)
{
	Menu menu = new Menu(MenuHandlerReport);
	menu.SetTitle("Leaderboard Stats");

	for (int x = 0; x < MAX_RANKS; x++)
	{
		char rank[2], formattedTime[15], name[30], output[50];
		int y = x + 1;
		IntToString(y, rank, sizeof rank);

		if (g_Leaderboard_clients.Get(x) == 0)
			Format(name, sizeof name, "None");
		else
			g_Leaderboard_names.GetString(x, name, sizeof name);

		FormatTimeFloat(g_Leaderboard_times.Get(x), formattedTime, sizeof formattedTime);

		Format(output, sizeof output, "%s \n%s", name, formattedTime);

		menu.AddItem(rank, output);
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int MenuHandlerReport(Menu menu, MenuAction action, int Client, int param2)
{
	return;
}