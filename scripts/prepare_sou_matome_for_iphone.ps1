# Đặt tập tin .ps1 cùng 5 tệp sách gốc (4 RAR + 1 PDF).
# Chạy trên Windows PowerShell, có cài 7-Zip. KHÔNG tải sách lên Internet.
param(
    [string]$InputFolder = $PSScriptRoot,
    [string]$OutputFolder = (Join-Path $PSScriptRoot "SouMatome_N2_Import_iPhone")
)

$ErrorActionPreference = "Stop"
$sevenZipCandidates = @(
    (Join-Path $env:ProgramFiles "7-Zip\7z.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe")
)
$sevenZip = $sevenZipCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $sevenZip) {
    $cmd = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($cmd) { $sevenZip = $cmd.Source }
}
if (-not $sevenZip) { throw "Can cai dat 7-Zip de giai nen 4 file RAR." }

$inputPath = (Resolve-Path -LiteralPath $InputFolder).Path
$books = Join-Path $OutputFolder "Books"
$audio = Join-Path $OutputFolder "Audio-CD"
$temp = Join-Path $env:TEMP ("SouMatome_N2_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $books, $audio, $temp | Out-Null

try {
    $archives = Get-ChildItem -LiteralPath $inputPath -File -Filter "*.rar"
    if ($archives.Count -ne 4) {
        Write-Warning ("Tim thay " + $archives.Count + "/4 tap tin RAR")
    }
    foreach ($rar in $archives) {
        $sub = Join-Path $temp $rar.BaseName
        New-Item -ItemType Directory -Force -Path $sub | Out-Null
        Write-Host ("Dang giai nen: " + $rar.Name)
        & $sevenZip x "-o$sub" "-y" "--" $rar.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw ("Khong giai nen duoc: " + $rar.Name) }
    }

    # Sao chép cả bản tiếng Nhật và các file bổ trợ Nhật–Việt: 8 PDF.
    $pdfs = @(Get-ChildItem -LiteralPath $inputPath -File -Filter "*.pdf") +
            @(Get-ChildItem -LiteralPath $temp -File -Filter "*.pdf" -Recurse)
    foreach ($file in $pdfs) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $books $file.Name) -Force
    }

    # CD1 và CD2 có tên file 01.mp3 trùng nhau nên phải lưu riêng.
    $tracks = @(Get-ChildItem -LiteralPath $temp -File -Filter "*.mp3" -Recurse)
    foreach ($track in $tracks) {
        $cd = if ($track.FullName -match "CD2|ＣＤ2") { "CD2" } else { "CD1" }
        $folder = Join-Path $audio $cd
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        Copy-Item -LiteralPath $track.FullName -Destination (Join-Path $folder $track.Name) -Force
    }

    $bookCount = @(Get-ChildItem -LiteralPath $books -File -Filter "*.pdf").Count
    $cd1Count = @(Get-ChildItem -LiteralPath (Join-Path $audio "CD1") -File -Filter "*.mp3" -ErrorAction SilentlyContinue).Count
    $cd2Count = @(Get-ChildItem -LiteralPath (Join-Path $audio "CD2") -File -Filter "*.mp3" -ErrorAction SilentlyContinue).Count
    Write-Host ("PDF: " + $bookCount + "/8; CD1: " + $cd1Count + "/64; CD2: " + $cd2Count + "/52")
    if (($bookCount -ne 8) -or ($cd1Count -ne 64) -or ($cd2Count -ne 52)) {
        Write-Warning "CON THIEU tai lieu, kiem tra lai cac tep goc."
    } else {
        Write-Host "THANH CONG: du 8 PDF va 116 MP3 theo danh sach tap tin."
    }
    Write-Host ("Thu muc de chuyen sang ung dung Tep iPhone: " + $OutputFolder)
} finally {
    Remove-Item -LiteralPath $temp -Force -Recurse -ErrorAction SilentlyContinue
}
