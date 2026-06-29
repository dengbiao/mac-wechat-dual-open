# Mac WeChat Dual Open Skill

A reusable AI-agent skill for creating, repairing, and launching a second WeChat instance on macOS.

It is designed for agents such as Codex, Claude Code, OpenClaw, Hermes, and other tools that can consume a skill-style folder containing `SKILL.md` plus scripts.

## What It Does

This skill maintains a copied WeChat app bundle, defaulting to:

- Source app: `/Applications/WeChat.app`
- Clone app: `/Applications/EarnMore.app`
- Clone bundle id: `com.tencent.xinEarnMore`

The bundled script can:

- Create a fresh clone from the main WeChat app.
- Repair an existing clone after WeChat upgrades break dual-open.
- Set the clone's `CFBundleIdentifier`.
- Remove macOS quarantine attributes when present.
- Re-sign the clone with an ad-hoc signature.
- Launch the cloned WeChat executable.

## Quick Use

From this repository root:

```bash
bash scripts/wechat-dual-open.sh
```

Check state without changing files:

```bash
bash scripts/wechat-dual-open.sh --diagnose
```

Force a fresh copy from the latest main WeChat app:

```bash
bash scripts/wechat-dual-open.sh --refresh-copy
```

Use a custom clone path and bundle id:

```bash
bash scripts/wechat-dual-open.sh \
  --target /Applications/WeChat-Work.app \
  --bundle-id com.tencent.xinWorkClone
```

## Install As A Skill

Clone this repository into your agent's skills directory, or copy the folder there.

Examples:

```bash
git clone https://github.com/dengbiao/mac-wechat-dual-open.git ~/.codex/skills/mac-wechat-dual-open
```

For tools that use another skill directory, clone to that tool's skill root while preserving this folder structure:

```text
mac-wechat-dual-open/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── wechat-dual-open.sh
```

Then ask your agent:

```text
Use $mac-wechat-dual-open to repair my macOS WeChat dual-open setup.
```

## Safety Notes

- The script never changes `/Applications/WeChat.app/Contents/Info.plist`.
- The clone bundle id must differ from the source WeChat bundle id.
- Destructive actions are limited to the selected clone app path.
- `--refresh-copy` removes only the selected clone app before re-copying from source.
- The script uses `sudo` only for privileged writes/signing under `/Applications`.

If codesigning fails, quit the cloned WeChat app and run the command again.

## License

MIT
