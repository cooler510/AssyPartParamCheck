# ============================================================================
#  sync_creotk_config.ps1
#  作用：把本项目 creotk.dat 的真实路径同步写入 Creo 的 config.pro，
#        实现插件的默认加载。项目路径变化后重新运行本脚本即可自动更新。
#
#  背景：Creo 安装目录下的 config.pro 是加密文件(%TSD-Header)，无法直接追加
#        明文行。Creo 同样能读取"明文" config.pro，因此本脚本用同目录下的
#        config.txt(明文内容) 作为基准，重写 config.pro 为明文，并把最后一行
#        更新为当前 creotk.dat 的绝对路径。
#
#  安全：首次运行会把原始 config.pro 备份为 config.pro.orig.bak（只备份一次）。
#        不移动、不删除 Creo 安装目录内的其它文件。
#
#  用法：直接运行（右键→用 PowerShell 运行），或双击 sync_creotk_config.bat。
# ============================================================================

# ---- 可配置项 ---------------------------------------------------------------
# Creo 的 config.pro 所在目录（如 Creo 版本/安装路径变化，改这里即可）
$CreoTextDir = 'D:\Program Files\PTC\Creo 4.0\M020\Common Files\text'

# creotk.dat 相对于本脚本所在目录(项目根目录)的相对路径
$DatRelativePath = 'AssyPartParamCheck\creotk.dat'
# ----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

function Write-Info($msg)  { Write-Host "[信息] $msg" }
function Write-Ok($msg)    { Write-Host "[完成] $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "[警告] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[错误] $msg" -ForegroundColor Red }

try {
    # 1) 定位脚本所在目录（项目根目录）
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Write-Info "项目根目录: $ScriptDir"

    # 2) 计算 creotk.dat 的绝对路径（随项目位置自动变化）
    $DatPath = Join-Path $ScriptDir $DatRelativePath
    if (-not (Test-Path -LiteralPath $DatPath)) {
        Write-Err "未找到 creotk.dat: $DatPath"
        Write-Err "请确认脚本放在项目根目录下，且存在 $DatRelativePath"
        exit 1
    }
    $DatPath = (Resolve-Path -LiteralPath $DatPath).Path
    Write-Info "creotk.dat 路径: $DatPath"

    # 3) 定位 config.pro / config.txt
    $ConfigPro = Join-Path $CreoTextDir 'config.pro'
    $ConfigTxt = Join-Path $CreoTextDir 'config.txt'
    if (-not (Test-Path -LiteralPath $CreoTextDir)) {
        Write-Err "未找到 Creo 配置目录: $CreoTextDir"
        Write-Err "请修改脚本顶部的 \$CreoTextDir 变量为你机器上的实际路径。"
        exit 1
    }

    # 4) 首次运行备份原始 config.pro（只备份一次，防止误覆盖加密原件）
    $Backup = Join-Path $CreoTextDir 'config.pro.orig.bak'
    if ((Test-Path -LiteralPath $ConfigPro) -and (-not (Test-Path -LiteralPath $Backup))) {
        Copy-Item -LiteralPath $ConfigPro -Destination $Backup -Force
        Write-Ok "已备份原始 config.pro -> $Backup"
    }

    # 5) 选取基准内容
    #    - 若 config.pro 已是明文(不含加密头)，以它为基准（保留历次修改）
    #    - 否则用 config.txt 明文内容为基准
    #    - 都不可用时，退化为只写 creotkdat 一行（会给出警告）
    $baseLines = @()
    $usedSource = ''

    $proIsPlain = $false
    if (Test-Path -LiteralPath $ConfigPro) {
        $firstBytes = Get-Content -LiteralPath $ConfigPro -TotalCount 1 -ErrorAction SilentlyContinue
        if ($firstBytes -and ($firstBytes -notmatch '%TSD-Header')) {
            $proIsPlain = $true
        }
    }

    if ($proIsPlain) {
        $baseLines = Get-Content -LiteralPath $ConfigPro
        $usedSource = 'config.pro (明文)'
    }
    elseif (Test-Path -LiteralPath $ConfigTxt) {
        $baseLines = Get-Content -LiteralPath $ConfigTxt
        $usedSource = 'config.txt (明文副本)'
    }
    else {
        Write-Warn2 "config.pro 为加密文件且未找到 config.txt，将只写入 creotkdat 一行。"
        Write-Warn2 "如需保留其它 Creo 配置项，请先准备好明文 config.txt。"
        $baseLines = @()
        $usedSource = '(空基准)'
    }
    Write-Info "基准内容来源: $usedSource"

    # 6) 去掉旧的 creotkdat 行 + 末尾空行
    $cleaned = New-Object System.Collections.Generic.List[string]
    foreach ($line in $baseLines) {
        if ($line -match '^\s*creotkdat\b') { continue }
        $cleaned.Add($line)
    }
    while ($cleaned.Count -gt 0 -and [string]::IsNullOrWhiteSpace($cleaned[$cleaned.Count - 1])) {
        $cleaned.RemoveAt($cleaned.Count - 1)
    }

    # 7) 追加当前 creotkdat 行
    $newLine = "creotkdat $DatPath"
    $cleaned.Add($newLine)

    # 8) 写回 config.pro（明文，UTF-8 无 BOM，Windows 换行）
    $content = ($cleaned -join "`r`n") + "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPro, $content, $utf8NoBom)
    Write-Ok "已更新 config.pro 最后一行: $newLine"

    # 9) 同步更新 config.txt，保持明文副本与 config.pro 一致
    [System.IO.File]::WriteAllText($ConfigTxt, $content, $utf8NoBom)
    Write-Ok "已同步 config.txt"

    Write-Host ""
    Write-Ok "全部完成。重启 Creo 后即可默认加载该插件。"
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
