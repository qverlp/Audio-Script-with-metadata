param(
    [Parameter(Mandatory = $true)][string]$URL,
    [string]$Title = "",
    [string]$Artist = "",
    [switch]$feat
)

$Desktop = [Environment]::GetFolderPath('Desktop')
$TempBase = Join-Path ([IO.Path]::GetTempPath()) "temp_$(Get-Random)"
$Temp = "$TempBase.m4a"

$LogPath = Join-Path $PSScriptRoot "downloads.log"
$UpdateFile = Join-Path $PSScriptRoot ".last_update"
$Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$ShouldUpdate = $true
if (Test-Path $UpdateFile) {
    try {
        $LastCheck = [datetime]::Parse((Get-Content $UpdateFile -Raw))
        if (((Get-Date) - $LastCheck).Days -lt 30) {
            $ShouldUpdate = $false
        }
    }
    catch { }
}

if ($ShouldUpdate) {
    Write-Host "Місячна перевірка оновлень..." -ForegroundColor Cyan
    try {
        $ytOutput = winget upgrade yt-dlp.yt-dlp --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String
        $ytExit = $LASTEXITCODE
        
        $ffOutput = winget upgrade Gyan.FFmpeg --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String
        $ffExit = $LASTEXITCODE
        
        $SuccessCodes = @(0, -1978335189)
        
        if ($ytExit -in $SuccessCodes -and $ffExit -in $SuccessCodes) {
            Add-Content -Path $LogPath -Value "[$Time] ПЕРЕВІРКА ОНОВЛЕННЯ: Успішно (оновлено або вже останні версії)" -Encoding UTF8
        }
        else {
            $ErrorMsg = ""
            if ($ytExit -notin $SuccessCodes) { $ErrorMsg += "yt-dlp (Код $ytExit). " }
            if ($ffExit -notin $SuccessCodes) { $ErrorMsg += "FFmpeg (Код $ffExit). " }
            Add-Content -Path $LogPath -Value "[$Time] ПЕРЕВІРКА ОНОВЛЕННЯ: Неуспішно - $ErrorMsg" -Encoding UTF8
        }
    }
    catch {
        Add-Content -Path $LogPath -Value "[$Time] ПЕРЕВІРКА ОНОВЛЕННЯ: Критична помилка - $($_.Exception.Message)" -Encoding UTF8
    }
    
    (Get-Date).ToString("yyyy-MM-dd") | Set-Content $UpdateFile
}

try {
    Write-Host "Отримання даних..." -ForegroundColor DarkMagenta
    
    $j = & yt-dlp -j --no-warnings --skip-download $URL 2>$null | ConvertFrom-Json
    if (-not $j) { throw "Не вдалося отримати метадані з YouTube." }

    $a = $j.artist
    if ($j.artists) {
        $u = $j.artists | Select-Object -Unique
        if ($feat -and $u.Count -gt 1) {
            $f = ($u | Select-Object -Skip 1) -join ", "
            $a = "$($u[0]) (feat. $f)"
        }
        else {
            $a = $u -join " & "
        }
    }
    if (-not $a) { $a = $j.channel }
    $a = $a -replace " - Topic", ""

    $FinalA = if ($Artist) { $Artist } else { $a }
    $FinalT = if ($Title) { $Title } else { $j.title }

    $FinalA = $FinalA -replace '[\\/:*?"<>|]', ''
    $FinalT = $FinalT -replace '[\\/:*?"<>|]', ''

    $BaseName = "$FinalA - $FinalT.m4a"
    $OutPath = Join-Path $Desktop $BaseName

    Write-Host "Виконавець: $FinalA`nНазва: $FinalT" -ForegroundColor Magenta

    & yt-dlp -q --progress --no-warnings -x --audio-format m4a --embed-thumbnail -o $Temp $URL
    if ($LASTEXITCODE -ne 0) { throw "Помилка yt-dlp під час завантаження." }

    & ffmpeg -y -i $Temp -c copy -metadata title="$FinalT" -metadata artist="$FinalA" $OutPath -hide_banner -loglevel error
    if ($LASTEXITCODE -ne 0) { throw "Помилка FFmpeg." }

    $LogLine = "[$Time] $URL -> $FinalA | $FinalT"
    Add-Content -Path $LogPath -Value $LogLine -Encoding UTF8

    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║ ✅ Готово! Файл збережено як:                     ║" -ForegroundColor Green
    Write-Host "║ $($BaseName)" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

}
catch {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║ ПОМИЛКА: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}
finally {
    Remove-Item "$TempBase*" -Force -ErrorAction SilentlyContinue
}