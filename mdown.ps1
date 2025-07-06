# Оголошуємо параметри
param(
    [Parameter(Mandatory=$true)] [string]$URL,
    [Parameter(Mandatory=$true)] [string]$Title,
    [Parameter(Mandatory=$true)] [string]$Artist
)

# Створюємо імена файлів
$FinalFilename = "$Artist - $Title.m4a"
$TempFilename = "temp_audio_$(Get-Random).m4a"

# Головний блок з надійною обробкою помилок
try {
    # --- Крок 1: Завантаження через yt-dlp ---
    & yt-dlp -x --audio-format m4a --embed-thumbnail -o $TempFilename $URL
    if ($LASTEXITCODE -ne 0) {
        # Створюємо власну помилку, щоб її перехопив блок catch
        throw "yt-dlp не зміг завантажити відео. Дивись помилку вище."
    }

    # --- Крок 2: Обробка метаданих через FFmpeg ---
    & ffmpeg -i $TempFilename -c:a copy -c:v copy -metadata title="$Title" -metadata artist="$Artist" $FinalFilename -hide_banner -loglevel error
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg не зміг обробити файл."
    }

    # --- Фінальне повідомлення (тільки при успіху) ---
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║ ✅ Готово! Файл збережено як:                     ║" -ForegroundColor Green
    Write-Host "║ $($FinalFilename)" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "" 
}
catch {
    # Цей блок спрацює при будь-якій помилці з блоку try
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║ ПОМИЛКА: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}
finally {
    # Цей блок виконається ЗАВЖДИ, гарантуючи видалення сміття
    if (Test-Path $TempFilename) {
        Remove-Item $TempFilename
    }
}