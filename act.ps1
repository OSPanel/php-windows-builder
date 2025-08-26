param(
    [string]$ExtensionName = "",
    [string]$PhpVersions = ""
)

if ($ExtensionName -eq 'iniparse' -and $PhpVersions -eq 'all') {
    Set-Location data
    $logFile = Join-Path (Get-Location) "scan.log"
    if (Test-Path $logFile) { Remove-Item $logFile }

    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $icon = switch ($Level) {
            "INFO"  { "ℹ️" }
            "WARN"  { "⚠️" }
            "ERROR" { "❌" }
            Default { "📝" }
        }
        $line = "[$time] [$Level] $Message"
        Write-Host "$icon $line"
        Add-Content -Path $logFile -Value $line
    }

    function Write-LogRaw {
        param([string]$Message)
        Add-Content -Path $logFile -Value $Message
    }

    Write-Log "🚀 Запуск анализа PHP-расширений" "INFO"

    $phpFolders = Get-ChildItem -Directory | Where-Object { $_.Name -like "PHP-*" }

    foreach ($phpFolder in $phpFolders) {
        $phpExe  = Join-Path $phpFolder.FullName "php.exe"
        $extDir  = Join-Path $phpFolder.FullName "ext"
        $iniFile = Join-Path $phpFolder.FullName "php.ini"

        if (!(Test-Path $phpExe)) { Write-Log "❌ Нет php.exe в $phpFolder" "WARN"; continue }
        if (!(Test-Path $extDir)) { Write-Log "❌ Нет ext в $phpFolder" "WARN"; continue }

        Write-Log "🔍 Обработка $($phpFolder.Name) → $phpExe" "INFO"

        # Удаляем старый php.ini
        if (Test-Path $iniFile) { Remove-Item $iniFile }

        # Буфер для будущего php.ini
        $iniBuffer = @()
        $iniBuffer += "; Автоматически сгенерированный php.ini"
        $iniBuffer += "; Все параметры закомментированы, extension=... всегда без php_ и .dll"
        $iniBuffer += ""

        $extensions = Get-ChildItem $extDir -File -Filter "*.dll" | ForEach-Object { $_.BaseName }

        foreach ($ext in $extensions) {
            $extBase = $ext
            if ($extBase -like "php_*") { $extBase = $extBase.Substring(4) }

            Write-Log "🔧 Проверка расширения $ext (phpinfo name: $extBase)" "INFO"

            # Добавляем секцию в буфер
            $iniBuffer += "[$extBase]"
            $iniBuffer += ""

            # Запуск phpinfo с обязательными базовыми расширениями
            $baseExt = @("mbstring", "apcu", "igbinary", "msgpack", "openssl", "sockets", "psr")
            $extArgs = @()
            foreach ($b in $baseExt + $extBase) {
                if ($b -in @("opcache", "xdebug")) {
                    $extArgs += "-d zend_extension=$b"
                } else {
                    $extArgs += "-d extension=$b"
                }
            }

            $phpCmd = "$phpExe -d extension_dir=$extDir $($extArgs -join ' ') -r `"phpinfo(INFO_MODULES);`""
            $output = & cmd /c $phpCmd 2>&1

            # Логируем полный вывод phpinfo
            Write-LogRaw "----- phpinfo($extBase) START -----"
            Write-LogRaw $output
            Write-LogRaw "----- phpinfo($extBase) END -----"
            Write-LogRaw ""

            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
                Write-Log "❌ Не удалось получить phpinfo для $ext" "ERROR"
                continue
            }

            $lines  = $output -split "`r?`n"
            $params = @{}

            $foundModule = $false
            for ($i = 0; $i -lt $lines.Count; $i++) {
                # 🔹 Исключение для opcache (ищем "Zend OPcache")
                if ($extBase -eq "opcache") {
                    if ($lines[$i] -match "^\s*Zend OPcache(\s|=>|$)") {
                        $foundModule = $true
                    }
                } elseif ($lines[$i] -match "^\s*$extBase(\s|=>|$)") {
                    $foundModule = $true
                }

                if ($foundModule -and $lines[$i] -match "Directive\s+=>\s+Local Value\s+=>\s+Master Value") {
                    $localParams = @{}
                    for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                        $line = $lines[$j]
                        if ([string]::IsNullOrWhiteSpace($line)) { break }

                        if ($line -match "^\s*([A-Za-z0-9_.]+)\s*=>\s*(.*?)\s*=>\s*(.*)$") {
                            $param  = $matches[1].Trim()
                            $master = $matches[3].Trim()
                            $keep   = $false

                            switch ($extBase) {
                                "ddtrace" {
                                    if ($param -like "datadog.*") { $keep = $true }
                                    if ($param -like "ddtrace.*") { $keep = $true }
                                }
                                "interbase" {
                                    if ($param -like "ibase.*") { $keep = $true }
                                }
                                "apcu" {
                                    if ($param -like "apc.*") { $keep = $true }
                                }
                                "phpdbg_webhelper" {
                                    if ($param -like "phpdbg.*") { $keep = $true }
                                }
                                "phalcon" {
                                    if ($param -like "phalcon.*") { $keep = $true }
                                }
                                Default {
                                    if ($param -like "$extBase.*") { $keep = $true }
                                }
                            }

                            if ($keep) {
                                $localParams[$param] = $master
                            }
                        } else {
                            break
                        }
                    }

                    # если нашли параметры для модуля -- сохраняем и выходим
                    if ($localParams.Count -gt 0) {
                        $params = $localParams
                        break
                    }
                    # иначе продолжаем искать следующий "Directive"
                }
            }

            if ($params.Count -eq 0) {
                Write-Log "⚠️ Нет параметров у $extBase" "WARN"
                continue
            }

            # Записываем параметры в буфер
            $iniBuffer += ""
            foreach ($kvp in $params.GetEnumerator() | Sort-Object Key) {
                $iniBuffer += ("; {0,-40} = {1}" -f $kvp.Key, $kvp.Value)
            }
            $iniBuffer += ""
        }

        # Сохраняем php.ini только после обработки всех расширений
        Set-Content -Path $iniFile -Value $iniBuffer -Encoding UTF8
        Write-Log "✅ php.ini сохранён для $($phpFolder.Name)" "INFO"
    }

    Set-Location ..
    Write-Log "🎉 Анализ завершен" "INFO"
    exit 0
}

if ($ExtensionName -eq 'ini' -and $PhpVersions -eq 'all') {
    # --- НАСТРОЙКИ ДЛЯ ВСТАВКИ ---
    $MatrixFile      = ".\resources\matrix-ini.json"
    $CommentsFile    = ".\resources\matrix-comments.json"
    $OutputRoot      = ".\data"
    $PhpFolderPrefix = "php-"
    # -----------------------------

    if (!(Test-Path $MatrixFile))  { throw "❌ Не найден файл матрицы: $MatrixFile" }
    if (!(Test-Path $CommentsFile)){ throw "❌ Не найден файл комментариев: $CommentsFile" }

    $matrixJson   = Get-Content -Raw -Path $MatrixFile   | ConvertFrom-Json
    $commentsJson = Get-Content -Raw -Path $CommentsFile | ConvertFrom-Json

    $data = $matrixJson.php_extensions_matrix.data

    # Выделяем версии PHP по ключам php_versions
    $allPhpVersions = @()
    foreach ($row in $data) {
        foreach ($prop in $row.php_versions.PSObject.Properties) {
            if ($prop.Name -match '^\d+\.\d+$') { $allPhpVersions += $prop.Name }
        }
    }
    $desiredVersions = $allPhpVersions | Sort-Object -Unique

    # Карта комментариев (как есть)
    $commentMap = @{}
    foreach ($p in $commentsJson.PSObject.Properties) { $commentMap[$p.Name] = $p.Value }

    # Группировка по расширению
    $byExtension = $data | Group-Object -Property extension

    foreach ($ver in $desiredVersions) {
        $outDir = Join-Path $OutputRoot ("{0}{1}" -f $PhpFolderPrefix, $ver)
        if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
        $outFile = Join-Path $outDir "php.ini"

        $lines = New-Object System.Collections.Generic.List[string]

        foreach ($extGroup in $byExtension | Sort-Object Name) {
            $extName = $extGroup.Name

            # Собираем итоговые записи секции с учётом правил
            $rows = @()
            foreach ($row in $extGroup.Group) {
                $param    = [string]$row.parameter
                $useFlag  = [bool]$row.use

                $verValueProp = $row.php_versions.PSObject.Properties |
                                Where-Object { $_.Name -eq $ver } |
                                Select-Object -First 1
                if ($null -eq $verValueProp) { continue }

                $valueText = if ($verValueProp.Value -ne $null) { [string]$verValueProp.Value } else { "" }

                # Правила "(none)" и "(empty)"
                if ($valueText -eq "(none)") { continue }
                if ($valueText -eq "(empty)") { $valueText = "" }

                $commentText = if ($commentMap.ContainsKey($param)) { [string]$commentMap[$param] } else { "" }

                $rows += [pscustomobject]@{
                    Parameter   = $param
                    Value       = $valueText
                    Comment     = $commentText
                    IsCommented = (-not $useFlag)
                }
            }

            # Если секция пуста -- пропускаем
            if ($rows.Count -eq 0) { continue }

            # Определяем позицию для выравнивания знака =
            if ($extName -eq "ddtrace") {
                # Для секции ddtrace - выравниваем по самому длинному параметру
                $maxActualParamLength = 0
                foreach ($r in $rows) {
                    $prefix = if ($r.IsCommented) { "; " } else { "" }
                    $fullParamLength = $prefix.Length + $r.Parameter.Length
                    if ($fullParamLength -gt $maxActualParamLength) {
                        $maxActualParamLength = $fullParamLength
                    }
                }
                $equalPosition = $maxActualParamLength
            } else {
                # Для всех остальных секций - выравниваем по 40-й позиции
                $equalPosition = 38
            }

            # Базовая позиция для комментариев всегда 60
            $baseCommentPosition = 62

            # Заголовок секции + пустая строка после него
            $lines.Add("[${extName}]")
            $lines.Add("")

            foreach ($r in $rows) {
                $prefix = if ($r.IsCommented) { "; " } else { "" }
                $paramWithPrefix = "{0}{1}" -f $prefix, $r.Parameter
                $paddedParam = $paramWithPrefix.PadRight($equalPosition)
                $val = ($r.Value ?? "")

                $baseLine = "{0} = {1}" -f $paddedParam, $val

                if ([string]::IsNullOrEmpty($r.Comment)) {
                    # Нет комментария
                    $lines.Add($baseLine.TrimEnd())
                } else {
                    # Есть комментарий
                    if ($baseLine.Length -le $baseCommentPosition) {
                        # Короткая строка - выравниваем комментарий по 60-й позиции
                        $paddedBaseLine = $baseLine.PadRight($baseCommentPosition)
                        $line = "{0}  ; {1}" -f $paddedBaseLine, $r.Comment
                        $lines.Add($line.TrimEnd())
                    } else {
                        # Длинная строка - комментарий сразу после значения через 2 пробела
                        $line = "{0}  ; {1}" -f $baseLine, $r.Comment
                        $lines.Add($line.TrimEnd())
                    }
                }
            }

            $lines.Add("")  # пустая строка между секциями
        }

        Set-Content -Path $outFile -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
        Write-Host "📝 Сгенерирован: $outFile"
    }

    # --- НАСТРОЙКИ ДЛЯ ВСТАВКИ ---
    $MatrixFile      = ".\resources\matrix-init-ini.json"
    $CommentsFile    = ".\resources\matrix-init-comments.json"
    $OutputRoot      = ".\data"
    $PhpFolderPrefix = "php-"
    # -----------------------------

    if (!(Test-Path $MatrixFile))  { throw "❌ Не найден файл матрицы: $MatrixFile" }
    if (!(Test-Path $CommentsFile)){ throw "❌ Не найден файл комментариев: $CommentsFile" }

    $matrixJson   = Get-Content -Raw -Path $MatrixFile   | ConvertFrom-Json
    $commentsJson = Get-Content -Raw -Path $CommentsFile | ConvertFrom-Json

    $data = $matrixJson.php_extensions_matrix.data

    # Выделяем версии PHP по ключам php_versions
    $allPhpVersions = @()
    foreach ($row in $data) {
        foreach ($prop in $row.php_versions.PSObject.Properties) {
            if ($prop.Name -match '^\d+\.\d+$') { $allPhpVersions += $prop.Name }
        }
    }
    $desiredVersions = $allPhpVersions | Sort-Object -Unique

    # Карта комментариев из parameters
    $commentMap = @{}
    foreach ($p in $commentsJson.parameters.PSObject.Properties) { $commentMap[$p.Name] = $p.Value }

    # Группировка по расширению
    $byExtension = $data | Group-Object -Property extension

    foreach ($ver in $desiredVersions) {
        $outDir = Join-Path $OutputRoot ("{0}{1}" -f $PhpFolderPrefix, $ver)
        if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
        $outFile = Join-Path $outDir "pre-ini.ini"

        $lines = New-Object System.Collections.Generic.List[string]

        foreach ($extGroup in $byExtension | Sort-Object Name) {
            $extName = $extGroup.Name

            # Собираем итоговые записи секции с учётом правил
            $rows = @()
            foreach ($row in $extGroup.Group) {
                $param    = [string]$row.parameter
                $useFlag  = [bool]$row.use

                $verValueProp = $row.php_versions.PSObject.Properties |
                                Where-Object { $_.Name -eq $ver } |
                                Select-Object -First 1
                if ($null -eq $verValueProp) { continue }

                $valueText = if ($verValueProp.Value -ne $null) { [string]$verValueProp.Value } else { "" }

                # Правила "(none)" и "(empty)"
                if ($valueText -eq "(none)") { continue }
                if ($valueText -eq "(empty)") { $valueText = "" }

                $commentText = if ($commentMap.ContainsKey($param)) { [string]$commentMap[$param] } else { "" }

                $rows += [pscustomobject]@{
                    Parameter   = $param
                    Value       = $valueText
                    Comment     = $commentText
                    IsCommented = (-not $useFlag)
                }
            }

            # Если секция пуста -- пропускаем
            if ($rows.Count -eq 0) { continue }

            # Определяем позицию для выравнивания знака =
            # Во всех секциях выравниваем по 40-й позиции
            $equalPosition = 38

            # Базовая позиция для комментариев всегда 60
            $baseCommentPosition = 62

            # Создаем декоративный заголовок секции
            $sectionTitle = "$extName"
            $separatorLength = [Math]::Max(40, $sectionTitle.Length + 4)
            $separator = ";---------------------------------------"

            $lines.Add($separator)
            $lines.Add("; $sectionTitle")
            $lines.Add($separator)
            $lines.Add("")

            foreach ($r in $rows) {
                $prefix = if ($r.IsCommented) { "; " } else { "" }
                $paramWithPrefix = "{0}{1}" -f $prefix, $r.Parameter
                $paddedParam = $paramWithPrefix.PadRight($equalPosition)
                $val = ($r.Value ?? "")

                $baseLine = "{0} = {1}" -f $paddedParam, $val

                if ([string]::IsNullOrEmpty($r.Comment)) {
                    # Нет комментария
                    $lines.Add($baseLine.TrimEnd())
                } else {
                    # Есть комментарий
                    if ($baseLine.Length -le $baseCommentPosition) {
                        # Короткая строка - выравниваем комментарий по 60-й позиции
                        $paddedBaseLine = $baseLine.PadRight($baseCommentPosition)
                        $line = "{0}  ; {1}" -f $paddedBaseLine, $r.Comment
                        $lines.Add($line.TrimEnd())
                    } else {
                        # Длинная строка - комментарий сразу после значения через 2 пробела
                        $line = "{0}  ; {1}" -f $baseLine, $r.Comment
                        $lines.Add($line.TrimEnd())
                    }
                }
            }

            $lines.Add("")  # пустая строка между секциями
        }

        Set-Content -Path $outFile -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
        Write-Host "📝 Сгенерирован: $outFile"
    }

    # корень с подпапкой data
    $base = Join-Path $PSScriptRoot 'data'

    # перебор только подпапок php-*
    Get-ChildItem $base -Directory -Filter 'php-*' | ForEach-Object {
        $dir = $_.FullName

        $pre  = Join-Path $dir 'pre-ini.ini'
        $ext  = Join-Path $dir 'ext.ini'
        $php  = Join-Path $dir 'php.ini'
        $out  = Join-Path $dir 'php.ini.merged'

        if ((Test-Path $pre) -and (Test-Path $ext) -and (Test-Path $php)) {
            Write-Host "🔧 Собираю $out"

            "[PHP]", "", (Get-Content $pre), (Get-Content $ext), "", ";---------------------------------------", "; Extensions settings", ";---------------------------------------", "",(Get-Content $php) |
                Set-Content $out -Encoding UTF8
        }
        else {
            Write-Host "⚠️ В папке $dir не хватает одного из файлов (pre-ini.ini, ext.ini, php.ini)" -ForegroundColor Yellow
        }
    }

    Write-Host "✅ Готово. НЕ ЗАБУДЬ про плагин sasl mongo." -ForegroundColor Green
    exit 0
}

if ($ExtensionName -eq 'compile' -and $PhpVersions -eq 'all') {
    # путь к файлам
    $matrixPath = "extension/BuildPhpExtension/config/matrix.json"
    $sendPath = "send.json"

    # Максимальное число расширений за раз
    $maxCount = 200

    # Читаем текущий список обработанных расширений
    if (Test-Path $sendPath) {
        $processed = Get-Content $sendPath | ConvertFrom-Json
    } else {
        $processed = @()
    }

    # Читаем файл матрицы
    if (-Not (Test-Path $matrixPath)) {
        Write-Host "❌ Файл матрицы не найден: $matrixPath" -ForegroundColor Red
        exit
    }
    $matrixContent = Get-Content $matrixPath | ConvertFrom-Json

    # Получаем список расширений (ключи верхнего уровня)
    $extensions = $matrixContent.PSObject.Properties | Select-Object -ExpandProperty Name

    # Фильтруем только те, что еще не обработаны
    $toProcess = $extensions | Where-Object { -not ($processed -contains $_) } | Select-Object -First $maxCount

    foreach ($extension in $toProcess) {
        $versions = "7.2,7.3,7.4,8.0,8.1,8.2,8.3,8.4"
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "act.ps1"
        Write-Host "🔄 Обрабатываю расширение: $extension"
        Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" `"$extension`" `"$versions`"" `
            -WorkingDirectory $PSScriptRoot `
            -NoNewWindow -Wait
        # Обработка после вызова
        $processed += $extension
    }

    # Записываем обновленный список обработанных
    $processed | ConvertTo-Json -Depth 1 | Set-Content $sendPath
    Write-Host "✅ Обработка завершена" -ForegroundColor Green
    exit 0
}

