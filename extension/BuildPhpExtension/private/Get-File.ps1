Function Get-File {
    <#
    .SYNOPSIS
        Downloads a file or content. Parses links if content is HTML to support legacy scripts.
    #>
    [OutputType([PSCustomObject], [void])]
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $Url,

        [Parameter(Mandatory = $false, Position=1)]
        [string] $FallbackUrl,

        [Parameter(Mandatory = $false, Position=2)]
        [string] $OutFile = '',

        [Parameter(Mandatory = $false, Position=3)]
        [int] $Retries = 3,

        [Parameter(Mandatory = $false, Position=4)]
        [int] $TimeoutSec = 0
    )

    $currentUrl = $Url
    
    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            # Если указан OutFile, просто скачиваем файл
            if ($OutFile -ne '') {
                Invoke-WebRequest -Uri $currentUrl -OutFile $OutFile -TimeoutSec $TimeoutSec -UseBasicParsing
                return # Возвращаем void, так как файл сохранен на диск
            } 
            # Если OutFile нет, нам нужно вернуть объект с контентом и ссылками
            else {
                $response = Invoke-WebRequest -Uri $currentUrl -TimeoutSec $TimeoutSec -UseBasicParsing
                $content = $response.Content

                # Эмуляция свойства .Links для совместимости с PowerShell Core/7+
                $links = @()
                
                # ИСПРАВЛЕНИЕ: В PowerShell одинарная кавычка внутри строки экранируется как ''
                # Регулярка ищет href="..." или href='...'
                $pattern = 'href=["'']([^"'']+)["'']'
                
                $matches = [regex]::Matches($content, $pattern, 'IgnoreCase')
                
                foreach ($m in $matches) {
                    # Создаем объект с свойством Href, чтобы работало $obj.Links.Href
                    $links += [PSCustomObject]@{
                        Href = $m.Groups[1].Value
                    }
                }

                # Возвращаем кастомный объект
                return [PSCustomObject]@{
                    Content = $content
                    Links   = $links
                    Status  = $response.StatusCode
                }
            }
        } catch {
            # Логика переключения на Fallback URL при последней попытке
            if ($i -eq ($Retries - 1)) {
                if ($FallbackUrl -and $currentUrl -ne $FallbackUrl) {
                    try {
                        Write-Warning "Primary URL failed. Trying fallback: $FallbackUrl"
                        if ($OutFile -ne '') {
                            Invoke-WebRequest -Uri $FallbackUrl -OutFile $OutFile -TimeoutSec $TimeoutSec -UseBasicParsing
                            return
                        } else {
                            $response = Invoke-WebRequest -Uri $FallbackUrl -TimeoutSec $TimeoutSec -UseBasicParsing
                            $content = $response.Content
                            $links = @()
                            # То же самое исправление регулярного выражения для Fallback
                            $pattern = 'href=["'']([^"'']+)["'']'
                            $matches = [regex]::Matches($content, $pattern, 'IgnoreCase')
                            foreach ($m in $matches) {
                                $links += [PSCustomObject]@{ Href = $m.Groups[1].Value }
                            }
                            return [PSCustomObject]@{
                                Content = $content
                                Links   = $links
                            }
                        }
                    } catch {
                        throw "Failed to download from $Url and $FallbackUrl - $($_.Exception.Message)"
                    }
                } else {
                    throw "Failed to download from $Url - $($_.Exception.Message)"
                }
            }
            Start-Sleep -Milliseconds 500
        }
    }
}
