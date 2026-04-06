param(
    [Parameter(Mandatory = $true)]
    [string]$MiniProgramId,

    [string]$BaseUrl = "http://127.0.0.1:8080/api/",
    [string]$HostApp,
    [string]$SdkVersion,
    [string]$HostVersion,
    [string]$Platform,
    [string]$Locale,
    [string]$TenantId,
    [string]$PinnedVersion,
    [string]$Capabilities,
    [string]$RequestId,
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
        throw "Unable to resolve the script root for inspect_delivery.ps1."
    }

$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$toolPath = Join-Path $repoRoot "packages\mini_program_tooling\bin\inspect_delivery.dart"

$arguments = @(
    "run",
    $toolPath,
    "--mini-program", $MiniProgramId,
    "--base-url", $BaseUrl,
    "--output", $Output
)

if ($HostApp) { $arguments += @("--host-app", $HostApp) }
if ($SdkVersion) { $arguments += @("--sdk-version", $SdkVersion) }
if ($HostVersion) { $arguments += @("--host-version", $HostVersion) }
if ($Platform) { $arguments += @("--platform", $Platform) }
if ($Locale) { $arguments += @("--locale", $Locale) }
if ($TenantId) { $arguments += @("--tenant-id", $TenantId) }
if ($PinnedVersion) { $arguments += @("--pinned-version", $PinnedVersion) }
if ($Capabilities) { $arguments += @("--capabilities", $Capabilities) }
if ($RequestId) { $arguments += @("--request-id", $RequestId) }

Push-Location $repoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
