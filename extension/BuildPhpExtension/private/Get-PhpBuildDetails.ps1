function Get-PhpBuildDetails {
    <#
    .SYNOPSIS
        Get the PHP build Details.
    .PARAMETER Config
        Extension Configuration
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Configuration for the extension')]
        [PSCustomObject] $Config
    )
    begin {
    }
    process {
        if($Config.php_version -eq 'master') {
            $baseUrl = $fallbackBaseUrl = "https://github.com/shivammathur/php-builder-windows/releases/download/master"
            $PhpSemver = 'master'
        } else {
                $baseUrl = "https://files.ospanel.io/~windows/releases"
                $releases = Invoke-WebRequest "$baseUrl/releases.json" | ConvertFrom-Json
                $phpSemver = $releases.$($Config.php_version).version
        }
        return [PSCustomObject]@{
            phpSemver = $phpSemver
            baseUrl = $baseUrl
            fallbackBaseUrl = $fallbackBaseUrl
        }
    }
    end {
    }
}
