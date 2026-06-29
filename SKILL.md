---
name: mac-wechat-dual-open
description: 在 macOS 上创建、修复和启动微信双开/微信分身/第二个 WeChat 实例。通过维护一个复制出来的 WeChat app bundle、设置不同的 CFBundleIdentifier、移除 quarantine 并重新 ad-hoc codesign 来恢复双开。Use when the user wants macOS WeChat dual-open/double-open, WeChat clone, second WeChat instance, says WeChat dual-open broke after upgrade, has an existing EarnMore.app clone that no longer launches, or wants a fresh second WeChat app configured.
---

# macOS 微信双开

## 概览

使用这个 skill 帮用户在 macOS 上完成微信双开。它适合两种常见场景：

- 已经配置过微信分身，但微信升级后双开失效。
- 还没有配置过，希望新建一个可启动的微信分身。

默认约定：

- 主微信：`/Applications/WeChat.app`
- 分身微信：`/Applications/EarnMore.app`
- 分身 Bundle ID：`com.tencent.xinEarnMore`

不要修改主微信 `/Applications/WeChat.app` 的 Bundle ID。只维护复制出来的分身 app。

## 快速执行

在当前 skill 目录下运行：

```bash
bash scripts/wechat-dual-open.sh
```

脚本会在需要写入 `/Applications`、修改 plist、移除 xattr、重新签名时使用 `sudo`。请用普通桌面用户运行，不要整个 shell 都切到 root，这样最后启动的分身微信会出现在当前用户会话里。

## 执行流程

1. 确认系统和主微信路径：
   - 默认主微信是 `/Applications/WeChat.app`。
   - 如果用户把微信安装在其他位置，传入 `--source /path/to/WeChat.app`。

2. 确认分身路径：
   - 默认分身是 `/Applications/EarnMore.app`。
   - 如果用户已有其他名称的分身，传入 `--target /Applications/<Name>.app`。
   - 分身路径不能放在主微信 app bundle 内部。

3. 创建或修复：
   - 如果分身已存在，默认原地修复。
   - 如果分身不存在，先从主微信复制一份。
   - 如果用户明确想从最新主微信重新复制，使用 `--refresh-copy`。

4. 校验和启动：
   - 脚本会校验 `CFBundleIdentifier` 和 codesign。
   - 默认启动分身里的 `Contents/MacOS/WeChat`。
   - 如果只想准备分身、不启动，使用 `--no-launch`。

## 常用命令

修复升级后失效的默认分身：

```bash
bash scripts/wechat-dual-open.sh
```

全新复制或用最新主微信刷新分身：

```bash
bash scripts/wechat-dual-open.sh --refresh-copy
```

创建或修复自定义分身：

```bash
bash scripts/wechat-dual-open.sh --target /Applications/WeChat-Work.app --bundle-id com.tencent.xinWorkClone
```

只诊断当前状态，不修改文件：

```bash
bash scripts/wechat-dual-open.sh --diagnose
```

查看完整参数：

```bash
bash scripts/wechat-dual-open.sh --help
```

## 安全规则

- 不要修改 `/Applications/WeChat.app/Contents/Info.plist`。
- 分身 Bundle ID 必须和主微信 Bundle ID 不同。
- 不要在用户未确认的情况下使用 `--refresh-copy` 删除已有分身。
- 如果 codesign 失败，先让用户退出分身微信，再重新执行脚本。
- 如果 macOS 安全策略阻止启动，先重新执行一次脚本；如果仍被阻止，使用 `xattr -l <target.app>` 检查 quarantine 状态。
- 如果需要多个分身，每个分身必须使用不同的 app 路径和不同的 Bundle ID。

## 给 Agent 的执行建议

优先直接运行脚本，不要手写一串 plist/codesign 命令。脚本已经包含路径检查、主微信 Bundle ID 检查、quarantine 清理、签名校验和启动逻辑。

当用户说“微信升级后双开失效”“EarnMore.app 打不开”“帮我恢复微信双开”时，默认运行：

```bash
bash scripts/wechat-dual-open.sh
```

当用户说“重新复制一份”“从最新微信重新生成分身”时，运行：

```bash
bash scripts/wechat-dual-open.sh --refresh-copy
```
