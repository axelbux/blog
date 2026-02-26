#!/usr/bin/env bash
set -euo pipefail

MAIN_VAULT="/home/axelbux/Документы/ObsidianBase"
REPO_PATH="/home/axelbux/Документы/GitHub/blog"
CONTENT_DIR="$REPO_PATH/content"

echo "=== Публикация блога из Obsidian ==="
echo "Vault:      $MAIN_VAULT"
echo "Repo:       $REPO_PATH"
echo "ContentDir: $CONTENT_DIR"
echo

if [ ! -d "$MAIN_VAULT" ]; then
  echo "❌ Vault не найден: $MAIN_VAULT" >&2
  exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "❌ Не репозиторий Git: $REPO_PATH" >&2
  exit 1
fi

mkdir -p "$CONTENT_DIR"

echo "✅ Базовые проверки пройдены"
echo

echo "=== Поиск опубликованных заметок (published: true) ==="

PUBLISHED_NOTES_FILE="$(mktemp)"
TOTAL_NOTES=0
TOTAL_PUBLISHED=0

while IFS= read -r -d '' md; do
  TOTAL_NOTES=$((TOTAL_NOTES + 1))
  if head -n 50 "$md" | grep -q '^published:\s*true\s*$'; then
    echo "$md" >> "$PUBLISHED_NOTES_FILE"
    TOTAL_PUBLISHED=$((TOTAL_PUBLISHED + 1))
    echo "✅ published: $md"
  fi
done < <(find "$MAIN_VAULT" -type f -name '*.md' -print0)

echo
echo "Всего заметок:        $TOTAL_NOTES"
echo "Опубликованных (true): $TOTAL_PUBLISHED"
echo "Список сохранён во временный файл: $PUBLISHED_NOTES_FILE"
echo

echo "=== Удаление устаревших заметок из content/ ==="

DELETED_COUNT=0

# Обходим все .md в content (кроме index.md)
while IFS= read -r -d '' md; do
  base_name="$(basename "$md")"
  if [ "$base_name" = "index.md" ]; then
    continue
  fi

  # Относительный путь относительно CONTENT_DIR
  rel_path="${md#"$CONTENT_DIR"/}"

  # Путь к соответствующему файлу во vault
  vault_path="$MAIN_VAULT/$rel_path"

  # Если файла во vault нет — удаляем из content
  if [ ! -f "$vault_path" ]; then
    echo "🗑️ Нет во vault, удаляю: $rel_path"
    rm -f "$md"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    continue
  fi

  # Если во vault убрали published: true — удаляем из content
  if ! head -n 50 "$vault_path" | grep -q '^published:\s*true\s*$'; then
    echo "🗑️ published: false/нет, удаляю: $rel_path"
    rm -f "$md"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    continue
  fi
done < <(find "$CONTENT_DIR" -type f -name '*.md' -print0)

echo "Удалено заметок: $DELETED_COUNT"
echo

echo "=== Копирование опубликованных заметок в content/ ==="

while IFS= read -r note; do
  rel_path="${note#"$MAIN_VAULT"/}"

  base_name="$(basename "$rel_path")"
  if [ "$base_name" = "index.md" ]; then
    echo "⏭ Пропуск index.md: $rel_path"
    continue
  fi

  dest_md="$CONTENT_DIR/$rel_path"
  dest_dir="$(dirname "$dest_md")"

  mkdir -p "$dest_dir"
  cp "$note" "$dest_md"

  echo "📄 Скопировано: $rel_path"
done < "$PUBLISHED_NOTES_FILE"

echo
echo "✅ Копирование заметок завершено"
