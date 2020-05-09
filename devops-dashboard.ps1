function Test-ForAccessToken {
    if ($null -eq $env:PAT) {
        throw 'No Personal Access Token environment variable set. Set with $env:pat = Read-Host'
    }
}

function Start-BuildDashboard {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $Port = 10002,
        [Parameter(Mandatory)]
        [string]
        $OrgName
    )
    Test-ForAccessToken 
    $PAToken = $env:PAT
    $uri = "https://dev.azure.com/$OrgName"
    $Headers = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAToken)")) }
    $DashboardName = 'AzureDevOpsBuildDashboard'
    $Init = New-UDEndpointInitialization -Variable @('OrgName', 'PAToken', 'uri', 'Headers')
    $BuildRefresh = New-UDEndpointSchedule -Every 5 -Minute

    #region projects
    $projectUri = "$uri/_apis/projects?api-version=2.0"
    try {
        $projectList = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $Headers
    } catch [System.Net.WebException] {
        if ($_.exception -like "*could not be resolved*") {
            throw "Check Network connection. Error: $($_.exception.message)"
        } elseif ($_.exception.response.statuscode -eq 'NotFound') {
            throw "Check OrgName $orgName is correct. Status code recieved: $($_.exception.response.statuscode)"
        } elseif ($_.exception.response.statuscode -eq 'Unauthorized') {
            throw "Check OrgName $orgName is correct,  Personal Access Token is correct, has read permissons to builds and has not expired. Status code recieved: $($_.exception.response.statuscode)"
        } else {
            throw $_
        }
    } catch {
        throw "$($_.Exception)"
    }

    # final check to make sure we have a valid object and at least one project
    if ($projectList.gettype().Name -ne 'PSCustomObject') {
        throw "Did not get correct response from Azure DevOps API. Require 'PSCustomObject' but got $($projectList.gettype().Name) type. Check OrgName, Personal Access Token value, permissions and expiration"
    } elseif ($projectList.count -lt 1) {
        throw "No projects found in org $OrgName"
    } else {
        $Cache:projectListSorted = $projectList.value | Sort-Object -Property name
    }
    #endregion

    #region update project and build date
    $buildDataRefresh = New-UDEndpoint -Schedule $BuildRefresh -Endpoint {
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
    } # end UDSelect

    $card = New-UDElement -Tag div -Id "Div1" -Endpoint {
        if ($null -eq $Session:Projectid) {
            # No project id yet so nothing to display - prevent divide by 0 errors for percentage
            $latestResult = 'none'
            $successRate = '0'
        }
        $latestResult = ($Cache:dataList | Where-Object -Property 'ProjectID' -EQ $Session:Projectid | Select-Object -property 'Result' -First 1).Result 
        $resultList = ($Cache:dataList | Where-Object -Property 'ProjectID' -EQ $Session:Projectid | Select-Object -property 'Result').Result
        $total = $resultList.count
        if ($total -gt 0) {
            $success = ($resultList | Group-Object | Where-Object -Property Name -eq 'succeeded').Count # get how many builds were successful
            if (-not $null -eq $Session:Projectid) {
                $successRate = "$([math]::round($success / $total * 100, 2))" + '%' # calculate percentage of sucessful build to 2 decimal places
            }
        } else {
            $successRate = '0%'
        }
        New-UDLayout -Columns 3 -Content {
            $backgroundColour = switch ($latestResult) {
                'succeeded' { 'green' }
                'partiallySucceeded' { 'blue' }
                'failed' { 'red' }
                Default { 'white' }
            }
            New-UDCard -Id 'statusCard' -Title 'Current Status' -BackgroundColor $backgroundColour -FontColor 'White' -Text $latestResult
            New-UDCard -Id 'buildCount' -Title 'Build Count' -BackgroundColor $backgroundColour -FontColor 'White' -Text ($Cache:dataList | Where-Object -Property 'ProjectID' -EQ $Session:Projectid | Measure-Object ).Count 
            New-UDCard -Id 'successRate' -Title 'Success Rate' -BackgroundColor $backgroundColour -FontColor 'White' -Text $successRate
        }
    } #end UDElement
    
    $grid = New-UDGrid -Id 'grid' -Title "Build Information" -Headers @('Build Number', 'Result', 'Commit', 'Start Time', 'Finish Time') -Properties @('BuildNumber', 'Result', 'Commit', 'StartTime', 'FinishTime') -Endpoint {
        $Cache:dataList | Where-Object -Property 'Projectid' -EQ $Session:Projectid | Out-UDGridData
    }
    #endregion

    $dashboard = New-UDDashboard -Title "Azure DevOps $OrgName" -Content { $projectSelect, $card, $grid } -EndpointInitialization $Init
    Start-UDDashboard -Dashboard $dashboard -Name $DashboardName -Endpoint @($buildDataRefresh) -Port $Port 
}