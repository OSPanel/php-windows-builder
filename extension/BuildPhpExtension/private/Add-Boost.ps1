Function Add-Boost {
    <#
    .SYNOPSIS
        Add boost library.
    #>
    [OutputType()]
    param(
    )
    begin {
    }
    process {
        $url = "https://archives.boost.io/release/1.72.0/source/boost_1_72_0.zip"
        Get-File -Url $url -OutFile "boost.zip"
        Expand-Archive -Path "boost.zip" -DestinationPath "../deps"
        if (-not (Test-Path "../deps/boost")) {
            New-Item -Path "../deps/boost" -ItemType Directory | Out-Null
        }
        if (-not (Test-Path "./boost")) {
            New-Item -Path "./boost" -ItemType Directory | Out-Null
        }
        Copy-Item -Path "../deps/boost_1_72_0/*" -Destination "../deps/boost" -Recurse
        Copy-Item -Path "../deps/boost_1_72_0/*" -Destination "./boost" -Recurse
    }
    end {
    }
}
