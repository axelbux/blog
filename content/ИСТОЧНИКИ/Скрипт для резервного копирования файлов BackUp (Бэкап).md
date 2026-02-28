---
Создан: 2026-02-28T12:49
Изменен: 2026-02-28T13:06
Категория: Источник
Корень:
  - "[[ТЕХНОЛОГИИ]]"
Связи:
  - "[[Linux]]"
  - "[[BackUp - Скрипт управления резервным копированием]]"
title: Скрипт для резервного копирования файлов BackUp (Бэкап)
date: 28.02.2026
published: true
---
## 1. Команды для повседневной работы

Эти команды считаем уже настроенными (после установки по шагам из части 3).

### Основные команды бэкапа

- `bckp start`
Запустить резервное копирование прямо сейчас (oneshot‑запуск).
- `bckp status`
Показать состояние сервиса бэкапа (успешно / ошибка / когда в прошлый раз запускался).
- `bckp last-log`
Показать лог **последнего** запуска бэкапа.
- `bckp log`
Показать полный лог (все запуски, с ротацией).
- `bckp now-log`
Онлайн‑просмотр лога, чтобы наблюдать прогресс.


### Проверка автоматического запуска

- `systemctl --user list-timers | grep axelbux-backup`
Проверить, что каждый час стоит таймер `axelbux-backup.timer`.
- `systemctl --user status axelbux-backup.service`
Проверить, как отработал последний запуск (код завершения, ошибки).

***

## 2. Описание функций и как менять настройки

### 2.1. Что делает система в целом

- Копирует папку с документами (по умолчанию `/home/axelbux/Документы`) на внешний диск `/run/media/axelbux/AxelBux_4TB/BackUP`.
- Хранит **зеркальную копию** (как сейчас на диске).
- Удалённые/старые версии складывает в `Trash_version`.
- Ведёт подробный лог `backup.log`.
- После каждого запуска показывает уведомление в системе: успешно / ошибка / прервано.


### 2.2. Главные файлы схемы

1) Скрипт бэкапа (логика):
`~/.local/bin/run-backup.sh`

2) Сервис и таймер (автозапуск каждый час, от пользователя):
`~/.config/systemd/user/axelbux-backup.service`
`~/.config/systemd/user/axelbux-backup.timer`

3) Утилита команд `bckp`:
`/usr/local/bin/bckp`
    + alias в `~/.bashrc`.

### 2.3. Как поменять пользователя, диск, папки

Все настройки сосредоточены в **верху** файла `run-backup.sh`:

```bash
SRC="/home/axelbux/Документы"       # откуда копируем
MOUNT_POINT="/run/media/axelbux/AxelBux_4TB"  # где смонтирован диск
DST="$MOUNT_POINT/BackUP"           # куда копируем
TRASH="$DST/Trash_version"          # куда складывать старые версии
DISK_NAME="AxelBux_4TB"             # человеко-читаемое имя для логов/уведомлений
```

Что можно менять:

- **Поменять пользователя**
Если у нового пользователя другое имя, достаточно:
    - поправить пути `/home/НОВЫЙ_ПОЛЬЗОВАТЕЛЬ/...`
    - выполнять установку и `systemctl --user` уже под этим пользователем.
Сервис всё равно работает в контексте текущего пользователя, никакого `su` внутри скрипта не нужно.
- **Поменять диск**
Например, новый диск монтируется как `/run/media/ivan/MyBackupDisk`:
    - `MOUNT_POINT="/run/media/ivan/MyBackupDisk"`
    - `DISK_NAME="MyBackupDisk"`
Остальное само подстроится, т.к. `DST` и `TRASH` вычисляются из `MOUNT_POINT`.
- **Добавить/убрать папки в копировании**
Копируется весь `SRC`. Есть два способа:

