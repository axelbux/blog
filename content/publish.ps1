# publish.ps1 — надёжная публикация с поддержкой медиа и обработкой ошибок
$ErrorActionPreference = "Stop"  # Остановить при критических ошибках

$MainVault = "C:\Users\Axel Bux\Документы\Мои базы Obsidian"
$ContentDir = "C:\Users\Axel Bux\Документы\GitHub\blog\content"
$SupportedExtensions = @(
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg',
    'pdf', 'mp4', 'mp3', 'wav', 'ogg', 'zip', 'epub', 'm4a'
)

try {
    # === 1. Проверка: существует ли основной vault?
    if (!(Test-Path $MainVault)) {
        Write-Error "❌ Основной vault не найден: $MainVault"
        exit 1
    }

    # === 2. Проверка: есть ли Git-репозиторий?
    $RepoPath = "C:\Users\Axel Bux\Документы\GitHub\blog"
    if (!(Test-Path (Join-Path $RepoPath ".git"))) {
        Write-Error "❌ Папка не является Git-репозиторием: $RepoPath"
        exit 1
    }

    # === 3. Проверка интернета (опционально, но полезно перед push)
    try {
        $response = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -ne 200) { throw }
    } catch {
        Write-Warning "⚠️ Возможно, нет подключения к интернету. Git push может не сработать."
        # Не останавливаем — пусть коммитится локально
    }

    # === 4. Найти все .md с published: true
    $publishedNotes = Get-ChildItem -Path $MainVault -Recurse -Include *.md -ErrorAction Stop | Where-Object {
        $lines = Get-Content $_.FullName -TotalCount 50 -ErrorAction SilentlyContinue
        $lines -match "^published:\s*true\s*$"
    }

    if ($publishedNotes.Count -eq 0) {
        Write-Host "ℹ️ Нет заметок с 'published: true'. Публикация не требуется."
        exit 0
    }

    # === 5. Убедиться, что content существует
    if (!(Test-Path $ContentDir)) {
        New-Item -ItemType Directory -Path $ContentDir -Force | Out-Null
    }

    # === 6. Собрать существующие .md (кроме index.md)
    $existingMdFiles = Get-ChildItem -Path $ContentDir -Recurse -Include *.md -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "index.md" } |
        ForEach-Object { $_.FullName.Substring($ContentDir.Length + 1).Replace('\', '/') }

    $publishedMdPaths = @()
    $publishedResourcePaths = @()

    foreach ($note in $publishedNotes) {
        try {
            $relPath = $note.FullName.Substring($MainVault.Length + 1).Replace('\', '/')
            $publishedMdPaths += $relPath

            $destMd = Join-Path $ContentDir $relPath
            $destDir = Split-Path $destMd -Parent
            if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item $note.FullName -Destination $destMd -Force
            Write-Host "📄 $relPath"
        } catch {
            Write-Warning "⚠️ Не удалось скопировать заметку: $($note.FullName). Пропущено."
            continue
        }

        # === Копирование ресурсов
        $content = Get-Content $note.FullName -Raw -ErrorAction SilentlyContinue
        if (!$content) { continue }

        # Шаблоны ссылок: ![[file.ext]], [[file.ext]], ![](path/file.ext)
        $patterns = @(
            '(?<!\\)!?\[\[([^\]]+\.(' + ($SupportedExtensions -join '|') + '))\]\]',
            '!$$[^)]*?([^)]+\.(' + ($SupportedExtensions -join '|') + '))'
        )

        $allRefs = @()
        foreach ($pattern in $patterns) {
            $matches = [regex]::Matches($content, $pattern)
            foreach ($m in $matches) {
                if ($m.Groups.Count -ge 2) {
                    $allRefs += $m.Groups[1].Value
                }
            }
        }

        $allRefs = $allRefs | Sort-Object -Unique

        foreach ($ref in $allRefs) {
            $sourceFile = $null

            # Если путь относительный (содержит / или \)
            if ($ref -match '[/\\]') {
                $candidate = Join-Path $MainVault $ref
                if (Test-Path $candidate) { $sourceFile = $candidate }
            } else {
                # Иначе ищем в той же папке, что и заметка
                $candidate = Join-Path (Split-Path $note.FullName -Parent) $ref
                if (Test-Path $candidate) { $sourceFile = $candidate }
            }

            # Если не нашли — ищем рекурсивно (осторожно: медленно)
            if (!$sourceFile) {
                $found = Get-ChildItem -Path $MainVault -Recurse -Name $ref -Include "*.$($ref.Split('.')[-1])" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $sourceFile = Join-Path $MainVault $found }
            }

            if ($sourceFile -and (Test-Path $sourceFile)) {
                try {
                    $relResource = $sourceFile.Substring($MainVault.Length + 1).Replace('\', '/')
                    $publishedResourcePaths += $relResource

                    $destResource = Join-Path $ContentDir $relResource
                    $resDir = Split-Path $destResource -Parent
                    if (!(Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir -Force | Out-Null }
                    Copy-Item $sourceFile -Destination $destResource -Force
                    Write-Host "📎 $relResource"
                } catch {
                    Write-Warning "⚠️ Не удалось скопировать ресурс: $ref. Пропущено."
                }
            }
        }
    }

    # === 7. Удалить старые .md (кроме index.md)
    foreach ($existing in $existingMdFiles) {
        if ($publishedMdPaths -notcontains $existing) {
            $fullPath = Join-Path $ContentDir $existing.Replace('/', '\')
            if (Test-Path $fullPath) {
                Remove-Item $fullPath -Force
                Write-Host "🗑️  Удалён: $existing"
            }
        }
    }

    # === 8. Восстановить index.md
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

    # === 9. Git: коммит и пуш
    Set-Location $RepoPath
    git add .
    $hasChanges = git status --porcelain
    if ($hasChanges) {
        git commit -m "Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git push origin v4
        Write-Host "✅ Успешно опубликовано на blog.axelbux.ru"
    } else {
        Write-Host "ℹ️ Нет изменений для коммита"
    }

} catch {
    Write-Error "❌ Критическая ошибка: $($_.Exception.Message)"
    exit 1
}