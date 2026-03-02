# Сервис проверки замен МПТ (VPS / Docker)

Раз в час парсит страницу замен МПТ, сравнивает с последним состоянием и отправляет FCM-уведомления на устройства, у которых в приложении выбрана соответствующая группа.

## Требования

- Docker и Docker Compose на VPS
- Ключ сервисного аккаунта Firebase (JSON)

## Получение ключа Firebase

1. [Firebase Console](https://console.firebase.google.com/) → проект **MyMPT**.
2. ⚙️ **Project settings** → вкладка **Service accounts**.
3. **Generate new private key** → скачается JSON-файл.
4. Сохраните его как `firebase-service-account.json` в папку `mpt-replacement-service/` на VPS (или в любое место и укажите путь в `docker-compose.yml` в volume).

**Важно:** не коммитьте этот файл в git. Добавьте в `.gitignore`:  
`mpt-replacement-service/firebase-service-account.json`

## Запуск через Docker Compose

В папке `mpt-replacement-service/`:

```bash
# Ключ уже лежит здесь как firebase-service-account.json
docker compose up -d --build
```

Сервис будет проверять замены **каждый час** (по времени контейнера, у нас `TZ=Europe/Moscow`).

Логи:

```bash
docker compose logs -f mpt-replacement
```

Остановка:

```bash
docker compose down
```

## Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `STATE_FILE` | Файл для хранения последнего состояния замен | `/data/last_replacements.json` |
| `DATA_DIR` | Каталог для данных (volume) | `/data` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Путь к JSON ключа Firebase в контейнере | `/app/firebase-service-account.json` |
| `CRON_SCHEDULE` | Расписание cron (каждый час) | `0 * * * *` |
| `RUN_ONCE` | Если `1` — одна проверка и выход (для ручного/cron хоста) | не задано |
| `TZ` | Часовой пояс | `Europe/Moscow` в docker-compose |
| `LOG_LEVEL` | Уровень логов: `debug`, `info`, `warn`, `error` | `info` |
| `LOG_DIR` | Папка для лог-файла | `{DATA_DIR}/logs` |
| `LOG_FILE` | Полный путь к файлу логов (если задан — пишем в файл) | `{LOG_DIR}/service.log` |

## Запуск одной проверки (без cron внутри контейнера)

Удобно, если cron настраиваете на самом хосте:

```bash
docker compose run --rm -e RUN_ONCE=1 mpt-replacement
```

Или в `docker-compose.yml` задать `command` и `RUN_ONCE=1`, а на VPS добавить в crontab:

```cron
0 * * * * cd /path/to/MyMPT/mpt-replacement-service && docker compose run --rm -e RUN_ONCE=1 mpt-replacement
```

## Только Docker (без Compose)

```bash
docker build -t mpt-replacement .
docker run -d --restart unless-stopped \
  -v /path/to/your/data:/data \
  -v /path/to/firebase-service-account.json:/app/firebase-service-account.json:ro \
  -e TZ=Europe/Moscow \
  mpt-replacement
```

## Логирование

- Логи пишутся в stdout (видны в `docker compose logs`) и дополнительно в файл `data/logs/service.log` (или `LOG_DIR`/`LOG_FILE`).
- Уровень: `LOG_LEVEL=debug` для подробного вывода (парсинг, загрузка состояния, группы без изменений).

## Данные

- Состояние замен хранится в volume `replacement-data` (файл `last_replacements.json`). При пересоздании контейнера без `docker compose down -v` данные сохраняются.
- Токены FCM и группы читаются из Firestore (коллекция `fcm_tokens`), куда пишет приложение.
