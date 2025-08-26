Function Invoke-Build {
    <#
    .SYNOPSIS
        Build the extension
    .PARAMETER Config
        Extension Configuration
    #>
    [OutputType()]
    param(
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Extension Configuration')]
        [PSCustomObject] $Config
    )
    begin {
    }
    process {
        Add-StepLog "Building $($Config.name) extension"
        try {
            Set-GAGroup start
            Set-Location -Path (Join-Path -Path (Get-Location) -ChildPath $Config.name)
            $builder = "..\php-sdk\phpsdk-starter.bat"
            $task = [System.IO.Path]::Combine($PSScriptRoot, '..\config\task.bat')
            if($Config.php_version -eq '7.2') {
                $task = [System.IO.Path]::Combine($PSScriptRoot, '..\config\task72.bat')
            }
            $options = $Config.options
            if ($Config.debug_symbols) {
                $options += " --enable-debug-pack"
            }
            Set-Content -Path task.bat -Value (Get-Content -Path $task -Raw).Replace("OPTIONS", $options)

            $ref = $Config.ref
            if($env:ARTIFACT_NAMING_SCHEME -eq 'pecl') {
                $ref = $Config.ref.ToLower()
            }

            if ($Config.name -match 'redis|memcached|couchbase|yac|yar|immutable_cache') {
                if (Test-Path "..\igbinary\x64\Release\php_igbinary.lib") {
                    Copy-Item "..\igbinary\x64\Release\php_igbinary.lib" "..\php-dev\lib\php_igbinary.lib" -Force
                }
                if (Test-Path "..\igbinary\x64\Release_TS\php_igbinary.lib") {
                    Copy-Item "..\igbinary\x64\Release_TS\php_igbinary.lib" "..\php-dev\lib\php_igbinary.lib" -Force
                }
            }
            
            if ($Config.name -match 'memcached') {
                if (Test-Path "..\msgpack\x64\Release\php_msgpack.lib") {
                    Copy-Item "..\msgpack\x64\Release\php_msgpack.lib" "..\php-dev\lib\php_msgpack.lib" -Force
                }
                if (Test-Path "..\msgpack\x64\Release_TS\php_msgpack.lib") {
                    Copy-Item "..\msgpack\x64\Release_TS\php_msgpack.lib" "..\php-dev\lib\php_msgpack.lib" -Force
                }
            }

            if ($Config.name -match 'apc|memcached|couchbase') {
                if (Test-Path "..\apcu\x64\Release\php_apcu.lib") {
                    Copy-Item "..\apcu\x64\Release\php_apcu.lib" "..\php-dev\lib\php_apcu.lib" -Force
                }
                if (Test-Path "..\apcu\x64\Release_TS\php_apcu.lib") {
                    Copy-Item "..\apcu\x64\Release_TS\php_apcu.lib" "..\php-dev\lib\php_apcu.lib" -Force
                }
            }

            $suffix = "php_" + (@(
                $Config.name,
                $ref,
                $Config.php_version,
                $Config.ts,
                $Config.vs_version,
                $Config.arch
            ) -join "-")
            & $builder -c $Config.vs_version -a $Config.Arch -s $Config.vs_toolset -t task.bat | Tee-Object -FilePath "build-$suffix.txt"
            Set-GAGroup end
            if(-not(Test-Path "$((Get-Location).Path)\$($Config.build_directory)\php_$($Config.name).dll")) {
                throw "Failed to build the extension"
            }
            Add-BuildLog tick $Config.name "Extension $($Config.name) built successfully"
        } catch {
            Add-BuildLog cross $Config.name "Failed to build the extension"
            throw
        }
    }
    end {
    }
}
