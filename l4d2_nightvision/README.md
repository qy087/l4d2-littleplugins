# [L4D2] Enhanced Nightvision
A comprehensive night vision plugin for Left 4 Dead 2 that offers multiple visual modes, per‑player settings, and full translation support.

一个功能全面的 Left 4 Dead 2 夜视仪插件，提供多种视觉模式、独立玩家设置及完整翻译支持。

---

## 📖 Description | 描述

This plugin enhances the default night vision by adding two distinct types:
- **Yellow Filter** – classic night vision effect (using game's `m_bNightVisionOn`).
- **Spotlight** – creates a dynamic light entity attached to the player, with adjustable brightness.
- **Third‑party Filter** – applies custom color correction filters (`.raw` files) with adjustable intensity.

Settings are saved per player via client cookies, and all user‑facing text is fully translatable.

该插件在游戏默认夜视仪基础上增加了两种不同模式：
- **黄色滤镜** – 经典夜视效果（使用游戏原生的 `m_bNightVisionOn`）。
- **聚光灯** – 创建一个动态光源跟随玩家，亮度可调。
- **第三方滤镜** – 应用自定义色彩校正滤镜（`.raw` 文件，需要给客户端文件），强度可调。

所有设置通过客户端 Cookie 保存，玩家可见文本完全支持多语言。

---

## 🎮 Commands | 指令

| Command | Description | 描述 |
|---------|-------------|------|
| `sm_nightvisionmenu` / `sm_nvmenu` / `sm_nvs` | Open night vision settings menu | 打开夜视仪设置菜单 |
| `sm_nightvision` / `sm_nv` | Toggle night vision ON/OFF | 开关夜视仪 |
| `sm_nvbright` | Open brightness menu (spotlight only) | 打开亮度菜单（仅聚光灯模式） |

---

## ⚙️ ConVars | 控制台变量

| Cvar | Default | Description | 描述 |
|------|---------|-------------|------|
| `l4d2_nightvision_to_whom` | `3` | Which teams can use night vision: 0=off, 1=survivor only, 2=infected only, 3=both. | 哪些队伍可以使用：0=关闭，1=仅生还者，2=仅感染者，3=两者 |
| `l4d2_nightvision_type_default` | `1` | Default night vision type: 1=yellow, 2=spotlight, 3=filter. | 默认夜视类型：1=黄色滤镜，2=聚光灯，3=第三方滤镜 |
| `l4d2_nightvision_intensity_delta` | `0.05` | Step value for filter intensity adjustment (0.1–1.0). | 滤镜强度调整的步进值（0.1–1.0） |

---

## 📁 Configuration | 配置文件

### `addons/sourcemod/configs/nightvision.cfg`

Define custom filter templates. Example:

```cfg
"NightVision"
{
    "nv1"
    {
        "id"            "1"
        "display_name"  "Filter 1"
        "raw_file"      "materials/gammacase/nightvision/nv1.raw"
    }
    "nv2"
    {
        "id"            "2"
        "display_name"  "Filter 2"
        "raw_file"      "materials/gammacase/nightvision/nv2.raw"
    }
}