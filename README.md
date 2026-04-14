# Vista

macOS 原生侧边栏应用，作为 [yabai](https://github.com/koekeishiya/yabai) 的 GUI 前端，可视化管理多显示器、多 Space、多窗口。

---

## 用户安装

> 用户只需要 `Vista.app` + yabai 环境，**不需要 Xcode**。

### 1. 安装 yabai

```bash
brew install koekeishiya/formulae/yabai
```

### 2. 部分关闭 SIP（System Integrity Protection）

yabai 需要部分关闭 SIP 才能注入 scripting addition 到 Dock.app，从而控制窗口和 Space。

> 如果你只需要基本的窗口查询功能（不需要 focus space 等操作），可以跳过此步骤。但 Vista 的核心功能（切换 Space、聚焦窗口）依赖 scripting addition，**强烈建议完成此步骤**。

**步骤：**

1. **关机**

2. **进入恢复模式**
   - **Apple Silicon**：长按电源键直到出现"正在载入启动选项"，点击"选项"→"继续"
   - **Intel**：开机时按住 `Cmd+R`

3. **打开终端**（菜单栏 → 实用工具 → 终端）

4. **执行以下命令**：

   ```bash
   # Apple Silicon (macOS 13.0+)
   csrutil enable --without fs --without debug --without nvram

   # Intel (macOS 11.0+)
   csrutil disable --with kext --with dtrace --with nvram --with basesystem
   ```

   > 打印的警告信息可以安全忽略

5. **重启**

6. **（仅 Apple Silicon）启用非 Apple 签名的 arm64e 二进制**：

   ```bash
   sudo nvram boot-args=-arm64e_preview_abi
   # 然后再次重启
   ```

7. **验证 SIP 状态**：

   ```bash
   csrutil status
   # 应显示 disabled 或 unknown（部分禁用时显示 unknown 是正常的）
   ```

### 3. 配置 yabai scripting addition

```bash
# 一键配置免密 sudo：
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
```

创建或编辑 `~/.config/yabai/yabairc`，在顶部添加：

```bash
yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
sudo yabai --load-sa
```

### 4. 启动 yabai

```bash
yabai --start-service
```

### 5. macOS 系统设置

在 **系统设置 → 桌面与程序坞 → 调度中心** 中：

- ✅ "显示器具有单独的空间" — **必须开启**
- ❌ "根据最近的使用情况自动重新排列空间" — **建议关闭**（否则 Space 顺序会变，yabai 命令不可靠）

在 **系统设置 → 桌面与程序坞 → 桌面与台前调度** 中（macOS 14+）：

- ✅ "在桌面上显示项目" — **建议开启**
- "点按墙纸以显示桌面" 设为 **"仅在台前调度中"**

### 6. 运行 Vista

双击 `Vista.app` 即可运行。首次启动时需要在 **系统设置 → 隐私与安全性** 中授权：

- **辅助功能（Accessibility）** — 用于控制窗口
- **屏幕录制（Screen Recording）** — 用于截取窗口缩略图

### 使用方式

- 运行后菜单栏会出现侧边栏图标
- **热区触发**：鼠标移到当前屏幕最左侧，停留 200ms 弹出侧边栏
- **快捷键触发**：在设置中配置全局快捷键
- **点击 Space**：切换到该 Space
- **点击窗口**：切换到该 Space 并聚焦窗口
- 侧边栏会在操作后自动收起

---

## 开发者构建

> 以下步骤仅面向开发者，从源码编译 Vista。

### 额外前置条件

1. **Xcode 15+**（完整版，不是 Command Line Tools）

   从 App Store 安装后运行：

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

2. **XcodeGen**

   ```bash
   brew install xcodegen
   ```

### 构建步骤

```bash
cd vista/

# 生成 Xcode 项目
xcodegen generate

# 方式一：命令行编译
xcodebuild -project Vista.xcodeproj -scheme Vista -configuration Debug build

# 方式二：在 Xcode 中打开并运行（推荐）
open Vista.xcodeproj
# 然后按 Cmd+R 运行
```

编译产物 `Vista.app` 位于 Xcode 的 DerivedData 目录下，可以拷贝到 `/Applications/` 或任意位置使用。

## 项目结构

```
vista/Sources/
├── App/                    # 应用入口、AppDelegate、常量
├── Services/               # yabai Socket 通信、数据模型、缩略图服务
└── Features/
    ├── Sidebar/            # 侧边栏面板、ViewModel、SwiftUI 视图
    ├── HotZone/            # 鼠标左边缘热区检测
    ├── HotKeys/            # 全局快捷键管理（基于 HotKey 库）
    ├── MenuBar/            # 菜单栏图标
    └── Settings/           # 设置界面和持久化
```

## 技术栈

| 组件 | 方案 |
|------|------|
| 语言 | Swift 5.9 |
| UI | SwiftUI + AppKit (NSPanel) |
| yabai 通信 | Unix Socket 二进制协议 |
| 全局快捷键 | [soffes/HotKey](https://github.com/soffes/HotKey) |
| 窗口缩略图 | CGWindowListCreateImage |
| 项目管理 | XcodeGen |
| 最低版本 | macOS 13.0 (Ventura) |
