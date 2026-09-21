<#
.SYNOPSIS
    Launches every enabled tool of this repository, each in its own window.

.DESCRIPTION
    A tool is a folder <tool>\ holding a launcher named <tool>.bat. Tools are discovered at run time; config.json
    (personal, ignored by git, created from config.example.json on first run) decides which ones start and with
    which arguments:

        {
          "defaults": { "enabled": true },
          "tools": {
            "mute-call-while-dictating": { "enabled": true, "args": "-PollIntervalMilliseconds 100" }
          }
        }

    A tool missing from "tools" follows "defaults.enabled". "args" is forwarded verbatim to the tool launcher.
    A configured tool without a matching folder only raises a warning.

.USAGE
    launch-all-tools.bat   (or: powershell -ExecutionPolicy Bypass -File .\launch-all-tools.ps1)
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = $PSScriptRoot,
    [string]$ConfigFileName = 'config.json',
    [string]$ConfigExampleFileName = 'config.example.json'
)

Set-StrictMode -Version Latest

function Find-ToolLaunchers {
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    foreach ($directory in Get-ChildItem -Path $RepositoryRoot -Directory) {
        $launcher = Join-Path $directory.FullName ($directory.Name + '.bat')
        if (Test-Path $launcher) {
            [pscustomobject]@{ Name = $directory.Name; Launcher = $launcher; Directory = $directory.FullName }
        }
    }
}

function Initialize-LauncherConfig {
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$ExamplePath
    )
    if (Test-Path $ConfigPath) { return }
    if (-not (Test-Path $ExamplePath)) { throw "Neither $ConfigPath nor $ExamplePath exists." }
    Copy-Item -Path $ExamplePath -Destination $ConfigPath
    Write-Host "Created $ConfigPath from $ExamplePath - edit it to enable or disable tools."
}

function Read-LauncherConfig {
    param([Parameter(Mandatory)][string]$ConfigPath)
    $json = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $isEnabledByDefault = $true
    if ($json.PSObject.Properties['defaults'] -and $json.defaults.PSObject.Properties['enabled']) {
        $isEnabledByDefault = [bool]$json.defaults.enabled
    }
    $tools = @{}
    if ($json.PSObject.Properties['tools']) {
        foreach ($property in $json.tools.PSObject.Properties) { $tools[$property.Name] = $property.Value }
    }
    return [pscustomobject]@{ IsEnabledByDefault = $isEnabledByDefault; Tools = $tools }
}

function Resolve-ToolLaunchPlan {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$DiscoveredTools,
        [Parameter(Mandatory)]$Config
    )
    foreach ($tool in $DiscoveredTools) {
        $settings = $Config.Tools[$tool.Name]
        $isEnabled = $Config.IsEnabledByDefault
        $arguments = ''
        if ($settings) {
            if ($settings.PSObject.Properties['enabled']) { $isEnabled = [bool]$settings.enabled }
            if ($settings.PSObject.Properties['args']) { $arguments = [string]$settings.args }
        }
        [pscustomobject]@{
            Name = $tool.Name; Launcher = $tool.Launcher; Directory = $tool.Directory
            IsEnabled = $isEnabled; Arguments = $arguments
        }
    }
}

function Find-UnknownConfiguredTools {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$DiscoveredTools,
        [Parameter(Mandatory)]$Config
    )
    $discoveredNames = @($DiscoveredTools | ForEach-Object { $_.Name })
    return @($Config.Tools.Keys | Where-Object { $discoveredNames -notcontains $_ } | Sort-Object)
}

function Start-Tool {
    param([Parameter(Mandatory)]$Plan)
    $startParameters = @{ FilePath = $Plan.Launcher; WorkingDirectory = $Plan.Directory }
    if ($Plan.Arguments) { $startParameters.ArgumentList = $Plan.Arguments }
    Start-Process @startParameters
}

function Invoke-ToolLaunch {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Plans)
    $launchedCount = 0
    foreach ($plan in $Plans) {
        if (-not $plan.IsEnabled) { Write-Host "skipped  $($plan.Name) (disabled in config.json)"; continue }
        Start-Tool -Plan $plan
        Write-Host ("launched {0} {1}" -f $plan.Name, $plan.Arguments).TrimEnd()
        $launchedCount++
    }
    if ($launchedCount -eq 0) { Write-Host 'Nothing launched: no enabled tool found (expected <tool>\<tool>.bat).' }
}

$isDotSourced = $MyInvocation.InvocationName -eq '.'
if (-not $isDotSourced) {
    $configPath = Join-Path $RepositoryRoot $ConfigFileName
    Initialize-LauncherConfig -ConfigPath $configPath -ExamplePath (Join-Path $RepositoryRoot $ConfigExampleFileName)
    $config = Read-LauncherConfig -ConfigPath $configPath
    $discoveredTools = @(Find-ToolLaunchers -RepositoryRoot $RepositoryRoot)
    foreach ($unknown in Find-UnknownConfiguredTools -DiscoveredTools $discoveredTools -Config $config) {
        Write-Warning "config.json names '$unknown' but no $unknown\$unknown.bat exists - ignored."
    }
    Invoke-ToolLaunch -Plans @(Resolve-ToolLaunchPlan -DiscoveredTools $discoveredTools -Config $config)
}
