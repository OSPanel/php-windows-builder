Function Add-Patches {
    <#
    .SYNOPSIS
        Add patches to the extension.
    .PARAMETER Extension
        The extension name.
    #>
    [OutputType()]
    param(
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Extension')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Extension
    )
    begin {
    }
    process {
        # Apply patches only for php/php-windows-builder and shivammathur/php-windows-builder
        if($null -ne $env:GITHUB_REPOSITORY) {
            if($env:GITHUB_REPOSITORY -eq 'OSPanel/php-windows-builder') {
                if(Test-Path -PATH $PSScriptRoot\..\patches\$Extension.ps1) {
                    . $PSScriptRoot\..\patches\$Extension.ps1
                }
            }
        }
    }
    end {
    }
}