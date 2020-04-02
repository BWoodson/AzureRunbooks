# AzureRunbooks
A collection of Azure Runbooks to handle random tasks


## AutoStartStopVMs

Azure support automatically stopping a VM at a particular time, but not starting up at a particular time. This runbook look at all VMs with a 'power' tag that have a value with the 'xx:xx' format. Example: '08:16' starts the VM at 8 AM and shuts it down at 4 PM.

## AutoStartStopAnalysisServices

The same idea as **AutoStartStopVMs** but for Analysis Services

## SetResourceTags

Automatically sets the tagging for resources to match the tags of the resource group it belongs to. Does not overwrite tags if they already exist.