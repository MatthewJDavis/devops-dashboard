Task default -depends Analyse, Test

Task Analyse -description 'Analyse script with PSScriptAnalyzer' {
    $saResults = Invoke-ScriptAnalyzer -Path .\devops-dashboard.ps1 -Severity @('Error')
    if($saResults) {
        $saResults | Format-Table
        Write-Error -Message 'One or more Script Analyser errors/warnings were found'
    }
}

Task Test -description 'Run Pester tests ' {
    $testResults = Invoke-Pester -Path $PSScriptRoot -PassThru
    if($testResults.FailedCount -gt 0) {
        $testResults | Format-List
        Write-Error  -Message 'One or more pester test failed!'
    }
}
