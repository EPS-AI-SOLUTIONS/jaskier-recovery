# odzysk.ps1 - bootstrap odzyskiwania Jaskier (3 CLI) po awarii. REPO PUBLICZNE - ZERO SEKRETOW.
# Na swiezym Windows 11 (PowerShell 5.1):
#   iwr https://raw.githubusercontent.com/EPS-AI-SOLUTIONS/jaskier-recovery/main/odzysk.ps1 -UseBasicParsing | iex
# Interakcja TYLKO na poczatku (haslo Bitwarden + 2FA RAZ). Potem walk-away - restore-all.ps1 przejmuje.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RestoreRoot = Join-Path $env:USERPROFILE 'JaskierRestore'
New-Item -ItemType Directory -Force -Path $RestoreRoot | Out-Null
$Log = Join-Path $RestoreRoot 'odzysk.log'
function Step([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Host $l -ForegroundColor Cyan
    Add-Content -Path $Log -Value $l -Encoding UTF8
}

# --- 1/4: narzedzia (winget) ---
Step 'Instaluje narzedzia: git, gh, node, python, bitwarden-cli, age...'
$pkgs = 'Git.Git','GitHub.cli','OpenJS.NodeJS.LTS','Python.Python.3.13','Bitwarden.CLI','FiloSottile.age'
$i = 0
foreach ($p in $pkgs) {
    $i++
    Write-Progress -Activity 'Narzedzia' -Status $p -PercentComplete (100 * $i / $pkgs.Count)
    winget install --id $p -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
}
Write-Progress -Activity 'Narzedzia' -Completed
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# --- 2/4: Bitwarden - JEDYNA interakcja (haslo + 2FA RAZ; sesja w env, NIGDY w argumentach) ---
# Konto jest w regionie EU - bez tego bw celuje w domyslny vault.bitwarden.com i odrzuca poprawne haslo.
$BwServer = 'https://vault.bitwarden.eu'
Step "Ustawiam serwer Bitwarden: $BwServer (region EU, zgodnie z KARTA)"
$bwStatus = $null
try { $bwStatus = (& bw status 2>$null) | ConvertFrom-Json } catch { $bwStatus = $null }
if (-not $bwStatus -or $bwStatus.serverUrl -ne $BwServer) {
    if ($bwStatus -and $bwStatus.status -ne 'unauthenticated') { & bw logout | Out-Null }
    & bw config server $BwServer | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bitwarden: nie udalo sie ustawic serwera $BwServer - STOP (fail-closed)." }
}
Step 'Logowanie Bitwarden - podaj e-mail, haslo glowne i kod 2FA. To JEDYNY moment przy klawiaturze.'
$env:BW_SESSION = (& bw login --raw)
if (-not $env:BW_SESSION) { $env:BW_SESSION = (& bw unlock --raw) }   # bw byl juz zalogowany -> tylko unlock
if (-not $env:BW_SESSION) { throw 'Bitwarden: brak sesji - STOP (fail-closed).' }
& bw sync | Out-Null
Step 'Sesja aktywna. Od tego momentu mozesz odejsc od komputera.'

# --- 3/4: GitHub (PAT ze skarbca) + klon repo DR ---
Step 'Loguje gh (PAT: DR/github-pat) i klonuje jaskier-memory-dr...'
$pat = (& bw get password 'DR/github-pat')
if (-not $pat) { throw 'Brak DR/github-pat w Bitwarden - STOP (fail-closed).' }
$pat | & gh auth login --with-token
Remove-Variable pat
if (-not (& bw get item 'DR/age-key')) { throw 'Brak DR/age-key w Bitwarden - STOP (fail-closed).' }
$RepoDir = Join-Path $RestoreRoot 'jaskier-memory-dr'
if (-not (Test-Path (Join-Path $RepoDir '.git'))) {
    & gh repo clone EPS-AI-SOLUTIONS/jaskier-memory-dr $RepoDir
    if ($LASTEXITCODE -ne 0) { throw 'Klon jaskier-memory-dr nieudany - STOP (fail-closed).' }
}

# --- 4/4: przekazanie sterow (walk-away; BW_SESSION dziedziczy sie przez env) ---
Step 'Start restore-all.ps1 - dalej wszystko idzie samo, na koncu dzwiek + raport.'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoDir 'restore\restore-all.ps1')
exit $LASTEXITCODE
