---
Создан: 2026-02-28T12:49
Изменен: 2026-03-01T13:06
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
## Цель и что даёт эта схема

Эта схема позволяет:

- Автоматически делать бэкап важных данных на внешний диск.
- Иметь понятный лог и статус последнего бэкапа.
- Иметь автозапуск:
    - каждые N минут/часов по таймеру;
    - с задержкой после подключения диска (чтобы он успел смонтироваться).
- Полностью восстановить систему после переустановки, просто выполнив шаги из этого файла.

***

## 1. Команды для повседневной работы

Эти команды считаем уже настроенными (после установки по шагам из части 3 и 4).

### Основные команды бэкапа

- `bckp start`
Запустить резервное копирование прямо сейчас (oneshot‑запуск user‑сервиса).
- `bckp status`
Показать состояние **user‑сервиса** бэкапа (успешно / ошибка / когда в прошлый раз запускался).
- `bckp last-log`
Показать лог **последнего** запуска бэкапа (одна сессия, по разделителю).
- `bckp log`
Показать полный лог (все запуски, с ротацией старых успешных запусков).
- `bckp now-log`
Онлайн‑просмотр лога, чтобы наблюдать прогресс.


### Проверка автоматического запуска

- **По таймеру (каждый час, от пользователя):**

```bash
systemctl --user list-timers | grep axelbux-backup
```

Убедиться, что есть таймер `axelbux-backup.timer`.
- **По подключению диска (root‑триггер):**

```bash
systemctl status axelbux-backup-on-plug.service
```

Проверить, что сервис существует и последнее срабатывание было примерно во время подключения диска.
- **Состояние user‑сервиса:**

```bash
systemctl --user status axelbux-backup.service
```

Проверить, как отработал последний запуск (код завершения, ошибки).

***

## 2. Как всё устроено и что можно менять

### 2.1. Что делает система в целом

- Копирует папку с документами (по умолчанию `/home/axelbux/Документы`) на внешний диск `/run/media/axelbux/AxelBux_4TB/BackUP`.
- Поддерживает **зеркало** текущего состояния: удалённые файлы перемещаются в `Trash_version`.
- Хранит историю изменений и ошибок в `backup.log`, с мягкой ротацией (старые успешные сессии подчищаются после серии успешных запусков).
- Показывает уведомления:
    - при старте бэкапа: `BackUp - AxelBux_4TB / Резервное копирование начато`;
    - при завершении: `BackUp - AxelBux_4TB / ...` (успешно / с ошибками / прервано).
- Не считает **отсутствие подключённого диска** ошибкой: такой запуск помечается как «ПРОПУЩЕНО» и завершает работу с кодом 0, без уведомлений.


### 2.2. Главные сущности схемы

1) **Основной скрипт бэкапа** (логика rsync, логирование, статус):
`~/.local/bin/run-backup.sh`
2) **User‑сервис и таймер** (работают в контексте текущего пользователя, через `systemd --user`):
`~/.config/systemd/user/axelbux-backup.service`
`~/.config/systemd/user/axelbux-backup.timer`
3) **Утилита управления `bckp`** (человеческие команды):
`/usr/local/bin/bckp` + alias в `~/.bashrc`.
4) **Root‑сервис для автозапуска по подключению диска**:
`/etc/systemd/system/axelbux-backup-on-plug.service`
5) **Правило udev‑триггера по событию «диск подключён»**:
`/etc/udev/rules.d/99-axelbux-backup.rules`

### 2.3. Настройки в `run-backup.sh`

Все основные параметры меняются вверху скрипта:

```bash
SRC="/home/axelbux/Документы"          # откуда копируем
MOUNT_POINT="/run/media/axelbux/AxelBux_4TB"  # где смонтирован диск
DST="$MOUNT_POINT/BackUP"              # куда копируем
TRASH="$DST/Trash_version"             # куда складывать старые версии
LOG="$DST/backup.log"                  # основной лог
META="$DST/backup.meta"                # счётчик успешных запусков
STATUS="$DST/backup.status"            # статус последнего запуска
DISK_NAME="AxelBux_4TB"                # имя диска для логов/уведомлений
```

Что можно менять:

- **Поменять пользователя**
    - Заменить `/home/axelbux` на `/home/НОВЫЙ_ЮЗЕР`.
    - Выполнять установку и все `systemctl --user` уже под этим пользователем.
    - Везде в этом документе мысленно подставить нового пользователя.
