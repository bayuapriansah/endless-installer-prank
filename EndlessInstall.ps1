<#
.SYNOPSIS
Installer style console that shows ongoing progress and logs.
Purely visual, no changes are made to the system.

Usage:
  powershell.exe -ExecutionPolicy Bypass -File EndlessInstall.ps1
#>

[CmdletBinding()]
param(
    # Multiplier to speed up or slow down for testing (1 is normal, lower is faster)
    [double]$SpeedFactor = 1.0
)

if ($SpeedFactor -le 0) {
    $SpeedFactor = 0.2
}

$rand = New-Object System.Random

# Header
Write-Host ""
Write-Host "Environment setup utility"
Write-Host "------------------------------------------------------------"
Write-Host "[INFO ] This process may take a while, do not close this window."
Write-Host ""

# Simulated components
$packages = @(
    @{ Name = "python3.12";      Version = "3.12.1";  Tag = "runtime" },
    @{ Name = "nodejs-lts";      Version = "20.11.0"; Tag = "runtime" },
    @{ Name = "dotnet-host";     Version = "8.0.2";   Tag = "runtime" },
    @{ Name = "core-plugins";    Version = "1.8.4";   Tag = "plugins" },
    @{ Name = "web-adapter";     Version = "2.3.0";   Tag = "plugins" },
    @{ Name = "agent-service";   Version = "4.1.9";   Tag = "service" },
    @{ Name = "env-bootstrap";   Version = "0.9.7";   Tag = "config" }
)

$stages = @(
    @{ Threshold = 5;   Name = "Preparing environment";          Code = "stage:init" },
    @{ Threshold = 20;  Name = "Installing base runtimes";       Code = "stage:runtimes" },
    @{ Threshold = 40;  Name = "Installing language tooling";    Code = "stage:tooling" },
    @{ Threshold = 60;  Name = "Deploying plugins and add ons";  Code = "stage:plugins" },
    @{ Threshold = 80;  Name = "Configuring background services";Code = "stage:services" },
    @{ Threshold = 92;  Name = "Running health checks";          Code = "stage:healthcheck" },
    @{ Threshold = 99;  Name = "Finalizing configuration";       Code = "stage:finalize" }
)

$downloadMessages = @(
    "Resolving package source",
    "Requesting download URL",
    "Downloading payload",
    "Received payload segment",
    "Download throughput within expected range"
)

$verifyMessages = @(
    "Verifying checksum",
    "Validating signature",
    "Checksum validation completed",
    "Metadata validation successful"
)

$installMessages = @(
    "Extracting files",
    "Writing binaries to target path",
    "Registering components",
    "Updating environment variables",
    "Applying installation manifest"
)

$configMessages = @(
    "Updating configuration store",
    "Applying policy overrides",
    "Refreshing service configuration",
    "Writing runtime profile",
    "Synchronizing settings with local cache"
)

$healthMessages = @(
    "Running service availability check",
    "Pinging background agent endpoint",
    "Checking file system permissions",
    "Validating runtime versions",
    "Waiting for service registration to complete"
)

$warnMessages = @(
    "Detected slow disk response, retrying operation",
    "Background service response delayed, waiting",
    "Transient network issue detected, backing off",
    "Additional verification pass requested by policy"
)

function Get-StageForPercent {
    param([int]$Percent)
    foreach ($s in $stages) {
        if ($Percent -le $s.Threshold) {
            return $s
        }
    }
    return $stages[-1]
}

function Get-RandomMessageForStage {
    param(
        [string]$StageCode,
        [hashtable]$Package
    )

    $msgList = switch -Regex ($StageCode) {
        "init"        { $downloadMessages; break }
        "runtimes"    { $downloadMessages + $verifyMessages + $installMessages; break }
        "tooling"     { $downloadMessages + $installMessages; break }
        "plugins"     { $installMessages + $configMessages; break }
        "services"    { $installMessages + $configMessages + $healthMessages; break }
        "healthcheck" { $healthMessages + $configMessages; break }
        "finalize"    { $configMessages + $healthMessages; break }
        default       { $installMessages }
    }

    $base = $msgList | Get-Random
    $pkgPart = "{0} {1}" -f $Package.Name, $Package.Version
    return "{0} - {1}" -f $pkgPart, $base
}

function Get-RandomPackageForPercent {
    param([int]$Percent)

    if ($Percent -lt 25) {
        $candidates = $packages | Where-Object { $_.Tag -eq "runtime" }
    } elseif ($Percent -lt 55) {
        $candidates = $packages | Where-Object { $_.Tag -in @("runtime","plugins") }
    } elseif ($Percent -lt 80) {
        $candidates = $packages | Where-Object { $_.Tag -in @("plugins","service") }
    } else {
        $candidates = $packages
    }

    if (-not $candidates) {
        $candidates = $packages
    }

    return $candidates | Get-Random
}

$overallPercent = 0
$lastLogTime = Get-Date
$logIntervalSeconds = 2

Write-Host "[INFO ] Manifest loaded, starting operations..."
Write-Host ""

while ($true) {
    # Advance progress, but slow down a lot near the end
    if ($overallPercent -lt 92) {
        $step = $rand.Next(0, 2)  # 0 or 1
        $overallPercent += $step
    } elseif ($overallPercent -lt 97) {
        if ($rand.NextDouble() -lt 0.4) {
            $overallPercent += 1
        }
    } else {
        # Keep it in the 97 to 99 range and jitter a bit
        if ($rand.NextDouble() -lt 0.3) {
            $overallPercent += $rand.Next(0, 2)
        }
        if ($overallPercent -gt 99) {
            $overallPercent = 97 + $rand.Next(0, 3)
        }
    }

    if ($overallPercent -gt 99) {
        $overallPercent = 99
    }

    $stage = Get-StageForPercent -Percent $overallPercent
    $statusText = "{0} {1}% complete" -f $stage.Name, $overallPercent

    Write-Progress `
        -Activity "Environment setup" `
        -Status $statusText `
        -PercentComplete $overallPercent

    $now = Get-Date
    if ($now -ge $lastLogTime.AddSeconds($logIntervalSeconds / $SpeedFactor)) {
        $timestamp = $now.ToString("HH:mm:ss")
        $pkg = Get-RandomPackageForPercent -Percent $overallPercent
        $msg = Get-RandomMessageForStage -StageCode $stage.Code -Package $pkg

        $level = if ($rand.NextDouble() -lt 0.1) { "WARN " } else { "INFO " }

        Write-Host ("[{0}] [{1}] [{2}] {3}" -f `
            $timestamp, $level, $stage.Code, $msg)

        # Occasionally show a more explicit warning
        if ($rand.NextDouble() -lt 0.06) {
            $warn = $warnMessages | Get-Random
            Write-Host ("[{0}] [WARN ] [{1}] {2}" -f `
                $timestamp, $stage.Code, $warn)
        }

        # Randomize next log interval a bit
        $logIntervalSeconds = $rand.Next(2, 6)
        $lastLogTime = $now
    }

    Start-Sleep -Milliseconds ([int](400 / $SpeedFactor))
}
