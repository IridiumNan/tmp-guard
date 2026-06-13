# tmp-guard

> 临时文件生命周期管理器 — 实时磁盘快照 + 强制清理，让 `~/tmp` 成为一个有硬期限的安全草稿空间。

## 是什么

`tmp-guard` 是一个轻量的 Python 后台服务，管理 `~/tmp` 目录下的临时文件：

- `~/tmp` 指向 `/tmp/$USER`（tmpfs 内存文件系统）—— 写入极快，重启自动清空
- 后台每秒 rsync 增量同步到磁盘快照 `~/.cache/tmp-snapshots/curr`
- 每次开机时执行快照轮换：上一次的 `curr` → `last`，上上次的 `last` → **永久删除**

**核心理念**：给你一次开机周期的时间来审查和抢救遗留文件。不抢救的就自动清理，不留垃圾。

## 安装

```bash
# 下载安装脚本
curl -fsSL 'https://github.com/IridiumNan/tmp-guard/releases/download/v0.1/install.sh' | bash

```

```bash

# 或者手动安装
mkdir -p ~/.local/bin
wget -O ~/.local/bin/tmp-guard.py <URL>
chmod +x ~/.local/bin/tmp-guard.py

# 添加别名到 shell 配置
echo 'alias tg="$HOME/.local/bin/tmp-guard.py"' >> ~/.bashrc  # bash 用户
echo 'alias tg="$HOME/.local/bin/tmp-guard.py"' >> ~/.zshrc   # zsh 用户
source ~/.bashrc  # 或 source ~/.zshrc
```

安装 systemd 用户服务（推荐，开机自启）：

```bash
tg config > ~/.config/systemd/user/tmp-guard.service
systemctl --user daemon-reload
systemctl --user enable --now tmp-guard.service
```

## 命令

| 命令 | 说明 |
|------|------|
| `tg serve` | 启动后台同步守护进程（systemd 自动调用） |
| `tg list` | 列出上一次遗留的文件（下次重启永久删除） |
| `tg list curr` | 列出本次启动以来的文件 |
| `tg list-info [curr]` | 同 list，额外显示文件大小和修改时间 |
| `tg use <文件> <目标>` | 从当前快照永久保留文件（硬链接，不占额外空间） |
| `tg last-use <文件> <目标>` | 从上次遗留快照抢救文件 |
| `tg config [en\|cn]` | 打印 systemd 服务模板 |
| `tg help [en\|cn]` | 显示帮助信息 |

## 使用场景

### 浏览器下载中转站

把 Chrome / Firefox / Edge 的默认下载目录设为 `~/tmp`。所有下载先落进 tmpfs（不走磁盘 IO），确认需要保留的文件再移走：

```bash
# 一次性：修改浏览器设置，下载目录 -> ~/tmp

# 日常操作
cd ~/tmp
ls -lh paper.pdf          # 检查下载的文件
mv paper.pdf ~/Papers/    # 需要保留 → 移走
# 不需要的文件不管它，下次重启自动消失
```

### 代码实验与快速原型

克隆一个仓库到 `~/tmp`，快速验证想法或跑测试。跑得通再搬到正经项目目录，跑不通就扔掉。

```bash
cd ~/tmp
git clone https://github.com/some/lib.git
cd lib
make test

# 如果值得保留
mv ~/tmp/lib ~/Projects/lib-vendor/

# 如果只是临时看看 —— 什么都不用做，重启即清理
```

### 压缩包内容审查

收到一个 tarball / zip，不确定里面是什么、会不会污染当前目录？先在 `~/tmp` 里解开看看。

```bash
tar xzf mysterious.tar.gz -C ~/tmp/
ls -R ~/tmp/mysterious

# 内容没问题再解到正式目录
tar xzf mysterious.tar.gz -C ~/Projects/

# 不需要的 —— 放着就行，重启消失
```

### 截图与图片随手处理

截图工具（Flameshot、Spectacle 等）直接保存到 `~/tmp`。需要用的拖走，不需要的自动过期。

```bash
# 设置截图工具保存路径为 ~/tmp

# 需要保留的
mv ~/tmp/screenshot-*.png ~/Pictures/screenshots/

# 临时标注、裁剪等中间产物一律留在 ~/tmp
```

### 日志 / 调试数据临时分析

把线上日志 dump 到 `~/tmp`，grep / awk / jq 分析完就扔。

```bash
kubectl logs pod-name > ~/tmp/pod.log
grep ERROR ~/tmp/pod.log | wc -l
# 分析完，文件留在 ~/tmp，重启自动清理
```

### 数据库导出检查

导出数据库做一次快速检查，确认数据正确后丢弃。

```bash
pg_dump -t users mydb > ~/tmp/users.sql
head -50 ~/tmp/users.sql
# 确认无误后不需要手动删除，交给 tmp-guard
```

### 文件传输暂存区

`scp` / `rsync` / `nc` 接收文件时先落到 `~/tmp`，校验完成再搬到目标位置。

```bash
# 接收端
nc -l 9999 > ~/tmp/received.bin

# 校验
sha256sum ~/tmp/received.bin

# 校验通过后移到正式位置
mv ~/tmp/received.bin ~/data/incoming/
```

### 跨重启抢救遗忘文件

下班关机，第二天开机才想起昨天有个文件没移走。在下次重启前用 `tg last-use` 抢救：

```bash
# 开机后先看看上次遗留了什么
tg list
# Output:
#   report-draft.md
#   debug-core.2423

# 抢救需要的文件（硬链接，不占额外磁盘空间）
tg last-use report-draft.md ~/Documents/
tg last-use debug-core.2423 ~/debug-dumps/
```

### 查看当前周期文件

想知道这个开机周期里 `~/tmp` 都产生了哪些文件、大小多大：

```bash
tg list curr
# 带详细信息
tg list-info curr
```

## 典型工作流

1. 把浏览器 / 下载工具的默认保存目录设为 `~/tmp`
2. 日常使用：解包、编译、随手下载，所有文件丢进 `~/tmp`
3. 产生有价值文件时，立即移走：`mv ~/tmp/report.pdf ~/Documents/`
4. 如果忘了移走，下次开机用 `tg list` 查看遗留文件
5. 在下下次开机前，用 `tg last-use` 抢救重要遗留文件

**你永远不需要手动清理 `~/tmp`** —— 工具会自动强制执行期限。

## 注意事项

- 硬链接抢救仅在目标路径与 `~/.cache` 处于同一文件系统时有效
- 1 秒同步间隔意味着极端掉电时最多丢失最后 1 秒内的写入
- 磁盘占用最多为临时文件总量的 2 倍（`curr` + `last`）
- 不要将需要跨多个开机周期保留的文件长期存放在 `~/tmp` 中

## 版本

v0.1
