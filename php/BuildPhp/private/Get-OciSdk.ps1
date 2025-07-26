function Get-OciSdk {
    <#
    .SYNOPSIS
        Add the OCI SDK for building oci and pdo_oci extensions

    .PARAMETER Arch
        The architecture of the OCI sdk.
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The architecture of the OCI sdk.')]
        [string]$Arch
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
        Expand-Archive -Path "instantclient.zip" -DestinationPath "."      
    }
    end {
    }
}
