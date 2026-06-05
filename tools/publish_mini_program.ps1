param(
    [string]$MiniProgramId,
    [string]$MiniProgramRoot,
    [string]$RepoRoot,
    [switch]$SkipBuildPubGet,
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
        throw "Unable to resolve the script root for publish_mini_program.ps1."
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
        throw "Provide -MiniProgramId or -MiniProgramRoot."
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

function Invoke-LegacyPublishTool {
    $toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\publish_mini_program.dart"
    $arguments = @(
        "run",
        $toolPath,
        "--output", $Output
    )

    if ($MiniProgramRoot) { $arguments += @("--mini-program-root", $MiniProgramRoot) }
    if ($RepoRoot) { $arguments += @("--repo-root", $RepoRoot) }
    if ($MiniProgramId) { $arguments += @("--id", $MiniProgramId) }
    if ($SkipBuildPubGet) { $arguments += "--skip-build-pub-get" }

    Push-Location $RepoRoot
    try {
        & dart @arguments
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

if ($Output -eq "json") {
    Write-Warning "publish_mini_program.ps1 is falling back to the legacy Dart entrypoint because -Output json is not part of the public miniprogram CLI surface."
    Invoke-LegacyPublishTool
    return
}

$resolvedMiniProgramId = Resolve-MiniProgramId
$miniprogramExecutable = Resolve-MiniprogramExecutable
$arguments = @("publish", $resolvedMiniProgramId)

if ($MiniProgramRoot) { $arguments += @("--mini-program-root", $MiniProgramRoot) }
if ($RepoRoot) { $arguments += @("--repo-root", $RepoRoot) }
if ($SkipBuildPubGet) { $arguments += "--skip-build-pub-get" }

Push-Location $RepoRoot
try {
    & $miniprogramExecutable @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
