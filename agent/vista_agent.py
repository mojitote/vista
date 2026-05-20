"""
vista-agent — 语音驱动的桌面助手 Agent
通过 whisper.cpp 本地语音识别 + 豆包 API 意图解析 + vista-cmd 执行

依赖安装:
    pip install faster-whisper pyaudio pyttsx3 openai

环境变量:
    DOUBAO_API_KEY    — 豆包/火山引擎 API Key
    DOUBAO_MODEL      — 模型名称 (默认: doubao-1-5-thinking-pro-250415)
    DOUBAO_BASE_URL   — API Base URL (默认: https://ark.cn-beijing.volces.com/api/v3)
    VISTA_CMD_PATH    — vista-cmd 路径 (默认: 从 DerivedData 查找)
"""

import os
import sys
import json
import subprocess
import tempfile
import wave
import struct
import threading
from pathlib import Path

# ============================================================
# 配置
# ============================================================

DOUBAO_API_KEY = os.environ.get("DOUBAO_API_KEY", "")
DOUBAO_MODEL = os.environ.get("DOUBAO_MODEL", "doubao-1-5-thinking-pro-250415")
DOUBAO_BASE_URL = os.environ.get("DOUBAO_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3")

# vista-cmd 路径：优先环境变量，其次在 DerivedData 中查找
VISTA_CMD_PATH = os.environ.get("VISTA_CMD_PATH", "")

WHISPER_MODEL = "small"  # tiny/base/small/medium/large
SAMPLE_RATE = 16000
CHANNELS = 1
SILENCE_THRESHOLD = 500  # 静音阈值
SILENCE_DURATION = 1.5   # 静音多少秒算说完

# ============================================================
# vista-cmd 调用
# ============================================================

def find_vista_cmd() -> str:
    """查找 vista-cmd 二进制路径"""
    if VISTA_CMD_PATH and os.path.exists(VISTA_CMD_PATH):
        return VISTA_CMD_PATH
    
    # 在 DerivedData 中查找
    derived_data = Path.home() / "Library/Developer/Xcode/DerivedData"
    if derived_data.exists():
        for d in derived_data.iterdir():
            if d.name.startswith("Vista-"):
                cmd_path = d / "Build/Products/Debug/vista-cmd"
                if cmd_path.exists():
                    return str(cmd_path)
    
    # 在当前目录的 build 中查找
    local_build = Path(__file__).parent.parent / "build"
    if (local_build / "vista-cmd").exists():
        return str(local_build / "vista-cmd")
    
    print("⚠️  找不到 vista-cmd，请设置 VISTA_CMD_PATH 环境变量")
    sys.exit(1)


