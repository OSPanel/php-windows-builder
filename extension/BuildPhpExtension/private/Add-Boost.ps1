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
        Rename-Item -Path "../deps/boost_1_72_0" -NewName "boost"
        if (-not (Test-Path "./boost")) {
            New-Item -Path "./boost" -ItemType Directory | Out-Null
        }
        Copy-Item -Path "../deps/boost/*" -Destination "./boost" -Recurse
    }
    end {
    }
}
