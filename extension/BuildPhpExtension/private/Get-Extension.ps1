function Get-Extension {
    <#
    .SYNOPSIS
        Get the PHP extension.
    .PARAMETER ExtensionUrl
        Extension URL
    .PARAMETER ExtensionRef
        Extension Reference
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Extension URL')]
        [string] $ExtensionUrl,
        [Parameter(Mandatory = $true, Position=1, HelpMessage='Extension Reference')]
        [string] $ExtensionRef
    )
    begin {
    }
    process {
        Add-StepLog "Fetching extension from $ExtensionUrl-$ExtensionRef.tgz"
        try {
            if(
            ($null -eq $ExtensionUrl -or $null -eq $ExtensionRef) -or
                    ($ExtensionUrl -eq '' -or $ExtensionRef -eq '')
            ) {
                throw "Both Extension URL and Extension Reference are required."
            }
            $currentDirectory = (Get-Location).Path
                    $Extension = Split-Path -Path $ExtensionUrl -Leaf
                    $extension_orig = Split-Path -Path $ExtensionUrl -Leaf

                    if($Extension.Contains("dd-trace-php")) {
                        $Extension = "ddtrace"
                    }

                    if($Extension.Contains("datadog_trace")) {
                        $Extension = "ddtrace"
                    }

                    if($Extension.Contains("libsodium")) {
                        $Extension = "sodium"
                    }

                    if($Extension.Contains("oci8")) {
                        $Extension = "oci8_19"
                    }

                    if($Extension.Contains("pdo_oci")) {
                        $Extension = "pdo_oci"
                    }

                    if($Extension.Contains("apcu_bc")) {
                        $Extension = "apc"
                    }

                    $extensionPath = Join-Path -Path $currentDirectory -ChildPath $Extension

                    if (-not (Test-Path $extensionPath)) {
                        New-Item -Path $extensionPath -ItemType Directory | Out-Null
                    }

                    Set-Location -Path $extensionPath
                    $currentDirectory = (Get-Location).Path
                    
            if($null -ne $ExtensionUrl -and $null -ne $ExtensionRef) {
                if ($ExtensionUrl -like "*pecl.php.net*") {
                    try {
                        Get-File -Url "https://pecl.php.net/get/$extension_orig-$ExtensionRef.tgz" -OutFile "$extension_orig-$ExtensionRef.tgz"
                    } catch {}
                    if(-not(Test-Path "$extension_orig-$ExtensionRef.tgz")) {
                        try {
                            Get-File -Url "https://pecl.php.net/get/$($extension_orig.ToUpper())-$ExtensionRef.tgz" -OutFile "$extension_orig-$ExtensionRef.tgz"
                        } catch {}
                    }
                    & tar -xzf "$extension_orig-$ExtensionRef.tgz" -C $currentDirectory
                    Copy-Item -Path "$extension_orig-$ExtensionRef\*" -Destination $currentDirectory -Recurse -Force
                    Remove-Item -Path "$extension_orig-$ExtensionRef" -Recurse -Force
                } else {
                    if($null -ne $env:AUTH_TOKEN) {
                        $ExtensionUrl = $ExtensionUrl -replace '^https://', "https://${Env:AUTH_TOKEN}@"
                    }
                    git init > $null 2>&1
                    git remote add origin $ExtensionUrl > $null 2>&1
                    if ($Extension -in @("oci8_19","pdo_oci")) {
                        git fetch --depth=1 origin main > $null 2>&1
                    } else {
                        git fetch --depth=1 origin $ExtensionRef > $null 2>&1
                    }   
                    git checkout FETCH_HEAD > $null 2>&1
                    $targetExtensions = @("ddtrace", "lz4")
                    if($targetExtensions | Where-Object { $Extension.Contains($_) }) {
                        git submodule update --init --recursive > $null 2>&1
                    }
                }
            }

            & {
                try {
                    $currentDirectory = (Get-Location).Path
                    $currentDirectoryName = Split-Path $currentDirectory -Leaf
                    $parentDirectory = Split-Path $currentDirectory -Parent
                    $xmlPath = Join-Path $currentDirectory "package.xml"
                    if (-not (Test-Path $xmlPath)) { throw "package.xml not found at $xmlPath" }

                    [xml]$xml = Get-Content $xmlPath
                    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
                    $ns.AddNamespace("p", "http://pear.php.net/dtd/package-2.0")
                    $name = $xml.SelectSingleNode("//p:name", $ns).InnerText

                    if (-not $name) { throw "<name> tag not found in XML" }
                    if ($name -eq "datadog_trace") { $name = "ddtrace" }
                    if ($name -eq "oci8") { $name = $Extension }
                    if ($name -eq "apcu_bc") { $name = $Extension }
                    if ($name -eq $currentDirectoryName) { return }
                    $newPath = Join-Path $parentDirectory $name
                    if (Test-Path $newPath) { throw "Target folder already exists: $newPath" }

                    Set-Location $parentDirectory
                    Rename-Item -Path $currentDirectory -NewName $name

                    Write-Host "Renamed folder:`n$currentDirectory`n>`n$newPath"
                    Set-Location $newPath
                } catch {
                    Write-Host "Skipping rename: $_"
                }
            }

            if($Extension.Contains("lz4")) {
                    $currentDirectory = (Get-Location).Path
                    $parentDirectory = Split-Path $currentDirectory -Parent
                    Set-Location $parentDirectory
                    Rename-Item -Path $currentDirectory -NewName lz4
                    Set-Location lz4
            }

            $currentDirectory = (Get-Location).Path

            $Extension = Split-Path -Path (Get-Location) -Leaf

            $patches = $False
            if(Test-Path -PATH $PSScriptRoot\..\patches\$Extension.ps1) {
                 Add-Patches $Extension
                 $patches = $True
            }
            if(Test-Path -PATH $PSScriptRoot\..\patches\$Extension-$ExtensionRef.ps1) {
                 Add-Patches "$Extension-$ExtensionRef"
                 $patches = $True
            }

            $configW32 = Get-ChildItem (Get-Location).Path -Recurse -Filter "config.w32" -ErrorAction SilentlyContinue
            if($null -eq $configW32) {
                throw "No config.w32 found"
            }
            $subDirectory = $configW32.DirectoryName
            if((Get-Location).Path -ne $subDirectory) {
                Copy-Item -Path "${subDirectory}\*" -Destination $currentDirectory -Recurse -Force
                Remove-Item -Path $subDirectory -Recurse -Force
            }
            $configW32Content = Get-Content -Path "config.w32"
            $extensionLine =  $configW32Content | Select-String -Pattern '\s+(ZEND_)?EXTENSION\(' | Select-Object -Last 1
            if($null -eq $extensionLine) {
                throw "No extension found in config.w32"
            }
            $name = ($extensionLine -replace '.*EXTENSION\(([^,]+),.*', '$1') -replace '["'']', ''
            if($name.Contains('oci8')) {
                $name = $Extension
            } elseif($name.Contains('libsodium')) {
                $name = 'sodium'
            } elseif($Extension.Contains('mysql_xdevapi')) {
                $name = 'mysql_xdevapi'
            } elseif ([string]$configW32Content -match ($([regex]::Escape($name)) + '\s*=\s*["''](.+?)["'']')) {
                if($matches[1] -ne 'no') {
                    $name = $matches[1]
                }
            }

            if(!$patches) {
                Add-Patches $name
            }
            Add-BuildLog tick $name "Fetched $name extension"
            return $name
        } catch {
            Add-BuildLog cross extension "Failed to fetch extension from $ExtensionUrl"
            throw
        }
    }
    end {
    }
}
