﻿Function Add-SPRListItem {
 <#
.SYNOPSIS
    Adds items to a SharePoint list.

.DESCRIPTION
    Adds items to a SharePoint list.

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

.PARAMETER AutoCreateList
    If a Sharepoint list does not exist, one will be created based off of the guessed column types.

.PARAMETER Column
    Only import specific columns.
 
.PARAMETER ExcludeColumn
    Exclude specific columns.
    
.PARAMETER InputObject
    Allows piping from Get-SPRList

.PARAMETER Quiet
    Do not output new item. Makes imports faster; useful for automated imports.
 
.PARAMETER AsUser
    Add the item as a specific user.
 
.PARAMETER LogToList
    You can log imports and export results to a list. Note this has to be a list from Get-SPRList.
  
.PARAMETER DataTypeMap
    Helps create accurate datatypes when used with -AutoCreateList

.PARAMETER DomainMap
    Allows remapping the People Picker at the domain level.

.PARAMETER UserMap
    Allows remapping the People Picker at the user level.
  
.PARAMETER WhatIf
    If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

.PARAMETER Confirm
    If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.EXAMPLE
    $csv = Import-Csv -Path C:\temp\listitems.csv
    Add-SPRListItem -Site intranet.ad.local -List 'My List' -InputObject $mycsv

    Adds data from listitems.csv into the My List SharePoint list, so long as there are matching columns.

.EXAMPLE
    Import-Csv -Path C:\temp\listitems.csv | Add-SPRListItem -Site intranet.ad.local -List 'My List' -UserMap @{ 'brice.hagood' = 'bhagood' }

    Adds data from listitems.csv into the My List SharePoint list, so long as there are matching columns.
    
    Remaps People Picker entry brice.hagood to bhagood to accommodate for different naming conventions. Otherwise, People Picker will attempt to resolve brice.hagood on the potentially new domain.

.EXAMPLE
    $object = @()
    $object += [pscustomobject]@{ Title = 'Hello'; TestColumn = 'Sample Data'; }
    $object += [pscustomobject]@{ Title = 'Hello2'; TestColumn = 'Sample Data2'; }
    $object += [pscustomobject]@{ Title = 'Hello3'; TestColumn = 'Sample Data3'; }
    Add-SPRListItem -Site intranet.ad.local -List 'My List' -InputObject $object

    Adds data from a custom object $object into the My List SharePoint list, so long as there are matching columns (Title and TestColumn).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, HelpMessage = "Human-readble SharePoint list name")]
        [string]$List,
        [Parameter(Position = 1, HelpMessage = "Human-readble SharePoint web name")]
        [string]$Web,
        [Parameter(Position = 2, HelpMessage = "SharePoint Site Collection")]
        [string]$Site,
        [PSCredential]$Credential,
        [string[]]$Column,
        [string[]]$ExcludeColumn,
        [parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [switch]$AutoCreateList,
        [switch]$Quiet,
        [string]$AsUser,
        [object]$DomainMap,
        [object[]]$UserMap,
        [object]$DataTypeMap,
        [Microsoft.SharePoint.Client.List]$LogToList,
        [switch]$EnableException
    )
    begin {
        $addcount = 0
        $start = Get-Date
        if ($AsUser) {
            $userobject = Get-SPRUser -Site $Site -Identity $AsUser -Credential $Credential
        }
        
        function New-SPlist {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
            [CmdletbInding()]
            param ()
            $firstobject = $InputObject | Select-Object -First 1
            if ($firstobject.ListObject) {
                $rowlist = $firstobject.ListObject
            }
            if ($firstobject -is [Microsoft.SharePoint.Client.List]) {
                $rowlist = $InputObject | Select-Object -First 1
            }
            
            $thislist = New-SPRList -Title $List
            if ($rowlist) {
                $columns = $rowlist | Get-SPRColumnDetail -Simple | Select-Object -ExpandProperty Name
                $validcolumntypes = (($rowlist | Get-SPRColumnDetail).TypeAsString | Select-Object -Unique)
                $newcolumns = $rowlist | Get-SPRColumnDetail -Simple | Where-Object FromBaseType -eq $false | Where-Object ColumnName -notin $columns, 'ListObject', 'ListItem', 'Title', 'ID' | Select-Object -ExpandProperty Name
                $spdatatype = $rowlist | Get-SPRColumnDetail -Simple | Select-SPRObject -Property Name, 'TypeAsString as Type'
                
                if (-not $DataTypeMap) {
                    $tempdatatype = @()
                    foreach ($dt in $spdatatype) {
                        $name = $dt.Name
                        $type = $dt.Type
                        if ($type -eq 'User') {
                            $type = 'Text'
                        }
                        $tempdatatype += [pscustomobject]@{
                            Name = $name
                            Type = $type
                        }
                    }
                    $DataTypeMap = $tempdatatype
                }
            } else {
                $datatable = $firstobject | ConvertTo-DataTable
                $listcolumns = $thislist | Get-SPRColumnDetail | Where-Object Title -ne Type
                $columns = $listcolumns.Title
                $validcolumntypes = @('Number', 'Text', 'Note', 'DateTime', 'Boolean', 'Currency', 'Guid', 'Choice')
                $validcolumntypes += (($thislist | Get-SPRColumnDetail).TypeAsString | Select-Object -Unique)
                $newcolumns = $datatable.Columns | Where-Object ColumnName -notin $columns, 'ListObject', 'ListItem', 'Title', 'ID'
            }
            
            Write-PSFMessage -Level Verbose -Message "All columns: $columns"
            Write-PSFMessage -Level Verbose -Message "New columns: $newcolumns"
            
            foreach ($column in $newcolumns) {
                $type = $null
                if ($DataTypeMap) {
                    $type = $DataTypeMap | Where-Object Name -eq $column | Select-Object -ExpandProperty Type
                }
                if (-not $type) {
                    $type = switch ($column.DataType.Name) {
                        "Double" { "Number" }
                        "Int16" { "Number" }
                        "Int32" { "Number" }
                        "Int64" { "Number" }
                        "Single" { "Number" }
                        "UInt16" { "Number" }
                        "UInt32" { "Number" }
                        "UInt64" { "Number" }
                        "Text" { "Text" }
                        "Note" { "Note" }
                        "DateTime" { "DateTime" }
                        "Boolean" { "Boolean" }
                        "Number" { "Number" }
                        "Decimal" { "Currency" }
                        "Guid" { "Guid" }
                        default { "Text" }
                    }
                    # trying to make sure it doesn't create the default column too small
                    # didn't default to Note for sorting reasons
                    if ($type -eq "Text") {
                        $tests = $column.Table.$column | Select-Object -First 50
                        foreach ($test in $tests) {
                            $value = $test | Out-String
                            if ($value.Length -gt 150) {
                                $type = "Note"
                            }
                        }
                    }
                }
                
                if ($type -notin $validcolumntypes -or (-not $AllowUserField -and $type -eq 'User')) {
                    $type = "Note"
                }
                
                if ($column.ColumnName) {
                    $cname = $column.ColumnName
                } else {
                    $cname = $column
                }
                
                
                if ([System.Uri]::IsWellFormedUriString(($column.Table.$column | Select-Object -First 1 | Out-String), "Absolute") -or $type -eq 'URL') {
                    $xml = "<Field Type='URL' Name='$cname' StaticName='$cname' DisplayName='$cname' Format='Hyperlink'/>"
                    $null = $thislist | Add-SPRColumn -ColumnName $cname -Xml $xml
                } else {
                    $null = $thislist | Add-SPRColumn -ColumnName $cname -Type $type
                }
            }
            return $thislist
        }
        
        function Add-Row {
            [cmdletbinding()]
            param (
                [object[]]$Row,
                [object[]]$ColumnInfo,
                [object]$DomainMap,
                [object[]]$UserMap
            )
            foreach ($currentrow in $row) {
                
                if ($currentrow.ListObject) {
                    $columns = $currentrow.ListObject | Get-SPRColumnDetail | Where-Object FromBaseType -eq $false | Select-Object -ExpandProperty Name
                } elseif ($currentrow -is [Microsoft.SharePoint.Client.List]) {
                    $columns = $currentrow | Get-SPRColumnDetail | Where-Object FromBaseType -eq $false | Select-Object -ExpandProperty Name
                } else {
                    $columns = $currentrow.PsObject.Members | Where-Object MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
                    
                    if (-not $columns) {
                        $columns = $currentrow.PsObject.Members | Where-Object MemberType -eq Property | Select-Object -ExpandProperty Name |
                        Where-Object {
                            $_ -notin 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors'
                        }
                    }
                }
                
                foreach ($fieldname in $columns) {
                    $datatype = ($ColumnInfo | Where-Object Name -eq $fieldname).Type
                    if ($datatype -eq 'Date and Time') {
                        if ($currentrow.$fieldname) {
                            $value = ((Get-Date $currentrow.$fieldname).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ssZ")
                        } else {
                            $value = $null
                        }
                    } elseif ($datatype -eq 'Person or Group') {
                        $value = $currentrow.$fieldname
                        if ($null -ne $value) {
                            if ($UserMap) {
                                foreach ($user in $UserMap) {
                                    if ($value -eq $user.Keys) {
                                        $value = "$value".Replace($user.Keys, $user.Values)
                                    }
                                }
                            }
                            if ($DomainMap) {
                                $value = "$value".Replace($DomainMap.Keys, $DomainMap.Values)
                            }
                            $value = (Get-SPRUser -Identity $value).FormattedLogin
                            if ($value.Length -eq 0) {
                                $value = $null
                            }
                        }
                    } else {
                        if ($datatype -ne 'Multiple lines of text') {
                            $value = [System.Security.SecurityElement]::Escape($currentrow.$fieldname)
                        } else {
                            $value = $currentrow.$fieldname
                        }
                        if ($value.Length -eq 0) {
                            $value = $null
                        }
                    }
                    
                    # Skip reserved words, so far is only ID
                    if ($fieldname -notin 'ID', 'SPReplicatorDataType') {
                        Write-PSFMessage -Level Debug -Message "Adding $fieldname to row"
                        $newItem.set_item($fieldname, $value)
                    } else {
                        Write-PSFMessage -Level Debug -Message "Not adding $fieldname to row (reserved name)"
                    }
                }
            }
            $newItem
        }
    }
    process {
        if (Test-PSFFunctionInterrupt) {
            return
        }
        $thislist = Get-SPRList -Site $Site -Credential $Credential -List $List -Web $Web
        
        if (-not $thislist) {
            if (-not $AutoCreateList) {
                $failure = $true
                Stop-PSFFunction -EnableException:$EnableException -Message "List does not exist. To auto-create, use -AutoCreateList"
                return
            } else {
                if ((Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $List -Action "Adding List $List")) {
                    $thislist = New-SPList
                }
            }
        }
        
        if ($InputObject[0] -is [Microsoft.SharePoint.Client.List]) {
            $InputObject = $InputObject | Get-SPRListItem
        }
        
        $columns = $thislist | Get-SPRColumnDetail | Where-Object Type -ne Computed | Sort-Object List, DisplayName
        
        if ($Column) {
            $columns = $columns | Where-Object DisplayName -in $Column
        }
        
        if ($ExcludeColumn) {
            $columns = $columns | Where-Object DisplayName -notin $ExcludeColumn
        }
        foreach ($row in $InputObject) {
            if ((Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $thislist.Context.Url -Action "Adding List item to $List")) {
                try {
                    $itemCreateInfo = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation
                    $newItem = $thislist.AddItem($itemCreateInfo)
                    $newItem = Add-Row -Row $row -ColumnInfo $columns -DomainMap $DomainMap -UserMap $UserMap
                    $newItem.Update()
                    $script:spsite.Load($newItem)
                    
                    Write-PSFMessage -Level Verbose -Message "Adding new item to $List"
                    $addcount++
                    $script:spsite.ExecuteQuery()
                    
                    if ($AsUser) {
                        Write-PSFMessage -Level Verbose -Message "Getting that $($newItem.Id)"
                        Get-SPRListItem -List $List -Web $Web -Id $newItem.Id | Update-SPRListItemAuthorEditor -UserObject $userobject -Quiet:$Quet -Confirm:$false
                    } elseif (-not $Quiet) {
                        Write-PSFMessage -Level Verbose -Message "Getting that $($newItem.Id)"
                        Get-SPRListItem -List $List -Web $Web -Id $newItem.Id
                    }
                } catch {
                    $failure = $true
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_
                    return
                }
            }
        }
    }
    end {
        if ($LogToList) {
            if ($thislist) {
                $thislist.Context.Load($thislist)
                $thislist.Context.ExecuteQuery()
                $thislist.Context.Load($thislist.RootFolder)
                $thislist.Context.ExecuteQuery()
                $url = "$($thislist.Context.Url)$($thislist.RootFolder.ServerRelativeUrl)"
                $currentuser = $thislist.Context.CurrentUser.ToString()
            } else {
                $currentuser = $script:spsite.CurrentUser.ToString()
            }
            if ($failure) {
                $result = "Failed"
                $errormessage = Get-PSFMessage -Errors | Select-Object -Last 1 -ExpandProperty Message
            } else {
                $result = "Succeeded"
            }
            $elapsed = (Get-Date) - $start
            $duration = "{0:HH:mm:ss}" -f ([datetime]$elapsed.Ticks)
            [pscustomobject]@{
                Title      = $List
                ItemCount  = $addcount
                Result     = $result
                Type       = "Import"
                RunAs      = $currentuser
                Duration   = $duration
                URL        = $url
                FinishTime = Get-Date
                Message    = $errormessage
            } | Add-LogListItem -ListObject $LogToList -Quiet
        }
    }
}