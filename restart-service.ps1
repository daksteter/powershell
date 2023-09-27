# Define service, timeout, and log file path
$serviceName = "YourServiceName"
$timeoutInSeconds = 60
$logFile = "C:\path\to\your\logfile.log"

# Logging function
function Write-Log {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp | $message"
    
    Add-Content -Path $logFile -Value $logEntry
    Write-Output $logEntry
}

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

# Check if the service exists
if (-not $service) {
    Write-Log "Service $serviceName does not exist."
    exit
}

# Check if the service is running
if ($service.Status -eq "Running") {
    Write-Log "Stopping service $serviceName..."
    Stop-Service -Name $serviceName -Force

    # Wait for the service to stop with timeout
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Seconds 1
        $service.Refresh()
        if ($stopwatch.Elapsed.TotalSeconds -ge $timeoutInSeconds) {
            Write-Log "Timeout reached! Forcefully stopping the service..."
            Get-Process | Where-Object { $_.Id -eq $service.ProcessId } | Stop-Process -Force
            break
        }
    } while ($service.Status -eq 'Running')

    # Using the service's process path, get the folder and check for other processes running from that folder
    $serviceProcessPath = (Get-WmiObject win32_service | Where-Object { $_.Name -eq $serviceName }).PathName
    $serviceFolderPath = [System.IO.Path]::GetDirectoryName($serviceProcessPath)
    $otherProcesses = Get-Process | Where-Object { $_.Path -like "$serviceFolderPath\*" }

    foreach ($proc in $otherProcesses) {
        Write-Log "Stopping process $($proc.Name) from the same folder..."
        $proc | Stop-Process -Force
    }

    # Start the service
    Start-Service -Name $serviceName

} else {
    Write-Log "Service $serviceName is not running."
}
