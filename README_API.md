# Миграция на Django REST API + PostgreSQL

## Backend

```bash
cd backend
docker-compose up -d
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

API: http://127.0.0.1:8000/api/

## iOS

- Базовый URL API: `http://127.0.0.1:8000/api` (в `APIService.swift`)
- Для симулятора: `127.0.0.1` подойдёт
- Для устройства: укажите IP компьютера в сети (например `http://192.168.1.100:8000/api`)
- URL можно поменять в `UserDefaults` ключ `api_base_url`

## Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /api/items/ | Список товаров |
| POST | /api/items/ | Создать товар |
| GET | /api/items/{id}/ | Товар с размерами |
| PATCH | /api/items/{id}/ | Обновить товар |
| DELETE | /api/items/{id}/ | Удалить товар |
| GET/POST | /api/items/{id}/sizes/ | Размеры товара |
| PATCH/DELETE | /api/items/{id}/sizes/{id}/ | Размер |
| GET | /api/sizes/by_barcode/?barcode=xxx | Поиск по штрихкоду |
| GET/POST | /api/supplies/ | Поставки |
| GET | /api/supplies/?item_id=xxx | Поставки по товару |

## Удаление старого Core Data (опционально)

После проверки работы API можно удалить:
- CoreDataManager.swift
- SkladModel.swift
- *+CoreData.swift (Item, SizeQuantity, Supply, SupplyLineItem, InventoryChange)
- HistoryView.swift, RecordMovementView.swift, ItemsListView.swift, ContentView.swift (если не используются)