def run_vista_cmd(args: list[str]) -> dict:
    """调用 vista-cmd 并返回结果"""
    cmd_path = find_vista_cmd()
    try:
        result = subprocess.run(
            [cmd_path] + args,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.stdout.strip():
            try:
                return json.loads(result.stdout.strip())
            except json.JSONDecodeError:
                return {"success": result.returncode == 0, "message": result.stdout.strip()}
        return {"success": result.returncode == 0, "message": result.stderr.strip() or "done"}
    except subprocess.TimeoutExpired:
        return {"success": False, "message": "命令超时"}
    except Exception as e:
        return {"success": False, "message": str(e)}


# ============================================================
# 豆包 LLM 意图解析
# ============================================================

INTENT_SYSTEM_PROMPT = """你是一个桌面操作意图解析器。用户通过语音下达桌面操控指令，你需要将其转换为 vista-cmd 命令。

可用命令:
- focus <app>        切换到指定应用
- space <index>      切换到指定桌面 (数字)
- run <command>      在终端执行命令
- close              关闭当前窗口
- move <left|right>  移动窗口到左/右屏
- fullscreen         切换全屏
- open <url>         打开 URL

App 名称映射（用户可能说中文）:
- 终端/terminal → Terminal
- 编辑器/vscode/code → "Visual Studio Code"
- 浏览器/safari → Safari
- chrome/谷歌 → "Google Chrome"
- 飞书/lark → Feishu
- 微信 → WeChat

规则:
1. 输出一行 vista-cmd 命令（不带 vista-cmd 前缀）
2. 如果无法解析为桌面操作，输出: chat <原始文本>
3. 不要输出任何解释，只输出命令

示例:
用户: "切到终端"          → focus Terminal
用户: "第三个桌面"        → space 3
用户: "跑一下 npm start"  → run npm start
用户: "关了它"            → close
用户: "移到左边"          → move left
用户: "打开 localhost"    → open http://localhost
用户: "帮我写个函数"      → chat 帮我写个函数
"""


def parse_intent_with_llm(text: str) -> list[str]:
    """通过豆包 API 解析意图，返回 vista-cmd 参数列表"""
    if not DOUBAO_API_KEY:
        # 没有 API key，直接用 exec 模式（本地 SimpleIntentParser）
        return ["exec", text]
    
    try:
        from openai import OpenAI
        client = OpenAI(api_key=DOUBAO_API_KEY, base_url=DOUBAO_BASE_URL)
        
        response = client.chat.completions.create(
            model=DOUBAO_MODEL,
            messages=[
                {"role": "system", "content": INTENT_SYSTEM_PROMPT},
                {"role": "user", "content": text}
            ],
            max_tokens=100,
            temperature=0
        )
        
        cmd_str = response.choices[0].message.content.strip()
        # 解析命令字符串为参数列表
        parts = cmd_str.split(maxsplit=1)
        if len(parts) == 1:
            return [parts[0]]
        return [parts[0], parts[1]]
        
    except Exception as e:
        print(f"⚠️  LLM 解析失败: {e}，fallback 到本地解析")
        return ["exec", text]


# ============================================================
# 语音识别 (faster-whisper)
# ============================================================

def transcribe_audio(audio_file: str) -> str:
    """使用 faster-whisper 转录音频"""
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print("❌ 请安装 faster-whisper: pip install faster-whisper")
        sys.exit(1)
    
    model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")
    segments, info = model.transcribe(audio_file, language=None)  # 自动检测语言
    
    text = "".join(segment.text for segment in segments).strip()
    return text


def record_until_silence() -> str:
    """录音直到检测到静音，返回临时 WAV 文件路径"""
    try:
        import pyaudio
    except ImportError:
        print("❌ 请安装 pyaudio: pip install pyaudio")
        sys.exit(1)
    
    pa = pyaudio.PyAudio()
    stream = pa.open(
        format=pyaudio.paInt16,
        channels=CHANNELS,
        rate=SAMPLE_RATE,
        input=True,
        frames_per_buffer=1024
    )
    
    print("🎤 开始听...")
    frames = []
    silent_chunks = 0
    has_speech = False
    chunks_per_second = SAMPLE_RATE // 1024
    silence_chunks_needed = int(SILENCE_DURATION * chunks_per_second)
    
    while True:
        data = stream.read(1024, exception_on_overflow=False)
        frames.append(data)
        
        # 计算音量
        samples = struct.unpack(f"{len(data)//2}h", data)
        rms = (sum(s*s for s in samples) / len(samples)) ** 0.5
        
        if rms > SILENCE_THRESHOLD:
            has_speech = True
            silent_chunks = 0
        else:
            silent_chunks += 1
        
        # 说过话之后静音超过阈值 → 结束
        if has_speech and silent_chunks > silence_chunks_needed:
            break
        
        # 最长录音 30 秒
        if len(frames) > chunks_per_second * 30:
            break
    
    stream.stop_stream()
    stream.close()
    pa.terminate()
    
    # 保存为临时 WAV
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    with wave.open(tmp.name, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b"".join(frames))
    
    return tmp.name


# ============================================================
# TTS 语音反馈
# ============================================================

def speak(text: str):
    """macOS 系统 TTS"""
    subprocess.run(["say", "-r", "200", text], capture_output=True)


# ============================================================
# 主循环
# ============================================================

def process_one_command():
    """处理一次语音指令"""
    # 1. 录音
    audio_file = record_until_silence()
    
    try:
        # 2. ASR
        print("🔄 识别中...")
        text = transcribe_audio(audio_file)
        if not text:
            print("❌ 没有识别到有效内容")
            return
        
        print(f"📝 识别: {text}")
        
        # 3. 意图解析
        cmd_args = parse_intent_with_llm(text)
        print(f"🎯 命令: vista-cmd {' '.join(cmd_args)}")
        
        # 4. 执行
        result = run_vista_cmd(cmd_args)
        print(f"{'✅' if result.get('success') else '❌'} {result.get('message', '')}")
        
        # 5. TTS 反馈
        speak(result.get("message", "完成"))
        
    finally:
        os.unlink(audio_file)


def main():
    print("=" * 50)
    print("  Vista Voice Agent")
    print("  说 'Ctrl+C' 退出")
    print("=" * 50)
    print()
    
    # 检查 vista-cmd
    cmd_path = find_vista_cmd()
    print(f"✅ vista-cmd: {cmd_path}")
    
    if DOUBAO_API_KEY:
        print(f"✅ 豆包 API: {DOUBAO_MODEL}")
    else:
        print("⚠️  未设置 DOUBAO_API_KEY，使用本地意图解析")
    
    print()
    
    while True:
        try:
            input("按回车开始录音（或 Ctrl+C 退出）...")
            process_one_command()
            print()
        except KeyboardInterrupt:
            print("\n👋 再见")
            break


if __name__ == "__main__":
    main()
