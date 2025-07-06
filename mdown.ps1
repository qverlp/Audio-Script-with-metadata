# Оголошуємо параметри. Title і Artist тепер не є обов'язковими.
param(
    [Parameter(Mandatory=$true)]
    [string]$URL,

    [string]$Title = "",
    [string]$Artist = ""
)

# --- Блок налаштування шляхів ---
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
# Тимчасовий файл потрібен для надійного запису метаданих
$TempFilename = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "temp_audio_$(Get-Random).m4a"

# --- Головний блок з надійною обробкою помилок ---
try {
    # --- Крок 1: Отримання метаданих ---
    Write-Host "Отримання базових метаданих..." -ForegroundColor DarkMagenta
    $AutoTitle = (& yt-dlp --print "%(title)s" --skip-download $URL | Select-Object -First 1)
    $AutoArtist = (& yt-dlp --print "%(channel)s" --skip-download $URL | Select-Object -First 1)
    $ExtractorName = (& yt-dlp --print "%(extractor_key)s" --skip-download $URL | Select-Object -First 1).ToUpper()

    if ([string]::IsNullOrEmpty($AutoTitle)) {
        throw "Не вдалося отримати метадані з посилання."
    }

    # --- Крок 2: Визначення фінальних назви та виконавця ---
    # Використовуємо дані користувача, якщо вони є, інакше — автоматичні.
    $FinalTitle = if (-not ([string]::IsNullOrEmpty($Title))) { $Title } else { $AutoTitle }
    $FinalArtist = if (-not ([string]::IsNullOrEmpty($Artist))) { $Artist } else { $AutoArtist }

    Write-Host "Отримання даних із $($ExtractorName)..." -ForegroundColor DarkYellow
    Write-Host "Виконавець: $FinalArtist" -ForegroundColor Magenta
    Write-Host "Назва: $FinalTitle" -ForegroundColor Magenta

    # --- Крок 3: Уніфікований процес завантаження і обробки ---
    $BaseFilename = "$FinalArtist - $FinalTitle.m4a"
    $FinalFilename = Join-Path -Path $DesktopPath -ChildPath $BaseFilename

    # Завантаження у тимчасовий файл
    & yt-dlp -x --audio-format m4a --embed-thumbnail -o $TempFilename $URL
    if ($LASTEXITCODE -ne 0) { throw "yt-dlp не зміг завантажити відео." }

    # Обробка через FFmpeg
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