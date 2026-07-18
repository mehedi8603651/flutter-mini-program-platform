param(
    [string]$RepoRoot,
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot =
    if ($PSScriptRoot) {
        $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    else {
        throw "Unable to resolve the script root for verify_global_cli.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

function Get-FreeTcpPort {
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        $candidate = Get-Random -Minimum 38080 -Maximum 48080
        $existing = Get-NetTCPConnection -State Listen -LocalPort $candidate -ErrorAction SilentlyContinue
        if (-not $existing) {
            return $candidate
        }
    }

    throw "Failed to find a free TCP port for backend verification."
}

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Workdir,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Step -Name $Name
    Push-Location $Workdir
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell converts any native stderr output into an error
        # record when ErrorActionPreference is Stop. Dart emits informational
        # activation warnings on stderr, so use the process exit code as the
        # authoritative success signal for native commands.
        $ErrorActionPreference = "Continue"
        & $FilePath @Arguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode."
    }
}

function Invoke-MiniprogramStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Workdir,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Invoke-Step `
        -Name $Name `
        -Workdir $Workdir `
        -FilePath "dart" `
        -Arguments (@(
            "pub",
            "global",
            "run",
            "mini_program_tooling:miniprogram"
        ) + $Arguments)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("miniprogram_cli_verify_" + [System.Guid]::NewGuid().ToString("N"))
$pubCache = Join-Path $tempRoot "pub_cache"
$homeRoot = Join-Path $tempRoot "home"
$workspaceRoot = Join-Path $tempRoot "workspace"
$miniProgramRoot = Join-Path $workspaceRoot "coupon_center"
$hostRoot = Join-Path $workspaceRoot "host_app"
$backendWorkspaceRoot = Join-Path $workspaceRoot "backend_workspace"
$port = Get-FreeTcpPort
$backendStarted = $false
$toolingPackageRoot = Join-Path $RepoRoot "packages\mini_program_tooling"
$sourceSnapshotDirectory = Join-Path $toolingPackageRoot ".dart_tool\pub\bin\mini_program_tooling"

New-Item -ItemType Directory -Path $pubCache -Force | Out-Null
New-Item -ItemType Directory -Path $homeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $workspaceRoot -Force | Out-Null

$previousPubCache = $env:PUB_CACHE
$previousHome = $env:HOME
$previousUserProfile = $env:USERPROFILE
$env:PUB_CACHE = $pubCache
$env:HOME = $homeRoot
$env:USERPROFILE = $homeRoot

