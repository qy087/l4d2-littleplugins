#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define COOKIE_NAME_MAX 64

Database
	g_hDb;

char
	g_sCookieName[MAXPLAYERS + 1][COOKIE_NAME_MAX],
	g_sCookieDesc[MAXPLAYERS + 1][128],
	g_sPlayer[MAXPLAYERS + 1][72];

int
	g_iMenuPos[MAXPLAYERS + 1],
	g_iCookieAccess[MAXPLAYERS + 1],
	g_iCookieCached[MAXPLAYERS + 1],
	g_iCookieStamp[MAXPLAYERS + 1],
	g_iStaleDays[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name		= "clientprefs_manager",
	author		= "qy087",
	description = "Cookie litter scooper: cleans up the cookies deleted plugins leave behind.",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/qy087/l4d2-littleplugins"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_cookie", Command_Cookie, ADMFLAG_ROOT, "List, inspect or delete clientprefs cookies");
	RegAdminCmd("sm_cookie_delete", Command_Cookie, ADMFLAG_ROOT, "Inspect or delete a clientprefs cookie by name");
	RegAdminCmd("sm_cookie_stale", Command_Stale, ADMFLAG_ROOT, "List cookies not updated in N days (default 30)");
}

public void OnClientDisconnect(int client)
{
	g_iMenuPos[client] = 0;
	g_sCookieName[client][0] = '\0';
	g_sCookieDesc[client][0] = '\0';
	g_sPlayer[client][0] = '\0';
	g_iCookieAccess[client] = 0;
	g_iCookieCached[client] = 0;
	g_iCookieStamp[client] = 0;
}

Action Command_Cookie(int client, int args)
{
	if (!CheckDb(client))
		return Plugin_Handled;

	if (args < 1)
	{
		vListCookies(client);
		return Plugin_Handled;
	}

	char sName[COOKIE_NAME_MAX];
	GetCmdArg(1, sName, sizeof(sName));
	TrimString(sName);

	if (sName[0] == '\0')
	{
		vMsg(client, "[Cookie] Usage: sm_cookie [name] [delete|clear]");
		return Plugin_Handled;
	}

	strcopy(g_sCookieName[client], COOKIE_NAME_MAX, sName);

	if (client == 0 && args >= 2)
	{
		char sMode[16];
		GetCmdArg(2, sMode, sizeof(sMode));

		if (StrEqual(sMode, "delete"))
		{
			vDeleteCookie(client);
			return Plugin_Handled;
		}

		if (StrEqual(sMode, "clear"))
		{
			vClearAll(client);
			return Plugin_Handled;
		}
	}

	vLoadCookie(client);
	return Plugin_Handled;
}

Action Command_Stale(int client, int args)
{
	if (!CheckDb(client))
		return Plugin_Handled;

	int days = 30;

	if (args >= 1)
	{
		char sArg[16];
		GetCmdArg(1, sArg, sizeof(sArg));
		days = StringToInt(sArg);
	}

	if (days < 0)
		days = 0;
	else if (days > 3650)
		days = 3650;

	g_iStaleDays[client] = days;

	char sQuery[512];
	Format(sQuery, sizeof(sQuery),
		"SELECT c.name, COUNT(cc.player), MAX(cc.timestamp) FROM sm_cookies c \
		LEFT JOIN sm_cookie_cache cc ON cc.cookie_id = c.id \
		GROUP BY c.id, c.name \
		HAVING MAX(cc.timestamp) IS NULL OR MAX(cc.timestamp) < %d \
		ORDER BY MAX(cc.timestamp)",
		GetTime() - days * 86400);

	g_hDb.Query(Query_Stale, sQuery, GetUserId(client));
	return Plugin_Handled;
}

