function Get-Extension {
    <#
    .SYNOPSIS
        Get the PHP extension.
    .PARAMETER ExtensionUrl
        Extension URL
    .PARAMETER ExtensionRef
        Extension Reference
    .PARAMETER PhpVersion
        PHP Version
    .PARAMETER BuildDirectory
        Build directory
    .PARAMETER LocalSrc
        Is source local
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Extension URL')]
        [string] $ExtensionUrl = '',

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Extension Reference')]
        [string] $ExtensionRef = '',

        [Parameter(Mandatory = $true, Position=2, HelpMessage='PHP Version')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $PhpVersion,
        [Parameter(Mandatory = $true, Position=3, HelpMessage='Build directory')]
        [ValidateNotNull()]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $BuildDirectory,

        [Parameter(Mandatory = $true, Position=4, HelpMessage='Is source local')]
        [ValidateNotNull()]
        [bool] $LocalSrc = $false
    )

    begin {}

    process {
        if ($LocalSrc) {
            $currentDirectory = (Get-Location).Path
            $src = (Resolve-Path $currentDirectory).Path.TrimEnd('\')
            $dst = (Resolve-Path $BuildDirectory).Path.TrimEnd('\')
            if (Get-Command robocopy -ErrorAction SilentlyContinue) {
                & robocopy $src $dst /E /XD $dst "$src\.git" /XJ /MT:16 /R:2 /W:1 /NFL /NDL /NJH /NJS /NP *> $null
                if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
            } else {
                $excludeChild = $null
                if ($dst.StartsWith($src + '\', [StringComparison]::OrdinalIgnoreCase)) {
                    $rel = $dst.Substring($src.Length + 1)
                    $excludeChild = ($rel -split '\\', 2)[0]
                }
                Get-ChildItem -LiteralPath $src -Force |
                    Where-Object { $_.Name -ne '.git' -and ($null -eq $excludeChild -or $_.Name -ne $excludeChild) } |
                    Copy-Item -Destination $dst -Recurse -Force
            }
        }
        else {
            Add-StepLog "Fetching extension from $ExtensionUrl"
            try {
                if (
                    ($null -eq $ExtensionUrl -or $null -eq $ExtensionRef) -or
                    ($ExtensionUrl -eq '' -or $ExtensionRef -eq '')
                ) {
                    throw "Both Extension URL and Extension Reference are required."
                }

                Set-Location $BuildDirectory
                $currentDirectory = (Get-Location).Path
                $Extension = Split-Path -Path $ExtensionUrl -Leaf
                $extension_orig = $Extension
                
                if ($Extension.Contains("pecl_http"))        { $Extension = "http" }
                if ($Extension.Contains("dd-trace-php"))     { $Extension = "ddtrace" }
                if ($Extension.Contains("datadog_trace"))    { $Extension = "ddtrace" }
                if ($Extension.Contains("libsodium"))        { $Extension = "sodium" }
                if ($Extension.Contains("oci8"))             { $Extension = "oci8_19" }
                if ($Extension.Contains("pdo_oci"))          { $Extension = "pdo_oci" }

                $extensionPath = Join-Path -Path $currentDirectory -ChildPath $Extension

                if (-not (Test-Path $extensionPath)) {
                    New-Item -Path $extensionPath -ItemType Directory | Out-Null
                }

                Set-Location -Path $extensionPath
                $currentDirectory = (Get-Location).Path

                if ($null -ne $ExtensionUrl -and $null -ne $ExtensionRef) {
                    if ($ExtensionUrl -like "*pecl.php.net*") {
                        try {
                            Get-File -Url "https://pecl.php.net/get/$extension_orig-$ExtensionRef.tgz" -OutFile "$extension_orig-$ExtensionRef.tgz"
                        } catch {}

                        if (-not (Test-Path "$extension_orig-$ExtensionRef.tgz")) {
                            try {
                                Get-File -Url "https://pecl.php.net/get/$($extension_orig.ToUpper())-$ExtensionRef.tgz" -OutFile "$extension_orig-$ExtensionRef.tgz"
                            } catch {}
                        }

                        & tar -xzf "$extension_orig-$ExtensionRef.tgz" -C $currentDirectory
                        Copy-Item -Path "$extension_orig-$ExtensionRef\*" -Destination $currentDirectory -Recurse -Force
                        Remove-Item -Path "$extension_orig-$ExtensionRef" -Recurse -Force
                    }
                    else {
                        if ($null -ne $env:AUTH_TOKEN) {
                            $ExtensionUrl = $ExtensionUrl -replace '^https://', "https://${Env:AUTH_TOKEN}@"
                        }

                        git init > $null 2>&1
                        git remote add origin $ExtensionUrl > $null 2>&1

                        if ($Extension -in @("oci8_19", "pdo_oci")) {
                            git fetch --depth=1 origin main > $null 2>&1
                        }
                        else {
                            git fetch --depth=1 origin $ExtensionRef > $null 2>&1
                        }

                        git checkout FETCH_HEAD > $null 2>&1

                        $targetExtensions = @("ddtrace", "lz4", "phpredis", "redis", "brotli")
                        if ($targetExtensions | Where-Object { $Extension.Contains($_) }) {
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

                        if ($currentDirectoryName -eq "php-firebird") { 
                            $name = "interbase"
                        } else {
                            if (-not (Test-Path $xmlPath)) { throw "package.xml not found at $xmlPath" }
                            [xml]$xml = Get-Content $xmlPath
                            $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
                            $ns.AddNamespace("p", "http://pear.php.net/dtd/package-2.0")

                            $name = $xml.SelectSingleNode("//p:name", $ns).InnerText
                            if (-not $name) { throw "<name> tag not found in XML" }
                        }
                        
                        if ($name -eq "pecl_http") { $name = "http" }
                        if ($name -eq "datadog_trace") { $name = "ddtrace" }
                        if ($name -eq "oci8")          { $name = $Extension }

                        if ($name -eq $currentDirectoryName) { return }

                        $newPath = Join-Path $parentDirectory $name
                        if (Test-Path $newPath) { throw "Target folder already exists: $newPath" }

                        Set-Location $parentDirectory
                        Rename-Item -Path $currentDirectory -NewName $name

                        Write-Host "Renamed folder:`n$currentDirectory`n>`n$newPath"
                        Set-Location $newPath
                    }
                    catch {
                        Write-Host "Skipping rename: $_"
                    }
                }

                if ($Extension.Contains("lz4")) {
                    $currentDirectory = (Get-Location).Path
                    $parentDirectory = Split-Path $currentDirectory -Parent
                    Set-Location $parentDirectory
                    Rename-Item -Path $currentDirectory -NewName lz4
                    Set-Location lz4
                }
            }
            catch {
                Add-BuildLog cross extension "Failed to fetch extension from $ExtensionUrl"
                throw
            }
        }

        $currentDirectory = (Get-Location).Path
        $Extension = Split-Path -Path (Get-Location) -Leaf
        $patches = $false

        if ($null -ne $Extension) {
            if(Test-Path -PATH "$PSScriptRoot\..\patches\${Extension}-${ExtensionRef}.ps1") {
                    Add-Patches "${Extension}-${ExtensionRef}.ps1"
                    $patches = $true
            }
            
            if(Test-Path -PATH "$PSScriptRoot\..\patches\${Extension}.ps1") {
                    Add-Patches "${Extension}.ps1"
                    $patches = $true
            }
            
            if(Test-Path -PATH "$PSScriptRoot\..\patches\php\${PhpVersion}.ps1") {
                    Add-Patches "php\${PhpVersion}.ps1"
                    $patches = $true
            }
        }

        $configW32 = Get-ChildItem (Get-Location).Path -Recurse -Filter "config.w32" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $configW32) {
            if ($LocalSrc) {
                throw "No config.w32 found, please make sure you are in the extension source directory and it supports Windows."
            }
            else {
                throw "No config.w32 found, please check if the extension supports Windows."
            }
        }

        $subDirectory = $configW32.DirectoryName
        if ((Get-Location).Path -ne $subDirectory) {
            Copy-Item -Path "${subDirectory}\*" -Destination $currentDirectory -Recurse -Force
            Remove-Item -Path $subDirectory -Recurse -Force
        }

        $configW32Content = Get-Content -Path "config.w32"
        $extensionLine = $configW32Content | Select-String -Pattern '\s+(ZEND_)?EXTENSION\(' | Select-Object -Last 1

        if ($null -eq $extensionLine) {
            throw "No extension found in config.w32"
        }

        $name = ($extensionLine -replace '.*EXTENSION\(([^,]+),.*', '$1') -replace '["'']', ''

        if ($name.Contains('oci8')) {
            $name = $Extension
        }
        elseif ($name.Contains('libsodium')) {
            $name = 'sodium'
        }
        elseif ($Extension.Contains('mysql_xdevapi')) {
            $name = 'mysql_xdevapi'
        }
        elseif ([string]$configW32Content -match ($([regex]::Escape($name)) + '\s*=\s*["''](.+?)["'']')) {
            if ($matches[1] -ne 'no') {
                $name = $matches[1]
            }
        }

        if (-not $patches) {
            Add-Patches "${name}.ps1"
            Add-Patches "php\${PhpVersion}.ps1"
        }
        
        if (-not $LocalSrc) {
            Add-BuildLog tick $name "Fetched $name extension"
        }

        return $name
    }

    end {}
}
