# bootstrap-new-machine.ps1
# Replicates the trimmed/cached/gated PowerShell profile on a fresh Windows 11 machine.
# The profile itself syncs via OneDrive (it lives in OneDrive\Documents\PowerShell\);
# this script installs only the prerequisites the profile depends on.
# Idempotent. Safe to re-run.

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}

Write-Host '=== 1. PowerShell 7 ==='
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
    Refresh-Path
} else { Write-Host 'pwsh already installed' }

Write-Host "`n=== 2. Binaries via winget ==="
# If any id is wrong on a future winget, run:  winget search <name>
$pkgs = @(
    'starship',
    'ajeetdsouza.zoxide',
    'sharkdp.bat',
    'sharkdp.fd',
    'BurntSushi.ripgrep.MSVC'
)
foreach ($id in $pkgs) {
    winget install --id $id --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
}
Refresh-Path

Write-Host "`n=== 3. PowerShell modules: PSFzf + CompletionPredictor ===`"
& pwsh -NoProfile -Command "Install-Module PSFzf -Force -Scope CurrentUser -AllowClobber; Install-Module CompletionPredictor -Force -Scope CurrentUser -AllowClobber"

Write-Host "`n=== 4. Profile presence ==="
$prof = Join-Path $HOME 'OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
if (Test-Path $prof) {
    Write-Host "Profile already synced via OneDrive: $prof"
} else {
    Write-Host "WARNING: profile not found at $prof"
    Write-Host '        Ensure OneDrive has signed in and synced, or copy Microsoft.PowerShell_profile.ps1 there manually.'
}

Write-Host "`n=== 5. Pre-warm caches ==="
& pwsh -NoProfile -Command @'
$cd = Join-Path $HOME '.cache'
New-Item -ItemType Directory -Path $cd -Force | Out-Null
$z = (Get-Command zoxide -ErrorAction SilentlyContinue).Source
$s = (Get-Command starship -ErrorAction SilentlyContinue).Source
if ($z) { & zoxide init powershell --cmd cd | Out-File (Join-Path $cd 'zoxide-pwsh.ps1') -Encoding utf8 }
if ($s) { & starship init powershell | Out-File (Join-Path $cd 'starship-pwsh.ps1') -Encoding utf8 }
'@

Write-Host "`n=== 6. Defender exclusions (optional) ==="
$gsudo = Get-Command gsudo -ErrorAction SilentlyContinue
$npmDir = Join-Path $HOME 'AppData\Roaming\npm\node_modules\opencode-ai'
$cfgDir = Join-Path $HOME '.config\opencode'
if ($gsudo -and (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    & $gsudo.Source pwsh -NoProfile -Command "
        Add-MpPreference -ExclusionProcess 'node.exe','opencode.exe','claude.exe' -ErrorAction SilentlyContinue;
        Add-MpPreference -ExclusionPath '$npmDir','$cfgDir' -ErrorAction SilentlyContinue"
    Write-Host 'Defender exclusions added.'
} else {
    Write-Host 'gsudo not installed / node not present. In an elevated PowerShell:'
    Write-Host "  Add-MpPreference -ExclusionProcess 'node.exe','opencode.exe','claude.exe'"
    Write-Host "  Add-MpPreference -ExclusionPath '$npmDir', '$cfgDir'"
}

Write-Host "`n=== 7. Verify launch time ==="
& pwsh -NoProfile -Command "`$sw=[Diagnostics.Stopwatch]::StartNew(); & pwsh -NoProfile -Command 'exit'; `$sw.Stop(); Write-Host ('pwsh -NoProfile: ' + `$sw.ElapsedMilliseconds + ' ms')"
& pwsh -NoProfile -Command "`$sw=[Diagnostics.Stopwatch]::StartNew(); & pwsh -Command 'exit' 2>`$null; `$sw.Stop(); Write-Host ('pwsh +profile (non-interactive): ' + `$sw.ElapsedMilliseconds + ' ms')"

Write-Host "`nDone. Open a new Windows Terminal for the full interactive experience (starship prompt + PSFzf + zoxide)."
Write-Host 'NOTE: profile section 6 sets OCC env vars (ANTHROPIC_BASE_URL = http://127.0.0.1:10110/v1, model slots).'
Write-Host '      If the new machine is not running the OCC local gateway, comment out section 6 of the profile.'