# publish.ps1 — финальная версия с поддержкой [[file|text]] и всех ресурсов
$ErrorActionPreference = "Stop"

$MainVault = "C:\Users\Axel Bux\Документы\Мои базы Obsidian"
$ContentDir = "C:\Users\Axel Bux\Документы\GitHub\blog\content"
$RepoPath = "C:\Users\Axel Bux\Документы\GitHub\blog"

# Поддерживаемые расширения (включая скрипты и архивы)
$SupportedExtensions = @(
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg',
    'pdf', 'mp4', 'mp3', 'wav', 'ogg', 'zip', 'epub', 'm4a',
    'ps1', 'bat', 'txt', 'json', 'csv', 'md'
)

# Нормализация пути
$MainVault = $MainVault.TrimEnd('\', '/')

# === Проверки
if (!(Test-Path $MainVault)) { Write-Error "❌ Основной vault не найден: $MainVault"; exit 1 }
if (!(Test-Path (Join-Path $RepoPath ".git"))) { Write-Error "❌ Папка не является Git-репозиторием: $RepoPath"; exit 1 }

# === Найти опубликованные заметки
$publishedNotes = Get-ChildItem -Path $MainVault -Recurse -Include *.md -ErrorAction Stop | Where-Object {
    $lines = Get-Content $_.FullName -TotalCount 50 -ErrorAction SilentlyContinue
    $lines -match "^published:\s*true\s*$"
}

if (!$publishedNotes) { Write-Host "ℹ️ Нет заметок с 'published: true'. Публикация не требуется."; exit 0 }

# === Убедиться, что content существует
if (!(Test-Path $ContentDir)) { New-Item -ItemType Directory -Path $ContentDir -Force | Out-Null }

# === Собрать существующие .md (кроме index.md)
$existingMdFiles = Get-ChildItem -Path $ContentDir -Recurse -Include *.md -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "index.md" } |
    ForEach-Object { $_.FullName.Substring($ContentDir.Length).TrimStart('\', '/').Replace('\', '/') }

$publishedMdPaths = @{}

# === Обработка каждой заметки
foreach ($note in $publishedNotes) {
    $relPath = $note.FullName.Substring($MainVault.Length).TrimStart('\', '/').Replace('\', '/')
    $publishedMdPaths[$relPath] = $true

    $destMd = Join-Path $ContentDir $relPath
    $destDir = Split-Path $destMd -Parent
    if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item $note.FullName -Destination $destMd -Force
    Write-Host "📄 $relPath"

    # === Извлечение ссылок на ресурсы
    $content = Get-Content $note.FullName -Raw -ErrorAction SilentlyContinue
    if (!$content) { continue }

    $allRefs = @()

    # Obsidian: [[file.ext]] или [[file.ext|текст]]
    $obsidianMatches = [regex]::Matches($content, '(?<!\\)\[\[([^\]|]+\.(?:' + ($SupportedExtensions -join '|') + '))')
    foreach ($m in $obsidianMatches) { if ($m.Groups[1]) { $allRefs += $m.Groups[1].Value } }

    # Markdown: ![](path/file.ext)
    $mdMatches = [regex]::Matches($content, '!$$[^)]*?([^)]+\.(' + ($SupportedExtensions -join '|') + '))')
    foreach ($m in $mdMatches) { if ($m.Groups[1]) { $allRefs += $m.Groups[1].Value } }

    $allRefs = $allRefs | Sort-Object -Unique

    # === Копирование ресурсов
    foreach ($ref in $allRefs) {
        $sourceFile = $null

        # Относительный путь (содержит / или \)
        if ($ref -match '[/\\]') {
            $candidate = Join-Path $MainVault $ref
            if (Test-Path $candidate) { $sourceFile = $candidate }
        } else {
            # Искать в той же папке, что и заметка
            $candidate = Join-Path (Split-Path $note.FullName -Parent) $ref
            if (Test-Path $candidate) { $sourceFile = $candidate }
        }

        # Поиск по всему vault'у (если не найден)
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
            Write-Host "📎 $relResource"
        }
    }
}

# === Удалить старые .md (кроме index.md)
foreach ($existing in $existingMdFiles) {
    if (!$publishedMdPaths.ContainsKey($existing)) {
        $fullPath = Join-Path $ContentDir $existing.Replace('/', '\')
        if (Test-Path $fullPath) {
            Remove-Item $fullPath -Force
            Write-Host "🗑️  Удалён: $existing"
        }
    }
}

# === Восстановить index.md, если отсутствует
$indexPath = Join-Path $ContentDir "index.md"
if (!(Test-Path $indexPath)) {
    Set-Content -Path $indexPath -Value @"
---
title: Домашняя страница
---

Добро пожаловать в мой цифровой сад.
"@
    Write-Host "✅ Создан index.md"
}

# === Git: коммит и пуш
Set-Location $RepoPath
git add .
$hasChanges = git status --porcelain
if ($hasChanges) {
    git commit -m "Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin v4
    Write-Host "✅ Успешно опубликовано на blog.axelbux.ru"
} else {
    Write-Host "ℹ️ Нет изменений"
}