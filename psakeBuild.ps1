Task default -depends Analyse, Test

Task Analyse {
    'Running analyzer'
    Invoke-ScriptAnalyzer -Path .\devops-dashboard.ps1 -Verbose
}

Task Test {
    'Running Unit Tests'
    Invoke-Pester -Path $PSScriptRoot\Tests\Unit
}