try {
    if (Test-Path $sourceSnapshotDirectory) {
        Remove-Item -LiteralPath $sourceSnapshotDirectory -Recurse -Force
    }

    Invoke-Step `
        -Name "Activate global CLI from a temp PUB_CACHE" `
        -Workdir $RepoRoot `
        -FilePath "dart" `
        -Arguments @(
            "pub",
            "global",
            "activate",
            "--source",
            "path",
            (Join-Path $RepoRoot "packages\mini_program_tooling")
        )

    $miniprogramExecutable = Join-Path $pubCache "bin\miniprogram.bat"
    if (-not (Test-Path $miniprogramExecutable)) {
        throw "Installed miniprogram executable was not found at $miniprogramExecutable"
    }

    Invoke-MiniprogramStep `
        -Name "Create standalone mini-program" `
        -Workdir $workspaceRoot `
        -Arguments @("create", "coupon_center")

    Invoke-MiniprogramStep `
        -Name "Initialize standalone env config" `
        -Workdir $miniProgramRoot `
        -Arguments @("env", "init")

    Invoke-MiniprogramStep `
        -Name "Check standalone env status" `
        -Workdir $miniProgramRoot `
        -Arguments @("env", "status")

    Invoke-MiniprogramStep `
        -Name "Initialize a standalone artifact host workspace" `
        -Workdir $workspaceRoot `
        -Arguments @(
            "artifact-host",
            "init",
            "--root",
            $backendWorkspaceRoot
        )

    Invoke-MiniprogramStep `
        -Name "Run doctor against the standalone workspace" `
        -Workdir $miniProgramRoot `
        -Arguments @("doctor")

    Invoke-MiniprogramStep `
        -Name "Build standalone mini-program" `
        -Workdir $miniProgramRoot `
        -Arguments @("build", "coupon_center")

    Invoke-MiniprogramStep `
        -Name "Validate standalone mini-program" `
        -Workdir $miniProgramRoot `
        -Arguments @("validate", "coupon_center")

    Invoke-MiniprogramStep `
        -Name "Publish standalone mini-program to the local artifact host" `
        -Workdir $miniProgramRoot `
        -Arguments @("publish", "coupon_center")

    New-Item -ItemType Directory -Path (Join-Path $hostRoot "lib") -Force | Out-Null
    @'
name: smoke_host_app
version: 1.0.0+1

dependencies:
  flutter:
    sdk: flutter
'@ | Set-Content -Path (Join-Path $hostRoot "pubspec.yaml") -NoNewline

    Invoke-MiniprogramStep `
        -Name "Generate embedded app adapter" `
        -Workdir $hostRoot `
        -Arguments @("embed", "init")

    Invoke-MiniprogramStep `
        -Name "Start local artifact host through the installed CLI" `
        -Workdir $hostRoot `
        -Arguments @(
            "artifact-host",
            "start",
            "--port",
            "$port"
        )
    $backendStarted = $true

    Invoke-MiniprogramStep `
        -Name "Check artifact host status through the installed CLI" `
        -Workdir $hostRoot `
        -Arguments @("artifact-host", "status")

    Invoke-MiniprogramStep `
        -Name "Run doctor with a healthy artifact host" `
        -Workdir $hostRoot `
        -Arguments @("doctor")

    Invoke-MiniprogramStep `
        -Name "Stop local artifact host through the installed CLI" `
        -Workdir $hostRoot `
        -Arguments @("artifact-host", "stop")
    $backendStarted = $false

    Write-Host ""
    Write-Host "Installed miniprogram CLI verification passed." -ForegroundColor Green
}
finally {
    try {
        if (Test-Path (Join-Path $pubCache "bin\miniprogram.bat")) {
            if ($backendStarted) {
                try {
                    & dart pub global run mini_program_tooling:miniprogram artifact-host stop --root $backendWorkspaceRoot | Out-Null
                }
                catch {
                    Write-Warning "Cleanup stop failed: $_"
                }
            }

            try {
                & dart pub global run mini_program_tooling:miniprogram artifact-host reset-local --root $backendWorkspaceRoot --yes | Out-Null
            }
            catch {
                Write-Warning "Cleanup reset-local failed: $_"
            }
        }

        $stateRoot = Join-Path $RepoRoot ".mini_program"
        foreach ($path in @(
            (Join-Path $stateRoot "backend.local.json"),
            (Join-Path $stateRoot "backend.local.out.log"),
            (Join-Path $stateRoot "backend.local.err.log"),
            (Join-Path $stateRoot "backend.local.runner.cmd"),
            (Join-Path $stateRoot "backend.local.runner.sh"),
            (Join-Path $stateRoot "published_local_artifacts.json")
        )) {
            if (Test-Path $path) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path $stateRoot) {
            $remainingState = Get-ChildItem -LiteralPath $stateRoot -Force -ErrorAction SilentlyContinue
            if (-not $remainingState) {
                Remove-Item -LiteralPath $stateRoot -Force -ErrorAction SilentlyContinue
            }
        }
    }
    finally {
        $env:PUB_CACHE = $previousPubCache
        $env:HOME = $previousHome
        $env:USERPROFILE = $previousUserProfile
        try {
            # Path activation resolves the source package against the isolated
            # PUB_CACHE. Restore its package config before deleting that cache.
            Invoke-Step `
                -Name "Restore tooling package dependencies after isolated activation" `
                -Workdir $toolingPackageRoot `
                -FilePath "dart" `
                -Arguments @("pub", "get")
        }
        finally {
            if (-not $KeepTemp -and (Test-Path $tempRoot)) {
                $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
                $resolvedSystemTemp = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::GetTempPath()
                )
                if (-not $resolvedTempRoot.StartsWith(
                        $resolvedSystemTemp,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )) {
                    throw "Refusing to remove CLI verification data outside the system temp directory: $resolvedTempRoot"
                }
                Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
            }
        }
    }
}
