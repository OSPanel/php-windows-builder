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
    try {
        $url = "https://eu.ospanel.io/instantclient-sdk-$Arch.zip"

        Write-Host "Downloading OCI SDK from: $url"
        Invoke-WebRequest $url -OutFile "instantclient-sdk.zip"

        Write-Host "Extracting archive instantclient.zip..."
        Expand-Archive -Path "instantclient-sdk.zip" -DestinationPath "."

        Write-Host "OCI SDK successfully downloaded and extracted."
    }
    catch {
        Write-Error "Failed to retrieve OCI SDK: $_"
    }
}