void Query_Stale(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Query failed: %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		vMsg(client, "[Cookie] No cookies older than %d day(s) found.", g_iStaleDays[client]);
		return;
	}

	vMsg(client, "[Cookie] %d cookie(s) not updated for %d+ day(s):", results.RowCount, g_iStaleDays[client]);

	char sName[COOKIE_NAME_MAX];
	char sLast[40];

	while (results.FetchRow())
	{
		results.FetchString(0, sName, sizeof(sName));
		vStamp(GetStamp(results, 2), true, sLast, sizeof(sLast));
		vMsg(client, "  %s (%d), last: %s", sName, results.FetchInt(1), sLast);
	}

	if (!IsValidClient(client))
		vMsg(client, "[Cookie] Delete one with: sm_cookie <name> delete");
}

void vListCookies(int client)
{
	g_hDb.Query(Query_List,
		"SELECT c.name, COUNT(cc.player), MAX(cc.timestamp) FROM sm_cookies c \
		LEFT JOIN sm_cookie_cache cc ON cc.cookie_id = c.id \
		GROUP BY c.id, c.name ORDER BY c.name",
		GetUserId(client));
}

void Query_List(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Query failed: %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		vMsg(client, "[Cookie] No cookies found in the database.");
		return;
	}

	char sName[COOKIE_NAME_MAX];
	char sLast[40];

	if (!IsValidClient(client))
	{
		vMsg(client, "[Cookie] %d cookie(s):", results.RowCount);

		while (results.FetchRow())
		{
			results.FetchString(0, sName, sizeof(sName));
			vStamp(GetStamp(results, 2), true, sLast, sizeof(sLast));
			vMsg(client, "  %s (%d), last: %s", sName, results.FetchInt(1), sLast);
		}

		return;
	}

	Menu menu = new Menu(MenuHandler_Cookie);
	menu.SetTitle("☼ clientprefs cookies:");
	// menu.Pagination = 7;
	menu.ExitButton = true;

	char sDisplay[COOKIE_NAME_MAX + 40];

	while (results.FetchRow())
	{
		results.FetchString(0, sName, sizeof(sName));
		vStamp(GetStamp(results, 2), true, sLast, sizeof(sLast));
		Format(sDisplay, sizeof(sDisplay), "%s (%d, %s)", sName, results.FetchInt(1), sLast);
		menu.AddItem(sName, sDisplay);
	}

	menu.DisplayAt(client, g_iMenuPos[client], 20);
}

void vLoadCookie(int client)
{
	char sBuffer[COOKIE_NAME_MAX * 2 + 2];
	vEscapeName(client, sBuffer, sizeof(sBuffer));

	char sQuery[512];
	Format(sQuery, sizeof(sQuery),
		"SELECT c.description, c.access, COUNT(cc.player), MAX(cc.timestamp) FROM sm_cookies c \
		LEFT JOIN sm_cookie_cache cc ON cc.cookie_id = c.id \
		WHERE c.name = '%s' GROUP BY c.id, c.name, c.description, c.access",
		sBuffer);

	g_hDb.Query(Query_Cookie, sQuery, GetUserId(client));
}

void Query_Cookie(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Query failed: %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		vMsg(client, "[Cookie] Cookie \"%s\" not found in the database.", g_sCookieName[client]);
		return;
	}

	results.FetchRow();
	results.FetchString(0, g_sCookieDesc[client], sizeof(g_sCookieDesc[]));
	g_iCookieAccess[client] = results.FetchInt(1);
	g_iCookieCached[client] = results.FetchInt(2);
	g_iCookieStamp[client] = GetStamp(results, 3);

	if (!IsValidClient(client))
	{
		char sDesc[72];
		char sAccess[32];
		char sLast[64];

		if (g_sCookieDesc[client][0] == '\0')
			strcopy(sDesc, sizeof(sDesc), "-");
		else
			strcopy(sDesc, sizeof(sDesc), g_sCookieDesc[client]);

		vAccessLabel(g_iCookieAccess[client], sAccess, sizeof(sAccess));
		vStamp(g_iCookieStamp[client], false, sLast, sizeof(sLast));

		vMsg(client, "[Cookie] %s", g_sCookieName[client]);
		vMsg(client, "  description: %s", sDesc);
		vMsg(client, "  access: %s, cached values: %d", sAccess, g_iCookieCached[client]);
		vMsg(client, "  last update: %s", sLast);
		vListValues(client);
		return;
	}

	vShowConfirmMenu(client);
}

