[cmdletbinding()]
param(
    [Validateset('Default','Analyse','Test')]
    [string[]]
    $Task = 'default'
)


if (!(Get-Module -Name Pester -ListAvailable)) { Install-Module -Name Pester -Scope CurrentUser }
if (!(Get-Module -Name psake -ListAvailable)) { Install-Module -Name psake -Scope CurrentUser }
if (!(Get-Module -Name PSScriptAnalyzer -ListAvailable)) { Install-Module -Name PSScriptAnalyzer -Scope CurrentUser }

Invoke-psake -buildFile "$PSScriptRoot\psakeBuild.ps1" -taskList $Task -Verbose:$VerbosePreference
