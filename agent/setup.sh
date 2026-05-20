#!/bin/bash
# 安装 vista-cmd 到 /usr/local/bin 并设置 Python 环境
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Vista Voice Setup ==="
echo ""

# 1. 编译 vista-cmd
echo "📦 编译 vista-cmd..."
cd "$PROJECT_DIR"
xcodegen generate 2>/dev/null
xcodebuild -project Vista.xcodeproj -scheme vista-cmd \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Release build 2>/dev/null

# 获取编译产物路径
BUILT=$(xcodebuild -project Vista.xcodeproj -scheme vista-cmd \
    -configuration Release -showBuildSettings 2>/dev/null \
    | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')

if [ ! -f "$BUILT/vista-cmd" ]; then
    echo "❌ 编译失败"
    exit 1
fi

# 2. 安装到 /usr/local/bin
echo "📋 安装 vista-cmd 到 /usr/local/bin..."
cp "$BUILT/vista-cmd" /usr/local/bin/vista-cmd
chmod +x /usr/local/bin/vista-cmd
echo "✅ vista-cmd 已安装"

# 3. 设置 Python 环境
echo ""
echo "🐍 设置 Python 环境..."
cd "$SCRIPT_DIR"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install -r requirements.txt -q

echo ""
echo "=== 安装完成 ==="
echo ""
echo "使用方式:"
echo "  1. 确保 yabai 在运行（启动 Vista.app 即可）"
echo "  2. 运行 agent:"
echo "     cd $SCRIPT_DIR"
echo "     source .venv/bin/activate"
echo "     export DOUBAO_API_KEY=your_key_here"
echo "     python vista_agent.py"
echo ""
echo "  或直接用 CLI:"
echo "     vista-cmd focus Terminal"
echo "     vista-cmd list-windows"
echo "     vista-cmd exec '切到编辑器'"
