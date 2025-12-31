Function Get-File {
    <#
    .SYNOPSIS
        Downloads a file from a URL with retries and an optional fallback URL.
        Compatible with both old and new PowerShell versions.
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [ValidateNotNullOrEmpty()]
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
            # Выполняем запрос (без -UseBasicParsing — в новых версиях не нужно)
            if ($OutFile -ne '') {
                $result = Invoke-WebRequest -Uri $Url -OutFile $OutFile -TimeoutSec $TimeoutSec
            } else {
                $result = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec
            }

            # Только если мы ничего не сохраняем, возвращаем объект с контентом
            if ($OutFile -eq '') {
                # Если нет свойства .Links (новый PS), добавим его вручную
                if (-not ($result.PSObject.Properties.Name -contains 'Links')) {
                    # Пробуем распарсить href ссылки из HTML контента
                    $links = [regex]::Matches($result.Content, 'href="([^"]+)"') |
                        ForEach-Object { $_.Groups[1].Value }

                    $linkObjects = @()
                    foreach ($href in $links) {
                        $linkObjects += [PSCustomObject]@{ Href = $href }
                    }

                    # Добавляем свойство Links
                    Add-Member -InputObject $result -MemberType NoteProperty -Name Links -Value $linkObjects
                }

                return $result
            }

            break
        } catch {
            if ($i -eq ($Retries - 1)) {
                if ($FallbackUrl) {
                    try {
                        if ($OutFile -ne '') {
                            Invoke-WebRequest -Uri $FallbackUrl -OutFile $OutFile -TimeoutSec $TimeoutSec
                        } else {
                            $result = Invoke-WebRequest -Uri $FallbackUrl -TimeoutSec $TimeoutSec
                            
                            if (-not ($result.PSObject.Properties.Name -contains 'Links')) {
                                $links = [regex]::Matches($result.Content, 'href="([^"]+)"') |
                                    ForEach-Object { $_.Groups[1].Value }

                                $linkObjects = @()
                                foreach ($href in $links) {
                                    $linkObjects += [PSCustomObject]@{ Href = $href }
                                }

                                Add-Member -InputObject $result -MemberType NoteProperty -Name Links -Value $linkObjects
                            }

                            return $result
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
