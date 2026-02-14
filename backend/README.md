# Sklad API (Django + PostgreSQL)

## Запуск

```bash
# PostgreSQL (Docker)
docker-compose up -d

# Виртуальное окружение
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Зависимости
pip install -r requirements.txt

# Миграции
python manage.py migrate

# Запуск сервера
python manage.py runserver
```

API: http://127.0.0.1:8000/api/

## Endpoints

- `GET/POST /api/items/` — список и создание товаров
- `GET/PATCH/DELETE /api/items/{id}/` — товар
- `GET/POST /api/items/{id}/sizes/` — размеры товара
- `GET/PATCH/DELETE /api/items/{id}/sizes/{id}/` — размер
- `GET/POST /api/supplies/` — поставки
- `GET /api/supplies/?item_id={uuid}` — поставки по товару
- `GET /api/supplies/{id}/` — детали поставки

## Переменные окружения

- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`
- `DJANGO_SECRET_KEY`, `DJANGO_DEBUG`
