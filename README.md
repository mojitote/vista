# Vista

macOS 原生侧边栏应用，作为 [yabai](https://github.com/koekeishiya/yabai) 的 GUI 前端，可视化管理多显示器、多 Space、多窗口。

---

## 用户安装

> 用户只需要 `Vista.app` + yabai 环境，**不需要 Xcode**。

### 1. 安装 yabai v7.1.16

> **Vista 仅支持 yabai v7.1.16**。Homebrew 最新版（v7.1.18+）在 macOS Sequoia 上存在命令卡死等严重问题，请勿使用 `brew install` 安装。

```bash
# 下载 v7.1.16 预编译二进制
curl -L https://github.com/koekeishiya/yabai/releases/download/v7.1.16/yabai-v7.1.16.tar.gz -o /tmp/yabai.tar.gz

# 解压并安装到 Homebrew bin 目录（保持路径统一）
mkdir -p /tmp/yabai-extract && tar xzf /tmp/yabai.tar.gz -C /tmp/yabai-extract
sudo cp /tmp/yabai-extract/archive/bin/yabai /opt/homebrew/bin/yabai   # Apple Silicon
# sudo cp /tmp/yabai-extract/archive/bin/yabai /usr/local/bin/yabai    # Intel
sudo chmod +x /opt/homebrew/bin/yabai

# 验证版本
yabai --version
# 应输出 yabai-v7.1.16
```

> 如果之前通过 Homebrew 安装过 yabai，先执行 `brew uninstall yabai` 再进行上述步骤，避免冲突。

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

### 4.1 第二次及以后启动

首次安装完成后，后续每次登录系统通常只需要重新启动 `yabai` 主进程，并重新加载 scripting addition：

```bash
yabai --start-service
sudo yabai --load-sa
```

如果你已经在 `~/.config/yabai/yabairc` 里配置了下面这行：

```bash
yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
```

那么 Dock 重启后会自动重新注入；但在 macOS Sequoia + `yabai v7.1.16` 这类环境里，**登录后手动执行一次 `sudo yabai --load-sa` 仍然是最稳妥的做法**。

推荐把上面两行保存成你自己的启动脚本，例如：

```bash
#!/bin/zsh
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

yabai --start-service
sleep 1
sudo yabai --load-sa
```

执行方式：

```bash
chmod +x ~/bin/start-yabai.sh
~/bin/start-yabai.sh
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

编译产物 `Vista.app` 位于 Xcode 的 DerivedData 目录下。开发调试时建议直接从 DerivedData 运行，不要额外拷贝到 `/Applications/`。

## 已知问题与排错

### yabai v7.1.16+ 在 macOS Sequoia 上 scripting addition 注入失败

**症状**：`sudo yabai --load-sa` 报错 `protection failure` 或进程被直接 killed。

**原因**：yabai v7.1.16+ 使用新版 Clang 编译，scripting addition 的 loader 二进制 PAC ABI 版本为 v1（`caps 0x81`），而 Sequoia 的 Dock.app 使用 PAC ABI v0（`caps 0x80`）。内核强制 ABI 严格匹配，拒绝注入。详见 [yabai#2747](https://github.com/koekeishiya/yabai/issues/2747)。

**macOS Tahoe (26.x) 不受影响**（Dock.app 已升级到 ABI v1）。

**解决方案（任选一种）：**

**方案 A：Patch loader 的 PAC ABI 标记（推荐，可保持最新版 yabai）**

先运行一次 `sudo yabai --load-sa`（让它安装 osax 文件），然后执行 patch 脚本：

```bash
sudo bash -c '
FILE="/Library/ScriptingAdditions/yabai.osax/Contents/MacOS/loader"
read I O <<< $(otool -f "$FILE" | awk "/architecture/{i=\$2} /capabilities 0x81/{f=1} f&&/offset/{print i, \$2; exit}")
if [ -n "$O" ]; then
    printf "\x80" | dd of="$FILE" bs=1 seek=$((8 + I*20 + 4)) count=1 conv=notrunc 2>/dev/null
    printf "\x80" | dd of="$FILE" bs=1 seek=$((O + 11)) count=1 conv=notrunc 2>/dev/null
    codesign -f -s - "$FILE" 2>/dev/null
    echo "Patched! caps 0x81 -> 0x80"
else
    echo "No caps 0x81 found"
fi
'
sudo yabai --load-sa
```

> 每次 yabai 升级后需要重新执行此 patch。

**方案 B：降级到 v7.1.15**

```bash
curl -L https://github.com/koekeishiya/yabai/releases/download/v7.1.15/yabai-v7.1.15.tar.gz -o /tmp/yabai.tar.gz
mkdir -p /tmp/yabai-old && tar xzf /tmp/yabai.tar.gz -C /tmp/yabai-old
sudo cp /tmp/yabai-old/archive/bin/yabai /opt/homebrew/bin/yabai
sudo chmod +x /opt/homebrew/bin/yabai
```

降级后需重新配置 sudoers（binary hash 变了）：

```bash
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 /opt/homebrew/bin/yabai | cut -d " " -f 1) /opt/homebrew/bin/yabai --load-sa" | sudo tee /private/etc/sudoers.d/yabai
```

### yabai 命令卡住无响应

Homebrew 安装的 yabai v7.1.18 在 Sequoia 上可能出现任何命令（包括 `yabai --version`）卡住的问题。

**解决方案**：使用官方预编译的 v7.1.16 或 v7.1.15 二进制替代（参见上方降级方案）。覆盖当前正在使用的 `/opt/homebrew/bin/yabai` 后，需在 **系统设置 → 隐私与安全性 → 辅助功能** 中重新授权该路径。

### Vista 点击窗口无法跳转

可能原因：
1. **scripting addition 未加载** — 跨 Space 切换需要 SA，执行 `sudo yabai --load-sa` 并确认无报错
2. **原生全屏窗口** — `is-native-fullscreen: true` 的窗口（如全屏的 ChatGPT）yabai 无法控制，这是 macOS 限制
3. **同 Space 窗口正常、跨 Space 窗口失败** — 说明 SA 未加载，参考上述步骤

---

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
