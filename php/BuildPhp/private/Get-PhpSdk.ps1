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
        $url = "https://github.com/php/php-sdk-binary-tools/archive/php-sdk-$sdkVersion.zip"
    }
    process {
        Get-File -Url $url -OutFile php-sdk.zip
        Expand-Archive -Path php-sdk.zip -DestinationPath .
        Rename-Item -Path php-sdk-binary-tools-php-sdk-$sdkVersion php-sdk
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/OSPanel/php-windows-builder/refs/heads/master/resources/Series.php" -OutFile "php-sdk\lib\php\libsdk\SDK\Build\Dependency\Series.php"
    }
    end {
    }
}
