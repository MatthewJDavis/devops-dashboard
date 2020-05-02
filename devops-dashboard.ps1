# Get DevOps information
$OrgName = 'matthewjdavis111'
$PAToken = $env:PAT
$uri = "https://dev.azure.com/$OrgName"
$Cache:Headers = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAToken)")) }

#region projects
$projectUri = "$uri/_apis/projects?api-version=2.0"
$projectList = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $Cache:Headers
$projectListSorted = $projectList.value | Sort-Object -Property name
#endregion

#region select
$projectSelect = New-UDSelect -Label "Project" -Id 'projectSelect' -Option {
    foreach ($project in $projectListSorted) {
        New-UDSelectOption -Name $project.name -Value "$($project.id)"
    }
    
} -OnChange {
    $Session:Projectid = $eventData
    Sync-UDElement -Id 'grid'
}
#endregion

#region grid

$grid = New-UDGrid -Id 'grid' -Title 'Build Info' -Endpoint {
    if ($null -eq $Session:Projectid) {
        $Session:Projectid = $projectListSorted[0].id # needed to display build data when dashboard is first run
    }

    $BuildURI = "$uri/$Session:Projectid/_apis/build/builds?api-version=5.1"
    $buildList = Invoke-RestMethod -Uri $BuildURI -Headers $Cache:Headers
    $dataList = [System.Collections.Generic.list[pscustomobject]]::new()

    foreach ($build in $buildList.value) {
        $dataList.Add(
            [pscustomobject]@{
                'BuildNumber' = $build.buildNumber
                'StartTime'   = $build.StartTime
                'FinishTime'  = $build.FinishTime
                'Result'      = $build.result
                'Commit'      = (New-UDLink -Text $($build.sourceVersion.Substring(0, 6)) -Url $($build._links.sourceVersionDisplayUri.href)) 
            }
        )
    }
    #endregion
    $dataList | Out-UDGridData 
}
#endregion

$Dashboard = New-UDDashboard -Title "Build Dashboard!" -Content { $projectSelect, $grid }
Get-UDDashboard | Stop-UDDashboard
Start-UDDashboard -Dashboard $Dashboard -Port 10001
