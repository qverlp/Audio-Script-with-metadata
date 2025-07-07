# Оголошуємо параметри. Додано новий перемикач -feat.
param(
    [Parameter(Mandatory=$true)]
    [string]$URL,

    [string]$Title = "",
    [string]$Artist = "",

    [switch]$feat
)

# --- Блок налаштування шляхів ---
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
# Тимчасовий файл потрібен для надійного запису метаданих
$TempFilename = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "temp_audio_$(Get-Random).m4a"

# --- Головний блок з надійною обробкою помилок ---
try {
    # --- Крок 1: Отримання метаданих у форматі JSON ---
    Write-Host "Отримання розширених метаданих..." -ForegroundColor DarkMagenta
    # Завантажуємо всю інформацію про відео в одному JSON-об'єкті
    $JsonInfo = & yt-dlp -j --skip-download $URL | ConvertFrom-Json

    if ($null -eq $JsonInfo) {
        throw "Не вдалося отримати метадані з посилання (JSON)."
    }
    
    $AutoTitle = $JsonInfo.title
    $ExtractorName = $JsonInfo.extractor_key.ToUpper()

    # --- Крок 2: Інтелектуальне визначення виконавця з вибором логіки ---
    $AutoArtist = ""
    # Перевіряємо, чи існує список артистів
    if ($null -ne $JsonInfo.artists -is [array] -and $JsonInfo.artists.Count -gt 0) {
        # Завжди видаляємо дублікатів
        $UniqueArtists = $JsonInfo.artists | Select-Object -Unique

        if ($feat) {
            # ЛОГІКА "FEAT.": беремо першого, інших шукаємо в назві
            $MainArtist = $UniqueArtists[0]
            $FeaturedPerformers = New-Object System.Collections.ArrayList

            $OtherArtists = $UniqueArtists | Select-Object -Skip 1
            foreach ($artist_item in $OtherArtists) {
                if ($AutoTitle -match [regex]::Escape($artist_item)) {
                    $FeaturedPerformers.Add($artist_item) | Out-Null
                }
            }
            
            if ($FeaturedPerformers.Count -gt 0) {
                $AutoArtist = "$MainArtist (feat. $($FeaturedPerformers -join ", "))"
            } else {
                $AutoArtist = $MainArtist
            }
        } else {
            # ЛОГІКА ЗА ЗАМОВЧУВАННЯМ: Просто об'єднуємо всіх через &
            $AutoArtist = $UniqueArtists -join " & "
        }
    }
    
    # Запасні варіанти, якщо логіка вище не спрацювала
    if ([string]::IsNullOrEmpty($AutoArtist)) {
        $AutoArtist = if ($null -ne $JsonInfo.artist) { $JsonInfo.artist } else { $JsonInfo.channel }
    }

    # --- Крок 3: Очищення та капіталізація метаданих ---
    $CleanArtist = $AutoArtist -replace " - Topic", ""
    
    $TextInfo = (Get-Culture).TextInfo
    $CasedTitle = if ($AutoTitle -like "* *") { $TextInfo.ToTitleCase($AutoTitle.ToLower()) } else { $AutoTitle }
    $CasedArtist = if ($CleanArtist -like "* *") { $TextInfo.ToTitleCase($CleanArtist.ToLower()) } else { $CleanArtist }

    # --- Крок 4: Визначення фінальних назви та виконавця ---
    $FinalTitle = if (-not ([string]::IsNullOrEmpty($Title))) { $Title } else { $CasedTitle }
    $FinalArtist = if (-not ([string]::IsNullOrEmpty($Artist))) { $Artist } else { $CasedArtist }

    Write-Host "Отримання даних із $($ExtractorName)..." -ForegroundColor DarkYellow
    Write-Host "Виконавець: $FinalArtist" -ForegroundColor Magenta
    Write-Host "Назва: $FinalTitle" -ForegroundColor Magenta

    # --- Крок 5: Уніфікований процес завантаження і обробки ---
    $BaseFilename = "$FinalArtist - $FinalTitle.m4a"
    $FinalFilename = Join-Path -Path $DesktopPath -ChildPath $BaseFilename

    & yt-dlp -x --audio-format m4a --embed-thumbnail -o $TempFilename $URL
    if ($LASTEXITCODE -ne 0) { throw "yt-dlp не зміг завантажити відео." }

    & ffmpeg -i $TempFilename -c:a copy -c:v copy -metadata title="$FinalTitle" -metadata artist="$FinalArtist" $FinalFilename -hide_banner -loglevel error
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg не зміг обробити файл." }

    # Фінальне повідомлення
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║ ✅ Готово! Файл збережено як:                     ║" -ForegroundColor Green
    Write-Host "║ $($BaseFilename)" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}
catch {
    # Обробка помилок
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║ ПОМИЛКА: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}
finally {
    # Гарантоване видалення тимчасових файлів
    if (Test-Path $TempFilename) {
        Remove-Item $TempFilename
    }
}