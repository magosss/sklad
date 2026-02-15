# Склад + сайт заказов (ALABAR)

**Репозиторий:** [github.com/magosss/sklad](https://github.com/magosss/sklad)

Учёт остатков по складам (цехам), мобильное приложение для сотрудников и публичный сайт заказов с подгрузкой наличия из API.

## Состав проекта

| Часть | Описание |
|-------|----------|
| **backend/** | Django REST API: товары, размеры, остатки, поставки/отгрузки, JWT-авторизация, мультитенантность по цехам |


## Быстрый старт (локально)

```bash
cd backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env       # при необходимости отредактировать
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

Сайт: откройте `site/index.html` в браузере (по умолчанию API — `http://127.0.0.1:8000`).

## Деплой на домен

### Backend (API)

1. Задайте переменные окружения (см. `backend/.env.example`):
   - **DJANGO_SECRET_KEY** — длинный случайный ключ
   - **DJANGO_DEBUG** — `False`
   - **DJANGO_ALLOWED_HOSTS** — `kchrmarket.ru,www.kchrmarket.ru,api.kchrmarket.ru`
   - **CORS_ALLOWED_ORIGINS** — `https://kchrmarket.ru,https://www.kchrmarket.ru`
2. База: PostgreSQL (рекомендуется) или SQLite через `USE_SQLITE=true`.
3. Настройте раздачу медиафайлов (каталог `media/`).

### Сайт заказов (`site/`)

- Если сайт и API на **одном домене** (один сервер, один домен) — ничего менять не нужно: запросы идут на тот же хост.
- Если API на поддомене **api.kchrmarket.ru**, в `site/index.html` в `<head>` раскомментируйте:
  ```html
  <script>window.ALABAR_API_BASE='https://api.kchrmarket.ru';</script>
  ```
- Разместите папку `site/` на любом хостинге (Vercel, Netlify, nginx и т.д.).

### iOS-приложение

В коде задаётся URL API (например в `APIService.swift`). Для продакшена замените на ваш домен API или настройте чтение из `Info.plist` / xcconfig.

## Описание API (OpenAPI 3.1)

- **GET /api/schema/** — схема в формате OpenAPI 3.1 (JSON).
- **GET /api/schema/swagger/** — Swagger UI.
- **GET /api/schema/redoc/** — ReDoc.

Экспорт в файл (в каталоге `backend/`):
```bash
python manage.py spectacular --file openapi.yaml --format yaml
```

## Публичный API для сайта

- **GET /api/public/items/** — список товаров с остатками по размерам (без авторизации).
- Опционально: **?workshop_id=uuid** — только товары указанного цеха.

Остальные эндпоинты API требуют JWT (логин через `POST /api/auth/login/`).

## Репозиторий

Проект на GitHub: **https://github.com/magosss/sklad**

Клонирование:
```bash
git clone https://github.com/magosss/sklad.git
cd sklad
```

В репозитории не попадают (см. `.gitignore`): `venv/`, `db.sqlite3`, `media/`, `.env`, личные настройки Xcode.

## Документация

- [MULTIVENDOR.md](MULTIVENDOR.md) — мультитенантность (цеха, привязка пользователей).

## Лицензия

По желанию укажите лицензию в репозитории (MIT, Apache 2.0 и т.д.).
