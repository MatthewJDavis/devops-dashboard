$OrgName = 'matthewjdavis111'
$PAToken = $env:PAT
$uri = "https://dev.azure.com/$OrgName"
$Headers = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAToken)")) }
$Init = New-UDEndpointInitialization -Variable @('OrgName', 'PAToken', 'uri', 'Headers')

#region projects
$projectUri = "$uri/_apis/projects?api-version=2.0"
$projectList = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $Headers
$Cache:projectListSorted = $projectList.value | Sort-Object -Property name
#endregion

#region update build data
$Schedule = New-UDEndpointSchedule -Every 5 -Minute
$BuildDataRefresh = New-UDEndpoint -Schedule $Schedule -Endpoint {
    $Cache:dataList = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($project in $Cache:projectListSorted) {
        $BuildURI = "$uri/$($project.id)/_apis/build/builds?api-version=5.1"
        $buildList = Invoke-RestMethod -Uri $BuildURI -Headers $Headers
        foreach ($build in $buildList.value) {
            $Cache:dataList.Add(
                [pscustomobject]@{
                    'ProjectId'   = $project.id
                    'BuildNumber' = $build.buildNumber
                    'StartTime'   = $build.StartTime
                    'FinishTime'  = $build.FinishTime
                    'Result'      = $build.result
                    'Commit'      = (New-UDLink -Text $($build.sourceVersion.Substring(0, 6)) -Url $($build._links.sourceVersionDisplayUri.href))
                }
            )
        }
    }
    Sync-UDElement -Id 'grid'
}
#endregion

#region Dashboard components
$projectSelect = New-UDSelect -Label "Project" -Id 'projectSelect' -Option {
    foreach ($project in $cache:projectListSorted) {
        New-UDSelectOption -Name $project.name -Value "$($project.id)"
    }
} -OnChange {
    $Session:Projectid = $eventData
    Sync-UDElement -Id 'grid'
}

$grid = New-UDGrid -Id 'grid' -Title 'Build Info' -Endpoint {
    $Cache:dataList | Where-Object -Property 'Projectid' -EQ $Session:Projectid | Out-UDGridData
}
#endregion


$dashboard = New-UDDashboard -Title 'Azure DevOps Builds' -Content { $projectSelect, $grid } -EndpointInitialization $Init
Start-UDDashboard -Dashboard $dashboard -Endpoint $BuildDataRefresh -Port 10001