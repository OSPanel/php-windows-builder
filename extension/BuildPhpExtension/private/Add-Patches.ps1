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
        $cur_Ref = ""
        if ($Extension -match '^(.*?)-') {
            $cur_Ref = $matches[2]
        }
        if($null -ne $env:GITHUB_REPOSITORY) {
                if(Test-Path -PATH $PSScriptRoot\..\patches\$Extension.ps1) {
                    . $PSScriptRoot\..\patches\$Extension.ps1
                }
                if(Test-Path -PATH $PSScriptRoot\..\patches\$Extension-$cur_Ref.ps1) {
                    . $PSScriptRoot\..\patches\$Extension-$cur_Ref.ps1
                }
        }
    }
    end {
    }
}