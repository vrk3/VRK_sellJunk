# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Platform

WoW addon for **Ascension private server** (WotLK 3.3.5a, Interface 30300). Lua 5.1. No build system. No unit test framework — all testing is in-game.

**To test any change:** Save the file, switch to the game, type `/reload` in chat. Errors appear as red text. Verify behaviour manually.

**To reset saved data during testing:** Delete `WTF\Account\<account>\SavedVariables\VRK.lua` before logging in.

## Architecture

`VRK.lua` is loaded first and defines the global `VRK` namespace. Every other file must be loaded after it (enforced by `.toc` order).

### Module pattern

Every module self-registers in its own file:

```lua
local MyModule = {}
VRK:RegisterModule("MyModule", MyModule)

function MyModule:OnLoad()   -- called automatically after ADDON_LOADED
    self:RegisterEvent("SOME_EVENT", "Handler")
end
```

`VRK:RegisterModule()` also embeds AceEvent-3.0 into the module, giving it `RegisterEvent`, `RegisterMessage`, and `SendMessage`.

Modules communicate only via AceEvent messages — never by calling each other's internals directly. Use `VRK:GetModule("Name")` for cross-module calls that need a return value.

### Internal events

| Message | Fired by | Listened by |
|---|---|---|
| `VRK_LIST_CHANGED(listName)` | Lists | BagScan, MainFrame |
| `VRK_SETTINGS_CHANGED` | VRK.lua toggles, SettingsPanel | BagScan, MainFrame |
| `VRK_HISTORY_ADDED` | VRK:AddHistory() | MainFrame (HistoryPanel) |
| `VRK_BAG_COUNT_CHANGED(count)` | BagScan | MinimapButton (badge) |

### Key globals

| Symbol | What it is |
|---|---|
| `VRK.db` | AceDB instance — available after `ADDON_LOADED` |
| `VRK:S()` | Shortcut for `VRK.db.global.settings` |
| `VRK.lastHovered` | `{bag, slot, link}` of the last bag item hovered |
| `VRK_DEFAULT_JUNK` | Table defined in `data/DefaultJunk.lua` — loaded before VRK.lua init |

### Data layout

```
VRK.db.global.settings          -- all toggle settings (account-wide)
VRK.db.global.rememberedChoices -- [itemID] = {action, context, notified}
VRK.db.global.accountLists      -- sell/destroy/protect when listScope="account"
VRK.db.char.lists               -- sell/destroy/protect when listScope="character"
VRK.db.char.history             -- array of {action, link, value, timestamp}
VRK.db.char.stats               -- totalGoldEarned, totalItemsSold, totalItemsDestroyed
```

### UI pattern

`ListPanel` is a reusable widget — instantiate with `ListPanel:New(parent, listName, actionButtonText, actionFunc)`. It owns its own frame and binds directly to `VRK:GetModule("Lists")`. Used for the SELL, DESTROY, and PROTECT tabs.

`HistoryPanel` and `SettingsPanel` follow the same pattern: `Module:New(parent)` returns an instance with a `.frame` child.

`MainFrame` wires all panels together. Tab switching hides/shows `.frame` on each panel and calls `:Refresh()` on the newly visible one.

## Adding a new module

1. Create `modules/MyModule.lua`
2. Add it to `VRK.toc` after the existing module list
3. Follow the module pattern above — `VRK:RegisterModule` + `OnLoad`
4. Communicate via `VRK:SendMessage` / `self:RegisterMessage`

## Adding items to the default junk list

Edit `data/DefaultJunk.lua`. The table key is the numeric itemID, value is a display name string. IDs only take effect on a character's **first login** (`defaultsLoaded = false`). To re-trigger defaults, delete the SavedVariables file.

## Export string format

`VRK:v1:sell:id,id,id|destroy:id,id|protect:id,id`

Parsed by `Export:Deserialize()`. Merges into current lists (does not clear first).

## Libs (do not modify)

Copied from other addons on first setup. All in `libs/`. Load order in `.toc` must be: LibStub → CallbackHandler-1.0 → AceEvent-3.0 → AceDB-3.0 → LibDataBroker-1.1 → LibDBIcon-1.0.