if ($ExtensionName -eq 'extract' -and $PhpVersions -eq 'all') {
    # Путь к папке с архивами
    $dataDir = Join-Path -Path (Get-Location) -ChildPath "data"
    Set-Location $dataDir
    # Путь к подпапке php внутри dataDir
    $phpDir = Join-Path -Path $dataDir -ChildPath "php"

    # Получаем все zip-файлы в подпапке php
    $zipFiles = Get-ChildItem -Path $phpDir -Filter "php-*.zip"

    foreach ($zip in $zipFiles) {
        $fileName = $zip.Name

        # Ищем версию PHP, например 7.4 из php-7.4.33-...
        if ($fileName -match 'php-(\d+\.\d+)\.\d+-') {
            $version = $matches[1]
            $folderName = "PHP-$version".ToUpper()  # Приводим к верхнему регистру

            # Текущая папка (куда распаковать)
            $targetFolder = Join-Path -Path (Get-Location) -ChildPath $folderName

            # Создаём папку, если не существует
            if (-not (Test-Path -Path $targetFolder)) {
                New-Item -Path $targetFolder -ItemType Directory | Out-Null
            }

            # Распаковываем архив в текущую папку
            Expand-Archive -Path $zip.FullName -DestinationPath $targetFolder -Force

            Write-Host "✅ $fileName → $folderName"
        } else {
            Write-Host "⚠️ Пропущен: $fileName (не удалось определить версию)"
        }
    }

    # Копируем содержимое подпапки php_bundle из php в текущую папку
    $bundleSource = Join-Path -Path $dataDir -ChildPath "php_bundle"
    if (Test-Path -Path $bundleSource) {
        Copy-Item -Path "$bundleSource\*" -Destination (Get-Location) -Recurse -Force
        Write-Host "📁 Копирование содержимого 'php_bundle' завершено."
    } else {
        Write-Host "⚠️ Папка 'php_bundle' не найдена."
    }

    # Получаем все папки, начинающиеся на 'php-' в текущей директории
    $phpFolders = Get-ChildItem -Path . -Directory -Filter "php-*"

    foreach ($folder in $phpFolders) {
        # Полный путь к папке devel внутри текущей папки
        $develPath = Join-Path $folder.FullName "dev"
        # Проверяем, существует ли папка, и удаляем её со всем содержимым
        if (Test-Path $develPath) {
            Remove-Item -Path $develPath -Recurse -Force
            Write-Host "🗑️ Удалена папка: $develPath"
        } else {
            Write-Host "⚠️ Папка не найдена: $develPath"
        }

        # Папка bin внутри текущей папки
        $binPath = Join-Path $folder.FullName "bin"
        # Проверяем, существует ли папка bin
        if (Test-Path $binPath) {
            # Удаляем все файлы с расширением .pdb внутри папки bin
            Get-ChildItem -Path $binPath -Filter "*.pdb" -File | Remove-Item -Force
            Write-Host "🧹 Удалены .pdb файлы из: $binPath"
        } else {
            Write-Host "⚠️ Папка bin не найдена в: $($folder.FullName)"
        }

        # Удаляем подпапку sasl2 внутри bin, если она существует
        $sasl2Path = Join-Path $binPath "sasl2"
        if (Test-Path $sasl2Path) {
            Remove-Item -Path $sasl2Path -Recurse -Force
            Write-Host "🗑️ Удалена папка: $sasl2Path"
        } else {
            Write-Host "⚠️ Папка sasl2 не найдена в: $binPath"
        }
    }

    Set-Location ..

    # Папка, где находится скрипт
    $dataRoot = Join-Path $PSScriptRoot "data"
    $extensionsPath = Join-Path $dataRoot "extensions"
    $phpBasePath = $dataRoot  # PHP-* папки тоже внутри папки data

    # Получаем все ZIP-архивы в подпапке extensions
    Get-ChildItem -Path $extensionsPath -Filter *.zip | ForEach-Object {
        $zipFile = $_.FullName
        $fileName = $_.BaseName

        # Пример имени: php_imagick-3.7.0-8.0-nts-vs16-x64
        if ($fileName -match "^php_(?<name>\w+)-v?(?<extver>[\d\.]+)-(?<phpver>[\d\.]+)") {
            $extName = $matches['name']
            $phpVersion = $matches['phpver']
            $phpFolder = Join-Path $phpBasePath "PHP-$phpVersion"

            if (-not (Test-Path $phpFolder)) {
                Write-Host "⚠️ Папка PHP-$phpVersion не найдена для $fileName, пропущено." -ForegroundColor Yellow
                return
            }

            $extFolder = Join-Path $phpFolder "ext"
            $thirdPartyPath = Join-Path $phpFolder "3rd-party\$extName"
            $binTargetPath = Join-Path $phpFolder "bin\$extName"
            $isImagick = $extName -like "*imagick*"

            # Создание временной папки для распаковки
            $tempPath = Join-Path $env:TEMP ("ext_unpack_" + [guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempPath | Out-Null

            try {
                Expand-Archive -Path $zipFile -DestinationPath $tempPath -Force

                # Обрабатываем файлы в корне архива
                $rootFiles = Get-ChildItem -Path $tempPath -File
                foreach ($file in $rootFiles) {
                    if ($file.Extension -ieq ".pdb") {
                        continue
                    }

                    $extBaseName = "php_$extName.dll"

                    # imagick: игнорировать все .dll кроме php_imagick.dll
                    if ($isImagick -and $file.Extension -ieq ".dll" -and $file.Name -ne $extBaseName) {
                        continue
                    }

                    if ($file.Name -ieq $extBaseName) {
                        # Основной DLL -> ext
                        $destPath = Join-Path $extFolder $file.Name
                        Copy-Item -Path $file.FullName -Destination $destPath -Force
                    }
                    elseif ($file.Extension -ieq ".dll") {
                        # Прочие DLL в корне архива -> корень PHP (если не imagick)
                        $destPath = Join-Path $phpFolder $file.Name
                        if (Test-Path $destPath) {
                            Write-Host "⚠️ Файл уже существует в PHP-${phpVersion}: $($file.Name) -- не перезаписан." -ForegroundColor Yellow
                        } else {
                            Copy-Item -Path $file.FullName -Destination $destPath -Force
                        }
                    }
                    else {
                        # Остальные файлы в корне архива -> 3rd-party
                        if (-not (Test-Path $thirdPartyPath)) {
                            New-Item -ItemType Directory -Path $thirdPartyPath -Force | Out-Null
                        }
                        $destPath = Join-Path $thirdPartyPath $file.Name
                        Copy-Item -Path $file.FullName -Destination $destPath -Force
                    }
                }

                # Обрабатываем всё, что в подкаталогах архива
                $subItems = Get-ChildItem -Path $tempPath -Recurse | Where-Object { -not $_.PSIsContainer }

                foreach ($file in $subItems) {
                    if ($file.FullName -like "$tempPath\*") {
                        $relativePath = $file.FullName.Substring($tempPath.Length + 1)

                        # Пропуск файлов, уже обработанных в корне
                        if ($file.DirectoryName -eq $tempPath) {
                            continue
                        }

                        if ($file.Extension -ieq ".pdb") {
                            continue
                        }

                        # Обработка только artifacts-bin\bin
                        if ($relativePath -like "artifacts-bin\bin\*") {
                            $targetPath = Join-Path $binTargetPath ($relativePath -replace "^artifacts-bin[\\\/]bin[\\\/]", "")
                            $targetDir = Split-Path $targetPath -Parent

                            if (-not (Test-Path $targetDir)) {
                                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                            }

                            Copy-Item -Path $file.FullName -Destination $targetPath -Force
                        }
                        else {
                            # Всё остальное -> 3rd-party\<extName>
                            $targetPath = Join-Path $thirdPartyPath $relativePath
                            $targetDir = Split-Path $targetPath -Parent

                            if (-not (Test-Path $targetDir)) {
                                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                            }

                            Copy-Item -Path $file.FullName -Destination $targetPath -Force
                        }
                    }
                }

                Write-Host "✅ Обработан архив: $fileName"
            }
            finally {
                Remove-Item -Path $tempPath -Recurse -Force
            }
        }
        else {
            Write-Host "⚠️ Имя файла не соответствует шаблону: $fileName" -ForegroundColor Yellow
        }
    }

    # ▶️ Постобработка для каждой папки PHP-*
    Get-ChildItem -Path $phpBasePath -Directory -Filter "PHP-*" | ForEach-Object {
        $phpFolder = $_.FullName

        Write-Host "🔧 Постобработка: $($_.Name)"

        # 2. Копируем прочие util-файлы из bin\
        $tools = @("openssl.exe", "tidy.exe")
        foreach ($tool in $tools) {
            $src = Join-Path $phpFolder "bin\$tool"
            $dst = Join-Path $phpFolder $tool
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $dst -Force
                Write-Host "📥 Скопирован: $tool"
            }
        }

        # 3. Удаляем папку bin полностью
        $binFolder = Join-Path $phpFolder "bin"
        if (Test-Path $binFolder) {
            Remove-Item -Path $binFolder -Recurse -Force
            Write-Host "🗑️ Удалена папка bin"
        }

        if (Test-Path "$phpFolder\php7embed.lib") {
            Remove-Item -Path "$phpFolder\php7embed.lib" -Force
        }

        # 4. Удаляем папку 3rd-party\imagick\config полностью
        $imagickConfig = Join-Path $phpFolder "3rd-party\imagick\config"
        if (Test-Path $imagickConfig) {
            Remove-Item -Path $imagickConfig -Recurse -Force
            Write-Host "🗑️ Удалена папка imagick\config"
        }

        # 5. Генерация ext.ini
        $extFolder = Join-Path $phpFolder "ext"
        $extIniPath = Join-Path $phpFolder "ext.ini"

        if (Test-Path $extFolder) {
            $dllFiles = Get-ChildItem -Path $extFolder -Filter "*.dll" | Select-Object -ExpandProperty Name

            # Список названий расширений без "php_" и ".dll"
            $extNames = $dllFiles | ForEach-Object {
                ($_ -replace '^php_', '') -replace '\.dll$', ''
            }

            # Убираем дубликаты и сортируем
            $extNames = $extNames | Sort-Object -Unique

            Write-Host "🔍 Найдено расширений: $($extNames.Count)"
            if ($extNames.Count -eq 0) {
                Write-Host "⚠️ В папке $extFolder не найдено DLL файлов расширений"
                return
            }

            # --- Загрузка комментариев ---
            $commentsPath = Join-Path $PSScriptRoot "resources\ext-comments.json"
            $comments = @{}

            if (Test-Path $commentsPath) {
                try {
                    $commentsJson = Get-Content -Path $commentsPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($commentsJson.PSObject.Properties['extensions']) {
                        $commentsJson.extensions.PSObject.Properties | ForEach-Object {
                            $comments[$_.Name] = $_.Value
                        }
                    }
                    Write-Host "✅ Загружены комментарии из ext-comments.json ($($comments.Count) расширений)"
                }
                catch {
                    Write-Host "⚠️ Ошибка загрузки ext-comments.json: $($_.Exception.Message)"
                }
            }
            else {
                Write-Host "⚠️ Файл ext-comments.json не найден"
            }

            # Функция для форматирования строки
            function Format-ExtensionLine {
                param(
                    [string]$type,        # "extension" или "zend_extension"
                    [string]$extension,
                    [hashtable]$comments,
                    [bool]$commented = $false
                )

                $prefix = if ($commented) { "; " } else { "" }
                $line = "$prefix$type"

                # Выравниваем до 40 символов
                while ($line.Length -lt 39) {
                    $line += " "
                }

                $line += "= $extension"

                # Добавляем комментарий если есть
                if ($comments.ContainsKey($extension)) {
                    # Выравниваем до 60 символов для комментария
                    while ($line.Length -lt 64) {
                        $line += " "
                    }
                    $line += "; $($comments[$extension])"
                }

                return $line
            }

            # --- Конфигурация ---

            # Обязательные расширения
            $mandatoryList = @("mbstring", "openssl", "apcu", "igbinary", "msgpack", "sockets", "psr", "curl")

            # Часто используемые (включенные)
            $commonList = @(
                "brotli", "bz2", "crypto", "enchant", "exif", "fileinfo", "ftp", "gd", "gd2",
                "gettext", "gmp", "hrtime","imap", "intl", "lz4", "lzf", "mailparse", "mcrypt", "memcache",
                "memcached", "mysqli", "odbc", "pdo_mysql", "pdo_sqlite", "redis", "scrypt",
                "soap", "sodium", "sqlite3", "timezonedb", "xmlrpc", "xsl", "yaml", "zip", "zstd"
            )

            # Zend расширения
            $zendList = @("opcache", "xdebug", "scoutapm")

            # --- Формируем файл ---
            $iniLines = @()

            # Шапка
            $iniLines += ";---------------------------------------"
            $iniLines += "; Extensions"
            $iniLines += "; Do not change the order of extensions in the config!"
            $iniLines += ";---------------------------------------"
            $iniLines += ""

            # ionCube (если есть)
            if ($extNames -contains "ioncube") {
                $iniLines += Format-ExtensionLine -type "zend_extension" -extension "ioncube" -comments $comments -commented $true
                $iniLines += ""
            }

            # Обязательные расширения
            $foundMandatory = $mandatoryList | Where-Object { $extNames -contains $_ }

            if ($foundMandatory.Count -gt 0) {
                $iniLines += "; Mandatory extensions"
                $iniLines += "; Never disable these extensions!"
                $iniLines += ""

                foreach ($ext in $foundMandatory) {
                    $iniLines += Format-ExtensionLine -type "extension" -extension $ext -comments $comments
                }

                $iniLines += ""
            }

            # Часто используемые расширения
            $foundCommon = $commonList | Where-Object { $extNames -contains $_ } | Sort-Object

            if ($foundCommon.Count -gt 0) {
                $iniLines += "; Commonly used extensions"
                $iniLines += ""

                foreach ($ext in $foundCommon) {
                    $iniLines += Format-ExtensionLine -type "extension" -extension $ext -comments $comments
                }

                $iniLines += ""
            }

            # Опциональные расширения
            $usedExtensions = $mandatoryList + $commonList + $zendList + @("ioncube")
            $foundOptional = $extNames | Where-Object { $_ -notin $usedExtensions } | Sort-Object

            if ($foundOptional.Count -gt 0) {
                $iniLines += "; Optional / commented extensions"
                $iniLines += ""

                foreach ($ext in $foundOptional) {
                    $iniLines += Format-ExtensionLine -type "extension" -extension $ext -comments $comments -commented $true
                }

                $iniLines += ""
            }

            # Zend расширения
            $foundZend = $zendList | Where-Object { $extNames -contains $_ } | Sort-Object

            if ($foundZend.Count -gt 0) {
                $iniLines += "; Zend extensions"
                $iniLines += ""

                foreach ($ext in $foundZend) {
                    $iniLines += Format-ExtensionLine -type "zend_extension" -extension $ext -comments $comments -commented $true
                }
            }

            # Записываем файл
            Set-Content -Path $extIniPath -Value $iniLines -Encoding UTF8

            $enabledCount = $foundMandatory.Count + $foundCommon.Count
            $disabledCount = $foundOptional.Count + $foundZend.Count

            Write-Host "📝 Сгенерирован ext.ini (включено: $enabledCount, отключено: $disabledCount)"
            Write-Host "📂 Путь: $extIniPath"
        }
        else {
            Write-Host "❌ Папка с расширениями не найдена: $extFolder"
        }
    }
    exit 0
}

if ($ExtensionName -eq 'get' -and $PhpVersions -eq 'all') {
    # ========================== CONFIGURATION ==========================
    $Repo = "OSPanel/php-windows-builder"
    $WorkflowFileName = ""
    $OutputDirectory = "data"
    $Threads = 16
    # ===================================================================

    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
    }

    Write-Host "🔍 Получение списка завершенных запусков для репозитория '$Repo'..."
    $ghCommand = "gh run list --repo `"$Repo`" --status completed --limit 1000 --json databaseId"

    if (-not [string]::IsNullOrEmpty($WorkflowFileName)) {
        $ghCommand += " --workflow `"$WorkflowFileName`""
    }

    $completedRuns = Invoke-Expression $ghCommand | ConvertFrom-Json

    if ($null -eq $completedRuns -or $completedRuns.Count -eq 0) {
        Write-Host "⚠️ Завершенные запуски не найдены."
        exit 0
    }

    Write-Host "📦 Найдено $($completedRuns.Count) запусков. Начинаю параллельную загрузку..."
    Write-Host "========================================================================"

    $completedRuns | ForEach-Object -Parallel {
        $runId = $_.databaseId
        if (-not $runId) {
            Write-Host "❌ Пропущено: пустой ID" -ForegroundColor Red
            return
        }

        Write-Host "🔄 [ID: $runId] --- Начинаю обработку ---"

        $runArtifactsDir = Join-Path -Path $using:OutputDirectory -ChildPath $runId
        if (-not (Test-Path -Path $runArtifactsDir)) {
            New-Item -Path $runArtifactsDir -ItemType Directory | Out-Null
        }

        Write-Host "📥 [ID: $runId] Попытка загрузки артефактов в '$runArtifactsDir'..."
        gh run download $runId --repo $using:Repo --dir $runArtifactsDir

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ [ID: $runId] Успешно." -ForegroundColor Green
        } else {
            Write-Host "⚠️ [ID: $runId] Не удалось загрузить (артефакты могут отсутствовать)." -ForegroundColor Yellow
        }

        Write-Host "------------------------------------------------"
    } -ThrottleLimit $Threads

    Write-Host "========================================================================"
    Write-Host "🎉 Отладка завершена."
    exit 0
}

