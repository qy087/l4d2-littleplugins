# L4D2 Weapon CS:GO Reload (Modified)

基于[Harry Potter](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_weapon_csgo_reload) 的l4d2_weapon_csgo_reload进行修改实现类似 CS:GO / CS2 的换弹机制。

---

## 中文说明

### 主要特性
- **换弹不清空弹夹**：通过内存补丁实现，换弹过程中弹夹内剩余子弹不会被清空。
- **独立武器配置**：所有换弹时间参数从 ConVar 迁移至 KV 配置文件（`data/l4d2_weapon_csgo_reload.cfg`），每个武器可单独设置开关和装填时间，无需修改源码或重启服务器。

### 与原版插件的区别
| 项目 | 原版插件 | 本修改版 |
|------|----------|----------|
| 不清空弹夹方式 | 通过 `SDKHook_Reload` + 恢复弹夹的 hack 方式 | 直接使用内存补丁，更高效 |
| 换弹时间配置 | 每个武器一个 ConVar，共 17 个 ConVar | 统一 KV 配置文件，支持开关和时间 |
| 配置灵活性 | 仅能调整时间，无法单独禁用某武器 | 可单独禁用任意武器的计时器填充 |

### 依赖/Require
- **SourceMod 1.11+**
- **[source-scramble](https://github.com/nosoop/SMExt-SourceScramble/releases)**
- **[left4dhooks](https://forums.alliedmods.net/showthread.php?t=321696)**

### 安装方法
1. 将编译后的 `l4d2_weapon_csgo_reload.smx` 放入 `addons/sourcemod/plugins/`
2. 将 `l4d2_weapon_csgo_reload.txt` 放入 `addons/sourcemod/gamedata/`
3. 将 `l4d2_weapon_csgo_reload.cfg` 放入 `addons/sourcemod/data/`（可自行修改参数）
4. 重启服务器或执行 `sm plugins unload l4d2_weapon_csgo_reload;sm plugins load l4d2_weapon_csgo_reload`

### 配置文件说明
配置文件位置：`addons/sourcemod/data/l4d2_weapon_csgo_reload.cfg`

示例：
```kv
"l4d2_weapon_csgo_reload"
{
	"clear_clip_on_reload"	"0" // 0 = 换弹时不清空弹夹(启用内存补丁，CS风格)，1 = 换弹时清空弹夹(恢复原版行为，禁用内存补丁)
    "weapon_smg"
    {
        "enable"            "1"      // 0=禁用, 1=启用
        "reload_clip_time"  "1.04"   // 换弹时间(秒)
    }
	......
}
```

---

## English Description

### Key Features
- **Reload without losing remaining ammo**: Achieved via memory patches . The remaining bullets in the magazine are not cleared during reload。
- **Per-weapon configuratio**: All reload time settings are moved from ConVars to a KV config file (data/l4d2_weapon_csgo_reload.cfg). Each weapon can be individually enabled/disabled and its reload time adjusted without recompiling or restarting the server。

### Differences from Original Plugin
| Feature | Original Plugin | This Modified Version |
|------|----------|----------|
| Method to keep ammo during reload | Hacky SDKHook_Reload + clip recovery | Clean memory patches, more efficient |
| Reload time configuration | One ConVar per weapon (17 ConVars) | Unified KV file with enable/switch per weapon |
| Flexibility | Only time adjustment, cannot disable per weapon | Can individually disable timer fill for any weapon |

### Configuration File
Path: `addons/sourcemod/data/l4d2_weapon_csgo_reload.cfg`

Example:
```kv
"l4d2_weapon_csgo_reload"
{
	// 0 = Do not empty clip on reload (enable memory patches, CS style), 1 = Empty clip on reload (restore vanilla behavior, disable memory patches)
	"clear_clip_on_reload"	"0"
    "weapon_smg"
    {
        "enable"            "1"      // 0=disable, 1=enable
        "reload_clip_time"  "1.04"   // reload time in seconds
    }
	......
}
```

### Credits
- **Original plugin author:[Harry Potter](https://github.com/fbef0102)**
- **windows signature:[blueblur0730](https://github.com/blueblur0730)**