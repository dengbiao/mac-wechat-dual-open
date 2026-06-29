---
name: mac-wechat-dual-open
description: Create, repair, and launch a second WeChat instance on macOS by maintaining a copied WeChat app bundle with a distinct CFBundleIdentifier and ad-hoc code signature. Use when the user wants macOS WeChat dual-open/double-open, says WeChat dual-open broke after an upgrade, has an existing EarnMore.app/WeChat clone that no longer launches, or wants a fresh second WeChat app configured.
---

# Mac WeChat Dual Open

## Overview

Use this skill to make macOS WeChat dual-open work end to end. The bundled script handles both common cases:

- Existing clone broke after WeChat upgraded: repair the clone's `CFBundleIdentifier`, remove quarantine when present, re-sign it, then launch it.
- No clone exists yet: copy `/Applications/WeChat.app` to a second app, assign a different bundle id, re-sign it, then launch it.

The default clone path is `/Applications/EarnMore.app`, matching the common Zhihu/tutorial convention. Do not edit the main `/Applications/WeChat.app` bundle id.

## Quick Start

Run the bundled script from this skill folder:

```bash
bash scripts/wechat-dual-open.sh
```

The script uses `sudo` only for privileged writes/signing under `/Applications`. Run it as the normal desktop user, not with a fully-root shell, so the final launch opens in the user's session.

## Workflow

1. Confirm macOS and source app:
   - Source defaults to `/Applications/WeChat.app`.
   - If the user installed WeChat elsewhere, pass `--source /path/to/WeChat.app`.

2. Choose target clone:
   - Default target is `/Applications/EarnMore.app`.
   - If the user already has a clone with another name, pass `--target /Applications/<Name>.app`.
   - Keep the target outside the original `WeChat.app`.

3. Run repair/create:
   - If the target app exists, the script repairs it in place.
   - If the target app is missing, the script copies the source app first.
   - If the user wants a fresh clone from the latest source app, run with `--refresh-copy`.

4. Verify and launch:
   - The script verifies `CFBundleIdentifier`, runs `codesign --verify`, then starts `Contents/MacOS/WeChat` from the clone.
   - Use `--no-launch` when only preparing the clone.

## Common Commands

Repair the default existing clone after WeChat upgrade:

```bash
bash scripts/wechat-dual-open.sh
```

Create or repair a custom clone:

```bash
bash scripts/wechat-dual-open.sh --target /Applications/WeChat-Work.app --bundle-id com.tencent.xinWorkClone
```

Re-copy from the latest main WeChat app, then configure:

```bash
bash scripts/wechat-dual-open.sh --refresh-copy
```

Inspect current state without changing files:

```bash
bash scripts/wechat-dual-open.sh --diagnose
```

## Safety Rules

- Never change `/Applications/WeChat.app/Contents/Info.plist`.
- Always keep the clone bundle id different from the source WeChat bundle id.
- Do not run destructive commands outside the selected target app.
- If the target clone is currently running, ask the user to quit that cloned WeChat before re-signing if codesign fails.
- If macOS blocks launch with a security prompt, re-run the script once; if still blocked, inspect Gatekeeper/quarantine state with `xattr -l <target.app>`.
- If multiple clones are needed, give each clone a unique target path and unique bundle id.

## Script Reference

Use `scripts/wechat-dual-open.sh --help` for all options.
