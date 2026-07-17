# odzysk.ps1 — bootstrap odzyskiwania środowiska Jaskier po awarii dysku/komputera.
# Uruchomienie na ŚWIEŻYM Windows 11 (PowerShell 5.1 wystarczy, uprawnienia zwykłego użytkownika):
#
#   iwr -useb https://raw.githubusercontent.com/EPS-AI-SOLUTIONS/jaskier-recovery/main/odzysk.ps1 | iex
#
# Wymaga TYLKO: hasła głównego Bitwarden (+ 2FA / recovery code). Wszystkie sekrety pobiera z Bitwarden:
#   DR/github-pat — token GitHub (dostęp do prywatnego repo jaskier-memory-dr)
#   DR/age-key    — klucz prywatny age (deszyfracja paczki backupu z Google Drive)
# W tym pliku NIE MA żadnych sekretów (repo publiczne).
$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy Bypass -Scope Process -Force
Write-Host "`n=== JASKIER ODZYSK — bootstrap ===" -ForegroundColor Cyan

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- 1. Narzędzia bazowe (winget) ---
$pkgs = @(
    @{ id = 'Git.Git';            probe = 'git' },
    @{ id = 'GitHub.cli';         probe = 'gh' },
    @{ id = 'OpenJS.NodeJS.LTS';  probe = 'node' },
    @{ id = 'Python.Python.3.13'; probe = 'python' },
    @{ id = 'Bitwarden.CLI';      probe = 'bw' },
    @{ id = 'FiloSottile.age';    probe = 'age' }
)
foreach ($p in $pkgs) {
    Refresh-Path
    if (Get-Command $p.probe -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $($p.probe) już jest" -ForegroundColor Green; continue
    }
    Write-Host "  [..] instaluję $($p.id)..."
    winget install --id $p.id --accept-source-agreements --accept-package-agreements --silent | Out-Null
}
Refresh-Path
foreach ($p in $pkgs) {
    if (-not (Get-Command $p.probe -ErrorAction SilentlyContinue)) {
        throw "Brak '$($p.probe)' po instalacji — zamknij i otwórz PowerShell ponownie, uruchom skrypt jeszcze raz."
    }
}

# --- 2. Bitwarden: logowanie (interaktywne) ---
Write-Host "`n--- Bitwarden (vault.bitwarden.eu) ---" -ForegroundColor Cyan
bw config server https://vault.bitwarden.eu | Out-Null
$bwStatus = (bw status | ConvertFrom-Json).status
if ($bwStatus -eq 'unauthenticated') {
    Write-Host 'Zaloguj się (email + hasło główne + 2FA lub recovery code):'
    bw login
}
$session = bw unlock --raw
if (-not $session) { throw 'bw unlock nie zwrócił sesji — złe hasło?' }
Write-Host '  [ok] Bitwarden odblokowany' -ForegroundColor Green

# --- 3. GitHub auth przez PAT z Bitwarden ---
$pat = (bw get notes 'DR/github-pat' --session $session).Trim()
if (-not $pat) { throw "Brak wpisu 'DR/github-pat' w Bitwarden" }
$pat | gh auth login --hostname github.com --with-token
gh auth setup-git | Out-Null
Write-Host '  [ok] GitHub uwierzytelniony' -ForegroundColor Green

# --- 4. Klon prywatnego repo z pamięcią i kreatorem odzysku ---
$restoreRoot = Join-Path $env:USERPROFILE 'JaskierRestore'
New-Item -ItemType Directory -Force -Path $restoreRoot | Out-Null
$repoDir = Join-Path $restoreRoot 'jaskier-memory-dr'
if (-not (Test-Path (Join-Path $repoDir '.git'))) {
    git clone https://github.com/EPS-AI-SOLUTIONS/jaskier-memory-dr.git $repoDir
} else {
    git -C $repoDir pull --rebase
}

# --- 5. Przekazanie sterowania do kreatora ---
Write-Host "`n=== Start kreatora restore-all.ps1 ===" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoDir 'restore\restore-all.ps1') -BwSession $session
