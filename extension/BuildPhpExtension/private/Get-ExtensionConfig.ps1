Function Get-ExtensionConfig {
    <#
    .SYNOPSIS
        Get the configuration for the extension.
    .PARAMETER Extension
        Extension Name
    .PARAMETER ExtensionRef
        Extension Reference
    .PARAMETER PhpVersion
        PHP Version
    .PARAMETER Arch
        Extension Architecture
    .PARAMETER Ts
        Extension Thread Safety
    .PARAMETER VsVersion
        Visual Studio version
    .PARAMETER VsToolset
        Visual Studio toolset
    #>
    [OutputType()]
    param(
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Extension Name')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Extension,
        [Parameter(Mandatory = $true, Position=1, HelpMessage='Extension Ref')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $ExtensionRef,
        [Parameter(Mandatory = $true, Position=2, HelpMessage='PHP Version')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $PhpVersion,
        [Parameter(Mandatory = $true, Position=3, HelpMessage='Extension Architecture')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Arch,
        [Parameter(Mandatory = $true, Position=4, HelpMessage='Extension Thread Safety')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Ts,
        [Parameter(Mandatory = $true, Position=5, HelpMessage='Visual Studio version')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $VsVersion,
        [Parameter(Mandatory = $true, Position=6, HelpMessage='Visual Studio toolset')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $VsToolset
    )
    begin {
    }
    process {
        try {
            Add-StepLog "Reading build configuration for $Extension"
            if(Test-Path $PSScriptRoot\..\config\stubs\$Extension.composer.json) {
                Copy-Item $PSScriptRoot\..\config\stubs\$Extension.composer.json composer.json
            }
            if(Test-Path $PSScriptRoot\..\config\stubs\$Extension-$ExtensionRef.composer.json) {
                Copy-Item $PSScriptRoot\..\config\stubs\$Extension-$ExtensionRef.composer.json composer.json
            }
            $ref = $ExtensionRef
            if ($ref -match 'refs/pull/(\d+)/merge') {
                $ref = $Matches[1]
            }
            $packageName = $Extension
            if($Extension.Contains("datadog_trace")) {
                $packageName = "ddtrace"
            }
            $config = [PSCustomObject]@{
                name = $Extension
                package_name = $packageName
                ref = $ref
                php_version = $PhpVersion
                arch = $Arch
                ts = $Ts
                vs_version = $VsVersion
                vs_toolset = $VsToolset
                debug_symbols = $True
                options = @()
                php_libraries = @()
                extension_libraries = @()
                build_tools = @()
                extensions = @()
                docs = @()
                build_directory = ""
            }
            $composerJson = $null

            if(Test-Path composer.json) {
                $composerJson = Get-Content composer.json -Raw | ConvertFrom-Json
            }
            if($null -ne $composerJson -and $null -ne $composerJson."php-ext" -and $null -ne $composerJson."php-ext"."configure-options") {
                $composerJson."php-ext"."configure-options" | ForEach-Object {
                    if($null -ne $_."needs-value" -and $_."needs-value" -eq $true -and $_.name -eq "with-$($Extension.ToLower())") {
                        $config.options += "--$($_.name)=shared"
                    } else {
                        $config.options += "--$( $_.name )"
                    }
                }
            }
            $config.options = $config.options -join " "

            if($null -ne $env:CONFIGURE_ARGS -and -not([string]::IsNullOrWhiteSpace($env:CONFIGURE_ARGS))) {
                $config.options += " $env:CONFIGURE_ARGS"
            }

            $Libraries = @()
            if($null -ne $env:LIBRARIES -and -not([string]::IsNullOrWhiteSpace($env:LIBRARIES))) {
                $Libraries = ($env:LIBRARIES -replace ' ', '') -split ','
            }

            $standardExtensions = @(
                "bcmath", "bz2", "calendar", "ctype", "curl", "date", "dba", "dom", "enchant",
                "exif", "ffi", "fileinfo", "filter", "ftp", "gd", "gettext", "gmp", "hash",
                "iconv", "imap", "intl", "json", "ldap", "libxml", "mbstring", "mysqli", "mysqlnd",
                "odbc", "openssl", "pcntl", "pcre", "pdo", "pdo_dblib", "pdo_firebird", "pdo_mysql",
                "pdo_oci", "pdo_odbc", "pdo_pgsql", "pdo_sqlite", "pgsql", "phar", "posix", "readline",
                "reflection", "session", "shmop", "simplexml", "snmp", "soap", "sockets", "sodium",
                "spl", "sqlite3", "standard", "sysvmsg", "sysvsem", "sysvshm", "tidy", "tokenizer",
                "xml", "xmlreader", "xmlwriter", "xsl", "zip", "zlib"
            )

            if($null -ne $composerJson) {
                $composerJson."require" | ForEach-Object {
                    $_.PSObject.Properties | ForEach-Object {
                        if($_.Name -match "ext-") {
                            $requiredExtension = $_.Name.Replace("ext-", "")

                            if (-not ($standardExtensions -contains $requiredExtension)) {
                            if($_.Value -match "\d+\.\d+.*") {
                                $requiredExtension += "-$($_.Value)"
                                } elseif ($_.Value -eq "*") {
                                    $matrixFile = Join-Path $PSScriptRoot "..\config\matrix.json"
                                    if (Test-Path $matrixFile) {
                                        $matrix = Get-Content $matrixFile -Raw | ConvertFrom-Json
                                        if ($matrix.PSObject.Properties.Name -eq $requiredExtension) {
                                            $extInfo = $matrix.$requiredExtension
                                            if ($extInfo.ver.PSObject.Properties.Name -eq $PhpVersion) {
                                                $versionFromMatrix = $extInfo.ver.$PhpVersion
                                                if (![string]::IsNullOrWhiteSpace($versionFromMatrix)) {
                                                    $requiredExtension += "-$versionFromMatrix"
                                                }
                                            }
                                        }
                                    }
                            }
                            $config.extensions += $requiredExtension
                                Write-Host "Added required extension: $requiredExtension"
                            }

                        } elseif(-not($_.Name -match "php")) {
                            # If using the stub composer.json
                            $Libraries += $_.Name
                        }
                    }
                }
            }

            $configW32Content = [string](Get-Content -Path "config.w32")
            if($configW32Content.contains('PATH_PROG')) {
                [regex]::Matches($configW32Content, 'PATH_PROG\(([''"])([^''"]+)\1') | ForEach-Object {
                    $config.build_tools += $_.Groups[2].Value
                }
            }
            if($configW32Content.contains('PYTHONHOME')) {
                $config.build_tools += "python"
            }

            if($env:AUTO_DETECT_ARGS -eq 'true') {
                $argument = Get-ArgumentFromConfig $Extension $configW32Content
                $argumentKey = $argument.Split("=")[0]
                if($null -ne $argument -and -not($config.options.contains($argumentKey))) {
                    $config.options += " $argument"
                }
            }

            if ([System.Environment]::GetEnvironmentVariable("no-debug-symbols-$Extension") -eq 'true') {
                $config.debug_symbols = $False
            }

            if($env:AUTO_DETECT_LIBS -eq 'true') {
                $detectedLibraries = Get-LibrariesFromConfig $Extension $VsVersion $Arch $configW32Content
                if($null -ne $detectedLibraries) {
                    $LibrariesList = $Libraries
                    $Libraries = $detectedLibraries.Split(" ")
                    $LibrariesList | ForEach-Object {
                        $libraryName = $_
                        $_ -Match '^(.+?)-\d|' | Out-Null
                        if($Matches.Count -gt 1) {
                            $libraryName = $Matches[1]
                        }
                        if (-not(($Libraries -Join ' ').Contains($libraryName))) {
                            $Libraries += $_
                        }
                    }
                }
            }

            if($Libraries.Count -gt 0) {
                $phpSeries = Get-File -Url "https://files.ospanel.io/~windows/php-sdk/deps/$VsVersion/$Arch"
                $extensionSeries = Get-File -Url "https://files.ospanel.io/~windows/pecl/deps"
                $extensionArchivesSeries = Get-File -Url "https://files.ospanel.io/~windows/pecl/deps/archives"
            }
            $thirdPartyLibraries = @("boost", "instantclient", "odbc_cli")
            $Libraries | Select-Object -Unique | ForEach-Object {
                if($thirdPartyLibraries.Contains($_)) {
                    $config.extension_libraries += $_
                } elseif($null -ne $_ -and -not([string]::IsNullOrWhiteSpace($_))) {
                    if ($phpSeries.Content.ToLower().Contains($_) -and -not($config.php_libraries.Contains($_))) {
                        $config.php_libraries += $_
                    } elseif (($extensionSeries.Content + $extensionArchivesSeries.Content).ToLower().Contains($_.ToLower()) -and -not($config.extension_libraries.Contains($_))) {
                        $lib = Get-PeclLibraryZip -Library $_ -PhpVersion $PhpVersion -VsVersion $VsVersion -Arch $Arch -ExtensionSeries $extensionSeries
                        if($null -ne $lib) {
                            $config.extension_libraries += $lib
                        } else {
                            $lib = Get-PeclLibraryZip -Library $_ -PhpVersion $PhpVersion -VsVersion $VsVersion -Arch $Arch -ExtensionSeries $extensionArchivesSeries
                            if($null -ne $lib) {
                                $config.extension_libraries += $lib
                            } else {
                                throw "Library $_ not found for the PHP version $PhpVersion and Visual Studio version $VsVersion"
                            }
                        }
                    } else {
                        throw "Library $_ not found for the PHP version $PhpVersion and Visual Studio version $VsVersion"
                    }
                }
            }

            # TODO: This should be implemented using composer.json once implemented
            $packageXml = Get-ChildItem (Get-Location).Path -Filter "package.xml" -ErrorAction SilentlyContinue | Select-Object -First 1
            if($null -ne $packageXml) {
                $xml = [xml](Get-Content $packageXml.FullName)
                $config.docs = $xml.SelectNodes("//*[@role='doc']") | ForEach-Object {
                    $path = $_.name
                    $current = $_.ParentNode
                    while ($null -ne $current -and $current.NodeType -eq "Element" -and $current.get_name() -eq "dir") {
                        $path = $current.name + '/' + $path
                        $current = $current.ParentNode
                    }
                    if ($path.StartsWith("/")) {
                        $path = $path.TrimStart("/")
                    }
                    $path -replace "/", "\"
                }
            }

            $config.build_directory = if ($Arch -eq "x64") { "x64\" } else { "" }
            $config.build_directory += "Release"
            if ($Ts -eq "ts") { $config.build_directory += "_TS" }
            Set-GAGroup start
            foreach ($prop in $config.PSObject.Properties) {
                Write-Host "$($prop.Name): $($prop.Value)"
            }
            Set-GAGroup end
            Add-BuildLog tick $Extension "Build configuration completed"
            return $config
        } catch {
            Add-BuildLog cross $Extension "Failed to read build configuration for $Extension"
            throw
        }

    }
    end {
    }
}
