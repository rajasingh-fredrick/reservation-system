param(
    [string]$SourceHost = "127.0.0.1",
    [ValidateRange(1, 65535)][int]$SourcePort = 3306,
    [Parameter(Mandatory = $true)][string]$DestinationHost,
    [ValidateRange(1, 65535)][int]$DestinationPort = 3306,
    [string]$SourceUser = "appuser",
    [string]$DestinationUser = "appuser",
    [string]$Database = "harmony"
)

$ErrorActionPreference = "Stop"

if ($Database -notmatch '^[a-zA-Z0-9_]{1,64}$') {
    throw "Database name must contain only letters, numbers, and underscores (maximum 64)."
}
foreach ($hostName in @($SourceHost, $DestinationHost)) {
    if ([string]::IsNullOrWhiteSpace($hostName) -or $hostName -match '[\s"'']') {
        throw "Source and destination hosts must be non-empty host names or IP addresses."
    }
}

$dumpTool = (Get-Command mysqldump.exe -ErrorAction Stop).Source
$mysqlTool = (Get-Command mysql.exe -ErrorAction Stop).Source
$sourceCredential = Get-Credential -UserName $SourceUser -Message "Enter credentials for the source MySQL server."
if ($null -eq $sourceCredential) { throw "Source credential entry was cancelled." }
$destinationCredential = Get-Credential -UserName $DestinationUser -Message "Enter credentials for the destination MySQL server."
if ($null -eq $destinationCredential) { throw "Destination credential entry was cancelled." }

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("harmony-mysql-migration-" + [guid]::NewGuid().ToString("N"))
$directorySecurity = New-Object System.Security.AccessControl.DirectorySecurity
$directorySecurity.SetAccessRuleProtection($true, $false)
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$directorySecurity.SetOwner($currentUser)
$directoryRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $currentUser,
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit,
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$directorySecurity.AddAccessRule($directoryRule)
[void][System.IO.Directory]::CreateDirectory($temporaryDirectory, $directorySecurity)

