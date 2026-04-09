param(
    [string]$RepoRoot,
    [string]$MiniProgramId,
    [string]$MiniProgramRoot,
    [ValidateSet("text", "json")]
    [string]$Output = "text"
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
        throw "Unable to resolve the script root for validate_delivery.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

function Resolve-MiniprogramExecutable {
    $command = Get-Command miniprogram -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw @'
The global `miniprogram` command was not found.

Install the published CLI:
  dart pub global activate mini_program_tooling

For repo-local contributor work:
  dart pub global activate --source path <repo-root>\packages\mini_program_tooling
'@
}

function Resolve-MiniProgramId {
    if ($MiniProgramId) {
        return $MiniProgramId
    }
    if (-not $MiniProgramRoot) {
        return $null
    }
    $manifestPath = Join-Path $MiniProgramRoot "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        throw "Unable to infer the mini-program id because manifest.json was not found: $manifestPath"
    }
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    if (-not $manifest.id) {
        throw "Unable to infer the mini-program id because manifest.json is missing an id: $manifestPath"
    }
    return [string]$manifest.id
}

$resolvedMiniProgramId = Resolve-MiniProgramId
$canDelegateToMiniprogram = ($Output -eq "text" -and $resolvedMiniProgramId)

if ($canDelegateToMiniprogram) {
    $miniprogramExecutable = Resolve-MiniprogramExecutable
    $arguments = @("validate", $resolvedMiniProgramId, "--repo-root", $RepoRoot)
    if ($MiniProgramRoot) {
        $arguments += @("--mini-program-root", $MiniProgramRoot)
    }

    Push-Location $RepoRoot
    try {
        & $miniprogramExecutable @arguments
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

if ($Output -eq "json") {
    Write-Warning "validate_delivery.ps1 is using the legacy Dart entrypoint because -Output json is not part of the public miniprogram CLI surface."
} elseif (-not $resolvedMiniProgramId) {
    Write-Warning "validate_delivery.ps1 is using the legacy Dart entrypoint because whole-repo validation is not part of the public miniprogram CLI surface."
}

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\validate_delivery.dart"

$arguments = @(
    "run",
    $toolPath,
    "--repo-root", $RepoRoot,
    "--output", $Output
)

if ($MiniProgramId) {
    $arguments += @("--mini-program", $MiniProgramId)
}
if ($MiniProgramRoot) {
    $arguments += @("--mini-program-root", $MiniProgramRoot)
}

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
