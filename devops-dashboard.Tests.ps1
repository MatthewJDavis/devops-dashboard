$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"


Describe "Devops Dashboard" {
    It "throws an error when there is no environment variable set" {
        { Test-ForAccessToken } | Should -Throw
    }
}