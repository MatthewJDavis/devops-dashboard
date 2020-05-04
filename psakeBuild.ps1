Task default -depends Analyse, Test

Task Analyse -description 'Analyse script with PSScriptAnalyzer' {
    'Running analyzer'
    Invoke-ScriptAnalyzer -Path .\devops-dashboard.ps1 -Verbose
}

Task Test -description 'Run pester tests ' {
    'Running Unit Tests'
    $testResults = Invoke-Pester -Path $PSScriptRoot\Tests\Unit -PassThru
    if($testResults.FailedCount -gt 0) {
        $testResults | Format-List
        Write-Error  -Message 'One or more pester test failed!'
    }
}
