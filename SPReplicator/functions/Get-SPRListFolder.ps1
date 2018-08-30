﻿Function Get-SPRListFolder {
<#
.SYNOPSIS
    Gets a list of folders in a list.

.DESCRIPTION
    Gets a list of folders in a list.

.PARAMETER Name
    Name of the folder. If no name is provided, all folders will be returned.
   
.PARAMETER List
    The human readable list name. So 'My List' as opposed to 'My List', unless you named it MyList.

.PARAMETER Web
    The human readable web name. So 'My Web' as opposed to 'MyWeb', unless you named it MyWeb.

.PARAMETER Site
    The address to the site collection. You can also pass a hostname and it'll figure it out.

    Don't want to specify the Site or Credential every time? Use Connect-SPRSite to create a reusable connection.
    See New-Help Connect-SPRsite for more information.

.PARAMETER Credential
    Provide alternative credentials to the site collection. Otherwise, it will use default credentials.

.PARAMETER InputObject
    Piped input from a web
    
.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.EXAMPLE
    Get-SPRListFolder -List 'My List'

    Gets a list of all folders in My List
    
.EXAMPLE
    Get-SPRList -ListName 'My List' | Get-SPRListFolder -Name Sup

    Get a folder called Sup on My List
#>
    [CmdletBinding()]
    param (
        [string]$Name,
        [Parameter(HelpMessage = "Human-readble SharePoint list name")]
        [string[]]$List,
        [Parameter(HelpMessage = "Human-readble SharePoint web name")]
        [string[]]$Web,
        [Parameter(HelpMessage = "SharePoint Site Collection")]
        [string]$Site,
        [PSCredential]$Credential,
        [Parameter(ValueFromPipeline)]
        [Microsoft.SharePoint.Client.List[]]$InputObject,
        [switch]$EnableException
    )
    process {
        if (-not $InputObject) {
            if ($Site) {
                $InputObject = Get-SprList -Site $Site -Credential $Credential -List $List -Web $Web
            }
            elseif ($script:spsite) {
                $InputObject = Get-SPRList -List $List -Web $Web
            }
            else {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must specify Site and List pipe in results from Get-SPRList"
                return
            }
        }
        try {
            foreach ($thislist in $InputObject) {
                $folders = $thislist.RootFolder.Folders
                $thislist.Context.Load($folders)
                $thislist.Context.ExecuteQuery()
                if ($Name) {
                    foreach ($folder in $Name) {
                        $folders | Where-Object ServerRelativeUrl -match $folder | Select-SPRObject -Property Name, ServerRelativeUrl, TimeCreated, TimeLastModified
                    }
                }
                else {
                    $folders | Select-SPRObject -Property Name, ServerRelativeUrl, TimeCreated, TimeLastModified
                }
            }
        }
        catch {
            Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_ -Continue
        }
    }
}