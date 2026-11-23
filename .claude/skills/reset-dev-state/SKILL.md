---
name: reset-dev-state
description: Reset RightMouseMenu's permissions and macOS state to simulate a first install. Use when the user says "清理权限缓存" (permissions only) or "我要模拟完全全新的开发" / asks for a completely fresh install (full reset).
---

# Reset RightMouseMenu to a first-install state

The Debug build (`Scripts/run.sh`) and the installed/Release build are separate apps, so each is reset on its own:

| | Development (Debug) | Installed (Release / DMG) |
|---|---|---|
| App ID | `com.stone.rightmousemenu.dev` | `com.stone.rightmousemenu` |
| Extension ID | `com.stone.rightmousemenu.dev.findersync` | `com.stone.rightmousemenu.findersync` |
| Settings suite | `com.stone.RightMouseMenu.dev.shared` | `com.stone.RightMouseMenu.shared` |
| Request folder | `~/Library/Application Support/RightMouseMenu Dev` | `~/Library/Application Support/RightMouseMenu` |

macOS keeps the state in places `tccutil` alone does not reach:

| State | Reset by |
|---|---|
| Automation permission (TCC) | `tccutil reset All <app ID>` |
| Finder extension on/off (PlugInKit election, shared by every copy with the same extension ID) | `pluginkit -e default -i <extension ID>` |
| Registered extension copies | `pluginkit -r <appex path>` |
| Settings | `defaults delete <app ID>` and `<settings suite>` |

`Scripts/reset_dev_state.sh` does all of this for one identity. It quits only that app and its extension, and restarts
Finder at the end (Finder windows close and reopen).

## Which mode

Default target is the **development** build. Add `--installed` only when the user asks about the installed / DMG copy.

- **"清理权限缓存"** (clear permission cache): `bash Scripts/reset_dev_state.sh`
  Permissions and extension registration only; settings are kept.
- **"我要模拟完全全新的开发"** (completely fresh development): `bash Scripts/reset_dev_state.sh --full`
  Also deletes the dev settings, the dev request folder and `.build` (PlugInKit rediscovers extensions still on disk).
- **Installed copy**: `bash Scripts/reset_dev_state.sh --installed` (add `--full` to delete its settings too).
  Before a full reset of the installed copy, **ask** whether to also delete `/Applications/RightMouseMenu.app`;
  delete it only if the user agrees.

Run with `--dry-run` first if unsure what it will touch. Never touch other apps' state (e.g. `cn.better365.iRightMouse`
is a different product).

## Afterwards

1. Check the script's last output: the remaining registrations should have no leading `+`.
2. Tell the user how to continue:
   - Development: `bash Scripts/run.sh` (rebuilds, registers the extension, launches "RightMouseMenu Dev").
   - Installed copy: open `/Applications/RightMouseMenu.app`.
   Then enable the extension in Permissions → Open Login Items & Extensions; Automation prompts appear on first
   use or via the Request buttons on the Permissions page.
3. If both the dev and installed extensions are enabled, Finder shows both sets of menu items; disable one while testing
   the other.