- **Поменять диск и точку монтирования**

Например, диск монтируется как `/run/media/ivan/MyBackupDisk`:

```bash
MOUNT_POINT="/run/media/ivan/MyBackupDisk"
DISK_NAME="MyBackupDisk"
```

В udev‑правиле нужно также заменить `ID_FS_LABEL` на новую метку диска.
- **Расширить / сузить объём данных**

1) Изменить `SRC`, например:
`SRC="/home/axelbux"` — будет копироваться весь домашний каталог.
2) Добавить `--exclude` в команду rsync (ниже в коде) для игнорирования отдельных каталогов, например:
```bash
rsync -r -t -v --delete -u --modify-window=1 -s \
  --backup --backup-dir="$TRASH" \
  --exclude=".cache" \
  --exclude="Загрузки" \
  "$SRC" "$DST" >"$RSYNC_OUTPUT_FILE" 2>&1
```

- **Изменить частоту бэкапа по таймеру**

В `~/.config/systemd/user/axelbux-backup.timer`:

```ini
[Timer]
OnBootSec=10min
OnUnitActiveSec=60min   # интервал между запусками
Unit=axelbux-backup.service
```

Можно поставить, например, `OnUnitActiveSec=30min` или `2h`.


### 2.4. Важная логика устойчивости

В `run-backup.sh` заложено:

- Проверка:

```bash
if [ ! -d "$MOUNT_POINT" ] || [ ! -w "$MOUNT_POINT" ]; then
  exit 0
fi
```

Если точка монтирования ещё не существует или недоступна для записи (udev сработал раньше автомонта) — скрипт тихо выходит с кодом 0.
- Дополнительная проверка `mountpoint -q "$MOUNT_POINT"` — если диск не смонтирован, запуск помечается как «ПРОПУЩЕНО (диск не смонтирован)», пишется в лог и `backup.status`, уведомлений нет.
- Учёт количества подряд успешных запусков через `META`. После 4 подряд успехов лог ротируется: старые сессии удаляются, остаётся только текущая.
- Обработка кодов rsync:
    - `0` — успех;
    - `20` — прервано (например, Ctrl+C или отключение диска);
    - `23` — частичная передача (что‑то не скопировалось);
    - остальные — общая ошибка.
- Уведомления через `notify-send`:
    - при старте: `"BackUp - ${DISK_NAME}" / "Резервное копирование начато"`;
    - при завершении — разные тексты в зависимости от результата.

***

## 3. Полная установка с нуля (включая триггер по подключению диска)

### Шаг 0. Предпосылки и зависимости

1) **Система**: ALT Linux (или любая система с systemd, user‑сервисами и udev).
2) **Root‑доступ** через `su`.
3) **Уведомления**: нужен `notify-send` (в ALT можно через `apt-get`):
```bash
su
apt-get update
apt-get install notify-send
exit
```

Проверка:

```bash
notify-send "Тест" "Если видишь это — уведомления работают"
```


### Шаг 1. Проверяем диск и создаём каталог для скриптов

1) Подключить внешний диск и убедиться, что он смонтирован:
```bash
ls /run/media/$USER
```

Ожидаем увидеть `AxelBux_4TB` (или своё имя диска).

2) Убедиться в метке диска и UUID (полезно для udev):
```bash
lsblk -o NAME,LABEL,UUID
```

У меня, например:

```text
sda1      AxelBux_4TB C80EE9B90EE9A124
```

3) Создать папку для пользовательских скриптов:
```bash
mkdir -p ~/.local/bin
```


### Шаг 2. Пишем основной скрипт `run-backup.sh`

Открыть файл:

```bash
nano ~/.local/bin/run-backup.sh
```

Вставить **полный текст актуального скрипта**:

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

# Если точка монтирования ещё не существует или недоступна для записи,
# выходим без ошибки (udev может сработать раньше, чем диск смонтируется)
if [ ! -d "$MOUNT_POINT" ]; then
  exit 0
fi

if [ ! -w "$MOUNT_POINT" ]; then
  exit 0
fi

# --------------------------------------------------
# Вспомогательные функции
# --------------------------------------------------

# Чтение счётчика успешных подряд бэкапов
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

