Function Add-OciSdk {
    <#
    .SYNOPSIS
        Add sdk for OCI extensions.
    .PARAMETER Config
        The directory to add to PATH.
    #>
    [OutputType()]
    param(
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Configuration for the extension')]
        [PSCustomObject] $Config
    )
    begin {
    }
    process {
        $repositoryInfo = $env:GITHUB_REPOSITORY -split '/'
        $owner = $repositoryInfo[0]
        $repository = $repositoryInfo[1]
        $ref = $env:GITHUB_REF
        $branch = $ref -replace 'refs/heads/', ''
        $downloadUrl = "https://raw.githubusercontent.com/$owner/$repository/refs/heads/$branch/resources/instantclient.zip"
        Invoke-WebRequest $downloadUrl -OutFile "instantclient.zip"
        Expand-Archive -Path "instantclient.zip" -DestinationPath "../deps" -Force
        Add-Path -PathItem (Join-Path (Get-Location).Path ../deps)
    }
    end {
    }
}
