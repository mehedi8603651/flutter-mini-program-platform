param(
    [string]$RepoRoot,
    [switch]$SkipAnalyze,
    [switch]$SkipHosts,
    [switch]$SkipBackend,
    [switch]$SkipSdk,
    [switch]$SkipDeliveryValidation
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
        throw "Unable to resolve the script root for smoke_repo.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$powerShellExecutable =
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        "pwsh"
    }
    elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
        "powershell"
    }
    else {
        throw "Neither 'pwsh' nor 'powershell' is available on PATH."
    }

function Invoke-SmokeStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Workdir,

        [Parameter(Mandatory = $true)]
        [string[]]$Command
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan

    Push-Location $Workdir
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $commandName = $Command[0]
        $commandArguments =
            if ($Command.Length -gt 1) {
                @($Command[1..($Command.Length - 1)])
            }
            else {
                @()
            }

        $process = Start-Process `
            -FilePath $commandName `
            -ArgumentList $commandArguments `
            -WorkingDirectory $Workdir `
            -NoNewWindow `
            -Wait `
            -PassThru

        if ($process.ExitCode -ne 0) {
            throw "Step failed with exit code $($process.ExitCode)."
        }

        $stopwatch.Stop()
        $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds.ToString("0.0")
        Write-Host "PASS [$Name] $elapsedSeconds`s" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

$steps = [System.Collections.Generic.List[object]]::new()

if (-not $SkipDeliveryValidation) {
    $steps.Add([pscustomobject]@{
        Name = "Delivery validation"
        Workdir = $RepoRoot
        Command = @(
            $powerShellExecutable,
            "-NoLogo", "-NoProfile",
            "-File", (Join-Path $RepoRoot "tools\validate_delivery.ps1"),
            "-RepoRoot", $RepoRoot
        )
    })
}

if (-not $SkipBackend) {
    if (-not $SkipAnalyze) {
        $steps.Add([pscustomobject]@{
            Name = "Backend analyze"
            Workdir = (Join-Path $RepoRoot "backend\local_backend_service")
            Command = @("dart", "analyze")
        })
    }

    $steps.Add([pscustomobject]@{
        Name = "Backend test"
        Workdir = (Join-Path $RepoRoot "backend\local_backend_service")
        Command = @("dart", "test")
    })
}

if (-not $SkipSdk) {
    if (-not $SkipAnalyze) {
        $steps.Add([pscustomobject]@{
            Name = "SDK analyze"
            Workdir = (Join-Path $RepoRoot "packages\mini_program_sdk")
            Command = @("flutter", "analyze")
        })
    }

    $steps.Add([pscustomobject]@{
        Name = "SDK test"
        Workdir = (Join-Path $RepoRoot "packages\mini_program_sdk")
        Command = @("flutter", "test")
    })
}

if (-not $SkipHosts) {
    foreach ($hostApp in @("super_app_host", "partner_app_host")) {
        $hostWorkdir = Join-Path $RepoRoot "hosts\$hostApp"
        $hostLabel = $hostApp -replace "_", " "

        if (-not $SkipAnalyze) {
            $steps.Add([pscustomobject]@{
                Name = "$hostLabel analyze"
                Workdir = $hostWorkdir
                Command = @("flutter", "analyze")
            })
        }

        $steps.Add([pscustomobject]@{
            Name = "$hostLabel test"
            Workdir = $hostWorkdir
            Command = @("flutter", "test")
        })
    }
}

if ($steps.Count -eq 0) {
    Write-Host "No smoke steps selected." -ForegroundColor Yellow
    exit 0
}

$repoStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($step in $steps) {
    Invoke-SmokeStep -Name $step.Name -Workdir $step.Workdir -Command $step.Command
}
$repoStopwatch.Stop()

Write-Host ""
$elapsedMinutes = $repoStopwatch.Elapsed.TotalMinutes.ToString("0.0")
Write-Host "Smoke suite passed in $elapsedMinutes minutes." -ForegroundColor Green
