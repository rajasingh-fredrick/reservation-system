param(
    [switch]$Validate,
    [switch]$ImportLegacy,
    [switch]$Apply,
    [string]$SourcePath = ".data\db"
)

$ErrorActionPreference = "Stop"
$credential = Get-Credential -UserName "appuser" -Message "Local MySQL password (used only by this shell and its child processes)"
if ($null -eq $credential) { throw "MySQL credential entry was cancelled." }
$env:MYSQL_USER = $credential.UserName
$env:MYSQL_PASSWORD = $credential.GetNetworkCredential().Password
try {
    if ($Apply -and -not $ImportLegacy) { throw "-Apply requires -ImportLegacy." }
    if ($ImportLegacy) {
        $arguments = @("run", "db:import-legacy", "--", "--source", $SourcePath)
        if ($Apply) { $arguments += "--apply" }
        & npm.cmd @arguments
        if ($LASTEXITCODE -ne 0) { throw "Legacy data import failed." }
        exit 0
    }
    & npm.cmd run db:migrate
    if ($LASTEXITCODE -ne 0) { throw "MySQL migration failed." }
    if ($Validate) {
        & npm.cmd run typecheck
        if ($LASTEXITCODE -ne 0) { throw "Typecheck failed." }
        & npm.cmd test
        if ($LASTEXITCODE -ne 0) { throw "Tests failed." }
        & npm.cmd run build
        if ($LASTEXITCODE -ne 0) { throw "Production build failed." }
        & npm.cmd run db:check
        if ($LASTEXITCODE -ne 0) { throw "Database verification failed." }
        exit 0
    }
    Write-Host "MySQL is ready. This shell has temporary credentials. Run npm.cmd test, npm.cmd run build, or npm.cmd run dev here. Exit to clear credentials."
    & powershell -NoProfile -NoExit
} finally {
    Remove-Item Env:MYSQL_PASSWORD -ErrorAction SilentlyContinue
    $credential = $null
}