1) **Меняем точку источника**
Было: `SRC="/home/axelbux/Документы"`
Можно сделать:
`SRC="/home/axelbux"` — тогда скопируется весь домашний каталог.
2) **Исключаем лишнее через rsync**
Внизу команды `rsync` можно добавить опции `--exclude`:

```bash
rsync -r -t -v --delete -u --modify-window=1 -s \
  --backup --backup-dir="$TRASH" \
  --exclude=".cache" \
  --exclude="Загрузки" \
  "$SRC" "$DST" >"$RSYNC_OUTPUT_FILE" 2>&1
```

Это удобно, когда источник широкий, но какие‑то папки не нужны.
- **Изменить частоту бэкапа**
В файле таймера `axelbux-backup.timer`:

```ini
[Timer]
OnBootSec=10min
OnUnitActiveSec=60min   # ← интервал между запусками
```

Можно поставить, например, `OnUnitActiveSec=30min` или `2h`.

***

## 3. Пошаговая инструкция (с нуля, для «не программиста»)

### Шаг 0. Предпосылки и зависимости

Перед стартом:

1) **Система**: ALT Linux (или другая с systemd и пользовательскими сервисами).
2) **Права**: есть root‑доступ через `su`.
3) **Установить notify‑send** (чтобы вообще были уведомления):
```bash
su
apt-get update
apt-get install notify-send
exit
```

Проверка под своим пользователем:

```bash
notify-send "Тест" "Если видишь это — уведомления работают"
```

Если появилось всплывающее окно – всё ок.

***

### Шаг 1. Создаём каталог для скрипта и проверяем диск

1) Убедись, что внешний диск подключён и виден как:
```bash
ls /run/media/$USER
```

Ожидаем что‑то вроде `AxelBux_4TB`.

2) Создаём папку для пользовательских скриптов:
```bash
mkdir -p ~/.local/bin
```


***

### Шаг 2. Пишем основной скрипт `run-backup.sh`

Открой файл:

```bash
nano ~/.local/bin/run-backup.sh
```

Вставь:

