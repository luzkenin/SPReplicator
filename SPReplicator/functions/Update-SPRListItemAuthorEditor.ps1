﻿Function Update-SPRListItemAuthorEditor {
<#
.SYNOPSIS
    Updates author (created by) from a SharePoint list.

.DESCRIPTION
    Updates author (created by) from a SharePoint list.

.PARAMETER Identity
    The Identity of the user.

.PARAMETER Column
    List of specific column(s) to be updated. If no columns are specified, we'll try to figure out which fields to update.

.PARAMETER List
    The human readable list name. So 'My List' as opposed to 'MyList', unless you named it MyList.

.PARAMETER Web
    The human readable web name. So 'My Web' as opposed to 'MyWeb', unless you named it MyWeb.

.PARAMETER Site
    The address to the site collection. You can also pass a hostname and it'll figure it out.

    Don't want to specify the Site or Credential every time? Use Connect-SPRSite to create a reusable connection.
    See Get-Help Connect-SPRsite for more information.

.PARAMETER Credential
    Provide alternative credentials to the site collection. Otherwise, it will use default credentials.

.PARAMETER InputObject
    Allows piping from Get-SPRListItem.
    
.PARAMETER Quiet
    Do not output new item. Makes imports faster; useful for automated imports.

.PARAMETER UserObject
    Pass a pre-resolved userobject.
    
.PARAMETER WhatIf
    If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

.PARAMETER Confirm
    If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.EXAMPLE
    Get-SPRListItem -List 'My List' -Site intranet.ad.local | Update-SPRListItemAuthorEditor -Identity ad\newuser

    Update the author and editor for all items in My List on intranet.ad.local to ad\newuser. Prompts for confirmation.

.EXAMPLE
    Get-SPRListItem -List 'My List' -Site intranet.ad.local | Update-SPRListItemAuthorEditor -Identity ad\newuser -Column Editor -Confirm:$false

    Updates just the editor for all items in My List on intranet.ad.local to ad\newuser. Does not prompt for confirmation.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Position = 0, HelpMessage = "Human-readble SharePoint list name")]
        [string[]]$List,
        [Parameter(Position = 1, HelpMessage = "Human-readble SharePoint web name")]
        [string[]]$Web,
        [Parameter(Position = 2, HelpMessage = "SharePoint Site Collection")]
        [string]$Site,
        [PSCredential]$Credential,
        [ValidateSet("Author", "Editor")]
        [string[]]$Column = @("Author", "Editor"),
        [string]$Identity,
        [parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [Microsoft.SharePoint.Client.User]$UserObject,
        [switch]$Quiet,
        [switch]$EnableException
    )
    begin {
        $script:updates = @()
        function Update-Row {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[cmdletbinding()]
            param (
                [object[]]$Row,
                [string[]]$ColumnNames,
                [object]$UserObject
            )
            
            $newuser = "{0};#{1}" -f $UserObject.Id, $UserObject.LoginName
            
            foreach ($currentrow in $row) {
                $runupdate = $false
                foreach ($fieldname in $ColumnNames) {
                    if (($currentrow.ListItem[$fieldname].Id) -ne $UserObject.Id) {
                        Write-PSFMessage -Level Debug -Message "Updating $fieldname setting to $UserObject"
                        $runupdate = $true
                        if ($fieldname -eq "Author") {
                            #IMPORTANT: Must be same name to get author updated
                            $currentrow.ListItem["Author"] = $newuser
                            $currentrow.ListItem["Editor"] = $newuser
                            $currentrow.ListItem.Update()
                        }
                        else {
                            $currentrow.ListItem[$fieldname] = $newuser
                            $currentrow.ListItem.Update()
                        }
                    }
                }
            }
            if ($runupdate) {
                $script:updates += $currentrow
            }
        }
    }
    process {
        if (-not $InputObject) {
            if ($Site) {
                $InputObject = Get-SPRListItem -Site $Site -Credential $Credential -List $List -Web $Web
            }
            elseif ($script:spsite) {
                $InputObject = Get-SPRListItem -List $List -Web $Web
            }
            else {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must specify Site and List pipe in results from Get-SPRList"
                return
            }
        }
        
        if (-not $InputObject) {
            Stop-PSFFunction -EnableException:$EnableException -Message "No records to update."
            return
        }
        
        if ($InputObject -is [Microsoft.SharePoint.Client.List]) {
            $InputObject = $InputObject | Get-SPRListItem
        }
        
        foreach ($item in $InputObject) {
            if (-not $item.ListObject) {
                Stop-PSFFunction -EnableException:$EnableException -Message "Invalid InputObject" -Continue
            }
            
            $thislist = $item.ListObject
            
            if (-not $UserObject) {
                try {
                    $UserObject = Get-SPRUser -Identity $Identity
                }
                catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_
                    continue
                }
            }
            
            if ((Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $thislist.Context.Url -Action "Updating record on $($thislist.Title), changing $Column to $Identity")) {
                try {
                    Update-Row -Row $item -ColumnNames $Column -UserObject $UserObject
                }
                catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                }
            }
        }
    }
    end {
        if ($script:updates.Id) {
            Write-PSFMessage -Level Debug -Message "Executing ExecuteQuery"
            $script:spsite.ExecuteQuery()
            if (-not $Quiet) {
                foreach ($listitem in $script:updates) {
                    Get-SPRListItem -Web $Web -List $listitem.ListObject.Title -Id $listitem.ListItem.Id
                }
            }
        }
        else {
            Write-PSFMessage -Level Verbose -Message "Nothing to update"
        }
    }
}