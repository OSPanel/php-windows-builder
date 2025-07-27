Function Add-Extension {
    <#
    .SYNOPSIS
        Build a PHP extension.
    .PAMAETER Extension
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
        Invoke-WebRequest -Uri "https://pecl.php.net/get/$Extension" -OutFile "$Extension.tgz"

        $cur_Extension = $Extension
        $cur_Ref = ""
        if ($Extension -match '^(.*?)-') {
            $cur_Extension = $matches[1]
            $cur_Ref = $matches[2]
        }
        $currentDirectory = (Get-Location).Path
        if (-not (Test-Path "$currentDirectory\$cur_Extension")) {
            New-Item -Path "$currentDirectory\$cur_Extension" -ItemType Directory
        }
        & tar -xzf "$Extension.tgz" -C  "$currentDirectory\$cur_Extension"
        Move-Item -Path "$cur_Extension\$Extension\*" -Destination "$cur_Extension" -Force
        Set-Location "$cur_Extension"
        $extensionBuildDirectory = Join-Path -Path (Get-Location).Path -ChildPath $config.build_directory
        if($null -ne $env:GITHUB_REPOSITORY) {
                if(Test-Path -PATH $PSScriptRoot\..\patches\$cur_Extension.ps1) {
                    . $PSScriptRoot\..\patches\$cur_Extension.ps1
                }
                if(Test-Path -PATH $PSScriptRoot\..\patches\$cur_Extension-$cur_Ref.ps1) {
                    . $PSScriptRoot\..\patches\$cur_Extension-$cur_Ref.ps1
                }
        }
        $configW32Content = [string](Get-Content -Path "config.w32")
        $argument = Get-ArgumentFromConfig $cur_Extension $configW32Content
        $bat_content = @()
        $bat_content += ""
        $bat_content += "call phpize 2>&1"
            if($Config.php_version -eq '7.2') {
        $bat_content += "call configure --with-php-build=`"..\deps`" $argument --with-mp=`"disable`" --with-prefix=$Prefix 2>&1"
            } else {
        $bat_content += "call configure --with-php-build=`"..\deps`" $argument --with-mp=`"disable`" --enable-native-intrinsics=sse2,ssse3,sse4.1,sse4.2 --with-prefix=$Prefix 2>&1"
            }

        $bat_content += "nmake /nologo 2>&1"
        $bat_content += "exit %errorlevel%"
        Set-Content -Encoding "ASCII" -Path $cur_Extension-task.bat -Value $bat_content
        $builder = "$currentDirectory\php-sdk\phpsdk-starter.bat"
        $task = (Get-Item -Path "." -Verbose).FullName + "\$cur_Extension-task.bat"
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
        New-Item -Path $includePath\ext -Name $cur_Extension -ItemType "directory" | Out-Null
        Get-ChildItem -Path (Get-Location).Path -Recurse -Include '*.h', '*.c' | Copy-Item -Destination "$includePath\ext\$cur_Extension"
        Copy-Item -Path "$extensionBuildDirectory\*.dll" -Destination "$currentDirectory\php-bin\ext" -Force
        Copy-Item -Path "$extensionBuildDirectory\*.lib" -Destination "$currentDirectory\php-dev\lib" -Force
        Add-Content -Path "$currentDirectory\php-bin\php.ini" -Value "extension=$cur_Extension"
        if (-not (Test-Path "..\pecl\$cur_Extension")) { New-Item -ItemType Directory -Path "..\pecl\$cur_Extension" -Force | Out-Null }; Copy-Item ".\*" -Destination "..\pecl\$cur_Extension" -Recurse -Force
        Set-Location $currentDirectory
        Set-GAGroup end
    }
    end {
    }
}