if ($ExtensionName -eq 'update' -and $PhpVersions -eq 'all') {
    $j = Get-Content "extension/BuildPhpExtension/config/matrix.json" | ConvertFrom-Json

    function Normalize-Version($v) {
        if (-not $v -or $v -notmatch '^\d') { return $null }
        $v = $v -replace '[^0-9\.]', ''
        try { return [version]$v } catch { return $null }
    }

    foreach ($ext in $j.PSObject.Properties.Name) {
        $matrixVersions = $j.$ext.ver.PSObject.Properties.Value `
            | ForEach-Object { Normalize-Version $_ } `
            | Where-Object { $_ }  # убираем null

        if (-not $matrixVersions) { continue }

        $matrixMax = ($matrixVersions | Sort-Object -Descending)[0]

        try {
            $peclRaw = Invoke-RestMethod https://pecl.php.net/rest/r/$ext/latest.txt
            if ($peclRaw -match 'RC|beta|alpha') { continue }
            $peclVer = Normalize-Version $peclRaw

            if ($peclVer -and $peclVer -gt $matrixMax) {
                Write-Host "🔄 $ext => матрица $matrixMax < pecl $peclVer"
            }
        } catch {
            # PECL entry doesn't exist -- skip
        }
    }
    exit 0
}

if ($ExtensionName -eq 'delete' -and $PhpVersions -eq 'all') {
    Write-Host "⚠️ Удаление всех артефактов и запусков workflow для OSPanel/php-windows-builder..." -ForegroundColor Yellow

    (gh api repos/OSPanel/php-windows-builder/actions/artifacts | ConvertFrom-Json).artifacts.id |
    ForEach-Object {
        Write-Host "🗑️ Удаляю артефакт ID: $_"
        gh api --method DELETE "repos/OSPanel/php-windows-builder/actions/artifacts/$_"
    }

    (gh api repos/OSPanel/php-windows-builder/actions/runs | ConvertFrom-Json).workflow_runs.id |
    ForEach-Object {
        Write-Host "🗑️ Удаляю запуск workflow ID: $_"
        gh api --method DELETE "repos/OSPanel/php-windows-builder/actions/runs/$_"
    }

    Write-Host "✅ Все артефакты и запуски workflow удалены." -ForegroundColor Green
    exit 0
}

