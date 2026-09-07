[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [string]$PluginCacheRoot = (Join-Path $env:USERPROFILE '.codex\plugins\cache\openai-bundled')
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$targets = foreach ($pluginName in @('browser', 'chrome'))
{
    $pluginRoot = Join-Path $PluginCacheRoot $pluginName
    if (Test-Path -LiteralPath $pluginRoot)
    {
        Get-ChildItem -LiteralPath $pluginRoot -Directory | Where-Object { $_.Name -ne 'latest' } | ForEach-Object {
            $candidates = @(
                (Join-Path $_.FullName 'scripts\browser-service.mjs'),
                (Join-Path $_.FullName 'scripts\browser-client.mjs')
            ) | Where-Object { Test-Path -LiteralPath $_ }
            $candidate = $candidates | Where-Object {
                [System.IO.File]::ReadAllText($_).Contains('addAfterSubmittedCodeHook')
            } | Select-Object -First 1
            if ($candidate)
            {
                Get-Item -LiteralPath $candidate
            }
        }
    }
}

if (-not $targets)
{
    Write-Error "未找到 Browser/Chrome 插件 bundle：$PluginCacheRoot"
    exit 3
}

$needsRepair = $false
$changedAny = $false
$unsupportedAny = $false

foreach ($target in $targets)
{
    $path = $target.FullName
    $before = [System.IO.File]::ReadAllText($path)
    $content = $before
    $changes = [System.Collections.Generic.List[string]]::new()
    $targetNeedsRepair = $false
    $targetUnsupported = $false

    $statsigPatched = 'networkOverrideFunc:(o,i)=>e.fetch(o,i),preventAllNetworkTraffic:!0'
    $statsigOriginal = 'networkOverrideFunc:(o,i)=>e.fetch(o,i),preventAllNetworkTraffic:!1'
    $statsigOriginalWithoutFlag = 'networkOverrideFunc:(o,i)=>e.fetch(o,i)},loggingEnabled:"always"'
    $statsigPatchedWithoutFlag = 'networkOverrideFunc:(o,i)=>e.fetch(o,i),preventAllNetworkTraffic:!0},loggingEnabled:"always"'
    $statsigServiceOriginalWithoutFlag = 'networkOverrideFunc:(i,s)=>t.fetch(i,s)},loggingEnabled:"always"'
    $statsigServicePatchedWithoutFlag = 'networkOverrideFunc:(i,s)=>t.fetch(i,s),preventAllNetworkTraffic:!0},loggingEnabled:"always"'
    $statsigCurrentOriginalWithoutFlag = 'networkOverrideFunc:(i,s)=>e.fetch(i,s)},loggingEnabled:"always"'
    $statsigCurrentPatchedWithoutFlag = 'networkOverrideFunc:(i,s)=>e.fetch(i,s),preventAllNetworkTraffic:!0},loggingEnabled:"always"'
    $statsigAlreadyPatched = $content.Contains($statsigPatched) -or
        $content.Contains($statsigPatchedWithoutFlag) -or
        $content.Contains($statsigServicePatchedWithoutFlag) -or
        $content.Contains($statsigCurrentPatchedWithoutFlag)
    if (-not $statsigAlreadyPatched)
    {
        if ($content.Contains($statsigOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($statsigOriginal, $statsigPatched)
                $changes.Add('禁用非必要 Statsig 网络请求')
            }
        }
        elseif ($content.Contains($statsigOriginalWithoutFlag))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($statsigOriginalWithoutFlag, $statsigPatchedWithoutFlag)
                $changes.Add('禁用非必要 Statsig 网络请求')
            }
        }
        elseif ($content.Contains($statsigServiceOriginalWithoutFlag))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($statsigServiceOriginalWithoutFlag, $statsigServicePatchedWithoutFlag)
                $changes.Add('禁用非必要 Statsig 网络请求')
            }
        }
        elseif ($content.Contains($statsigCurrentOriginalWithoutFlag))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($statsigCurrentOriginalWithoutFlag, $statsigCurrentPatchedWithoutFlag)
                $changes.Add('禁用非必要 Statsig 网络请求')
            }
        }
        else
        {
            Write-Warning "不支持的 Statsig 代码结构：$path"
            $targetUnsupported = $true
            $unsupportedAny = $true
        }
    }

    $hookPatched = 'addAfterSubmittedCodeHook({timeoutMs:1500,'
    $hookOriginal = 'addAfterSubmittedCodeHook({timeoutMs:12e3,'
    $hookCurrentPatched = 'var TJ=1500;function ZD'
    $hookCurrentOriginal = 'var TJ=1e4;function ZD'
    $hookLegacyPatched = 'var JX=1500;function OD'
    $hookLegacyOriginal = 'var JX=1e4;function OD'
    if ($content.Contains('addAfterSubmittedCodeHook({timeoutMs:TJ,'))
    {
        if (-not $content.Contains($hookCurrentPatched))
        {
            if ($content.Contains($hookCurrentOriginal))
            {
                $targetNeedsRepair = $true
                $needsRepair = $true
                if (-not $CheckOnly)
                {
                    $content = $content.Replace($hookCurrentOriginal, $hookCurrentPatched)
                    $changes.Add('缩短页面事件附加等待')
                }
            }
            else
            {
                Write-Warning "不支持的页面事件代码结构：$path"
                $targetUnsupported = $true
                $unsupportedAny = $true
            }
        }
    }
    elseif ($content.Contains('addAfterSubmittedCodeHook({timeoutMs:JX,'))
    {
        if (-not $content.Contains($hookLegacyPatched))
        {
            if ($content.Contains($hookLegacyOriginal))
            {
                $targetNeedsRepair = $true
                $needsRepair = $true
                if (-not $CheckOnly)
                {
                    $content = $content.Replace($hookLegacyOriginal, $hookLegacyPatched)
                    $changes.Add('缩短页面事件附加等待')
                }
            }
            else
            {
                Write-Warning "不支持的页面事件代码结构：$path"
                $targetUnsupported = $true
                $unsupportedAny = $true
            }
        }
    }
    elseif (-not $content.Contains($hookPatched))
    {
        if ($content.Contains($hookOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($hookOriginal, $hookPatched)
                $changes.Add('缩短页面事件附加等待')
            }
        }
        else
        {
            Write-Warning "不支持的页面事件代码结构：$path"
            $targetUnsupported = $true
            $unsupportedAny = $true
        }
    }

    $recorderPatched = 'CP([SP(),AP()],c)'
    $recorderOriginal = 'CP([SP(),AP(),EP()],c)'
    $recorderOriginalReordered = 'CP([SP(),EP(),AP()],c)'
    $recorderServicePatched = 'PD([ID(),DD()],e)'
    $recorderServiceOriginal = 'PD([ID(),RD(),DD()],e)'
    $recorderCurrentPatched = 'ZD([JD(),eM()],r)'
    $recorderCurrentOriginal = 'ZD([JD(),YD(),eM()],r)'
    $recorderLegacyPatched = 'OD([MD(),FD()],e)'
    $recorderLegacyOriginal = 'OD([MD(),BD(),FD()],e)'
    $recorderAlreadyPatched = $content.Contains($recorderPatched) -or
        $content.Contains($recorderServicePatched) -or
        $content.Contains($recorderCurrentPatched) -or
        $content.Contains($recorderLegacyPatched)
    if (-not $recorderAlreadyPatched)
    {
        if ($content.Contains($recorderOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($recorderOriginal, $recorderPatched)
                $changes.Add('关闭自动响应截图记录器')
            }
        }
        elseif ($content.Contains($recorderOriginalReordered))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($recorderOriginalReordered, $recorderPatched)
                $changes.Add('关闭自动响应截图记录器')
            }
        }
        elseif ($content.Contains($recorderServiceOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($recorderServiceOriginal, $recorderServicePatched)
                $changes.Add('关闭自动响应截图记录器')
            }
        }
        elseif ($content.Contains($recorderCurrentOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($recorderCurrentOriginal, $recorderCurrentPatched)
                $changes.Add('关闭自动响应截图记录器')
            }
        }
        elseif ($content.Contains($recorderLegacyOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($recorderLegacyOriginal, $recorderLegacyPatched)
                $changes.Add('关闭自动响应截图记录器')
            }
        }
        else
        {
            Write-Warning "不支持的响应记录器代码结构：$path"
            $targetUnsupported = $true
            $unsupportedAny = $true
        }
    }

    $siteTimeoutPatched = 'return await Promise.race([e.fetch(t,r),new Promise((n,o)=>setTimeout(()=>o(new Error("Browser site-status request timed out.")),1500))])}'
    $siteTimeoutOriginal = 'return await e.fetch(t,r)}'
    $siteTimeoutServicePatched = 'let n=await Promise.race([fA(e,r.endpoint,{method:"GET"}),new Promise((t,a)=>setTimeout(()=>a(new Error("Browser site-status request timed out.")),1500))]);'
    $siteTimeoutServiceOriginal = 'let n=await fA(e,r.endpoint,{method:"GET"});'
    $siteTimeoutCurrentPatched = 'let n=await Promise.race([kA(t,r.endpoint,{method:"GET"}),new Promise((o,i)=>setTimeout(()=>i(new Error("Browser site-status request timed out.")),1500))]);'
    $siteTimeoutCurrentOriginal = 'let n=await kA(t,r.endpoint,{method:"GET"});'
    $siteTimeoutLegacyPatched = 'let n=await Promise.race([xA(e,r.endpoint,{method:"GET"}),new Promise((t,a)=>setTimeout(()=>a(new Error("Browser site-status request timed out.")),1500))]);'
    $siteTimeoutLegacyOriginal = 'let n=await xA(e,r.endpoint,{method:"GET"});'
    if ($content.Contains($siteTimeoutCurrentOriginal))
    {
        $targetNeedsRepair = $true
        $needsRepair = $true
        if (-not $CheckOnly)
        {
            $content = $content.Replace($siteTimeoutCurrentOriginal, $siteTimeoutCurrentPatched)
            $changes.Add('为站点状态请求增加 1.5 秒失败上限')
        }
    }
    elseif ($content.Contains($siteTimeoutLegacyOriginal))
    {
        $targetNeedsRepair = $true
        $needsRepair = $true
        if (-not $CheckOnly)
        {
            $content = $content.Replace($siteTimeoutLegacyOriginal, $siteTimeoutLegacyPatched)
            $changes.Add('为站点状态请求增加 1.5 秒失败上限')
        }
    }
    elseif (-not ($content.Contains($siteTimeoutCurrentPatched) -or $content.Contains($siteTimeoutLegacyPatched) -or $content.Contains($siteTimeoutServicePatched) -or $content.Contains($siteTimeoutPatched)))
    {
        if ($content.Contains($siteTimeoutOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($siteTimeoutOriginal, $siteTimeoutPatched)
                $changes.Add('为站点状态请求增加 1.5 秒失败上限')
            }
        }
        elseif ($content.Contains($siteTimeoutServiceOriginal))
        {
            $targetNeedsRepair = $true
            $needsRepair = $true
            if (-not $CheckOnly)
            {
                $content = $content.Replace($siteTimeoutServiceOriginal, $siteTimeoutServicePatched)
                $changes.Add('为站点状态请求增加 1.5 秒失败上限')
            }
        }
        else
        {
            Write-Warning "不支持的站点状态请求代码结构：$path"
            $targetUnsupported = $true
            $unsupportedAny = $true
        }
    }

    $legacyDemoBypass = 'if(typeof t=="string"&&t.startsWith("https://red-rain-station-demo.caulfieldalice50.chatgpt.site/"))return;'
    if ($content.Contains($legacyDemoBypass))
    {
        $targetNeedsRepair = $true
        $needsRepair = $true
        if (-not $CheckOnly)
        {
            $content = $content.Replace($legacyDemoBypass, '')
            $changes.Add('移除旧的 Demo 专用绕过')
        }
    }

    if ($CheckOnly)
    {
        if ($targetUnsupported)
        {
            Write-Output "UNSUPPORTED $path"
        }
        elseif ($targetNeedsRepair)
        {
            Write-Output "NEEDS_REPAIR $path"
        }
        else
        {
            Write-Output "OK $path"
        }
        continue
    }

    if ($content -ne $before)
    {
        $backupPath = "$path.codex-timeout-original"
        if (-not (Test-Path -LiteralPath $backupPath))
        {
            [System.IO.File]::WriteAllText($backupPath, $before, $utf8NoBom)
        }

        [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
        & node --check $path 2>$null
        if ($LASTEXITCODE -ne 0)
        {
            [System.IO.File]::WriteAllText($path, $before, $utf8NoBom)
            Write-Error "JavaScript 校验失败，已恢复：$path"
            exit 4
        }

        $changedAny = $true
        Write-Output "REPAIRED $path [$($changes -join '；')]"
    }
    elseif (-not $targetUnsupported)
    {
        & node --check $path 2>$null
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "JavaScript 校验失败：$path"
            exit 4
        }
        Write-Output "OK $path"
    }
}

if ($unsupportedAny)
{
    exit 3
}

if ($CheckOnly -and $needsRepair)
{
    exit 2
}

if ($changedAny)
{
    Write-Output 'RESTART_REQUIRED 请重启 Codex 后再使用 Browser/Chrome。'
}
