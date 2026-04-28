# VRK Profiles System — Design Spec

## Overview

Add per-character named profiles to VRK junk manager. Each profile holds its own sell/destroy/protect lists and remembered loot choices. Settings, stats, and history remain per-character but are independent of the active profile.

---

## Data Model

**Profile structure** — each profile lives in `VRK.db.char.profiles[name]`:

| Field | Type | Description |
|---|---|---|
| `sell` | table<itemID, true> | items on the sell list |
| `destroy` | table<itemID, true> | items on the destroy list |
| `protect` | table<itemID, true> | items on the protect list |
| `rememberedChoices` | table<itemLink, action> | remembered loot-roll choices |

**Special profile:** `"Default"` — created on first login, cannot be deleted or renamed.

**Character-level keys** (unchanged, not per-profile):

- `VRK.db.char.profiles` — table of all profiles
- `VRK.db.char.activeProfile` — string key of currently active profile
- `VRK.db.char.stats` — sell/destroy counts, gold earned
- `VRK.db.char.history` — action log
- `VRK.db.char.defaultsLoaded` — flag for first-run defaults population
- `VRK.db.global.settings` — all settings (account-wide)

**Migration:** On `PLAYER_LOGIN`, if `VRK.db.char.lists` exists but `profiles` does not, migrate:
1. Create `profiles.Default` from existing `lists` and `rememberedChoices`
2. Delete old `lists` and `rememberedChoices` keys from char
3. Set `activeProfile = "Default"`

This runs once per existing character. New characters after this change get `profiles.Default` initialized directly.

---

## Core API — Lists.lua

All list operations already read/write through `Lists:GetDB()` which returns the active profile's lists. This stays the same — callers don't change.

New functions:

| Function | Signature | Description |
|---|---|---|
| `GetProfile` | `(name) → profileTable or nil` | Get a profile by name |
| `GetCurrentProfile` | `() → profileTable` | Alias for `profiles[activeProfile]` |
| `GetActiveProfileName` | `() → string` | Returns `activeProfile` key |
| `SetActiveProfile` | `(name)` | Switch active profile, fire `VRK_PROFILE_CHANGED` |
| `CreateProfile` | `(name) → profileTable` | Create new profile as deep-copy of Default template |
| `CloneProfile` | `(fromName, toName)` | Copy sell/destroy/protect/rememberedChoices |
| `DeleteProfile` | `(name)` | Delete profile; blocked for "Default" |
| `RenameProfile` | `(oldName, newName)` | Rename profile; blocked for "Default" |
| `GetAllProfileNames` | `() → sortedTable<string>` | All profile names for UI dropdown |
| `ProfileExists` | `(name) → boolean` | Check if a profile name is taken |

---

## Events

| Event | Payload | Listeners |
|---|---|---|
| `VRK_PROFILE_CHANGED` | `oldName, newName` | `BagScan`, `Tooltip`, `LootRoll` — re-read from `Lists:GetAll()` |

---

## Settings Panel (SettingsPanel.lua)

Add to top of Settings tab, above existing controls:

**Profile selector row:**
- Label: "Profile:"
- Dropdown (read from `GetAllProfileNames()`) — shows `activeProfile` name
- On select: call `SetActiveProfile(name)`, refresh dropdown label

**Inline action buttons** (small icon buttons next to the dropdown):
- Rename (pencil icon) — opens input dialog: "New name:" pre-filled
- Delete (X icon) — `StaticPopup_Confirm` with warning; blocked for "Default" with tooltip

**Clone button:**
- Label: "Clone Profile"
- Opens dialog with:
  - Label: "Clone from:"
  - Dropdown of all profile names
  - Label: "New profile name:"
  - EditBox for new name
  - Confirm / Cancel buttons

**"Default" profile:**
- Always exists, cannot be deleted or renamed
- If the only profile, cannot be deleted (button disabled)

---

## UI Flows

### Switching Profile
1. Open VRK UI → Settings tab
2. Click Profile dropdown → select target profile
3. Lists panels (Sell/Destroy/Protect) instantly show new profile's data
4. Badge counts update

### Cloning a Profile
1. Settings tab → click "Clone Profile"
2. Dialog opens → pick source from dropdown, enter new name
3. Confirm → new profile created with copied lists + remembered choices
4. Dialog closes, dropdown refreshes, new profile auto-selected

### First Login (existing character)
1. `PLAYER_LOGIN` fires
2. Migration detects `lists` exists but no `profiles`
3. Creates `profiles.Default` from `lists` + `rememberedChoices`
4. Cleans up old keys
5. `activeProfile = "Default"`
6. No visible interruption to user

### First Login (new character after this change)
1. `PLAYER_LOGIN` fires
2. No migration needed
3. `profiles.Default` initialized empty (or from defaults if `defaultsLoaded` not set)
4. `activeProfile = "Default"`

---

## Scope Notes

- **Lists** are per-profile. `Lists:GetAll()` reads from `profiles[activeProfile]`.
- **Settings** are account-wide, unchanged.
- **Stats** are per-character, not per-profile — gold earned stays with the character.
- **History** is per-character, not per-profile — action log is chronological.
- **Remembered loot choices** are per-profile — each profile remembers its own loot roll decisions.
