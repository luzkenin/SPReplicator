# SPReplicator
PowerShell module to replicate SharePoint list data

## Get-SPRService
Creates a SharePoint Web service proxy object that lets you use and manage the Web service in Windows PowerShell.

![image](https://user-images.githubusercontent.com/8278033/42355459-ee853e20-8068-11e8-82cf-053ee6ebc5ce.png)

## Get-SPRList
Creates a SharePoint Web service proxy object that lets you use and manage a SharePoint list in Windows PowerShell.
    
![image](https://user-images.githubusercontent.com/8278033/42355538-5094da9e-8069-11e8-976e-5504c9af4076.png)

or alternatively

![image](https://user-images.githubusercontent.com/8278033/42355538-5094da9e-8069-11e8-976e-5504c9af4076.png)

## Get-SPRListData
Returns data from a SharePoint list using a Web service proxy object.
 
![image](https://user-images.githubusercontent.com/8278033/42355607-a08c5e3c-8069-11e8-92a4-b9273d648cf9.png)

## Get-SPRColumnDetail
Returns information (Name, DisplayName, Data type) about columns in a SharePoint list using a Web service proxy object.

![image](https://user-images.githubusercontent.com/8278033/42355638-cad24f08-8069-11e8-9fe2-c7ae147f1db9.png)

## Clear-SPRListData
Deletes all items from a SharePoint list using a Web service proxy object.
 
![image](https://user-images.githubusercontent.com/8278033/42355673-059062f6-806a-11e8-93e6-10e75ad8ab49.png)

## Add-SPRListItem
Adds items to a SharePoint list using a Web service proxy object.

![image](https://user-images.githubusercontent.com/8278033/42388506-6d84b5ca-80e1-11e8-9ed7-7bbfede791a1.png)

## Export-SPRListData
Exports all items to a file from a SharePoint list using a Web service proxy object.

![image](https://user-images.githubusercontent.com/8278033/42403716-d47ab30a-811e-11e8-9a33-7254d90a6f4b.png)

## Import-SPRListData
Imports all items from a file into a SharePoint list using a Web service proxy object.

![image](https://user-images.githubusercontent.com/8278033/42403894-6b91e0d2-8120-11e8-8659-34a7bb942b4a.png)

<!---
Connect-SPRSite -Uri sharepoint2016
Get-SPRList -Uri sharepoint2016 -ListName 'My List'
Get-SPRListData -Uri sharepoint2016 -ListName 'My List'
Get-SPRColumnDetail -Uri sharepoint2016 -ListName 'My List'

$object = @()
    $object += [pscustomobject]@{ Title = 'Hello'; TestColumn = 'Sample Data'; }
    $object += [pscustomobject]@{ Title = 'Hello2'; TestColumn = 'Sample Data2'; }
    $object += [pscustomobject]@{ Title = 'Hello3'; TestColumn = 'Sample Data3'; }
Add-SPRListItem -Uri sharepoint2016 -ListName 'My List' -InputObject $object

Invoke-DbaSqlQuery -SqlInstance sql2017 -Query "Select Title = 'Hello SQL', TestColumn = 'Sample SQL Data'" | 
Add-SPRListItem -Uri sharepoint2016 -ListName 'My List' 

$item = Invoke-DbaSqlQuery -SqlInstance sql2017 -Query "Select Title = 'Hello SQL', TestColumn = 'Sample SQL Data'" | 
Add-SPRListItem -Uri sharepoint2016 -ListName 'My List' 

Get-SPRListData -Uri sharepoint2016 -ListName 'My List' -Id $item.Id

rm C:\temp\mylist.xml
Export-SPRListData -Uri sharepoint2016 -ListName 'My List' -Path C:\temp\mylist.xml

Import-CliXml -Path C:\temp\mylist.xml | Add-SPRListItem -Uri sharepoint2016 -ListName 'My List'
Import-SPRListData -Uri sharepoint2016  -ListName 'My List' -Path C:\temp\mylist.xml

Clear-SPRListData -Uri sharepoint2016 -ListName 'My List' -Confirm:$false

New-SPRList -ListName 'My List'
New-SPRList -ListName 'My List2'
Add-SPRColumn -ListName 'My List'

Get-SPRList -Uri sharepoint2016 -ListName 'My List2' | Remove-SPRList -Confirm:$false
Get-SPRListData -ListName 'My List' | Where-Object Id -in $item.Id | Remove-SPRListData
-->