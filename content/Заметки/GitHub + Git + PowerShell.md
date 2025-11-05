---
Создан: 2025-11-03T21:39
Изменен: 2025-11-05T18:45
tags:
  - технологии
published: true
title: Полезные команды GitHub + Git + PowerShell
---
## Базовая команда (самая частая)
Эта команда объединяет `git fetch` (загрузка изменений) и `git merge` (объединение с локальной версией).

```
git pull
```

```Upload
cd "C:\Users\Axel Bux\Документы\GitHub\blog"
git pull
```

## Если при загрузке произошла ошибка или удаление
Можно откатить на одну версию назад.

```
cd "C:\Users\Axel Bux\Документы\GitHub\blog"
git reset --hard HEAD~1
git push --force origin v4
```