```bash
#!/bin/bash

# Настройки
SRC="/home/axelbux/Документы"
MOUNT_POINT="/run/media/axelbux/AxelBux_4TB"
DST="$MOUNT_POINT/BackUP"
TRASH="$DST/Trash_version"
LOG="$DST/backup.log"
META="$DST/backup.meta"
STATUS="$DST/backup.status"
DISK_NAME="AxelBux_4TB"

read_success_counter() {
  if [ -f "$META" ]; then
    SUCCESS_COUNT=$(cat "$META" 2>/dev/null)
  else
    SUCCESS_COUNT=0
  fi
  if ! [[ "$SUCCESS_COUNT" =~ ^[0-9]+$ ]]; then
    SUCCESS_COUNT=0
  fi
}

write_success_counter() {
  echo "$SUCCESS_COUNT" > "$META"
}

start_new_session() {
  if [ -f "$LOG" ] && [ -s "$LOG" ]; then
    printf "\n\n\n" >> "$LOG"
  fi
  LINE_NO=0
  SESSION_ERRORS=()
}

log_line() {
  LINE_NO=$((LINE_NO + 1))
  local now msg
  now=$(date +"%Y-%m-%d %H:%M:%S")
  msg="$1"
  printf "[%04d] [%s] %s\n" "$LINE_NO" "$now" "$msg" >> "$LOG"
}

register_error() {
  local line_no="$1"
  local text="$2"
  SESSION_ERRORS+=("строка ${line_no}: ${text}")
}

send_notify() {
  local title="$1"
  local body="$2"
  notify-send "$title" "$body"
}

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
RESULT="УСПЕШНО"
RSYNC_EXIT=0

mkdir -p "$DST" "$TRASH"

start_new_session
read_success_counter

log_line "START: Начато резервное копирование на ${DISK_NAME}"

if ! mountpoint -q "$MOUNT_POINT"; then
  log_line "ERROR: Точка монтирования ${MOUNT_POINT} недоступна. Бэкап пропущен."
  register_error "$LINE_NO" "Точка монтирования недоступна"
  RESULT="С ОШИБКАМИ"
  RSYNC_EXIT=1
  SUCCESS_COUNT=0
  write_success_counter
  END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  log_line "SUMMARY: Дата/время начала: ${START_TIME}"
  log_line "SUMMARY: Дата/время завершения: ${END_TIME}"
  log_line "SUMMARY: Результат: ${RESULT}"
  log_line "SUMMARY: Ошибок: ${#SESSION_ERRORS[@]}"
  for err in "${SESSION_ERRORS[@]}"; do
    log_line "SUMMARY: ${err}"
  done
  echo "${END_TIME}|С ОШИБКАМИ|Диск не смонтирован" > "$STATUS"
  send_notify "Резервное копирование" "Ошибка: диск ${DISK_NAME} не смонтирован"
  exit 1
fi

log_line "INFO: Точка монтирования ${MOUNT_POINT} доступна"
log_line "INFO: Каталог назначения: ${DST}"
log_line "INFO: Каталог Trash_version: ${TRASH}"
log_line "INFO: Запуск rsync"

RSYNC_OUTPUT_FILE="$(mktemp)"
rsync -r -t -v --delete -u --modify-window=1 -s \
  --backup --backup-dir="$TRASH" \
  "$SRC" "$DST" >"$RSYNC_OUTPUT_FILE" 2>&1
RSYNC_EXIT=$?

while IFS= read -r line; do
  log_line "RSYNC: ${line}"
done < "$RSYNC_OUTPUT_FILE"

rm -f "$RSYNC_OUTPUT_FILE"

END_TIME=$(date +"%Y-%m-%d %H:%M:%S")

case "$RSYNC_EXIT" in
  0)
    RESULT="УСПЕШНО"
    ;;
  20)
    RESULT="ПРЕРВАНО"
    register_error "$LINE_NO" "rsync прерван сигналом (код 20)"
    ;;
  23)
    RESULT="С ОШИБКАМИ"
    register_error "$LINE_NO" "rsync завершился с частичной передачей (код 23). См. строки RSYNC: выше."
    ;;
  *)
    RESULT="С ОШИБКАМИ"
    register_error "$LINE_NO" "rsync завершился с кодом ${RSYNC_EXIT}"
    ;;
esac

STATUS_TEXT="OK"
case "$RESULT" in
  "УСПЕШНО")
    STATUS_TEXT="Резервное копирование завершено!"
    ;;
  "С ОШИБКАМИ")
    STATUS_TEXT="Резервное копирование завершено с ОШИБКАМИ (код ${RSYNC_EXIT})"
    ;;
  "ПРЕРВАНО")
    STATUS_TEXT="Резервное копирование прервано (код ${RSYNC_EXIT})"
    ;;
esac
echo "${END_TIME}|${RESULT}|${STATUS_TEXT}" > "$STATUS"

if [ "$RESULT" = "УСПЕШНО" ]; then
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  if [ "$SUCCESS_COUNT" -ge 4 ]; then
    TMP_LOG="$(mktemp)"
    tac "$LOG" | awk 'BEGIN{empty=0} {if($0==""){empty++} else empty=0} {print} (empty==3){exit}' | tac > "$TMP_LOG"
    mv "$TMP_LOG" "$LOG"
  fi
else
  SUCCESS_COUNT=0
fi

write_success_counter

log_line "SUMMARY: Дата/время начала: ${START_TIME}"
log_line "SUMMARY: Дата/время завершения: ${END_TIME}"
log_line "SUMMARY: Результат: ${RESULT}"
log_line "SUMMARY: Код rsync: ${RSYNC_EXIT}"
log_line "SUMMARY: Ошибок: ${#SESSION_ERRORS[@]}"
if [ "${#SESSION_ERRORS[@]}" -gt 0 ]; then
  log_line "SUMMARY: Ошибка(и):"
  for err in "${SESSION_ERRORS[@]}"; do
    log_line "SUMMARY:  - ${err}"
  done
else
  log_line "SUMMARY: Ошибок не обнаружено"
fi

case "$RESULT" in
  "УСПЕШНО")
    send_notify "Резервное копирование" "Резервное копирование завершено!"
    ;;
  "С ОШИБКАМИ")
    send_notify "Резервное копирование" "Резервное копирование завершено с ОШИБКАМИ"
    ;;
  "ПРЕРВАНО")
    send_notify "Резервное копирование" "Резервное копирование прервано"
    ;;
esac

exit "$RSYNC_EXIT"
```

