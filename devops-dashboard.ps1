function Test-ForAccessToken {
    if ($null -eq $env:PAT) {
        throw 'No Personal Access Token environment variable set. Set with $env:PAT="token"'
    }
}

function Start-BuildDashboard {
    Test-ForAccessToken
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
                        'BuildNumber' = (New-UDLink -Text $($build.buildNumber) -Url $($build._links.Web.href))
                        'StartTime'   = $build.StartTime
                        'FinishTime'  = $build.FinishTime
                        'Result'      = $build.result
                        'Commit'      = (New-UDLink -Text $($build.sourceVersion.Substring(0, 6)) -Url $($build._links.sourceVersionDisplayUri.href))
                        'Badge'       = $build._links.badge.href
                    }
                )
            }
        }
        Sync-UDElement -Id 'grid'
    }
    #endregion

    #region Dashboard components
    $projectSelect = New-UDSelect -Label "Project" -Id 'projectSelect' -Option {
        $SelectionList = [System.Collections.Generic.List[pscustomobject]]::new()
        $default = [pscustomobject]@{
            'Name'  = 'Select Project'
            'Value' = 'default'
        }
        $SelectionList.Add($default)
        foreach ($project in $cache:projectListSorted) {
            $SelectionList.Add(
                [pscustomobject]@{
                    'Name'  = $project.name
                    'Value' = "$($project.id)"
                }
            )
        }
        foreach ($item in $SelectionList) {
            New-UDSelectOption -Name $item.Name -Value $($item.Value)
        }
    } -OnChange {
        $Session:Projectid = $eventData
        Sync-UDElement -Id 'grid'
        Sync-UDElement -id 'Div1'
    }

    $card = New-UDElement -Tag div -Id "Div1" -Endpoint {
        if ($null -eq $Session:Projectid) {
            $result = '0'
            $rate = '0'
        }
        $result = ($Cache:dataList | Where-Object -Property 'ProjectID' -EQ $Session:Projectid | Select-Object -property 'Result' -First 1).Result 
        $resultList = ($Cache:dataList | Where-Object -Property 'ProjectID' -EQ $Session:Projectid | Select-Object -property 'Result').Result
        $total = $resultList.count
        if ($total -gt 0) {
            $success = ($resultList | Group-Object | Where-Object -Property Name -eq 'succeeded').Count
            if (-not $null -eq $Session:Projectid) {
                $rate = "$([math]::round($success / $total * 100, 2))" + '%'
            }
        } else {
            $rate = '0%'
        }
        New-UDLayout -Columns 3 -Content {
            $backgroundColour = switch ($result) {
                'succeeded' { 'green' }
                'partiallySucceeded' { 'blue' }
                'failed' { 'red' }
                Default { 'white' }
            }
            New-UDCard -Id 'statusCard' -Title 'Current Status' -BackgroundColor $backgroundColour -FontColor 'White' -Text $result
            New-UDCard -Id 'buildCount' -Title 'Build Count' -BackgroundColor $backgroundColour -FontColor 'White' -Text ($Cache:dataList | Where-Object -Property 'ProjectID' -EQ $Session:Projectid | Measure-Object ).Count 
            New-UDCard -Id 'successRate' -Title 'Success Rate' -BackgroundColor $backgroundColour -FontColor 'White' -Text $rate
        }
    }
    $grid = New-UDGrid -Id 'grid' -Title "Build Information" -Headers @('Build Number', 'Result', 'Commit', 'Start Time', 'Finish Time') -Properties @('BuildNumber', 'Result', 'Commit', 'StartTime', 'FinishTime') -Endpoint {
        $Cache:dataList | Where-Object -Property 'Projectid' -EQ $Session:Projectid | Out-UDGridData
    }
    #endregion

    $dashboard = New-UDDashboard -Title "Azure DevOps $OrgName" -Content { $projectSelect, $card, $grid } -EndpointInitialization $Init
    Start-UDDashboard -Dashboard $dashboard -Endpoint $BuildDataRefresh -Port 10002 
}
