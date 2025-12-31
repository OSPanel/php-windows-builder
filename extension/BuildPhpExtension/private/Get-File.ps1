Function Get-File {
    <#
    .SYNOPSIS
        Downloads a file or HTML page from a URL, with retries and HTML link extraction support for PS7+.
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string] $Url,

        [Parameter(Position=1)]
        [string] $FallbackUrl,

        [Parameter(Position=2)]
        [string] $OutFile = '',

        [Parameter(Position=3)]
        [int] $Retries = 3,

        [Parameter(Position=4)]
        [int] $TimeoutSec = 0
    )

    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            # Выполняем запрос
            $resp = if ($OutFile -ne '') {
                Invoke-WebRequest -Uri $Url -OutFile $OutFile -TimeoutSec $TimeoutSec
            } else {
                Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec
            }

            # Если это был файл — просто выходим
            if ($OutFile -ne '') {
                return $true
            }

            # Если это HTML‑страница, добавим поле Links
            if ($resp.Headers.'Content-Type' -match 'text/html' -or
                $resp.Content -match '<html') {

                # Парсим ссылки вручную
                $matches = [regex]::Matches($resp.Content, 'href="([^"]+)"')
                $hrefs = @()
                foreach ($m in $matches) {
                    $hrefs += [PSCustomObject]@{
                        Href = $m.Groups[1].Value
                    }
                }

                # Возвращаем объект, похожий на старый HtmlWebResponseObject
                return [PSCustomObject]@{
                    StatusCode = $resp.StatusCode
                    Headers    = $resp.Headers
                    Content    = $resp.Content
                    Links      = $hrefs
                }
            }

            # Если не HTML — возвращаем просто сырые данные
            return [PSCustomObject]@{
                StatusCode = $resp.StatusCode
                Headers    = $resp.Headers
                Content    = $resp.Content
                Links      = @()
            }

        } catch {
            Write-Warning "Attempt $($i + 1) failed: $($_.Exception.Message)"

            if ($i -eq ($Retries - 1)) {
                if ($FallbackUrl) {
                    try {
                        if ($OutFile -ne '') {
                            Invoke-WebRequest -Uri $FallbackUrl -OutFile $OutFile -TimeoutSec $TimeoutSec
                            return $true
                        } else {
                            $respFallback = Invoke-WebRequest -Uri $FallbackUrl -TimeoutSec $TimeoutSec
                            return [PSCustomObject]@{
                                StatusCode = $respFallback.StatusCode
                                Headers    = $respFallback.Headers
                                Content    = $respFallback.Content
                                Links      = @()
                            }
                        }
                    } catch {
                        throw "Failed to download the file from $Url and $FallbackUrl - $($_.Exception.Message)"
                    }
                } else {
                    throw "Failed to download the file from $Url - $($_.Exception.Message)"
                }
            }
        }
    }
}