int MenuHandler_Cookie(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iMenuPos[client] = menu.Selection;

			char sInfo[COOKIE_NAME_MAX];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			strcopy(g_sCookieName[client], COOKIE_NAME_MAX, sInfo);

			if (!CheckDb(client))
				return 0;

			vLoadCookie(client);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vShowConfirmMenu(int client)
{
	char sBuffer[52];
	if (g_sCookieDesc[client][0] == '\0')
		strcopy(sBuffer, sizeof(sBuffer), "-");
	else
		strcopy(sBuffer, sizeof(sBuffer), g_sCookieDesc[client]);

	char sAccess[32];
	vAccessLabel(g_iCookieAccess[client], sAccess, sizeof(sAccess));

	char sLast[24];
	vStamp(g_iCookieStamp[client], true, sLast, sizeof(sLast));

	Menu menu = new Menu(MenuHandler_Confirm);
	menu.SetTitle("☼ 删除 cookie?\n%s\n%s\n权限: %s | 缓存值: %d 条\n最后更新: %s",
		g_sCookieName[client], sBuffer, sAccess, g_iCookieCached[client], sLast);
	menu.AddItem("yes", "确认删除");
	menu.AddItem("values", "查看缓存数据");
	menu.AddItem("clear", "清空全部缓存值");
	menu.AddItem("no", "取消");
	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

int MenuHandler_Confirm(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[8];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			switch (sInfo[0])
			{
				case 'y': vDeleteCookie(client);
				case 'v': vListValues(client);
				case 'c': vShowClearConfirmMenu(client);
				case 'n': RequestFrame(NextFrame_List, GetUserId(client));
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				RequestFrame(NextFrame_List, GetUserId(client));
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vListValues(int client)
{
	char sEscaped[COOKIE_NAME_MAX * 2 + 2];
	vEscapeName(client, sEscaped, sizeof(sEscaped));

	char sQuery[512];
	Format(sQuery, sizeof(sQuery),
		"SELECT player, value FROM sm_cookie_cache WHERE cookie_id IN \
		(SELECT id FROM sm_cookies WHERE name = '%s') ORDER BY player",
		sEscaped);

	g_hDb.Query(Query_Values, sQuery, GetUserId(client));
}

void Query_Values(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Query failed: %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		vMsg(client, "[Cookie] Cookie \"%s\" has no cached values (never written or already cleared).", g_sCookieName[client]);

		if (IsValidClient(client))
			RequestFrame(NextFrame_Cookie, GetUserId(client));

		return;
	}

	char sPlayer[72];
	char sValue[128];

	if (!IsValidClient(client))
	{
		vMsg(client, "[Cookie] %s cached values:", g_sCookieName[client]);

		while (results.FetchRow())
		{
			results.FetchString(0, sPlayer, sizeof(sPlayer));
			results.FetchString(1, sValue, sizeof(sValue));
			vMsg(client, "  %s: %s", sPlayer, sValue);
		}

		return;
	}

	Menu menu = new Menu(MenuHandler_Values);
	menu.SetTitle("☼ %s 的缓存数据:", g_sCookieName[client]);
	menu.ExitBackButton = true;

	char sDisplay[254];

	while (results.FetchRow())
	{
		results.FetchString(0, sPlayer, sizeof(sPlayer));
		results.FetchString(1, sValue, sizeof(sValue));
		Format(sDisplay, sizeof(sDisplay), "%s: %s", sPlayer, sValue);
		menu.AddItem(sPlayer, sDisplay);
	}

	menu.Display(client, 30);
}

int MenuHandler_Values(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[72];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			strcopy(g_sPlayer[client], sizeof(g_sPlayer[]), sInfo);
			vLoadValue(client);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				RequestFrame(NextFrame_Cookie, GetUserId(client));
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vLoadValue(int client)
{
	char sPlayer[144];
	g_hDb.Escape(g_sPlayer[client], sPlayer, sizeof(sPlayer));

	char sEscaped[COOKIE_NAME_MAX * 2 + 2];
	vEscapeName(client, sEscaped, sizeof(sEscaped));

	char sQuery[512];
	Format(sQuery, sizeof(sQuery),
		"SELECT value FROM sm_cookie_cache WHERE player = '%s' AND cookie_id IN \
		(SELECT id FROM sm_cookies WHERE name = '%s')",
		sPlayer, sEscaped);

	g_hDb.Query(Query_Value, sQuery, GetUserId(client));
}

void Query_Value(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	if (!IsValidClient(client))
		return;

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Query failed: %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		vMsg(client, "[Cookie] That cached value no longer exists.");
		RequestFrame(NextFrame_Values, GetUserId(client));
		return;
	}

	results.FetchRow();

	char sValue[64];
	results.FetchString(0, sValue, sizeof(sValue));

	if (sValue[0] == '\0')
		strcopy(sValue, sizeof(sValue), "-");

	Menu menu = new Menu(MenuHandler_ValueConfirm);
	menu.SetTitle("☼ 删除这条缓存值?\n%s\n%s\ncookie: %s", g_sPlayer[client], sValue, g_sCookieName[client]);
	menu.AddItem("yes", "确认删除");
	menu.AddItem("no", "取消");
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

int MenuHandler_ValueConfirm(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[8];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			switch (sInfo[0])
			{
				case 'y': vDeleteValue(client);
				case 'n': RequestFrame(NextFrame_Values, GetUserId(client));
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				RequestFrame(NextFrame_Values, GetUserId(client));
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vDeleteValue(int client)
{
	char sPlayer[144];
	g_hDb.Escape(g_sPlayer[client], sPlayer, sizeof(sPlayer));

	char sEscaped[COOKIE_NAME_MAX * 2 + 2];
	vEscapeName(client, sEscaped, sizeof(sEscaped));

	char sQuery[512];
	Format(sQuery, sizeof(sQuery),
		"DELETE FROM sm_cookie_cache WHERE player = '%s' AND cookie_id IN \
		(SELECT id FROM sm_cookies WHERE name = '%s')",
		sPlayer, sEscaped);

	g_hDb.Query(Query_Deleted, sQuery, GetUserId(client));
}

void Query_Deleted(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Delete failed: %s", error);
		return;
	}

	vMsg(client, "[Cookie] Deleted %d cached value(s) of %s in \"%s\" (online players keep their in-memory values until they reconnect).",
		results.AffectedRows, g_sPlayer[client], g_sCookieName[client]);

	if (IsValidClient(client))
		RequestFrame(NextFrame_Values, GetUserId(client));
}

void NextFrame_Values(int userId)
{
	int client = GetClientOfUserId(userId);
	if (!IsValidClient(client))
		return;

	if (CheckDb(client))
		vListValues(client);
}

void NextFrame_Cookie(int userId)
{
	int client = GetClientOfUserId(userId);
	if (IsValidClient(client) && CheckDb(client))
		vLoadCookie(client);
}

void vShowClearConfirmMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ClearConfirm);
	menu.SetTitle("☼ 清空全部缓存值?\n%s\n将删除 %d 条缓存值，cookie 本身保留", g_sCookieName[client], g_iCookieCached[client]);
	menu.AddItem("yes", "确认清空");
	menu.AddItem("no", "取消");
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

int MenuHandler_ClearConfirm(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[8];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			switch (sInfo[0])
			{
				case 'y': vClearAll(client);
				case 'n': RequestFrame(NextFrame_Cookie, GetUserId(client));
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				RequestFrame(NextFrame_Cookie, GetUserId(client));
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vClearAll(int client)
{
	char sEscaped[COOKIE_NAME_MAX * 2 + 2];
	vEscapeName(client, sEscaped, sizeof(sEscaped));

	char sQuery[512];
	Format(sQuery, sizeof(sQuery),
		"DELETE FROM sm_cookie_cache WHERE cookie_id IN \
		(SELECT id FROM sm_cookies WHERE name = '%s')", sEscaped);

	g_hDb.Query(Query_Cleared, sQuery, GetUserId(client));
}

void Query_Cleared(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);

	if (error[0] != '\0')
	{
		vMsg(client, "[Cookie] Clear failed: %s", error);
		return;
	}

	vMsg(client, "[Cookie] Cleared %d cached value(s) of \"%s\" (online players keep their in-memory values until they reconnect).",
		results.AffectedRows, g_sCookieName[client]);

	if (IsValidClient(client))
		RequestFrame(NextFrame_Cookie, GetUserId(client));
}

void NextFrame_List(int userId)
{
	int client = GetClientOfUserId(userId);
	if (IsValidClient(client) && CheckDb(client))
		vListCookies(client);
}

void vDeleteCookie(int client)
{
	char sEscaped[COOKIE_NAME_MAX * 2 + 2];
	vEscapeName(client, sEscaped, sizeof(sEscaped));

	char sQuery[512];
	Transaction txn = new Transaction();

	Format(sQuery, sizeof(sQuery),
		"DELETE FROM sm_cookie_cache WHERE cookie_id IN \
		(SELECT id FROM sm_cookies WHERE name = '%s')", sEscaped);
	txn.AddQuery(sQuery);

	Format(sQuery, sizeof(sQuery), "DELETE FROM sm_cookies WHERE name = '%s'", sEscaped);
	txn.AddQuery(sQuery);

	g_hDb.Execute(txn, Txn_DeleteSuccess, Txn_DeleteError, GetUserId(client));
}

void Txn_DeleteSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = GetClientOfUserId(data);

	vMsg(client, "[Cookie] Deleted \"%s\": %d cached value(s), %d cookie row(s).",
		g_sCookieName[client], results[0].AffectedRows, results[1].AffectedRows);
	vMsg(client, "[Cookie] If a plugin still registers this cookie it will be recreated on its next reload; online players need to reconnect to drop their in-memory values.");

	if (IsValidClient(client))
		RequestFrame(NextFrame_List, data);
}

void Txn_DeleteError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	int client = GetClientOfUserId(data);
	vMsg(client, "[Cookie] Delete failed: %s", error);
}

bool CheckDb(int client)
{
	if (g_hDb != null)
		return true;

	char sError[128];
	g_hDb = SQL_Connect("clientprefs", true, sError, sizeof(sError));

	if (g_hDb == null)
	{
		vMsg(client, "[Cookie] Failed to connect to the clientprefs database: %s", sError);
		return false;
	}

	return true;
}

void vEscapeName(int client, char[] buffer, int maxlen)
{
	g_hDb.Escape(g_sCookieName[client], buffer, maxlen);
}

void vMsg(int client, const char[] fmt, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), fmt, 3);

	if (IsValidClient(client))
		PrintToChat(client, "%s", buffer);
	else
		PrintToServer("%s", buffer);
}

void vStamp(int stamp, bool bShort, char[] buffer, int maxlen)
{
	if (stamp <= 0)
	{
		strcopy(buffer, maxlen, "从未写入/never");
		return;
	}

	char sTime[32];

	if (bShort)
	{
		FormatTime(sTime, sizeof(sTime), "%Y-%m-%d", stamp);
		strcopy(buffer, maxlen, sTime);
		return;
	}

	FormatTime(sTime, sizeof(sTime), "%Y-%m-%d %H:%M", stamp);

	int days = (GetTime() - stamp) / 86400;

	if (days <= 0)
		Format(buffer, maxlen, "%s (今天)", sTime);
	else
		Format(buffer, maxlen, "%s (%d 天前)", sTime, days);
}

void vAccessLabel(int access, char[] buffer, int maxlen)
{
	switch (access)
	{
		case 0: strcopy(buffer, maxlen, "公开/Public");
		case 1: strcopy(buffer, maxlen, "受保护/Protected");
		case 2: strcopy(buffer, maxlen, "私有/Private");
		default: Format(buffer, maxlen, "未知/Unknown(%d)", access);
	}
}

int GetStamp(DBResultSet results, int field)
{
	return results.IsFieldNull(field) ? 0 : results.FetchInt(field);
}

int GetUserId(int client)
{
	return IsValidClient(client) ? GetClientUserId(client) : 0;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