Сохранить (`Ctrl+O`, Enter, `Ctrl+X`) и сделать исполняемым:

```bash
chmod +x ~/.local/bin/run-backup.sh
```


***

### Шаг 3. Создаём user‑service и timer

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/axelbux-backup.service
```

Вставь:

```ini
[Unit]
Description=AxelBux backup to 4TB disk (user)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/run-backup.sh
```

Теперь таймер:

```bash
nano ~/.config/systemd/user/axelbux-backup.timer
```

Вставь:

```ini
[Unit]
Description=Run AxelBux backup every hour (user)

[Timer]
OnBootSec=10min
OnUnitActiveSec=60min
Unit=axelbux-backup.service

[Install]
WantedBy=timers.target
```

Применить и включить:

```bash
systemctl --user daemon-reload
systemctl --user enable --now axelbux-backup.timer
```

Проверка:

```bash
systemctl --user list-timers | grep axelbux-backup
```


***

### Шаг 4. Команда `bckp`

От root:

```bash
su
nano /usr/local/bin/bckp
```

Содержимое:

```bash
#!/bin/bash

LOG="/run/media/axelbux/AxelBux_4TB/BackUP/backup.log"
SERVICE="axelbux-backup.service"

usage() {
  echo "Использование: bckp {start|status|log|now-log|last-log}"
  exit 1
}

cmd="$1"

case "$cmd" in
  start)
    systemctl --user start "$SERVICE"
    ;;
  status)
    systemctl --user status "$SERVICE"
    ;;
  log)
    [ -f "$LOG" ] && cat "$LOG" || echo "Лог-файл не найден: $LOG"
    ;;
  now-log)
    [ -f "$LOG" ] && tail -f "$LOG" || echo "Лог-файл не найден: $LOG"
    ;;
  last-log)
    if [ -f "$LOG" ]; then
      tac "$LOG" | awk 'BEGIN{empty=0;printed=0} {
        if($0==""){empty++} else empty=0
        print
        printed=1
        if(empty==3){exit}
      }' | tac
    else
      echo "Лог-файл не найден: $LOG"
    fi
    ;;
  *)
    usage
    ;;
esac
```

Сделать исполняемым и выйти:

```bash
chmod +x /usr/local/bin/bckp
exit
```

Добавить alias и подхватить его:

```bash
echo "alias bckp='/usr/local/bin/bckp'" >> ~/.bashrc
source ~/.bashrc
```


***

### Шаг 5. Финальная проверка

1) Ручной запуск:
```bash
bckp start
```

2) Проверить лог:
```bash
bckp last-log
```

3) Убедиться, что появилось уведомление «Резервное копирование завершено!».
4) Проверить таймер:
```bash
systemctl --user list-timers | grep axelbux-backup
```

Если всё это работает — система полностью развернута, и в следующий раз тебе достаточно:

- перед любыми изменениями вспомнить:

1) есть ли `notify-send`,
2) запущен ли user‑таймер,
3) правильны ли пути `SRC` и `MOUNT_POINT`.

Хочешь, я всё это ещё и в формате Markdown‑файла сверстаю (SetupBackupFromScratch.md), чтобы положить рядом с текущими мануалами?

