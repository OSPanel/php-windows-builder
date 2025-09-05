function Get-PhpSdk {
    <#
    .SYNOPSIS
        Get the PHP SDK.
    #>
    [OutputType()]
    param (
    )
    begin {
        $sdkVersion = "2.4.0"
        $url = "https://files.ospanel.io/php-sdk-$sdkVersion.zip"
    }
    process {
        Get-File -Url $url -OutFile php-sdk.zip
        Expand-Archive -Path php-sdk.zip -DestinationPath .
        Rename-Item -Path php-sdk-binary-tools-php-sdk-$sdkVersion php-sdk
    }
    end {
    }
}
