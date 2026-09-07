---
name: alcor-remote-workspace
description: 为 Windows SMB 映射的 Alcor 工作区分流本地与 SSH 操作。Codex 位于 Y:\work\alcor、Y:\face24\alcor 或对应 UNC 路径时，Git/repo、Linux/POSIX 操作和构建走 SSH，源码编辑及 Windows 设备操作留在本地。
---

# Alcor 远程工作区

## 环境与路径

按当前工作区选择对应 Linux 根目录，子路径保持不变：

| Windows 根目录 | Linux 根目录 |
| --- | --- |
| `Y:\work\alcor` 或 `\\192.168.52.130\share\work\alcor` | `/home/manbo/work/alcor` |
| `Y:\face24\alcor` 或 `\\192.168.52.130\share\face24\alcor` | `/home/manbo/face24/alcor` |

- SSH 主机为 `192.168.52.130`，使用 `~/.ssh/config` 中的用户名和密钥，不保存凭据。
- 先读取项目 `AGENTS.md`；其仓库、构建和提交规则优先。
- 当前环境已经是 Linux 且位于对应项目目录时直接执行，不建立嵌套 SSH。

Windows 映射场景开始远程操作前，确认 SSH 连接，并检查当前工作区对应的 Linux 根目录包含 `.repo`。

## 操作分流

### 保留在本地

- 使用 `apply_patch` 精准编辑源文件。
- 读取少量已知文件、针对少数目录执行文本搜索。
- 查看图片、Office、PDF 等本地资料。
- 使用 Windows COM 串口、浏览器、Web 接口和本机设备工具。
- 处理只存在于 Windows 的临时文件或用户目录文件。

### 通过 SSH 或直接在 Linux 执行

- 所有 Git 状态、差异、历史、分支、索引、属性和文件模式检查。
- `repo` 清单、子仓库定位和其他依赖 Linux 项目布局的操作。
- 符号链接、硬链接、可执行位、所有者、权限、大小写敏感路径和换行符语义检查。
- Bash 脚本、Make/Ninja/AOSP 构建命令、交叉工具链和仅 Linux 可用的项目工具。
- ELF/共享库/目标文件检查，例如 `file`、`readelf`、`nm`、`objdump` 和 BuildID。
- 依赖 Linux 路径、文件锁、原子重命名、Unix socket、FIFO 或 inotify 的测试和生成器。
- 全项目或大目录递归扫描、统计、校验和、打包、批量格式检查；避免让 SMB 往返成为瓶颈。
- 需要在同一 Linux 文件系统中完成的大规模复制、移动或清理；执行前必须验证目标绝对路径和授权范围。

判断不确定时，先问：结果是否依赖 Git/POSIX/Linux 语义，或是否会递归访问大量文件。任一为是即走 SSH；普通小文件读取不增加 SSH 往返。

## PowerShell 调用远端 Bash

在 Windows PowerShell 中调用 `ssh` 时，远端 Bash 命令如果包含 `$?`、`$变量` 或 `$(...)`，必须把整段远端命令放在 PowerShell 单引号中，避免 PowerShell 在发送前先展开。不要用反斜杠转义 PowerShell 的 `$`；反斜杠只会进入参数并破坏远端 Bash 语法。

```powershell
ssh -o BatchMode=yes 192.168.52.130 'cd /home/manbo/work/alcor && log=/tmp/alcor-build.log && command >"$log" 2>&1; code=$?; printf "BUILD_EXIT=%s\n" "$code"; rm -f "$log"; exit "$code"'
```

单引号包裹后，远端命令内部优先使用 Bash 双引号。命令同时需要复杂单双引号时，拆成多个短 SSH 调用，避免构造多层转义字符串。执行构建前先用只读短命令确认 SSH 和工作区，构建后始终检查远端真实退出码。

## 共享工作区规则

- Windows 和 Linux 看到同一份源文件。不要通过 SSH 编辑器、`sed -i`、远端复制等方式绕开当前会话的源码编辑流程。
- 必须运行 Linux 格式化器或生成器时，先确认它只修改任务范围内的文件，再在远端执行并立即检查差异。
- 使用短 SSH 命令并保留真实退出码。大输出重定向到远端 `/tmp/alcor-*.log`，任务结束时删除本轮临时日志。
- 目标设备 SSH、OTA 和板端验证属于 `remote-device-validation`，不要把构建机和目标设备混为一条连接。
