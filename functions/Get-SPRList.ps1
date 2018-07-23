﻿Function Get-SPRList {
<#
.SYNOPSIS
    Returns a SharePoint list object.

.DESCRIPTION
    Returns a SharePoint list object.

.PARAMETER WebName
    The human readable web name. So 'My Web' as opposed to 'MyWeb', unless you named it MyWeb.

.PARAMETER Site
    The address to the site collection. You can also pass a hostname and it'll figure it out.

    Don't want to specify the Site or Credential every time? Use Connect-SPRSite to create a reusable connection.
    See Get-Help Connect-SPRsite for more information.

.PARAMETER Credential
    Provide alternative credentials to the site collection. Otherwise, it will use default credentials.

.PARAMETER ListName
    The human readable list name. So 'My List' as opposed to 'MyList', unless you named it MyList.

.PARAMETER InputObject
    Allows piping from Connect-SPRSite

.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.EXAMPLE
    Get-SPRList -Site intranet.ad.local -ListName 'My List'

    Creates a web service object for My List on intranet.ad.local. Figures out the wsdl address automatically.

.EXAMPLE
    Connect-SPRSite -Site intranet.ad.local | Get-SPRList -ListName 'My List'

    Creates a web service object for My List on intranet.ad.local. Figures out the wsdl address automatically.

.EXAMPLE
    Get-SPRList -Site intranet.ad.local -ListName 'My List' -Credential (Get-Credential ad\user)

    Creates a web service object for My List and logs into the webapp as ad\user.
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, HelpMessage = "Human-readble SharePoint list name")]
        [string[]]$ListName,
        [Parameter(Position = 1, HelpMessage = "Human-readble SharePoint web name")]
        [string[]]$WebName,
        [Parameter(Position = 2, HelpMessage = "SharePoint Site Collection")]
        [string]$Site,
        [PSCredential]$Credential,
        [parameter(ValueFromPipeline)]
        [object]$InputObject,
        [switch]$EnableException
    )
    process {
        if (-not $InputObject) {
            if ($Site) {
                $null = Connect-SPRSite -Site $Site -Credential $Credential
            }
            
            if ($WebName) {
                $InputObject = Get-SPRWeb -WebName $WebName
            }
            elseif ($global:spweb) {
                $InputObject = $global:spweb
            }
            
            if (-not $InputObject) {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must specify Site, WebName or run Connect-SPRSite"
                return
            }
        }

        foreach ($server in $InputObject.Context) {
            if (-not $ListName) {
                try {
                    $server.Load($global:spweb)
                    $server.ExecuteQuery()
                    $lists = $global:spweb.Lists
                    $server.Load($lists)
                    $server.ExecuteQuery()
                    $lists | Select-DefaultView -Property Id, Title, Description, ItemCount, BaseType, Created
                }
                catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_
                }
            }
            else {
                foreach ($currentlist in $ListName) {
                    try {
                        $server.Load($global:spweb)
                        $server.ExecuteQuery()
                        $lists = $global:spweb.Lists
                        $server.Load($lists)
                        $server.ExecuteQuery()
                        $list = $lists | Where-Object Title -eq $currentlist
                        if ($list) {
                            Write-PSFMessage -Level Verbose -Message "Getting $currentlist from $($server.Url)"
                            $server.Load($list)
                            $server.ExecuteQuery()
                            Add-Member -InputObject $list -MemberType ScriptMethod -Name ToString -Value { $this.Title } -Force
                            $list | Select-DefaultView -Property Id, Title, Description, ItemCount, BaseType, Created
                        }
                    }
                    catch {
                        Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_
                    }
                }
            }
        }
    }
}