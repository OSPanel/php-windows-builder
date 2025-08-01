function Invoke-PhpBuildExtension {
    <#
    .SYNOPSIS
        Build PHP Extension
    .PARAMETER ExtensionUrl
        Extension URL
    .PARAMETER ExtensionRef
        Extension Reference
    .PARAMETER PhpVersion
        PHP Version
    .PARAMETER Arch
        Architecture
    .PARAMETER Ts
        Thread Safety
    .PARAMETER Libraries
        Libraries required by the extension
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $false, Position=0, HelpMessage='Extension URL')]
        [string] $ExtensionUrl = '',
        [Parameter(Mandatory = $false, Position=1, HelpMessage='Extension Reference')]
        [string] $ExtensionRef = '',
        [Parameter(Mandatory = $true, Position=2, HelpMessage='PHP Version')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $PhpVersion,
        [Parameter(Mandatory = $true, Position=3, HelpMessage='PHP Architecture')]
        [ValidateNotNull()]
        [ValidateSet('x86', 'x64')]
        [string] $Arch,
        [Parameter(Mandatory = $true, Position=4, HelpMessage='PHP Build Type')]
        [ValidateNotNull()]
        [ValidateSet('nts', 'ts')]
        [string] $Ts
    )
    begin {
    }
    process {
        Set-StrictMode -Off
        Set-NetSecurityProtocolType
        $VsData = (Get-VsVersion -PhpVersion $PhpVersion)
        if($null -eq $VsData.vs) {
            throw "PHP version $PhpVersion is not supported."
        }

        $currentDirectory = (Get-Location).Path

        $buildDirectory = Get-BuildDirectory

        Set-Location "$buildDirectory"

        $source = Get-ExtensionSource -ExtensionUrl $ExtensionUrl -ExtensionRef $ExtensionRef

        $extension = Get-Extension -ExtensionUrl $source.url -ExtensionRef $source.ref

        Set-Location "$buildDirectory"
        
        $config = Add-BuildRequirements -Extension $extension `
                                        -ExtensionRef $source.ref `
                                        -PhpVersion $PhpVersion `
                                        -Arch $Arch `
                                        -Ts $Ts `
                                        -VsVersion $VsData.vs `
                                        -VsToolset $VsData.toolset

        Set-Location "$buildDirectory"
        
        if (Test-Path '..\deps') { New-Item -ItemType Directory -Path 'deps' -Force | Out-Null; Copy-Item '..\deps\*' -Destination 'deps' -Recurse -Force }

        $config = @($config) | Where-Object { $_.GetType().FullName -eq 'System.Management.Automation.PSCustomObject' } | Select-Object -First 1
        
        Invoke-Build -Config $config

        if($env:RUN_TESTS -eq 'true') {
            Invoke-Tests -Config $config
        }

        Add-Package -Config $config

        Set-Location $currentDirectory
        Move-Item -Path "$buildDirectory\$($Config.package_name)\artifacts\*" -Destination "$currentDirectory\artifacts" -Force
    }
    end {
    }
}
