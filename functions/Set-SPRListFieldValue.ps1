﻿Function Set-SPRListFieldValue {
<#
.SYNOPSIS
    Updates columns to new valus in a SharePoint list.

.DESCRIPTION
    Updates columns to new valus in a SharePoint list.

.PARAMETER List
    The human readable list name. So 'My List' as opposed to 'MyList', unless you named it MyList.

.PARAMETER Value
    The new value

.PARAMETER Column
    List of specific column(s) to be updated.
    
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
 
.PARAMETER WhatIf
    If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

.PARAMETER Confirm
    If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.EXAMPLE
Get-SPRListItem -List Grades | Where LastName -match LeMaire | Set-SPRListFieldValue -Column Grade -Value A
    
Changes Grade to A for all items matching LastName LeMaire in the Grades list 😏. Assumes current site is connected.
 
.EXAMPLE
Connect-SPRSite -Site https://school.sharepoint.com -Credential ad\user
Get-SPRListItem -List Grades | Where LastName -match LeMaire | Set-SPRListFieldValue -Column Grade -Value A

Connects to  https://school.sharepoint.com as user ad\user then changes Grade to A for all items matching LastName LeMaire in the Grades list.
    
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Position = 0, HelpMessage = "Human-readble SharePoint list name")]
        [string]$List,
        [Parameter(Mandatory)]
        [string[]]$Column,
        [Parameter(HelpMessage = "SharePoint Site Collection")]
        [string]$Site,
        [Parameter(Mandatory)]
        [string]$Value,
        [PSCredential]$Credential,
        [Parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [switch]$Quiet,
        [switch]$EnableException
    )
    begin {
        $spuser = $null
        $script:updates = @()
        function Update-Row {
            [cmdletbinding()]
            param (
                [object[]]$Row,
                [string[]]$ColumnNames,
                [string]$Value
            )
            foreach ($currentrow in $row) {
                $runupdate = $false
                foreach ($fieldname in $ColumnNames) {
                    if (-not $currentrow.ListItem[$fieldname]) {
                        Stop-PSFFunction -EnableException:$EnableException -Message "$fieldname does not exist" -Continue
                    }
                    
                    Write-PSFMessage -Level Debug -Message "Updating $fieldname"
                    $runupdate = $true
                    $currentrow.ListItem[$fieldname] = $Value
                    $currentrow.ListItem.Update()
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
                $InputObject = Get-SPRListItem -Site $Site -Credential $Credential -List $List
            }
            elseif ($global:spsite) {
                $InputObject = Get-SPRListItem -List $List
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
            
            if ((Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $thislist.Context.Url -Action "Updating record $($item.Id) from $($list.Title)")) {
                try {
                    Update-Row -Row $item -ColumnNames $Column -Value $value
                }
                catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
                }
            }
        }
    }
    end {
        if ($script:updates.Id) {
            Write-PSFMessage -Level Verbose -Message "Executing ExecuteQuery"
            $global:spsite.ExecuteQuery()
            if (-not $Quiet) {
                foreach ($listitem in $script:updates) {
                    Get-SPRListItem -List $listitem.ListObject.Title -Id $listitem.ListItem.Id
                }
            }
        }
    }
}