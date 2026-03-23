---
Создан: 2025-11-05T16:15
Изменен: 2026-02-12T22:52
title: Сайт из заметок Obsidian. Пересказ всего процесса проделанного с чатом qwen.ai
date: 05.11.2025
published: true
Категория: Источник
Корень:
  - "[[ТЕХНОЛОГИИ]]"
---
**Чёткая, пошаговая инструкция** для тех, кто **не программист**, но хочет **автоматически публиковать заметки из Obsidian на свой сайт**, размещённый на **GitHub Pages** с собственным доменом (`blog.axelbux.ru`).

Всё настроено под вашу систему:
- Windows
- Obsidian
- GitHub
- Quartz v4 (статический генератор)
- Публикация только заметок с флагом `published: true`

---

# 🌱 Финальная цель

Вы пишете заметки в **Obsidian** → отмечаете нужные как `published: true` → запускаете скрипт → сайт **автоматически обновляется** на `https://blog.axelbux.ru`.

Все заметки хранятся **у вас на компьютере**, на GitHub попадают **только опубликованные**.

---

## 📦 Что понадобится

1. **Obsidian** — ваш цифровой сад
2. **Git** — для синхронизации с GitHub  
   👉 [Скачать Git](https://git-scm.com/download/win) → при установке выберите **«Add Git to PATH»**
3. **Node.js (v18–v20)** — для сборки сайта  
   👉 [Скачать Node.js v20 (LTS)](https://nodejs.org/dist/latest-v20.x/node-v20.18.1-x64.msi)
4. **Аккаунт на GitHub**
5. **Домен (например, blog.axelbux.ru)** — [[Настройка GitHub и подключение домена для своего блога|уже подключён к GitHub]]

---

## 🔧 Шаг 1. Подготовьте структуру папок

1. Создайте основное хранилище Obsidian:  
   ```
   C:\Users\Axel Bux\Obsidian\Vault
   ```
   → Это ваш «второй мозг»: сюда вы пишете **все заметки**, включая черновики.

2. Склонируйте сайт с GitHub:  
   ```powershell
   cd "C:\Users\Axel Bux\Документы\GitHub"
   git clone -b v4 https://github.com/axelbux/blog.git
   ```
   → Сайт будет здесь:  
   ```
   C:\Users\Axel Bux\Документы\GitHub\blog
   ```

---

## 🖊️ Шаг 2. Настройте Quartz (движок сайта)

1. Установите зависимости:
   ```powershell
   cd "C:\Users\Axel Bux\Документы\GitHub\blog"
   npm install
   ```

2. Убедитесь, что сайт работает локально:
   ```powershell
   npx quartz build --serve
   ```
   → Откроется `http://localhost:8080`. Закройте (`Ctrl+C`).

---

## 📝 Шаг 3. Пишите заметки с меткой публикации

В любой заметке в Obsidian добавьте в начало:

```md
---
published: true
title: Название заметки
---
```

Только такие заметки будут попадать на сайт.

> 💡 Заметки без `published: true` остаются приватными.

---

## ⚙️ Шаг 4. Создайте скрипт публикации

Создайте файл:  
`C:\Users\Axel Bux\Obsidian\publish.ps1`

Содержимое (скопируйте **всё целиком**):

```powershell
# publish.ps1 — автоматическая публикация заметок с published: true
$ErrorActionPreference = "Stop"
$MainVault = "C:\Users\Axel Bux\Obsidian\Vault"
$ContentDir = "C:\Users\Axel Bux\Документы\GitHub\blog\content"
$SupportedExtensions = @(
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg',
    'pdf', 'mp4', 'mp3', 'wav', 'ogg', 'zip', 'epub', 'm4a',
    'ps1', 'bat', 'txt', 'json', 'csv', 'md'
)
try {
    # Проверка: существует ли основной vault?
    if (!(Test-Path $MainVault)) {
        Write-Error "❌ Vault не найден: $MainVault"
        exit 1
    }
    # Проверка: есть ли Git-репозиторий?
    $RepoPath = "C:\Users\Axel Bux\Документы\GitHub\blog"
    if (!(Test-Path (Join-Path $RepoPath ".git"))) {
        Write-Error "❌ Не найден репозиторий: $RepoPath"
        exit 1
    }
    # Найти заметки с published: true
    $publishedNotes = Get-ChildItem -Path $MainVault -Recurse -Include *.md | Where-Object {
        $lines = Get-Content $_.FullName -TotalCount 50 -ErrorAction SilentlyContinue
        $lines -match "^published:\s*true\s*$"
    }
    if ($publishedNotes.Count -eq 0) {
        Write-Host "ℹ️ Нет заметок с 'published: true'"
        exit 0
    }
    # Убедиться, что content существует
    if (!(Test-Path $ContentDir)) {
        New-Item -ItemType Directory -Path $ContentDir | Out-Null
    }
    # Очистить старое
    if (Test-Path $ContentDir) {
        Get-ChildItem -Path $ContentDir -Recurse -Force | Remove-Item -Recurse -Force
    }
    # Копировать заметки и связанные файлы
    foreach ($note in $publishedNotes) {
        $relPath = $note.FullName.Substring($MainVault.Length + 1).Replace('\', '/')
        $destPath = Join-Path $ContentDir $relPath
        $destDir = Split-Path $destPath -Parent
        if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item $note.FullName -Destination $destPath -Force
        # Копировать изображения, архивы и др.
        $content = Get-Content $note.FullName -Raw
        if (!$content) { continue }
        $allRefs = @()
        # Obsidian: [[file.ext]] или [[file.ext|текст]]
        $obsidianMatches = [regex]::Matches($content, '(?<!\\)\[\[([^\]|]+\.(?:' + ($SupportedExtensions -join '|') + '))')
        foreach ($m in $obsidianMatches) { if ($m.Groups[1]) { $allRefs += $m.Groups[1].Value } }
        # Markdown: ![](path/file.ext)
        $mdMatches = [regex]::Matches($content, '!$$[^)]*?([^)]+\.(' + ($SupportedExtensions -join '|') + '))')
        foreach ($m in $mdMatches) { if ($m.Groups[1]) { $allRefs += $m.Groups[1].Value } }
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
                $relResource = $sourceFile.Substring($MainVault.Length + 1).Replace('\', '/')
                $destResource = Join-Path $ContentDir $relResource
                $resDir = Split-Path $destResource -Parent
                if (!(Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir -Force | Out-Null }
                Copy-Item $sourceFile -Destination $destResource -Force
            }
        }
    }
    # Восстановить index.md
    $indexPath = Join-Path $ContentDir "index.md"
    if (!(Test-Path $indexPath)) {
        Set-Content -Path $indexPath -Value @"
---
title: Домашняя страница
---
Добро пожаловать в мой цифровой сад.
"@
    }
    # Git: коммит и пуш
    Set-Location $RepoPath
    git add .
    $hasChanges = git status --porcelain
    if ($hasChanges) {
        git commit -m "Publish: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git push origin v4
        Write-Host "✅ Успешно опубликовано на blog.axelbux.ru"
    } else {
        Write-Host "ℹ️ Нет изменений"
    }
} catch {
    Write-Error "❌ Ошибка: $($_.Exception.Message)"
    exit 1
}
```

> 💡 Сохраните файл в **UTF-8 без BOM** (лучше через **VS Code** → ПКМ → «Сохранить с кодировкой» → **UTF-8**).

---

## 🚀 Шаг 5. Настройте автоматический запуск

### Вариант A: Через Obsidian (рекомендуется)

1. В основном vault’е (`Vault`) установите плагин **Shell commands** (Community plugins → Browse → «Shell commands»).
2. Откройте **Settings → Shell commands**.
3. Нажмите **+ Add new command**:
   - **Name**: `Опубликовать заметки`
   - **Command**:  
     ```powershell
     PowerShell -ExecutionPolicy Bypass -File "C:\Users\Axel Bux\Obsidian\publish.ps1"
     ```
4. Внизу включите:  
   ✅ **Run on startup**  
   (или ✅ **Run periodically**, например, каждые 30 минут)

→ При открытии Obsidian — публикация запустится автоматически.

---

## 🧪 Шаг 6. Проверка

1. В **Obsidian** создайте заметку:
   ```md
   ---
   published: true
   title: Тест
   ---
   Это тестовая заметка.
   ```
2. Закройте и снова откройте Obsidian.
3. Через 1–2 минуты зайдите на:  
   👉 https://blog.axelbux.ru  
   → Заметка должна появиться.

---

## 🛡️ Советы

- **Фавикон**: положите `favicon.ico` в  
  `C:\Users\Axel Bux\Документы\GitHub\blog\static\favicon.ico`
- **Обратная связь**: вместо комментариев добавьте в конец статьи:  
  ```md
  > 💬 Вопросы? Пишите в [Telegram](https://t.me/axelbux).
  ```
- **Резервная копия**: перед первым запуском скрипта сделайте копию папки `blog`.

---

## ✅ Готово!

Теперь у вас:
- ✅ Все заметки — локально
- ✅ Только `published: true` — на сайте
- ✅ Полный контроль и минимализм
- ✅ Автоматизация без сложных сервисов

Если что-то пойдёт не так — просто **удалите папку `content` и восстановите `index.md`** → сайт снова заработает.

Удачи! 🌿