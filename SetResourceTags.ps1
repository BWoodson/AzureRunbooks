<#
    .DESCRIPTION
        There's an Azure policy that mandates tags on resource groups. The resources in the groups inherit the mandated tags
        automatically from this runbook. This runbook runs against each resource and if a particular tag (from a list of defined tags)
        is missing it is copied down from the resource group.

    .NOTES
        AUTHOR: Brandon Woodson
        LASTEDIT: 11/21/2019
#>

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
 
## Script Runs Here
$subscriptions = Get-AzureRMSubscription

# List of the tags to copy down
$tags = @("Company","Department","DepartmentName","Application","Environment","BusinessPriority")

# These resource types don't support tags and will fail
$ignoredResourceTypes = @("microsoft.insights/metricalerts","Microsoft.Web/serverFarms")

ForEach ($sub in $subscriptions)
{
	# Set current Subscription
	Select-AzureRmSubscription $sub.SubscriptionID

	# List all Resources within the Subscription
	$resources = Get-AzureRmResource

	# For each Resource apply the Tag of the Resource Group
	Foreach ($resource in $resources)
	{
		"$($resource.Name)"
		# If we should ignore the resourse type Continue to the next resource
		if( $ignoredResourceTypes -contains "$($resource.ResourceType)" )
		{
			Continue
		}

		# Grab the tags of the resource
		$resourcetags = $resource.Tags

		# Make a copy of the tags to alter
		$newTags = $resourcetags
		if( !$newTags )
		{
			$newTags = @{}
		}

		$resourceId = $resource.resourceId

		# Grab the resource group the resource belongs to
		$Rgname = $resource.Resourcegroupname

		#Grab the tags of the resource group
		$RGTags = (Get-AzureRmResourceGroup -Name $Rgname).Tags

		# Keep track if the tags changed for the resource
		$tagsChanged = $false

		# Cycle through the tags we want to enforce
		$tags | ForEach-Object {
			# Check if tag does not exists. If it does exist we are not going to overwrite it.
			if(!$resourcetags."$($_)")
			{
				# Check if the resource group has the tag
				if($RGTags."$($_)")
				{
					# Save tag
					"Adding tag: $($_) = $($RGTags."$_")"
					try {
						$newTags."$($_)" = $RGTags."$($_)"
					}
					catch {
						Write-Error "Exception: $($_.Exception.Message)"
					}
					$tagsChanged = $true
				}
			}
		}

		if($tagsChanged)
		{
			try {
				$result = Set-AzureRmResource -ResourceId $resourceId -Tag $newTags -Force	
			}
			catch {
				"Error setting the resource ($($resourceId)) with resource type ($($resource.ResourceType))"
			}
		}
	}
}

"Done processing resources."