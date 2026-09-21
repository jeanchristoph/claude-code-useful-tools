<#
.SYNOPSIS
    Mutes the current Teams/Zoom call while Claude Code records a voice prompt, unmutes when the recording ends.

.DESCRIPTION
    Claude Code exposes no hook for voice recording, but Windows itself records when each application opens the
    microphone: LastUsedTimeStart / LastUsedTimeStop under
    HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged.
    This script polls those two values for claude.exe (READ-ONLY) and sends the Windows 11 global call-mute
    shortcut (Win+Alt+K) on each transition. That shortcut only affects call applications subscribed to the
    Windows call-mute API (Teams, Zoom...); Claude Code keeps hearing you.

    Nothing is written to the registry nor to any Windows setting. No automatic startup is configured.

.USAGE
    powershell -ExecutionPolicy Bypass -File .\mute-call-while-dictating.ps1
    Stop with Ctrl+C.

.LIMITATION
    Win+Alt+K is a toggle and Windows does not expose the current call-mute state. Start dictating while you are
    UNMUTED in the call: if you were already muted, the first toggle would unmute you for the duration of the
    dictation. The script only sends the closing toggle when it sent the opening one.

.PARAMETER PollIntervalMilliseconds
    Delay between two registry reads. Lower = faster mute, slightly more CPU. Default 100 ms.

.PARAMETER ClaudeExecutablePath
    Path of claude.exe as Windows registered it. Defaults to the claude command found in PATH.
#>
[CmdletBinding()]
param(
    [int]$PollIntervalMilliseconds = 100,
    [string]$ClaudeExecutablePath = (Get-Command claude -ErrorAction SilentlyContinue).Source
)

Set-StrictMode -Version Latest

$MicrophoneConsentStorePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged'

function ConvertTo-ConsentStoreKeyName {
    param([Parameter(Mandatory)][string]$ExecutablePath)
    # Windows stores the executable path with '#' in place of '\'.
    return $ExecutablePath -replace '\\', '#'
}

function Read-MicrophoneUsage {
    param([Parameter(Mandatory)][string]$RegistryKeyPath)
    $properties = Get-ItemProperty -Path $RegistryKeyPath -ErrorAction Stop
    return [pscustomobject]@{
        Start = [long]$properties.LastUsedTimeStart
        Stop  = [long]$properties.LastUsedTimeStop
    }
}

function Resolve-MicrophoneTransition {
    param(
        [Parameter(Mandatory)]$Previous,
        [Parameter(Mandatory)]$Current
    )
    if ($Current.Start -ne $Previous.Start) { return 'RecordingStarted' }
    if ($Current.Stop -ne $Previous.Stop) { return 'RecordingStopped' }
    return $null
}

function Initialize-KeyboardInterop {
    if ('CallMute.Keyboard' -as [type]) { return }
    Add-Type -Namespace CallMute -Name Keyboard -MemberDefinition @'
[DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
'@
}

function Send-CallMuteToggle {
    # Win+Alt+K — Windows 11 global call-mute shortcut. SendKeys cannot press the Windows key, hence keybd_event.
    $VK_LWIN = 0x5B; $VK_MENU = 0x12; $VK_K = 0x4B; $KEYEVENTF_KEYUP = 0x2
    [CallMute.Keyboard]::keybd_event($VK_LWIN, 0, 0, [UIntPtr]::Zero)
    [CallMute.Keyboard]::keybd_event($VK_MENU, 0, 0, [UIntPtr]::Zero)
    [CallMute.Keyboard]::keybd_event($VK_K, 0, 0, [UIntPtr]::Zero)
    [CallMute.Keyboard]::keybd_event($VK_K, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [CallMute.Keyboard]::keybd_event($VK_MENU, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [CallMute.Keyboard]::keybd_event($VK_LWIN, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Write-Transition {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $Message)
}

function Invoke-CallMuteWatch {
    param(
        [Parameter(Mandatory)][string]$RegistryKeyPath,
        [Parameter(Mandatory)][int]$IntervalMilliseconds
    )
    $previous = Read-MicrophoneUsage -RegistryKeyPath $RegistryKeyPath
    $hasMutedTheCall = $false
    Write-Transition "Watching $RegistryKeyPath — dictate with Claude Code, Ctrl+C to stop."
    while ($true) {
        Start-Sleep -Milliseconds $IntervalMilliseconds
        $current = Read-MicrophoneUsage -RegistryKeyPath $RegistryKeyPath
        $transition = Resolve-MicrophoneTransition -Previous $previous -Current $current
        $previous = $current
        if ($transition -eq 'RecordingStarted') {
            Send-CallMuteToggle; $hasMutedTheCall = $true
            Write-Transition 'Claude Code opened the microphone → call muted (Win+Alt+K)'
        }
        elseif ($transition -eq 'RecordingStopped' -and $hasMutedTheCall) {
            Send-CallMuteToggle; $hasMutedTheCall = $false
            Write-Transition 'Claude Code released the microphone → call unmuted (Win+Alt+K)'
        }
    }
}

$isDotSourced = $MyInvocation.InvocationName -eq '.'
if (-not $isDotSourced) {
    if (-not $ClaudeExecutablePath) { throw 'claude.exe not found in PATH — pass -ClaudeExecutablePath.' }
    $registryKeyPath = Join-Path $MicrophoneConsentStorePath (ConvertTo-ConsentStoreKeyName -ExecutablePath $ClaudeExecutablePath)
    if (-not (Test-Path $registryKeyPath)) {
        throw "No microphone usage recorded for $ClaudeExecutablePath yet — dictate once in Claude Code, then relaunch."
    }
    Initialize-KeyboardInterop
    Invoke-CallMuteWatch -RegistryKeyPath $registryKeyPath -IntervalMilliseconds $PollIntervalMilliseconds
}
