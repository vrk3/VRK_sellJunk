# VRK Drag-Drop Window + Minimap Fix + Debug + Crash Fix

## Status
Approved by user 2026-04-28. Implementation pending.

---

## 1. Fix: MainFrame nil crash on open

**Error:** `VRK\ui\MainFrame.lua:158: bad argument #1 to 'ipairs' (table expected, got nil)`

**Root cause:** `ShowTab` calls `ipairs(self.panelFrames)` but `self.panelFrames` can be nil if `Build()` step 10 didn't run or failed silently. The step 7/8/9 pcall error handlers create fallback panel objects but don't protect step 10 from also failing.

**Fix:** Add a nil guard in `ShowTab`:

```lua
function MainFrame:ShowTab(index)
    if not self.panelFrames then return end  -- guard
    for i, f in ipairs(self.panelFrames) do
```

Also ensure the error handlers in Build steps 7/8/9 always set `self.panelFrames` even if a step fails, by moving the `panelFrames` assignment before the error handlers and making the fallback graceful.

---

## 2. Fix: Right-Click on Minimap Button

**Problem:** Right-clicking the minimap button does nothing. Left-click works fine.

**Root cause:** `LibDBIcon-1.0` buttons don't automatically route right/middle mouse events to the LDB data object's `OnClick` handler — only left-click is handled by default.

**Solution:** After `DBIcon:Register()` succeeds, find the actual minimap button via `DBIcon:GetMinimapButton("VRK")` and hook its `OnMouseUp` script to detect right-click and middle-click.

**Implementation:**
- In `MinimapButton:OnLoad()`, after successful `DBIcon:Register()`, call `self:SetupButtonHooks()`
- `SetupButtonHooks()` obtains the button, verifies it's not already hooked, then hooks `OnMouseUp`
- Right-click → `ShowQuickMenu()` (existing behavior, just wasn't firing)
- Middle-click → `ShowDragDropWindow()` (new)

---

## 3. New Feature: Drag-Drop Window

### Overview

Middle-click on the minimap button opens a resizable window with three drop zones — **Sell**, **Destroy**, **Always Keep** — that accept dragged bag items.

### Visual Layout

```
┌────────────────────────────────────── VRK ───────────────────────────┐
│  ×                                                                        │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────────┐     │
│  │   SELL       │   │   DESTROY    │   │   ALWAYS KEEP           │     │
│  │   (green)    │   │   (red)      │   │   (blue)               │     │
│  │              │   │              │   │                        │     │
│  │  [item rows] │   │  [item rows] │   │   [item rows]          │     │
│  │              │   │              │   │                        │     │
│  │  0 items     │   │  0 items     │   │   0 items              │     │
│  │  [Clear]     │   │  [Clear]     │   │   [Clear]              │     │
│  └──────────────┘   └──────────────┘   └────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Window Properties

| Property | Value |
|---|---|
| Default size | 600 × 400 |
| Min size | 420 × 280 |
| Max size | 900 × 600 |
| Position | Saved to `VRK.db.global.dragDropWindow` |
| Movable | Yes, drag title bar |
| Resizable | Yes, drag bottom-right corner |

### Drop Zone Behavior

Each of the three sections accepts `OnReceiveDrag`. When a WoW cursor item is dropped:

1. Read `GetCursorInfo()` — confirm type is `"item"`
2. Get the item link
3. Add to the appropriate list via `Lists:Add(listName, link)`
4. Print confirmation: `"Added to Sell: [link]"` / `"Added to Destroy: [link]"` / `"Protected: [link]"`
5. Refresh that section

**No confirmation dialog** — instant add.

When the cursor hovers over a section (drag enter), highlight the section border with that list's color at full opacity.

### Section Behavior

Each section:
- Colored top strip: green (Sell #00FF00), red (Destroy #FF0000), blue (Always Keep #0088FF)
- Header text with list name
- Scrollable item list (same pattern as ListPanel rows)
- Bottom row: item count + Clear button
- Double-clicking an item row removes it from that list
- Hover shows tooltip with item link

### Window Frame

- Title bar: `"VRK — Drag Items Here"` with VRK gold color
- Close button (top-right X)
- All three sections resize together as window resizes — each takes 1/3 of inner width, all share the same height
- Sections use `OnEnter`/`OnLeave` to highlight border on drag hover

### Data Flow

```
Middle-click minimap → ShowDragDropWindow()
  → Create/Show DragDropWindow frame
  → RefreshAllSections() → Lists:GetAll(sell/destroy/protect)
  → Render rows in each section

Drop on section → OnReceiveDrag
  → GetCursorInfo() → item link
  → Lists:Add(listName, link)
  → VRK:Print confirmation
  → Refresh section

Escape or X click → Hide window
```

---

## 4. New Feature: Clickable Error Copy Link

### Problem

When a VRK error fires in-game, the user has no way to copy the error text to share it.

### Solution

On any VRK-caught error, print a chat line with a clickable hyperlink that copies the error text to the WoW clipboard when clicked.

### Implementation

**Error capture:** Every `pcall` in VRK that currently does `print("|cffFF4444VRK module '...' OnLoad error: "..tostring(err))` is updated to also store the error in `VRK._errorLog`.

**Error log format:**
```lua
VRK._errorLog = {}  -- [{ id, timestamp, text }]
-- Max 10 entries, FIFO
```

**Chat output format (on error):**
```
|cffFF4444[VRK Error]|r click to copy: |cff00FF00|Hvrkcopy:err_01|h[📋 Copy]|h|r  description of error
```

**Click handling:** Hook `SetItemRef` in VRK.lua to intercept `vrkcopy:err_XX` links and copy the corresponding error text to clipboard via `EditBox`/`HYBRID_UI_COPY_POPUP` trick (standard WoW clipboard copy technique).

**Copy confirmation:** After copying, optionally show a brief UI success indicator (e.g., `VRK:Print("Error copied to clipboard")`).

---

## 5. Files Changed

| File | Change |
|---|---|
| `VRK.lua` | Add `VRK._errorLog`, error capture in pcalls, SetItemRef hook for copy links |
| `ui/MainFrame.lua` | Nil guard in `ShowTab`, protect panelFrames initialization |
| `ui/MinimapButton.lua` | Add `SetupButtonHooks()`, hook right-click → `ShowQuickMenu()`, middle-click → `ShowDragDropWindow()` |
| `ui/DragDropWindow.lua` | **New file** — entire drag-drop window implementation |
| `VRK.toc` | Add `ui\DragDropWindow.lua` at end (after MinimapButton.lua) |

---

## 6. Open Questions (none)

All decisions made:
- Instant add on drop (no confirmation)
- No visual mockup (text-only design review)
- Window movable and resizable
- Sections resize together (1/3 each)
- Right-click goes to existing quick menu
- Middle-click opens new window
- Error copy link (Option A from brainstorming)