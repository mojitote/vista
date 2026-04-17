# Vista

macOS 原生侧边栏应用，作为 [yabai](https://github.com/koekeishiya/yabai) 的 GUI 前端，可视化管理多显示器、多 Space、多窗口。

> 仅支持 **Apple Silicon (arm64)** · **macOS 12 Monterey 以上**
>
> 已内置 **yabai v7.1.16**（arm64），用户**不需要**自己装 yabai 或动 Homebrew。

---

## 给朋友的快速指南（tl;dr）

当前版本为 ad-hoc 签名（未经 Apple 公证），按下面三步装就不会卡：

```bash
# 1. 从浏览器/微信/AirDrop 拿到 Vista-X.Y.Z-arm64.zip，双击解压，把 Vista.app 拖到 /Applications

# 2. 打开「终端」，执行一次（去掉 macOS 的"下载自互联网"隔离标记）：
xattr -dr com.apple.quarantine /Applications/Vista.app

# 3. 打开 Vista，跟着 Setup Assistant 走。其中 "配置 SIP" 要关机进恢复模式，
#    按向导里的说明操作（全程 5 分钟左右、会重启两次）
```

> 如果不执行第 2 步，双击会弹 **"Vista 已损坏，无法打开"** —— 这不是病毒，只是 Apple 对未公证应用的默认拦截。

---

## 安装（三步）

### 1. 下载并拖进 Applications

从 [Releases](https://github.com/mojitote/vista/releases/latest) 下载最新的 `Vista-X.Y.Z-arm64.zip`，双击解压，把 `Vista.app` 拖进 `/Applications`。

> **首次打开时**，由于 Vista 当前只做了本地 ad-hoc 签名，macOS Gatekeeper 会拦一次。
> 在 `访达` 里**右键** `Vista.app` → 选 **「打开」**→ 弹窗再点 **「打开」**。之后双击就能直接跑。

### 2. 跟着向导走

首次启动 Vista 会自动弹出 **设置向导** 窗口，清单里显示六项状态：

- **macOS 版本** · 需要 12+
- **SIP 部分关闭** · yabai 注入 scripting addition 必需
- **yabai 守护进程** · 一键启动/停止，不用命令行
- **scripting addition** · 一键复制命令 + 打开 Terminal
- **辅助功能权限** · 一键跳转系统设置
- **屏幕录制权限**（可选）· 启用窗口缩略图

按清单顺序点按钮，每一步都会复制对应命令到剪贴板、或打开 Terminal、或跳转系统设置。大多数用户 **5 分钟** 能过完。

> 关掉向导后，随时可以从菜单栏的 Vista 图标点 **Setup Assistant…** 重新打开。

### 3. 使用

- **鼠标热区触发**：把鼠标移到当前屏幕最左侧，停 200ms 弹出侧边栏
- **快捷键触发**：默认 `Option + Tab`（可在 Settings 里改）
- **双指/三指点击触发**（可选）：菜单栏 → Settings → Trigger Mode
- **单击 Space**：切换到该 Space
- **单击窗口**：切换到该 Space 并聚焦窗口
- **拖拽窗口到另一个 Space**：移动窗口

---

## 关于 SIP 部分关闭

> 这一步只需要做一次，之后永久生效。

macOS 的 System Integrity Protection 默认不允许把 scripting addition 注入 Dock.app —— 而 yabai 想要做"跨 Space 聚焦"这类操作必须这样注入。所以要**部分关闭** SIP（不是完全关闭，关键模块仍启用）。

**步骤**：

> ⚠️ **先看完再操作**：第 3 步要在恢复模式里手动输入命令。
> 那会儿系统是关机状态，**剪贴板不能用**，命令也没法通过浏览器/聊天工具获取。
> 请先用**另一台设备**（手机拍照、iPad、另一台电脑）把下面两条命令抄下来，再关机。

**要记下来的两条命令**：

```bash
# A（在恢复模式终端里执行）
csrutil enable --without fs --without debug --without nvram

# B（正常系统启动后、在普通终端里执行）
sudo nvram boot-args=-arm64e_preview_abi
```

**操作流程**：

1. 拿好手机 / 另一台电脑，把上面 A、B 两条记下来。
2. **关机**。
3. **进入恢复模式**：按住 **电源键** 直到出现「正在载入启动选项」→ 点 **选项** → **继续**。
4. 顶部菜单 **实用工具** → **终端**，手动输入**命令 A** 并回车。完成后关闭终端。
5. 顶部苹果菜单 → **重新启动**，让系统正常启动。
6. 登录后，打开 **Terminal.app**（或 iTerm 等），输入**命令 B** 并回车，按提示输入管理员密码。
7. 再重启一次，让 `boot-args` 生效。
8. 回到系统后在普通终端里 `csrutil status` 应显示 `System Integrity Protection status: unknown.`（这是正常的，说明是自定义配置）。

以后只要 Vista 用的是同一台机器、没动 SIP 设置，都不用再做一遍。

---

## 卸载

```bash
# 停 yabai 进程
killall yabai

# 删除 Vista
rm -rf /Applications/Vista.app

# 删 Vista 配置
rm -rf ~/Library/Application\ Support/Vista

# 删 Vista 为 yabai 装的 sudoers 条目
sudo rm /private/etc/sudoers.d/vista-yabai
```

恢复 SIP（如果你打算不再用 yabai 类工具）：恢复模式里 `csrutil enable`。

---

## 常见问题

### 点击窗口跳转没反应 / 跨 Space 操作失败

**原因**：scripting addition 没加载。

**排查**：打开 **Setup Assistant** 看 "scripting addition" 那行。如果是红/黄，点 "第 3 步" 的按钮，在 Terminal 里回车输密码。

**想每次开机自动加载**：编辑 `~/.config/yabai/yabairc`（没有就新建）加一行：

```bash
yabai -m signal --add event=dock_did_restart action="sudo /Applications/Vista.app/Contents/Resources/yabai/bin/yabai --load-sa"
```

**注意**：Dock 并不是开机就重启，所以这只在 Dock 崩/被杀之后自动加载。稳妥的做法是第一次登录后从 Setup Assistant 手动点一次。

### 原生全屏窗口（Split View）点击没反应

yabai 对 macOS 原生全屏窗口能控制的操作非常有限 —— 这是 macOS 的 WindowServer 限制，不是 Vista 或 yabai 的 bug。当前版本可以做：

- **全屏 → 非全屏 Space**：先退出全屏再移动（已实现）
- **全屏 → 全屏 Split View**：待实现
- **非全屏 → 全屏 Split View**：待实现

### Gatekeeper 反复拦截

如果你每次打开都被拦，说明第一次没走对"右键 → 打开"。在终端里执行：

```bash
sudo xattr -dr com.apple.quarantine /Applications/Vista.app
```

### 菜单栏看不到 Vista 图标

Vista 是隐藏 Dock 图标的 `LSUIElement` 应用。如果菜单栏右上角没看到侧边栏样式的小图标，可能被 macOS 折叠到隐藏区了——打开 **系统设置 → 控制中心 → 菜单栏上显示的项目** 调整。

---

## 技术栈

| 组件        | 方案                                  |
|-----------|-------------------------------------|
| 语言        | Swift 5.9                           |
| UI        | SwiftUI + AppKit (NSPanel)          |
| yabai 通信  | Unix Socket 二进制协议                   |
| 内置 yabai  | v7.1.16 arm64（MIT license）          |
| 全局快捷键     | [soffes/HotKey](https://github.com/soffes/HotKey) |
| 窗口缩略图     | CGWindowListCreateImage             |
| 项目管理      | XcodeGen                            |
| 最低版本      | macOS 12 (Monterey)                 |
| 架构        | arm64 only (Apple Silicon)          |

## 项目结构

```
vista/
├── Resources/
│   └── yabai/            # 内置 yabai 二进制 + LICENSE (MIT)
├── scripts/
│   ├── fetch-yabai.sh    # 下载 / 升级 yabai 二进制
│   └── package.sh        # 构建 + 签名 + 打 zip
├── Sources/
│   ├── App/              # 入口、AppDelegate、常量
│   ├── Services/         # yabai socket / runtime 检查 / 缩略图
│   └── Features/
│       ├── Onboarding/   # 首次启动向导
│       ├── Sidebar/      # 侧边栏面板、ViewModel、SwiftUI 视图
│       ├── HotZone/      # 鼠标热区检测
│       ├── HotKeys/      # 全局快捷键
│       ├── MenuBar/      # 菜单栏图标
│       ├── Scenes/       # Scene（工作区）管理
│       └── Settings/     # 设置界面和持久化
└── project.yml           # XcodeGen 配置
```

---

## 开发者构建

### 依赖

```bash
# Xcode 15+（完整版，不是 Command Line Tools）
# XcodeGen
brew install xcodegen
```

### 构建并运行

```bash
cd vista/

# 首次构建：拉 yabai 二进制到 Resources
./scripts/fetch-yabai.sh

# 生成 Xcode 工程
xcodegen generate

# 方式 A：命令行
xcodebuild -project Vista.xcodeproj -scheme Vista -configuration Debug build

# 方式 B：Xcode（推荐）
open Vista.xcodeproj
# 按 Cmd+R
```

### 打包分发

```bash
# ad-hoc 签名（默认，朋友圈内分发）
./scripts/package.sh

# Developer ID + 公证（正式发版）
export DEV_ID="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="vista-notary"   # 需先 `xcrun notarytool store-credentials vista-notary ...`
./scripts/package.sh
```

产物：

- `build/Vista.app` — 可直接运行
- `build/Vista-X.Y.Z-arm64.zip` — 发版用
- 终端打印 SHA-256（Homebrew Cask 需要）

### 升级内置 yabai（不推荐，7.1.18会引起位置问题）

```bash
./scripts/fetch-yabai.sh 7.1.20   # 指定版本号
git add Resources/yabai/bin/yabai
git commit -m "chore: bump yabai to v7.1.20"
```

---

## License

Vista 本身以 MIT 发布。内置的 yabai 二进制为独立作品，许可证见 `Resources/yabai/LICENSE.txt`（同为 MIT）。
