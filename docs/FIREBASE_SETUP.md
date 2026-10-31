# Настройка Firebase и уведомлений о заменах

Полная инструкция: установка, развёртывание и проверка.

---

## Что уже есть в коде

- **Приложение (Flutter):** Firebase, FCM, запрос разрешений, сохранение пары «токен + группа» в Firestore при старте и при смене группы, показ уведомлений в foreground.
- **Проверка замен:** выполняется на **VPS** в Docker-контейнере (`mpt-replacement-service`). Раз в час парсится страница замен MPT; при появлении новых замен отправляются FCM на устройства с выбранной группой.

---

## Требования

| Где | Что нужно |
|-----|-----------|
| Локально | Flutter SDK, Node.js (для Firebase CLI), Git |
| Firebase | Аккаунт Google, проект Firebase (Spark достаточно) |
| VPS | Docker и Docker Compose |

---

## Часть 1. Подготовка проекта и Firebase

### 1.1 Клонирование и зависимости

```bash
git clone <url-репозитория> MyMPT
cd MyMPT
flutter pub get
```

### 1.2 Проект Firebase

1. Откройте [Firebase Console](https://console.firebase.google.com/).
2. Создайте проект **MyMPT** (или выберите существующий).
3. Запомните **Project ID** (например `mympt-fc53d`).

### 1.3 Подключение приложения к Firebase

Если ещё не делали:

1. Установите [Firebase CLI](https://firebase.google.com/docs/cli#install_the_firebase_cli) и войдите:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. В корне проекта:
   ```bash
   dart pub global activate flutterfire_cli
   dart pub global run flutterfire_cli:flutterfire configure
   ```
   Выберите проект MyMPT и платформы (Android, iOS).
3. В проекте появятся:
   - `android/app/google-services.json`
   - `lib/firebase_options.dart`

### 1.4 Firestore

1. В [Firebase Console](https://console.firebase.google.com/) → проект **MyMPT**.
2. **Build** → **Firestore Database** → **Create database**.
3. Режим: тест или продакшен. Регион — на ваш выбор (например `europe-west1`).

### 1.5 Развёртывание правил Firestore

В корне проекта:

```bash
firebase use mympt-fc53d
firebase deploy --only firestore:rules
```

Правила из `firestore.rules` разрешают приложению запись в коллекцию `fcm_tokens`.

---

## Часть 2. Сборка и проверка приложения

### 2.1 Сборка

```bash
flutter pub get
flutter run
```

Или релизный APK:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

Файл: `build/app/outputs/flutter-apk/app-release.apk` (или `app-<abi>-release.apk`).

### 2.2 Проверка на устройстве

1. Установите приложение, запустите.
2. Разрешите уведомления при запросе.
3. Выберите специальность и группу (экран приветствия или Настройки).
4. В [Firestore](https://console.firebase.google.com/project/mympt-fc53d/firestore) откройте коллекцию **fcm_tokens**.
5. Должен появиться документ с полями: `token`, `groupCode`, `updatedAt`.

Если документ есть — приложение регистрирует устройство, сервис на VPS сможет отправлять на него FCM.

---

## Часть 3. Сервис проверки замен на VPS

### 3.1 Ключ сервисного аккаунта Firebase

1. [Firebase Console](https://console.firebase.google.com/) → проект **MyMPT**.
2. ⚙️ **Project settings** → вкладка **Service accounts**.
3. Кнопка **Generate new private key** → подтвердите → скачается JSON.
4. Переименуйте файл в **`firebase-service-account.json`**.
5. Положите его в папку **`mpt-replacement-service/`** на VPS (рядом с `docker-compose.yml`).

**Важно:** этот файл содержит секретный ключ. Он уже добавлен в `.gitignore` — не коммитьте его в репозиторий.

### 3.2 Развёртывание на VPS

На сервере (в каталоге с проектом):

```bash
cd mpt-replacement-service
docker compose up -d --build
```

Проверка логов:

```bash
docker compose logs -f mpt-replacement
```

Ожидаемые сообщения: при старте выполняется первая проверка, затем раз в час (в 0 минут по Москве) — `[runCheck] Done.` или сообщения об ошибках (если есть).

Остановка:

```bash
docker compose down
```

Подробнее: **[mpt-replacement-service/README.md](../mpt-replacement-service/README.md)**.

---

## Часть 4. Проверка работы целиком

### 4.1 Чек-лист

| Шаг | Проверка |
|-----|----------|
| 1 | В Firestore есть коллекция `fcm_tokens`, в ней документ с вашей группой после выбора группы в приложении. |
| 2 | На VPS контейнер запущен: `docker compose ps` в `mpt-replacement-service/`. |
| 3 | В логах нет постоянных ошибок: `docker compose logs -f mpt-replacement`. |
| 4 | На [странице замен MPT](https://mpt.ru/izmeneniya-v-raspisanii/) есть замены на сегодня/завтра для вашей группы — в течение часа после появления новых замен должно прийти FCM-уведомление (если сервис уже сохранил предыдущее состояние). |

### 4.2 Ручной запуск одной проверки (на VPS)

Чтобы не ждать час:

```bash
cd mpt-replacement-service
docker compose run --rm -e RUN_ONCE=1 mpt-replacement
```

Если на сайте уже есть замены по вашей группе и раньше их не было (или volume новый), уведомление может прийти после этой проверки.

### 4.3 Если уведомления не приходят

- Убедитесь, что в приложении разрешены уведомления и выбрана группа.
- Проверьте, что в Firestore в `fcm_tokens` есть документ с вашим `groupCode`.
- Посмотрите логи сервиса: ошибки загрузки страницы, парсинга или отправки FCM будут в логах.
- Для устаревших FCM-токенов сервис удаляет документ из Firestore; переустановите приложение или заново выберите группу, чтобы записался новый токен.

---

## Структура данных Firestore

| Коллекция | Кто пишет | Назначение |
|-----------|-----------|------------|
| **fcm_tokens** | Приложение | Документ на устройство: id = токен (слэши заменены на `_`), поля `token`, `groupCode`, `updatedAt`. Сервис на VPS читает и по ним шлёт FCM. |
| last_replacements | — | При схеме с VPS не используется; состояние хранится в файле в контейнере. |

---

## Устранение неполадок

### Ошибка «Failed to get FIS auth token» / «Firebase Installations Service is unavailable»

Ошибка появляется в логах, когда FCM не может получить токен у сервера Firebase (Firebase Installations Service).

**Частые причины:**

1. **Эмулятор без Google Play** — на AVD без образа с «Google APIs» или «Google Play» сервис FIS часто недоступен.
2. **Нет интернета** — устройство/эмулятор не может достучаться до серверов Firebase.
3. **Ограничения сети** — VPN, корпоративный файрвол или блокировки могут резать доступ к `firebaseinstallations.googleapis.com`.

**Что делать:**

- **Для проверки FCM** — запускайте приложение на **реальном устройстве** с интернетом и (для Android) с установленными Google Play Services.
- **Эмулятор** — создайте AVD с образом, где есть **Google Play** (например «Pixel 6» с «Google Play»), а не «Google APIs» без Play. Убедитесь, что у эмулятора есть доступ в интернет.
- Приложение при этом **не падает**: если токен получить не удалось, запись в Firestore просто не выполнится; после появления сети или на реальном устройстве FCM заработает как обычно.

Сообщения в логах от `E/FirebaseMessaging` при старте в таких условиях можно игнорировать при разработке.

---

## Секреты и .gitignore

В репозитории **не должны** попадать:

- **`mpt-replacement-service/firebase-service-account.json`** — ключ сервисного аккаунта Firebase (уже в `.gitignore`).
- **`mpt-replacement-service/data/`** — данные сервиса на диске (уже в `.gitignore`).

Файлы **можно** коммитить:

- **`android/app/google-services.json`** — конфиг проекта для Android (без приватных ключей).
- **`lib/firebase_options.dart`** — сгенерированные опции Firebase для приложения.

Перед первым коммитом проверьте: `git status` не должен показывать `firebase-service-account.json`.