function ConvertTo-MySqlOptionValue([string]$Value) {
    if ($Value.Contains("`r") -or $Value.Contains("`n")) {
        throw "MySQL usernames and passwords cannot contain line breaks for this migration."
    }
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function New-MySqlDefaultsFile([string]$Path, [PSCredential]$Credential) {
    $user = ConvertTo-MySqlOptionValue $Credential.UserName
    $password = ConvertTo-MySqlOptionValue $Credential.GetNetworkCredential().Password
    $contents = "[client]`nuser=$user`npassword=$password`n"
    [System.IO.File]::WriteAllText($Path, $contents, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-MySqlQuery([string]$DefaultsFile, [string]$HostName, [int]$Port, [string]$Query) {
    $arguments = @(
        "--defaults-extra-file=$DefaultsFile",
        "--host=$HostName",
        "--port=$Port",
        "--batch",
        "--skip-column-names",
        "--execute=$Query"
    )
    $output = & $mysqlTool @arguments
    if ($LASTEXITCODE -ne 0) { throw "A MySQL metadata query failed on ${HostName}:$Port." }
    return ($output -join "`n").Trim()
}

function Get-TableRowCounts([string]$DefaultsFile, [string]$HostName, [int]$Port) {
    $tableOutput = Invoke-MySqlQuery $DefaultsFile $HostName $Port `
        "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$Database' AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME;"
    $tableNames = @($tableOutput -split "`n" | Where-Object { $_ -ne "" })
    $counts = @{}
    foreach ($tableName in $tableNames) {
        $identifier = $tableName.Replace('`', '``')
        $count = Invoke-MySqlQuery $DefaultsFile $HostName $Port "SELECT COUNT(*) FROM ``$identifier``;"
        $counts[$tableName] = [long]$count
    }
    return $counts
}

function Invoke-MySqlRestore([string]$DefaultsFile, [string]$HostName, [int]$Port, [string]$DumpPath) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $mysqlTool
    $arguments = @(
        "--defaults-extra-file=$DefaultsFile",
        "--host=$HostName",
        "--port=$Port",
        "--default-character-set=utf8mb4",
        "--binary-mode"
    )
    $startInfo.Arguments = ($arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join " "
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Could not start the MySQL restore client." }
    try {
        $dump = [System.IO.File]::OpenRead($DumpPath)
        try { $dump.CopyTo($process.StandardInput.BaseStream) }
        finally { $dump.Dispose() }
    } finally {
        $process.StandardInput.Close()
    }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "MySQL restore failed on ${HostName}:$Port (exit code $($process.ExitCode))." }
    $process.Dispose()
}

try {
    $sourceDefaults = Join-Path $temporaryDirectory "source.cnf"
    $destinationDefaults = Join-Path $temporaryDirectory "destination.cnf"
    $dumpPath = Join-Path $temporaryDirectory "database.sql"
    New-MySqlDefaultsFile $sourceDefaults $sourceCredential
    New-MySqlDefaultsFile $destinationDefaults $destinationCredential

    $sourceServerId = Invoke-MySqlQuery $sourceDefaults $SourceHost $SourcePort "SELECT @@server_uuid;"
    $destinationServerId = Invoke-MySqlQuery $destinationDefaults $DestinationHost $DestinationPort "SELECT @@server_uuid;"
    if ($sourceServerId -eq $destinationServerId) {
        throw "Source and destination resolve to the same MySQL server. Migration cancelled."
    }

    $sourceExists = Invoke-MySqlQuery $sourceDefaults $SourceHost $SourcePort `
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$Database';"
    if ($sourceExists -ne "1") { throw "Database '$Database' does not exist on the source server." }
    $settings = Invoke-MySqlQuery $sourceDefaults $SourceHost $SourcePort `
        "SELECT DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$Database';"
    $databaseSettings = $settings -split "`t"
    $characterSet = $databaseSettings[0]
    $collation = $databaseSettings[1]
    if ($characterSet -notmatch '^[a-zA-Z0-9_]+$' -or $collation -notmatch '^[a-zA-Z0-9_]+$') {
        throw "The source database returned unexpected character set metadata."
    }

    $destinationExists = Invoke-MySqlQuery $destinationDefaults $DestinationHost $DestinationPort `
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$Database';"
    if ($destinationExists -eq "1") {
        $destinationObjectCount = Invoke-MySqlQuery $destinationDefaults $DestinationHost $DestinationPort `
            "SELECT (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.EVENTS WHERE EVENT_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA='$Database');"
        if ($destinationObjectCount -ne "0") {
            throw "Destination database '$Database' is not empty. No data was changed."
        }
        Invoke-MySqlQuery $destinationDefaults $DestinationHost $DestinationPort `
            "ALTER DATABASE ``$Database`` CHARACTER SET $characterSet COLLATE $collation;" | Out-Null
    }

    Write-Host "Dumping '$Database' from ${SourceHost}:$SourcePort..."
    $dumpArguments = @(
        "--defaults-extra-file=$sourceDefaults",
        "--host=$SourceHost",
        "--port=$SourcePort",
        "--default-character-set=utf8mb4",
        "--single-transaction",
        "--routines",
        "--events",
        "--triggers",
        "--hex-blob",
        "--no-tablespaces",
        "--set-gtid-purged=OFF",
        "--databases",
        $Database,
        "--result-file=$dumpPath"
    )
    & $dumpTool @dumpArguments
    if ($LASTEXITCODE -ne 0) { throw "MySQL dump failed on ${SourceHost}:$SourcePort." }
    if (-not (Test-Path $dumpPath) -or (Get-Item $dumpPath).Length -eq 0) {
        throw "MySQL dump did not produce a non-empty SQL file."
    }

    $sourceRowCounts = Get-TableRowCounts $sourceDefaults $SourceHost $SourcePort
    Write-Host "Restoring database on ${DestinationHost}:$DestinationPort..."
    Invoke-MySqlRestore $destinationDefaults $DestinationHost $DestinationPort $dumpPath

    $destinationObjectCount = Invoke-MySqlQuery $destinationDefaults $DestinationHost $DestinationPort `
        "SELECT (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.EVENTS WHERE EVENT_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA='$Database');"
    $sourceObjectCount = Invoke-MySqlQuery $sourceDefaults $SourceHost $SourcePort `
        "SELECT (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.EVENTS WHERE EVENT_SCHEMA='$Database') + (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA='$Database');"
    if ($destinationObjectCount -ne $sourceObjectCount) {
        throw "Destination object count does not match the source. Keep the application offline and inspect both databases before retrying."
    }

    $destinationRowCounts = Get-TableRowCounts $destinationDefaults $DestinationHost $DestinationPort
    foreach ($tableName in $sourceRowCounts.Keys) {
        if (-not $destinationRowCounts.ContainsKey($tableName) -or $destinationRowCounts[$tableName] -ne $sourceRowCounts[$tableName]) {
            throw "Row count verification failed for table '$tableName'. Keep the application offline and inspect both databases."
        }
    }
    if ($destinationRowCounts.Count -ne $sourceRowCounts.Count) {
        throw "Source and destination table lists do not match. Keep the application offline and inspect both databases."
    }

    Write-Host "Migration complete. '$Database' was copied and table row counts were verified."
    Write-Host "MySQL accounts and passwords were not copied; configure destination credentials separately."
} finally {
    if (Test-Path $temporaryDirectory) {
        Remove-Item $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    $sourceCredential = $null
    $destinationCredential = $null
}