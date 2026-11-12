# [SM] Clientprefs Cookie 管理器 / Clientprefs Cookie Manager

**插件名称 / Plugin Name:** `clientprefs_manager`  
**版本 / Version:** 1.0  
**作者 / Author:** qy087  
**适用游戏 / Game:** 任意 Source 游戏 / Any Source game

---

## 简介 / Description

**中文**  
插件删了，Cookie 还在。这个插件专门铲这类没人认领的遗留数据：列出库里所有 Cookie，看它们在谁名下、存了谁的什么值、多久没更新，然后精确删掉没人要的——整条、整个缓存、或者某一个人。不用半夜爬服务器敲 `sqlite3`，也不用把整个数据库扬了。

**English**  
Plugins get deleted. Their cookies don't. This plugin scoops up that leftover data: list every cookie, see what is still stored, for whom, and when it was last touched, then remove exactly the abandoned ones — a whole cookie, all cached values, or a single player's value. No `sqlite3`, no nuking the database.

---

## ⚠️ 免责声明 / Disclaimer

**中文**  
本插件直接读写 clientprefs 数据库，删除操作**不可撤销**。请先确认每条 Cookie 属于哪个插件、是否还在使用；不确定就先备份数据库（例如 `cp clientprefs-sqlite.sq3 clientprefs-sqlite.sq3.bak`）。除非你知道自己在删什么，否则别在生产服上乱点。

**English**  
This plugin reads and writes the clientprefs database directly, and deletions **cannot be undone**. Make sure you know which plugin owns each cookie and whether it is still in use; when in doubt, back up the database first (e.g. `cp clientprefs-sqlite.sq3 clientprefs-sqlite.sq3.bak`). If you are not sure what you are deleting, do not click it on a live server.

---

## 功能 / Features

- 列出数据库里所有 Cookie，包括插件已经跑路、数据还赖在库里的那种，并显示每个 Cookie 的缓存条数。  
  Lists every cookie in the database, including ones no plugin registers anymore, with its cached value count.
- 显示每条 Cookie 的最后写入时间（最近一次玩家值被写入的时间），方便判断是不是已经没人用的老数据。  
  Shows when each cookie was last written, so stale data is easy to spot.
- `sm_cookie_stale [天数]` 按"N 天没写入/更新"筛选 Cookie（包括从未写入过的），适合定期巡检。  
  `sm_cookie_stale [days]` filters cookies not updated in N days (including ones never written), handy for regular checkups.
- 游戏内用菜单操作，服务端控制台用纯文本输出（列表、详情、删除、清空都能用）。  
  Everything works from in-game menus; the server console gets plain-text output for list, details, delete and clear.
- 删除前显示 Cookie 的描述、访问级别、缓存条数和最后更新时间（游戏内菜单；控制台先执行 `sm_cookie <名字>` 查看）。  
  Shows description, access level, cached value count and last update time before deleting (in-game menu; on the console, run `sm_cookie <name>` first).
- 查看缓存数据（游戏内）：分页显示 `authId: value`，每行可点，二次确认后只删该玩家的值。  
  View cached values (in game): paginated `authId: value` list, each row can be selected to delete just that player's value (with confirmation).
- 控制台支持 `sm_cookie <名字> delete` / `clear`，直接删除整条或只清缓存（执行前没有二次确认，删之前请先确认名字）。  
  On the console, `sm_cookie <name> delete` / `clear` acts immediately, so double-check the name first.
- 清空全部缓存值：只清 `sm_cookie_cache`，保留 Cookie 注册行。  
  Clear all cached values while keeping the cookie registration row.
- 删除整条 Cookie：先删缓存再删注册，使用事务提交。  
  Delete the whole cookie: cached values and registration are removed in one transaction.

---

## 依赖 / Dependencies

- **[SourceMod](https://www.sourcemod.net/)** 1.12 或更高 / 1.12 or higher
- `configs/databases.cfg` 中需要有 `clientprefs` 配置（默认已存在）/ the `clientprefs` section in `configs/databases.cfg` is required (present by default)

---

## 安装 / Installation

1. 将 `clientprefs_manager.smx` 放入 `addons/sourcemod/plugins/`。  
   Put `clientprefs_manager.smx` into `addons/sourcemod/plugins/`.
2. 重启服务器或在控制台执行 `sm plugins load clientprefs_manager`。  
   Restart the server or run `sm plugins load clientprefs_manager`.

---

## 命令 / Commands

| 命令 / Command | 说明 / Description |
|----------------|--------------------|
| `sm_cookie` | 列出所有 Cookie / list every cookie |
| `sm_cookie <名字>` | 查看详情和缓存值 / show a cookie and its cached values |
| `sm_cookie <名字> delete` | 删除整条 Cookie / delete a cookie |
| `sm_cookie <名字> clear` | 清空缓存值，保留注册行 / clear cached values |
| `sm_cookie_delete <名字>` | `sm_cookie <名字>` 的快捷方式 / shortcut for `sm_cookie <name>` |
| `sm_cookie_stale [天数]` | 列出 N 天未更新的 Cookie，默认 30 天 / stale cookies, default 30 days |

`delete` / `clear` 只在服务端控制台可用。  
`delete` / `clear` are console-only.

菜单流程 / Menu flow:

```
Cookie 列表（名字 + 缓存条数 + 最后写入日期）
└ 确认页（描述 / 权限 / 缓存条数 / 最后更新）
   ├ 确认删除（缓存 + 注册行一起删）
   ├ 查看缓存数据 → 每行可点 → 确认后删除单条
   ├ 清空全部缓存值（保留注册行）
   └ 取消 → 回列表
```

---

## 注意事项 / Notes

- 删除只改数据库；在线玩家的 clientprefs 内存缓存要等他们重进服务器才清空。  
  Deletion only touches the database; online players keep their in-memory values until they reconnect.
- "最后更新"取的是 `sm_cookie_cache.timestamp`，即最近一次玩家值被写入（插件 `Cookie.Set`）的时间；删除缓存值不会回写这个时间。  
  "Last update" comes from `sm_cookie_cache.timestamp`, the last time a player value was written by a plugin; deleting cached values does not update it.
- 如果该 Cookie 仍被某个插件注册，插件重载后会自动重新创建它。  
  If a plugin still registers the cookie, it will be recreated the next time that plugin reloads.
- Cookie 名字实际只能用到 **29 字符**：clientprefs 会静默截断 30 字符的名字，导致写库正常但重连后读回空值。查看数据时以数据库里的真实名字为准。  
  Cookie names are effectively limited to **29 characters**: clientprefs silently truncates 30-character names, which makes writes succeed but reads return empty after a reconnect. Always compare against the real name stored in the database.

---

## 已知问题 / Known Issues

- 无 / None.