if (-not $ExtensionName -or -not $PhpVersions) {
    Write-Host "❌ Ошибка: Требуются параметры ExtensionName и PhpVersions, если не используется 'get all' или 'delete all'." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Требуется 'jq', но он не установлен. Пожалуйста, установите jq сначала." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Требуется 'gh', но он не установлен. Пожалуйста, установите GitHub CLI сначала." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "extension\BuildPhpExtension\config\matrix.json")) {
    Write-Host "❌ Файл matrix.json не найден в текущей директории." -ForegroundColor Red
    exit 1
}

$repo = jq -r ".$ExtensionName.source" "extension/BuildPhpExtension/config/matrix.json"
if ([string]::IsNullOrEmpty($repo) -or $repo -eq "null") {
    Write-Host "❌ URL репозитория не найден для $ExtensionName в matrix.json." -ForegroundColor Red
    exit 1
}

$phpVersionList = $PhpVersions -split ","
$validVersions = @()
$invalidVersions = @()

$extGroups = @{}

foreach ($phpVersion in $phpVersionList) {
    $phpVersion = $phpVersion.Trim()
    Write-Host "🔍 Обрабатываю версию PHP: $phpVersion" -ForegroundColor Cyan

    $extVersion = jq -r ".$ExtensionName.ver.`"$phpVersion`"" "extension/BuildPhpExtension/config/matrix.json"

    if ([string]::IsNullOrEmpty($extVersion) -or $extVersion -eq "null") {
        Write-Host "⚠️ PHP $phpVersion - версия не найдена" -ForegroundColor Yellow
        $invalidVersions += $phpVersion
    } else {
        Write-Host "✅ PHP $phpVersion - версия расширения: $extVersion" -ForegroundColor Green

        if ($extGroups.ContainsKey($extVersion)) {
            $extGroups[$extVersion] += $phpVersion
        } else {
            $extGroups[$extVersion] = @($phpVersion)
        }
    }
}

foreach ($extVersion in $extGroups.Keys) {
    $phpVersions = $extGroups[$extVersion] -join ','

    Write-Host "🚀 Запускаю workflow для расширения '$ExtensionName' версии $extVersion и PHP версий: $phpVersions" -ForegroundColor Blue

    gh workflow run pecl.yml `
        -R OSPanel/php-windows-builder `
        -f extension-url="$repo" `
        -f extension-ref="$extVersion" `
        -f php-version-list="$phpVersions" `
        -f arch-list="x64" `
        -f ts-list="nts"

    Write-Host ""
}

if ($invalidVersions.Count -gt 0) {
    $invalidVersionsString = $invalidVersions -join ", "
    Write-Host "⚠️ Предупреждение: Следующие версии PHP не найдены в matrix.json для ${ExtensionName}: $invalidVersionsString" -ForegroundColor Yellow
}

$totalValidPhpVersions = 0
$totalWorkflowsRun = $extGroups.Keys.Count

foreach ($versions in $extGroups.Values) {
    $totalValidPhpVersions += $versions.Count
}

if ($totalValidPhpVersions -gt 0) {
    Write-Host "✅ Успешно запущено $totalWorkflowsRun workflow для $totalValidPhpVersions версий PHP" -ForegroundColor Green
} else {
    Write-Host "❌ Не найдено валидных версий PHP для расширения $ExtensionName." -ForegroundColor Red
}