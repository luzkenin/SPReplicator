Set-PSFConfig -Module SPReplicator -Name Location -Value Onprem -Description "Specifies primary location: SharePoint Online (Online) or On-Premises (Onprem)" -Initialize
Set-PSFConfig -Module SPReplicator -Name SiteMapper -Value @{ } -Description "Hosts and locations (online vs onprem)" -Initialize