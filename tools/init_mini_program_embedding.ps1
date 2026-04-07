param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [string]$RepoRoot,
    [string]$HostAppId,
    [string]$HostVersion,
    [string]$NativeRoutePath = "/native/profile-editor",
    [switch]$Force,
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
        throw "Unable to resolve the script root for init_mini_program_embedding.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\init_mini_program_embedding.dart"

$arguments = @(
    "run",
    $toolPath,
    "--project-root", $ProjectRoot,
    "--repo-root", $RepoRoot,
    "--native-route-path", $NativeRoutePath,
    "--output", $Output
)

if ($HostAppId) { $arguments += @("--host-app-id", $HostAppId) }
if ($HostVersion) { $arguments += @("--host-version", $HostVersion) }
if ($Force) { $arguments += "--force" }

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
