#!/bin/bash
set -euo pipefail

# ============================================================
# tmp-guard 安装脚本
# ============================================================

# 下载地址（留空，发布时填写）
SRC=''

# 目标路径
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/tmp-guard.py"

echo "==> tmp-guard 安装脚本"

# -------------------- 1. 创建目录 --------------------
echo "--> 创建 $BIN_DIR"
mkdir -p "$BIN_DIR"

# -------------------- 2. 下载脚本 --------------------
if [[ -z "$SRC" ]]; then
    echo "--> 错误: SRC 下载地址未配置，请在 install.sh 中填写 SRC 变量后重试"
    exit 1
fi

echo "--> 下载 $SRC -> $BIN_PATH"
wget -O "$BIN_PATH" "$SRC"

# -------------------- 3. 添加执行权限 --------------------
chmod +x "$BIN_PATH"
echo "--> 已添加执行权限"

# -------------------- 4. 配置 shell 别名 --------------------
ALIAS_LINE='alias tg="$HOME/.local/bin/tmp-guard.py"'

setup_shell_rc() {
    local rc_file="$1"
    if [[ -f "$rc_file" ]]; then
        if grep -q "alias tg=" "$rc_file" 2>/dev/null; then
            echo "--> $rc_file 中已存在 tg 别名，跳过"
        else
            echo "$ALIAS_LINE" >>"$rc_file"
            echo "--> 已添加别名到 $rc_file"
        fi
    fi
}

setup_shell_rc "$HOME/.bashrc"
setup_shell_rc "$HOME/.zshrc"

# -------------------- 5. 完成 --------------------
echo
echo "==> 安装完成!"
echo
echo "    使用前请先执行: source ~/.bashrc   # 或 source ~/.zshrc"
echo "    验证安装:       tg help"
echo
echo "    配置开机自启 (可选):"
echo "      tg config > ~/.config/systemd/user/tmp-guard.service"
echo "      systemctl --user daemon-reload"
echo "      systemctl --user enable --now tmp-guard.service"
