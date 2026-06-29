# macOS 微信双开 Skill

一个可复用的 AI Agent Skill，用于在 macOS 上创建、修复和启动第二个微信实例。

这个仓库面向 Codex、Claude Code、OpenClaw、Hermes 等支持 skill 目录结构的 AI 工具。它也可以不经过 AI 工具，直接在终端运行脚本。

English keywords: macOS WeChat dual open, WeChat double open, AI agent skill, Codex skill, Claude Code skill.

## 适用场景

这个 skill 主要解决两类问题：

- 已经配置过微信双开，但微信升级后双开失效。
- 从未配置过双开，希望自动创建一个可启动的微信分身。

默认配置：

- 主微信：`/Applications/WeChat.app`
- 分身微信：`/Applications/EarnMore.app`
- 分身 Bundle ID：`com.tencent.xinEarnMore`

脚本会维护一个复制出来的微信 app bundle，并完成这些动作：

- 从主微信复制出新的分身 app。
- 修复已有分身 app 的 `CFBundleIdentifier`。
- 移除可能导致启动拦截的 quarantine 属性。
- 使用 ad-hoc 方式重新签名分身 app。
- 校验签名和 Bundle ID。
- 启动分身微信。

## 直接使用

在仓库根目录执行：

```bash
bash scripts/wechat-dual-open.sh
```

只检查当前状态，不修改文件：

```bash
bash scripts/wechat-dual-open.sh --diagnose
```

微信升级后，如果想用最新主微信重新复制一份分身：

```bash
bash scripts/wechat-dual-open.sh --refresh-copy
```

使用自定义分身名称和 Bundle ID：

```bash
bash scripts/wechat-dual-open.sh \
  --target /Applications/WeChat-Work.app \
  --bundle-id com.tencent.xinWorkClone
```

只配置和校验，不自动启动：

```bash
bash scripts/wechat-dual-open.sh --no-launch
```

## 安装为 AI Skill

把这个仓库 clone 到你的 AI 工具的 skills 目录即可。

Codex 示例：

```bash
git clone https://github.com/dengbiao/mac-wechat-dual-open.git ~/.codex/skills/mac-wechat-dual-open
```

如果你的工具使用其他 skills 目录，也可以复制到对应位置，只要保留下面的目录结构：

```text
mac-wechat-dual-open/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── wechat-dual-open.sh
```

然后可以这样要求 AI 工具执行：

```text
使用 $mac-wechat-dual-open 帮我修复 macOS 微信双开。
```

或者：

```text
Use $mac-wechat-dual-open to repair my macOS WeChat dual-open setup.
```

## 常见命令

查看脚本完整参数：

```bash
bash scripts/wechat-dual-open.sh --help
```

修复默认分身：

```bash
bash scripts/wechat-dual-open.sh
```

重新复制并修复：

```bash
bash scripts/wechat-dual-open.sh --refresh-copy
```

指定主微信位置：

```bash
bash scripts/wechat-dual-open.sh --source /Applications/WeChat.app
```

## 安全说明

- 脚本不会修改主微信 `/Applications/WeChat.app/Contents/Info.plist`。
- 分身的 Bundle ID 必须和主微信不同。
- 破坏性操作只会作用在指定的分身 app 路径上。
- `--refresh-copy` 只会删除指定的分身 app，然后从主微信重新复制。
- 脚本只在写入 `/Applications`、修改 plist、移除 xattr、重新签名时使用 `sudo`。
- 如果签名失败，先退出分身微信，再重新运行脚本。

## 原理简述

macOS 上的微信双开通常依赖一个复制出来的 WeChat app bundle。为了让系统把它当成另一个应用，需要给分身 app 设置不同的 `CFBundleIdentifier`，再重新签名：

```bash
sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.tencent.xinEarnMore" /Applications/EarnMore.app/Contents/Info.plist
sudo codesign --force --deep --sign - /Applications/EarnMore.app
nohup /Applications/EarnMore.app/Contents/MacOS/WeChat >/dev/null 2>&1 &
```

这个仓库把上述流程封装成一个幂等脚本，并补上路径检查、诊断、quarantine 清理、签名校验和 AI skill 说明。

## License

MIT
