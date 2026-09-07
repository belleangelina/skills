---
name: windows-docx-rendering
description: 在 Windows 上安全调用 LibreOffice 渲染、转换和检查 DOCX，规避错误的 UserInstallation URI 导致的卡死及 bootstrap.ini 损坏误报。处理 Windows 本地或 UNC/SMB 路径下的 Word 文档，并需要与 documents 技能配合完成渲染 QA 时使用。
---

# Windows DOCX 渲染

将本技能与 `documents` 技能配合使用。本技能只补充 Windows/LibreOffice 的启动与故障规避规则，文档编辑和质量要求仍以 `documents` 技能为准。

## 安全渲染流程

1. 将待处理 DOCX 复制到本机临时目录，不要让 LibreOffice 直接转换 UNC/SMB 路径中的文件。
2. 为本次任务创建独立的本机 LibreOffice 用户配置目录。
3. 将配置目录转换为 `file:///C:/...` 形式的 URI：

```powershell
$ErrorActionPreference = 'Stop'
$profileUri = 'file:///' + $profilePath.Replace('\', '/')
$profileArg = '-env:UserInstallation=' + $profileUri

if ($profileArg -eq '-env:UserInstallation=')
{
    throw 'LibreOffice UserInstallation URI is empty'
}
```

使用 `.Replace()` 而不是 `-replace`。后者使用正则表达式，在 PowerShell、
JSON 或其他命令封装层之间传递时容易因反斜杠转义丢失而变成非法模式 `\`；
若脚本仍继续执行，LibreOffice 实际收到的会是空参数
`-env:UserInstallation=`，并可能误报 `bootstrap.ini` 已损坏。

4. 启动前输出或记录 `$profileArg`，确认它以
   `-env:UserInstallation=file:///C:/` 开头，再使用独立配置目录执行无界面转换：

```powershell
& 'C:\Program Files\LibreOffice\program\soffice.com' `
    --headless `
    $profileArg `
    --convert-to pdf `
    --outdir $outputDir `
    $localDocx

if ($LASTEXITCODE -ne 0)
{
    throw "LibreOffice conversion failed: $LASTEXITCODE"
}
```

5. 确认 PDF 已生成后，再使用当前环境中已验证可用的 PDF 栅格化工具生成逐页 PNG，并检查每一页。

## 禁止事项

- 不要使用 `file://C:\...`、包含反斜杠的 URI，或把盘符冒号编码为 `%3A`。
- 不要在 URI 构造报错后继续启动 LibreOffice；必须设置 `$ErrorActionPreference = 'Stop'`，且禁止传入空的 `-env:UserInstallation=`。
- 当前 `documents` 技能附带的 `render_docx.py` 若在 Windows 上生成错误的 LibreOffice 配置 URI，不要直接调用或反复重试。
- 出现弹窗、超时或“`bootstrap.ini` 已损坏”提示后，立即停止重试并检查启动参数；不要据此修改 `C:\Program Files\LibreOffice\program\bootstrap.ini` 或重装 LibreOffice。
- 不要笼统结束所有 `soffice`/`soffice.bin` 进程。只能结束能够确认由本次任务启动的进程，避免影响用户正在使用的 LibreOffice。
- 不要为了通过 QA 而声称未实际生成、检查的页面已经通过视觉审查。

## 故障判断

遇到 `bootstrap.ini` 损坏提示时，依次检查：

1. `bootstrap.ini` 的内容、时间和读取权限。
2. `soffice.com --version` 是否正常。
3. 本次 `UserInstallation` 是否为合法的 `file:///C:/...` URI。
4. 使用 `Win32_Process.CommandLine` 检查本轮 `soffice.com` 和 `soffice.bin` 实际收到的参数；如果看到 `-env:UserInstallation=`，应先修复 URI 构造和错误处理。

如果前两项正常而第三项或第四项异常，应判断为启动参数导致的误报，不要改动安装文件。
