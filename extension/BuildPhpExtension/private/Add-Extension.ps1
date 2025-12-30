Function Add-Extension {
    <#
    .SYNOPSIS
        Build a PHP extension.
    .PARAMETER Extension
        Extension name.
    .PARAMETER Config
        Configuration for the extension.
    .PARAMETER Prefix
        Prefix for the builds.
    #>
    [OutputType()]
    param(
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Extension name')]
        [PSCustomObject] $Extension,
        [Parameter(Mandatory = $true, Position=1, HelpMessage='Configuration for the extension')]
        [PSCustomObject] $Config,
        [Parameter(Mandatory = $true, Position=2, HelpMessage='Extension build prefix')]
        [string] $Prefix
    )
    begin {
    }
    process {
        Set-GAGroup start
        $currentDirectory = (Get-Location).Path
        $matrix = (Get-Content "$PSScriptRoot\..\config\matrix.json" -Raw | ConvertFrom-Json)
        $extensionName, $extensionVersion = $Extension -split '-', 2
        $url = $matrix.$extensionName.source
        $ref = $extensionVersion
        $local = ($null -eq $url -or $ref -eq '')
        $source = @{
            url   = $url
            ref   = $ref
            local = $local
        }
        $Extension = Get-Extension -ExtensionUrl $source.url -ExtensionRef $source.ref -PhpVersion $Config.php_version -BuildDirectory $currentDirectory -LocalSrc $source.local

        $configW32Content = [string](Get-Content -Path "config.w32")
        $argument = Get-ArgumentFromConfig $Extension $configW32Content
        $bat_content = @()
        $bat_content += ""
        $bat_content += "call phpize 2>&1"
        Write-Host "ARGUMENT: $argument"
            if($Config.php_version -eq '7.2') {
        $bat_content += "call configure `"--with-php-build=..\deps`" $argument `"--with-mp=disable`" `"--with-prefix=$Prefix`" 2>&1"
            } else {
        $bat_content += "call configure `"--with-php-build=..\deps`" $argument `"--with-mp=disable`" `"--enable-native-intrinsics=sse2,ssse3,sse4.1,sse4.2`" `"--with-prefix=$Prefix`" 2>&1"
            }

        $bat_content += "nmake /nologo 2>&1"
        $bat_content += "exit %errorlevel%"
        Set-Content -Encoding "ASCII" -Path $Extension-task.bat -Value $bat_content
        $builder = "$currentDirectory\php-sdk\phpsdk-starter.bat"
        $task = (Get-Item -Path "." -Verbose).FullName + "\$Extension-task.bat"
        $suffix = "php_" + (@(
            $Config.name,
            $Config.ref,
            $Config.php_version,
            $Config.ts,
            $Config.vs_version,
            $Config.arch
        ) -join "-")
        & $builder -c $Config.vs_version -a $Config.Arch -s $Config.vs_toolset -t $task | Tee-Object -FilePath "build-$suffix.txt"
        Write-Host (Get-Content "build-$suffix.txt" -Raw)
        $includePath = "$currentDirectory\php-dev\include"
        New-Item -Path $includePath\ext -Name $Extension -ItemType "directory" | Out-Null
        # Get-ChildItem -Path (Get-Location).Path -Recurse -Include '*.h', '*.c' | Copy-Item -Destination "$includePath\ext\$Extension"
        Copy-Item -Path (Join-Path (Get-Location).Path '*') -Destination "$includePath\ext\$Extension" -Recurse -Force
        Copy-Item -Path "$extensionBuildDirectory\*.dll" -Destination "$currentDirectory\php-bin\ext" -Force
        Copy-Item -Path "$extensionBuildDirectory\*.lib" -Destination "$currentDirectory\php-dev\lib" -Force
        Add-Content -Path "$currentDirectory\php-bin\php.ini" -Value "extension=$Extension"
        if (-not (Test-Path "..\pecl\$Extension")) { New-Item -ItemType Directory -Path "..\pecl\$Extension" -Force | Out-Null }; Copy-Item ".\*" -Destination "..\pecl\$Extension" -Recurse -Force
        Set-Location $currentDirectory
        Set-GAGroup end
    }
    end {
    }
}