# Запись счётчика успешных подряд бэкапов
write_success_counter() {
  echo "$SUCCESS_COUNT" > "$META"
}

# Запуск новой сессии логирования
start_new_session() {
  # если лог существует и не пустой – добавить 3 пустых строки
  if [ -f "$LOG" ] && [ -s "$LOG" ]; then
    printf "\n\n\n" >> "$LOG"
  fi
  LINE_NO=0
  SESSION_ERRORS=()
}

# Логирование строки с авто‑нумерацией
log_line() {
  LINE_NO=$((LINE_NO + 1))
  local now msg
  now=$(date +"%Y-%m-%d %H:%M:%S")
  msg="$1"
  printf "[%04d] [%s] %s\n" "$LINE_NO" "$now" "$msg" >> "$LOG"
}

# Регистрация ошибки (для итогового блока)
register_error() {
  local line_no="$1"
  local text="$2"
  SESSION_ERRORS+=("строка ${line_no}: ${text}")
}

# Отправка уведомления (попытка в пользовательскую сессию axelbux)
send_notify() {
  local title="$1"
  local body="$2"
  notify-send "$title" "$body"
}

# --------------------------------------------------
# Основная логика
# --------------------------------------------------

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
RESULT="УСПЕШНО"
RSYNC_EXIT=0

mkdir -p "$DST" "$TRASH"

# Подготовка логирования и счётчика
start_new_session
read_success_counter

log_line "START: Начато резервное копирование на ${DISK_NAME}"
send_notify "BackUp - ${DISK_NAME}" "Резервное копирование начато"

# Проверка точки монтирования
if ! mountpoint -q "$MOUNT_POINT"; then
  log_line "INFO: Диск ${DISK_NAME} не смонтирован. Бэкап пропущен (это не ошибка)."
  END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  log_line "SUMMARY: Дата/время начала: ${START_TIME}"
  log_line "SUMMARY: Дата/время завершения: ${END_TIME}"
  log_line "SUMMARY: Результат: ПРОПУЩЕНО (диск не смонтирован)"
  log_line "SUMMARY: Ошибок: 0"
  echo "${END_TIME}|ПРОПУЩЕНО|Диск не смонтирован (съёмный, это норм)" > "$STATUS"
  # Никаких уведомлений и код завершения 0
  exit 0
fi

log_line "INFO: Точка монтирования ${MOUNT_POINT} доступна"
log_line "INFO: Каталог назначения: ${DST}"
log_line "INFO: Каталог Trash_version: ${TRASH}"
log_line "INFO: Запуск rsync"

# Запуск rsync и захват вывода
RSYNC_OUTPUT_FILE="$(mktemp)"
rsync -r -t -v --delete -u --modify-window=1 -s \
  --backup --backup-dir="$TRASH" \
  "$SRC" "$DST" >"$RSYNC_OUTPUT_FILE" 2>&1
RSYNC_EXIT=$?

# Разбор вывода rsync построчно и логирование
while IFS= read -r line; do
  log_line "RSYNC: ${line}"
done < "$RSYNC_OUTPUT_FILE"

rm -f "$RSYNC_OUTPUT_FILE"

END_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# Определение результата по коду rsync
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

# Записываем статус для пользовательского сервиса
# Формат: ВРЕМЯ_ЗАВЕРШЕНИЯ|РЕЗУЛЬТАТ|ТЕКСТ
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

# Обновление счётчика успешных сессий и ротация лога
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

# Итоговый блок
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

# Уведомления по результату
case "$RESULT" in
  "УСПЕШНО")
    send_notify "BackUp - ${DISK_NAME}" "Резервное копирование завершено!"
    ;;
  "С ОШИБКАМИ")
    send_notify "BackUp - ${DISK_NAME}" "Резервное копирование завершено с ОШИБКАМИ"
    ;;
  "ПРЕРВАНО")
    send_notify "BackUp - ${DISK_NAME}" "Резервное копирование прервано"
    ;;
esac

