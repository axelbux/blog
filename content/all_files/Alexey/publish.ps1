# publish.ps1 — устойчивая версия для путей с пробелами и кириллицей
$ErrorActionPreference = "Stop"
$MainVault = "C:\Users\Axel Bux\Документы\ObsidianBase\"
$ContentDir = "C:\Users\Axel Bux\Документы\GitHub\blog\content"
$RepoPath = "C:\Users\Axel Bux\Документы\GitHub\blog"

# Поддерживаемые расширения
$SupportedExtensions = @(
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg',
    'pdf', 'mp4', 'mp3', 'wav', 'ogg', 'zip', 'epub', 'm4a',
    'ps1', 'bat', 'txt', 'json', 'csv', 'md'
)

# === Проверки
if (!(Test-Path $MainVault)) {
    Write-Error "❌ Vault не найден: $MainVault"
    exit 1
}
if (!(Test-Path (Join-Path $RepoPath ".git"))) {
    Write-Error "❌ Не репозиторий: $RepoPath"
    exit 1
}

# === Найти опубликованные заметки
$publishedNotes = Get-ChildItem -Path $MainVault -Recurse -Include *.md -ErrorAction Stop | Where-Object {
    $lines = Get-Content $_.FullName -TotalCount 50 -ErrorAction SilentlyContinue
    $lines -match "^published:\s*true\s*$"
}
if (!$publishedNotes) { Write-Host "ℹ️ Нет заметок с 'published: true'"; exit 0 }

# === Убедиться, что content существует
if (!(Test-Path $ContentDir)) { New-Item -ItemType Directory -Path $ContentDir -Force | Out-Null }

# === Обработка
foreach ($note in $publishedNotes) {
    $relPath = $note.FullName.Substring($MainVault.Length).TrimStart('\', '/').Replace('\', '/')
    $destMd = Join-Path $ContentDir $relPath
    $destDir = Split-Path $destMd -Parent
    if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item $note.FullName -Destination $destMd -Force

    # === Извлечение ссылок БЕЗ хрупких regex-конструкций
    $content = Get-Content $note.FullName -Raw -ErrorAction SilentlyContinue
    if (!$content) { continue }

    $allRefs = @()
    # Obsidian: [[file.ext]] или [[file.ext|текст]] — безопасный парсинг
    $content | Select-String -Pattern '\!\?\[\[([^\]\|]+)\.(png|jpg|jpeg|gif|pdf|mp4|mp3|wav|ogg|zip|epub|m4a|ps1|bat|txt|json|csv)\b' -AllMatches | ForEach-Object {
        $_.Matches | ForEach-Object { $allRefs += $_.Groups[1].Value + '.' + $_.Groups[2].Value }
    }
    # Markdown: ![](path/file.ext)
    $content | Select-String -Pattern '!$$[^)]+?/([^)]+\.(png|jpg|jpeg|gif|pdf|mp4|mp3|wav|ogg|zip|epub|m4a|ps1|bat|txt|json|csv))\b' -AllMatches | ForEach-Object {
        $_.Matches | ForEach-Object { $allRefs += $_.Groups[1].Value }
    }

    $allRefs = $allRefs | Sort-Object -Unique
    foreach ($ref in $allRefs) {
        $sourceFile = $null
        if ($ref -match '[/\\]') {
            $candidate = Join-Path $MainVault $ref
            if (Test-Path $candidate) { $sourceFile = $candidate }
        } else {
            $candidate = Join-Path (Split-Path $note.FullName -Parent) $ref
            if (Test-Path $candidate) { $sourceFile = $candidate }
        }
        if (!$sourceFile) {
            $found = Get-ChildItem -Path $MainVault -Recurse -Name $ref -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $sourceFile = Join-Path $MainVault $found }
        }
        if ($sourceFile -and (Test-Path $sourceFile)) {
            $relResource = $sourceFile.Substring($MainVault.Length).TrimStart('\', '/').Replace('\', '/')
            $destResource = Join-Path $ContentDir $relResource
            $resDir = Split-Path $destResource -Parent
            if (!(Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir -Force | Out-Null }
            Copy-Item $sourceFile -Destination $destResource -Force
        }
    }
}

# === Восстановить index.md
$indexPath = Join-Path $ContentDir "index.md"
if (!(Test-Path $indexPath)) {
    Set-Content -Path $indexPath -Value @"
---
title: Домашняя страница
---
Добро пожаловать в мой цифровой сад.
"@
}

# === Git
Set-Location $RepoPath
git add .
$hasChanges = git status --porcelain
if ($hasChanges) {
    git commit -m "Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin v4
    Write-Host "✅ Опубликовано"
} else {
    Write-Host "ℹ️ Нет изменений"
}