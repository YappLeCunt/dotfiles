# Profile trimmed for fast non-interactive launches while keeping the full
# interactive experience (PSReadLine, PSFzf, zoxide, starship) in a real console.
# Backup: Microsoft.PowerShell_profile.ps1.bak

$Interactive = $Host.Name -eq 'ConsoleHost' -and `
               [Environment]::UserInteractive -and `
               -not [Console]::IsOutputRedirected

# ═══ 1. PSReadLine options (interactive only) ═══
if ($Interactive) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -MaximumHistoryCount 32768
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -ShowToolTips

    Set-PSReadLineOption -AddToHistoryHandler {
        param($line)
        if ($line.Length -lt 4) { return $false }
        if ($line -match '(password|secret|token|apikey|-AsPlainText)') { return $false }
        return $true
    }

    Set-PSReadLineOption -Colors @{
        InlinePrediction       = "`e[38;5;238m"
        ListPrediction         = "`e[38;5;237m"
        ListPredictionSelected = "`e[48;5;236m"
        ListPredictionTooltip  = "`e[38;5;240m"
        Command   = "`e[38;5;110m"
        Parameter = "`e[38;5;145m"
        Operator  = "`e[38;5;145m"
        String    = "`e[38;5;108m"
        Number    = "`e[38;5;180m"
        Variable  = "`e[38;5;152m"
        Comment   = "`e[38;5;242m"
        Type      = "`e[38;5;146m"
        Member    = "`e[38;5;152m"
        Emphasis  = "`e[38;5;39m"
        Error     = "`e[38;5;167m"
        Default   = "`e[38;5;252m"
    }

    # ═══ 2. Keybindings ═══
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Escape    -Function RevertLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'F2'     -Function SwitchPredictionView
}

# ═══ 3. PSFzf — must come AFTER PSReadLine options (interactive only) ═══
if ($Interactive) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                    -PSReadlineChordReverseHistory 'Ctrl+r'
}
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_DEFAULT_OPTS    = '--height 40% --layout=reverse --border --info=inline'

# ═══ 4. Env + aliases (always) ═══
$env:BAT_THEME = 'ansi'
Set-Alias ll Get-ChildItem
Set-Alias grep rg
Set-Alias cat bat

# ═══ 5. zoxide — cached init (interactive only) ═══
if ($Interactive) {
    $zBin = (Get-Command zoxide -ErrorAction SilentlyContinue).Source
    if ($zBin) {
        $cacheDir = Join-Path $HOME '.cache'
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        $zCache = Join-Path $cacheDir 'zoxide-pwsh.ps1'
        if (-not (Test-Path $zCache) -or ((Get-Item $zBin).LastWriteTime -gt (Get-Item $zCache).LastWriteTime)) {
            & zoxide init powershell --cmd cd | Out-File -FilePath $zCache -Encoding utf8
        }
        . $zCache
    }
}

# ═══ 6. OCC (Claude Code via OpenCode Go) ═══
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:10110/v1"
$env:ANTHROPIC_API_KEY = "local-gateway-token-CHANGE-ME"
$env:CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"

# Model slot mappings
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "opencode-go/kimi-k3"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL_NAME = "opencode-go/kimi-k3"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL_DESCRIPTION = "occ proxy model"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "opencode-go/glm-5.2"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL_NAME = "opencode-go/glm-5.2"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION = "occ proxy model"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "opencode-go/mimo-v2.5"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME = "opencode-go/mimo-v2.5"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION = "occ proxy model"
$env:ANTHROPIC_DEFAULT_FABLE_MODEL = "opencode-go/mimo-v2.5-pro"
$env:ANTHROPIC_DEFAULT_FABLE_MODEL_NAME = "opencode-go/mimo-v2.5-pro"
$env:ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION = "occ proxy model"
$env:ANTHROPIC_MODEL = "opencode-go/glm-5.2"
$env:ANTHROPIC_SMALL_FAST_MODEL = "opencode-go/mimo-v2.5"

# ═══ 7. Starship — cached init (interactive only, LAST) ═══
if ($Interactive) {
    $sBin = (Get-Command starship -ErrorAction SilentlyContinue).Source
    if ($sBin) {
        $cacheDir = Join-Path $HOME '.cache'
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        $sCache = Join-Path $cacheDir 'starship-pwsh.ps1'
        if (-not (Test-Path $sCache) -or ((Get-Item $sBin).LastWriteTime -gt (Get-Item $sCache).LastWriteTime)) {
            & starship init powershell | Out-File -FilePath $sCache -Encoding utf8
        }
        . $sCache
        Enable-TransientPrompt
        function Invoke-Starship-TransientFunction {
            &starship module character
        }
    }
}