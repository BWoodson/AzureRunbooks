<#
    .DESCRIPTION
        Runs every hour and starts or stops a VM if it has a 'power' tag in the format of '00:00'
        Times are in 24 hour format where numbers less than 10 must have a leading 0

    .NOTES
        AUTHOR: Brandon Woodson
        LASTEDIT: 4/12/2019
#>

# Find out now since Azure deals in UTC
$utc = [DateTime]::Now.DateTime
$est = Get-TimeZone -Name "Eastern Standard Time"
$now = [System.TimeZoneInfo]::ConvertTimeFromUtc($utc,$est)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Process all VMs
Write-Output "-= Process VMs =-"

try {
    $allVMs = Get-AzureRmVM
}
catch {
    Write-Error "Error $($_.Exception.Message)" -ErrorAction Stop
}

$allTaggedVMs = $allVMs | Where-Object { $_.Tags.power }

Write-Output "Found $($allTaggedVMs.count) VMs with power tags."

foreach ($taggedVM in $allTaggedVMs)
{
    # Runbooks run on UTC so we need to adjust the time to EST
    $currentHour = ($now).toString("HH")

    Write-Output "-- Checking $($taggedVM.Name)"
    Write-Output "Power: $($taggedVM.Tags.power)"
    
    if( $taggedVM.Tags.power -match '[a-zA-Z]' ) {
        Write-Error "Ignoring: Value contains letters"
        Continue
    }

    if( $taggedVM.Tags.power -match '^[0-9]{2}:[0-9]{2}' ) {
        $time = $taggedVM.Tags.power -Split ":"
        $startHour = $time[0]
        $stopHour = $time[1]

        Write-Output "|$currentHour|$startHour|$stopHour|"

        if( $startHour -eq $currentHour ) {
            Write-Output "Starting $($taggedVM.Name)"
            $taggedVM | Start-AzureRmVM
            Continue
        }

        if( $stopHour -eq $currentHour ) {
            Write-Output "Stopping $($taggedVM.Name)"
            $taggedVM | Stop-AzureRmVM -Force
            Continue
        }

        Write-Output "Doesn't match Start or Stop time"
    } else {
        Write-Error "Ignoring: Value format error"
    }
}