Function Add-ExtensionDependencies {
    <#
    .SYNOPSIS
        Add a directory to PATH environment variable.
    .PARAMETER Config
        Configuration for the extension.
    #>
    [OutputType()]
    param(
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Configuration for the extension')]
        [PSCustomObject] $Config
    )
    begin {
    }
    process {
        if($Config.extension_libraries.Count -ne 0) {
            Add-StepLog "Adding libraries (third-party)"
        }
        $Config.extension_libraries | ForEach-Object {
            $library = $_.split('-')[0]
            try {
                switch ($_)
                {
                    boost {
                        Add-Boost
                    }
                    instantclient {
                        Add-OciSdk -Config $Config
                    }
                    odbc_cli {
                        Add-OdbcCli -Config $Config
                    }
                    Default {
                        $url = "https://files.ospanel.io/~windows/pecl/deps/$_"
                        Get-File -Url $url -OutFile $_
                        Expand-Archive -Path $_ -DestinationPath "..\deps" -Force
                        if(Test-Path "..\deps\LICENSE") {
                            Rename-Item -Path "..\deps\LICENSE" -NewName "LICENSE.$library"
                        }
                        if(Test-Path "..\deps\lib\ossl-modules") {
                            Move-Item -Path "..\deps\lib\ossl-modules\*" -Destination "..\deps\lib"
                            Remove-Item -Path "..\deps\lib\ossl-modules" -Force -Recurse
                        }
                    }
                }
                Add-BuildLog tick "$library" "Added $($_ -replace '\.zip$')"
            } catch {
                Add-BuildLog cross "$library" "Failed to download $library"
                throw
            }
        }
    }
    end {
    }
}
