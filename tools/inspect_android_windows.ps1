param(
    [string]$DeviceSerial,
    [string]$ApplicationId = 'dev.miniprogram.mp_only_host',
    [string]$AdbPath,
    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $AdbPath) {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) {
        $AdbPath = $adbCommand.Source
    } elseif ($env:ANDROID_HOME) {
        $AdbPath = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    } elseif ($env:LOCALAPPDATA) {
        $AdbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }
}
if (-not $AdbPath -or -not (Test-Path -LiteralPath $AdbPath)) {
    throw 'ADB was not found. Supply -AdbPath pointing to Android SDK platform-tools/adb.'
}
if (-not $DeviceSerial) {
    $devicesOutput = & $AdbPath devices
    if ($LASTEXITCODE -ne 0) { throw 'ADB could not list devices.' }
    $devices = @($devicesOutput | Where-Object { $_ -match '^\S+\s+device$' })
    if ($devices.Count -ne 1) {
        throw 'Connect and authorize a device, then supply -DeviceSerial if multiple devices are connected.'
    }
    $DeviceSerial = ($devices[0] -split '\s+')[0]
}

function Invoke-DeviceRead {
    param([string[]]$Arguments)
    $lines = & $AdbPath -s $DeviceSerial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB command failed: $($Arguments -join ' ')" }
    return $lines
}

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("Android mini-program windows: $ApplicationId")
$report.Add("Device serial: $DeviceSerial")
foreach ($property in @('ro.product.manufacturer', 'ro.product.model', 'ro.build.version.release', 'ro.build.version.sdk')) {
    $value = Invoke-DeviceRead -Arguments @('shell', 'getprop', $property)
    $report.Add("${property}: $value")
}
$launcherResult = Invoke-DeviceRead -Arguments @(
    'shell', 'cmd', 'package', 'resolve-activity', '--brief',
    '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.HOME'
)
$launcherComponent = $launcherResult | Where-Object { $_ -match '^\S+/\S+$' } | Select-Object -Last 1
if ($launcherComponent) {
    $launcherPackage = ($launcherComponent -split '/', 2)[0]
    $report.Add("Home launcher: $launcherComponent")
    $launcherDetails = Invoke-DeviceRead -Arguments @('shell', 'dumpsys', 'package', $launcherPackage)
    foreach ($line in ($launcherDetails | Select-String 'versionCode=|versionName=' | Select-Object -First 2)) {
        $report.Add("Launcher $($line.Line.Trim())")
    }
}
$package = Invoke-DeviceRead -Arguments @('shell', 'dumpsys', 'package', $ApplicationId)
if (-not ($package -match 'versionCode=')) { throw "Package $ApplicationId is not installed." }
$report.Add('Package:')
foreach ($line in ($package | Select-String 'versionCode=|versionName=|lastUpdateTime=|pkgFlags=')) {
    $report.Add($line.Line.Trim())
}

# Keep only this application's recent-task records, not other apps' intents.
$recents = Invoke-DeviceRead -Arguments @('shell', 'dumpsys', 'activity', 'recents')
$taskBlocks = [System.Collections.Generic.List[string]]::new()
$block = [System.Collections.Generic.List[string]]::new()
foreach ($line in $recents) {
    if ($line -match '^\s*\* Recent #') {
        if ($block.Count -gt 0) { $taskBlocks.Add(($block -join "`n")) }
        $block.Clear()
    }
    if ($block.Count -gt 0 -or $line -match '^\s*\* Recent #') {
        if ($line -match '^\s*(Active|Visible) recent tasks') { break }
        $block.Add($line)
    }
}
if ($block.Count -gt 0) { $taskBlocks.Add(($block -join "`n")) }
$ownedComponent = '(?m)^\s*(?:(?:mActivityComponent|realActivity)=|intent=\{[^\r\n]*\bcmp=)' + [regex]::Escape($ApplicationId) + '/'
$ownedTasks = @($taskBlocks | Where-Object { $_ -match $ownedComponent })
$report.Add("Native Recent-task records found: $($ownedTasks.Count)")
foreach ($task in $ownedTasks) { $report.Add($task) }
$report.Add('Running activities:')
$activities = Invoke-DeviceRead -Arguments @('shell', 'dumpsys', 'activity', 'activities')
foreach ($line in $activities) {
    if ($line -match [regex]::Escape($ApplicationId)) { $report.Add($line) }
}
$report.Add('Separate native task IDs establish task creation. Check the phone UI to verify separate Recent apps cards.')
$report.Add('Some OEM launchers filter cards by package even when tasks are alive. See docs/android_native_windows_compatibility.md.')
$text = $report -join "`n"
Write-Output $text
if ($OutputFile) { Set-Content -LiteralPath $OutputFile -Value $text -Encoding UTF8 }
