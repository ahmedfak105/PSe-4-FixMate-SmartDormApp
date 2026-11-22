#Requires -Version 5.1
<#
.SYNOPSIS
  Read-only local backup of the existing FixMate hosted Supabase database.
.DESCRIPTION
  Creates private roles/schema/data SQL files with SHA256 checksums.
  Does NOT run SQL migrations, restore, modify the live database, export
  private Storage image bytes, or mark release gate #47 completed.
  Requires Supabase CLI and a running Docker Desktop installation.
.NOTES
  Private database connection/password stay on the operator's computer.
  Run from a trusted PowerShell window. Never paste secrets in GitHub/chat.
#>
[CmdletBinding()]
param(
    [string] $OutputRoot = (Join-Path $HOME 'FixMateSecureBackups'),
    [switch] $Help
)

$ErrorActionPreference = 'Stop'
$ProjectRef = 'epsvagztisdovixlqehi'

if ($Help) {
    Write-Host 'Usage: .\scripts\backup_fixmate_windows.ps1 [-OutputRoot "D:\FixMateSecureBackups"]'
    Write-Host 'Prerequisites: Supabase CLI, Docker Desktop running, private DB password.'
    Write-Host 'Creates roles.sql, schema.sql, data.sql and CHECKSUMS.json on your PC.'
    Write-Host 'NOTE: Private Storage files and isolated restoration are separate steps.'
    exit 0
}

foreach ($program in @('supabase', 'docker')) {
    if (-not (Get-Command $program -ErrorAction SilentlyContinue)) {
        throw "Missing $program. Install it first; no live changes were made."
    }
}

$dumpHelp = (& supabase db dump --help 2>&1 | Out-String)
foreach ($option in @('--db-url', '--role-only', '--data-only', '--use-copy')) {
    if (-not $dumpHelp.Contains($option)) {
        throw "Current Supabase CLI does not document $option. Update the CLI; do not guess flags."
    }
}

& docker info --format '{{.ServerVersion}}' 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop is not running. Start Docker before backup.'
}

Write-Host ''
Write-Host 'FixMate: backup existing database only. No migration/restore commands will run.'
Write-Host "Expected project: $ProjectRef"
Write-Host 'From Supabase Dashboard > Connect, choose Session Pooler and copy the'
Write-Host 'connection URI with the placeholder [YOUR-PASSWORD] (NOT the real password).'
Write-Host 'Example shape: postgresql://postgres.PROJECT:[YOUR-PASSWORD]@HOST:5432/postgres'
$template = Read-Host 'Paste connection URI WITH placeholder [YOUR-PASSWORD]'
if (-not $template.StartsWith('postgres://') -and
    -not $template.StartsWith('postgresql://')) {
    throw 'Invalid PostgreSQL URI scheme. Backup was not attempted.'
}
if (-not $template.Contains($ProjectRef) -or
    -not $template.Contains('[YOUR-PASSWORD]')) {
    throw 'Wrong project or missing [YOUR-PASSWORD] placeholder. Aborting.'
}
if ($template -match '(?i)password=[^&\s]+') {
    throw 'A password seems present in the URL template. Do not paste secrets.'
}
if ($template -notmatch '(?i)@[^/\s]+/postgres(?:\?|$)') {
    throw 'Expected a Postgres URI ending in /postgres, copied from project Connect.'
}
if ($template -match '\s') {
    throw 'The database URI must not contain whitespace.'
}

$secure = Read-Host 'Database password (hidden; never send it to chat)' -AsSecureString
if (-not $secure -or $secure.Length -eq 0) {
    throw 'Empty password. Aborting.'
}

# Convert only inside this local PowerShell process. No secrets are written
# into source control, output files or diagnostic messages.
$bstr = [IntPtr]::Zero
$connection = $null
try {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $rawPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $encodedPassword = [System.Uri]::EscapeDataString($rawPassword)
    $connection = $template.Replace('[YOUR-PASSWORD]', $encodedPassword)
    if ($connection -notmatch '(?i)(?:\?|&)sslmode=') {
        if ($connection.Contains('?')) {
            $connection += '&sslmode=require'
        } else {
            $connection += '?sslmode=require'
        }
    }
} finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $rawPassword = $null
    $encodedPassword = $null
    $secure = $null
}
$template = $null

if ($env:OneDrive -and $OutputRoot.StartsWith($env:OneDrive,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose an encrypted LOCAL backup directory outside OneDrive/synced folders.'
}
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$folder = Join-Path $OutputRoot ("FixMate-$stamp-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $folder -Force | Out-Null

try {
    $steps = @(
        @{ Name = 'roles.sql';  Flags = @('--role-only') },
        @{ Name = 'schema.sql'; Flags = @() },
        @{ Name = 'data.sql';   Flags = @('--use-copy', '--data-only',
                                         '-x', 'storage.buckets_vectors',
                                         '-x', 'storage.vector_indexes') }
    )
    foreach ($step in $steps) {
        $destination = Join-Path $folder $step.Name
        Write-Host ("Exporting " + $step.Name + " ...")
        $arguments = @('db', 'dump', '--db-url', $connection, '-f', $destination)
        $arguments += $step.Flags
        & supabase @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Supabase CLI failed exporting $($step.Name). Incomplete backup in private folder."
        }
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or
            (Get-Item -LiteralPath $destination).Length -eq 0) {
            throw "Missing or empty $($step.Name). Backup not validated."
        }
    }

    $names = @('roles.sql', 'schema.sql', 'data.sql')
    $files = foreach ($name in $names) {
        $path = Join-Path $folder $name
        $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
        [pscustomobject]@{
            file   = $name
            bytes  = (Get-Item -LiteralPath $path).Length
            sha256 = $hash.Hash
        }
    }
    $manifest = [ordered]@{
        project_ref = $ProjectRef
        created_utc = [DateTime]::UtcNow.ToString('o')
        database_dump = 'FILES_CREATED_NOT_RESTORE_TESTED'
        private_storage = 'NOT_EXPORTED'
        remote_changes = 'NONE'
        files = @($files)
    }
    $manifest | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $folder 'CHECKSUMS.json') -Encoding UTF8

    Write-Host ''
    Write-Host 'Database SQL files created successfully and SHA256 checksums recorded.'
    Write-Host ("PRIVATE output directory: " + $folder)
    Write-Warning 'This is NOT a completed disaster-recovery backup.'
    Write-Warning 'Export private report-photos via Storage S3/Cyberduck, then VERIFY'
    Write-Warning 'an isolated database and photo restore before Release Gate #47.'
} finally {
    $connection = $null
}