exit "$RSYNC_EXIT"
```

Сохранить (`Ctrl+O`, Enter, `Ctrl+X`) и сделать исполняемым:

```bash
chmod +x ~/.local/bin/run-backup.sh
```


### Шаг 3. User‑service и timer (автозапуск каждый N минут)

Создать каталог для user‑юнитов:

```bash
mkdir -p ~/.config/systemd/user
```


#### 3.1. User‑service `axelbux-backup.service`

```bash
nano ~/.config/systemd/user/axelbux-backup.service
```

Содержимое:

```ini
[Unit]
Description=AxelBux backup to 4TB disk (user)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/run-backup.sh
```


#### 3.2. Таймер `axelbux-backup.timer`

```bash
nano ~/.config/systemd/user/axelbux-backup.timer
```

Содержимое:

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

Активировать:

```bash
systemctl --user daemon-reload
systemctl --user enable --now axelbux-backup.timer
```

Проверка:

```bash
systemctl --user list-timers | grep axelbux-backup
```


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

Добавить alias:

```bash
echo "alias bckp='/usr/local/bin/bckp'" >> ~/.bashrc
source ~/.bashrc
```


### Шаг 5. Root‑сервис для автозапуска по подключению диска (с задержкой и уведомлениями)

1) Узнать свои `DISPLAY` и `DBUS_SESSION_BUS_ADDRESS` в графической сессии:
```bash
echo "$DISPLAY"
echo "$DBUS_SESSION_BUS_ADDRESS"
```

Пример:

```text
:0
unix:path=/run/user/1000/bus
```

2) Создать/обновить сервис:
```bash
su
nano /etc/systemd/system/axelbux-backup-on-plug.service
```

Содержимое (подставь свои `DISPLAY` и `DBUS_SESSION_BUS_ADDRESS`, если отличаются):

```ini
[Unit]
Description=AxelBux backup to 4TB disk on plug
After=dev-sda1.device

[Service]
Type=oneshot
User=axelbux
Group=axelbux
Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
ExecStartPre=/bin/sleep 30
ExecStart=/home/axelbux/.local/bin/run-backup.sh
```

- `ExecStartPre=/bin/sleep 30` — задержка 30 секунд после появления устройства, чтобы диск успел смонтироваться.
- Можно менять на `sleep 60`, если нужно больше времени.

Применить:

```bash
systemctl daemon-reload
exit
```

Проверка вручную:

```bash
su
systemctl start axelbux-backup-on-plug.service
exit

bckp last-log
```

Должен появиться свежий запуск, а также два уведомления: «начато» и «завершено».

### Шаг 6. Udev‑правило: триггер по подключению диска

Создать правило:

```bash
su
nano /etc/udev/rules.d/99-axelbux-backup.rules
```

Содержимое (по метке):

```udev
ACTION=="add", KERNEL=="sd?1", ENV{ID_FS_LABEL}=="AxelBux_4TB", TAG+="systemd", ENV{SYSTEMD_WANTS}="axelbux-backup-on-plug.service"
```

Если удобнее по UUID, можно вместо `ID_FS_LABEL`:

```udev
ACTION=="add", KERNEL=="sd?1", ENV{ID_FS_UUID}=="C80EE9B90EE9A124", TAG+="systemd", ENV{SYSTEMD_WANTS}="axelbux-backup-on-plug.service"
```

Сохранить и обновить:

```bash
udevadm control --reload
exit
```

Проверка:

1) Отключить диск.
2) Подключить диск.
3) Подождать чуть больше 30 секунд.
4) Убедиться:
```bash
bckp last-log
```

Время `START` должно быть примерно «время подключения + 30 секунд», а на рабочем столе должны появиться уведомления «BackUp - AxelBux_4TB / Резервное копирование начато» и затем «... завершено!».

***

## 4. Как полностью восстановить схему после переустановки системы

1. Установить систему и пользователя (например, `axelbux`).
2. Поставить `notify-send` и проверить уведомления.
3. Подключить диск с существующим `BackUP` и логами, убедиться, что он монтируется как `/run/media/axelbux/AxelBux_4TB`.
4. Выполнить шаги:
    - Шаг 1 (проверка диска, создание `~/.local/bin`).
    - Шаг 2 (создать `run-backup.sh`, сделать исполняемым).
    - Шаг 3 (user‑service и timer).
    - Шаг 4 (`bckp`).
    - Шаг 5 (root‑сервис с задержкой и окружением для уведомлений).
    - Шаг 6 (udev‑правило).

После этого схема будет вести себя так же, как сейчас: бэкап запускается:

- по таймеру (каждый час, пока диск подключён);
- при подключении диска (через 30 секунд задержки), с уведомлениями о начале и завершении.
