$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = "1.0.0.0"

function Import-ModuleFile
{
	<#
		.SYNOPSIS
			Loads files into the module on module import.
		
		.DESCRIPTION
			This helper function is used during module initialization.
			It should always be dotsourced itself, in order to proper function.
			
			This provides a central location to react to files being imported, if later desired
		
		.PARAMETER Path
			The path to the file to load
		
		.EXAMPLE
			PS C:\> . Import-ModuleFile -File $function.FullName
	
			Imports the file stored in $function according to import policy
	#>
	[CmdletBinding()]
	Param (
		[string]
		$Path
	)
	
	if ($doDotSource) { . $Path }
	else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null) }
}

# Detect whether at some level dotsourcing was enforced
$script:doDotSource = Get-PSFConfigValue -FullName SPReplicator.Import.DoDotSource -Fallback $false
if ($SPReplicator_dotsourcemodule) { $script:doDotSource = $true }

# Execute Preimport actions
. Import-ModuleFile -Path "$ModuleRoot\internal\scripts\preimport.ps1"

# Import all internal functions
foreach ($function in (Get-ChildItem "$ModuleRoot\internal\functions" -Filter "*.ps1" -Recurse -ErrorAction Ignore))
{
	. Import-ModuleFile -Path $function.FullName
}

# Import all public functions
foreach ($function in (Get-ChildItem "$ModuleRoot\functions" -Filter "*.ps1" -Recurse -ErrorAction Ignore))
{
	. Import-ModuleFile -Path $function.FullName
}

# Execute Postimport actions
. Import-ModuleFile -Path "$ModuleRoot\internal\scripts\postimport.ps1"

# Those remain in the psm1 in order for it to be easily available from PowerShell Studio completion
$script:spweb = $global:SPReplicator.Web
$script:spsite = $global:SPReplicator.Site
if ($global:SPReplicator.LogList) {	$global:SPReplicator.LogList | Set-SPRLogList }

$global:SPReplicator = [pscustomobject]@{
	Web	    = $script:spweb
	Site    = $script:spsite
	LogList = $global:SPReplicator.LogList
	ListNames = $global:SPReplicator.ListNames
	UserCache = @{ }
}