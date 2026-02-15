from decimal import Decimal
from .models import Item, Order, OrderLineItem, SizeQuantity, Supply, SupplyLineItem, Workshop
from django.contrib.auth.models import User


def get_or_create_size(item: Item, size_label: str) -> SizeQuantity:
    size, _ = SizeQuantity.objects.get_or_create(
        item=item,
        size_label=size_label,
        defaults={'quantity': 0}
    )
    return size


def get_workshop_for_user(user):
    """Возвращает склад пользователя из привязки."""
    try:
        return user.workshop_assignment.workshop
    except Exception:
        return None


def create_supply(
    supply_type: str,
    lines: list[tuple],
    created_by: User = None,
) -> Supply:
    """
    lines: [(item_id, size_label, quantity), ...]
    """
    if not lines:
        raise ValueError('No lines')

    workshop = get_workshop_for_user(created_by) if created_by else None

    last = Supply.objects.filter(workshop=workshop).order_by('-number').first() if workshop else Supply.objects.filter(workshop__isnull=True).order_by('-number').first()
    number = (last.number + 1) if last else 1

    supply = Supply.objects.create(
        number=number,
        type=supply_type,
        workshop=workshop,
        created_by=created_by,
    )
    delta = 1 if supply_type == 'in' else -1

    # Товары только из цеха пользователя (защита мультитенантности)
    item_queryset = Item.objects.filter(workshop=workshop) if workshop else Item.objects.filter(workshop__isnull=True)

    for item_id, size_label, quantity in lines:
        try:
            item = item_queryset.get(id=item_id)
        except Item.DoesNotExist:
            raise ValueError(f'Товар с id {item_id} не найден или не принадлежит вашему цеху.')
        size = get_or_create_size(item, size_label)
        if supply_type == 'out' and size.quantity < quantity:
            raise ValueError(
                f'Недостаточно на складе: {item.name}, размер {size_label} — доступно {size.quantity}, запрошено {quantity}.'
            )
        SupplyLineItem.objects.create(
            supply=supply,
            item=item,
            size_label=size_label,
            quantity=quantity
        )
        new_qty = max(0, size.quantity + quantity * delta)
        size.quantity = new_qty
        size.save()
        item.updated_at = supply.date
        item.save(update_fields=['updated_at'])

    return supply


def create_order(
    workshop: Workshop | None,
    source: str,
    delivery_address: str,
    client_phone: str,
    lines: list[tuple],
) -> Order:
    """
    lines: [(item_id, size_label, quantity), ...]
    total считается по ценам товаров (item.price * quantity).
    При создании заказа остатки на складе уменьшаются.
    """
    if not lines:
        raise ValueError('Добавьте хотя бы одну позицию в заказ')

    item_queryset = (
        Item.objects.filter(workshop=workshop)
        if workshop
        else Item.objects.filter(workshop__isnull=True)
    )

    # Проверка наличия и списание
    for item_id, size_label, quantity in lines:
        try:
            item = item_queryset.get(id=item_id)
        except Item.DoesNotExist:
            raise ValueError(f'Товар с id {item_id} не найден или не принадлежит вашему цеху.')
        size = get_or_create_size(item, size_label)
        if size.quantity < quantity:
            raise ValueError(
                f'Недостаточно на складе: {item.name}, размер {size_label} — доступно {size.quantity}, запрошено {quantity}.'
            )

    order = Order.objects.create(
        workshop=workshop,
        source=source or '',
        delivery_address=delivery_address or '',
        client_phone=client_phone or '',
        total=Decimal('0'),
    )
    total = Decimal('0')

    for item_id, size_label, quantity in lines:
        item = item_queryset.get(id=item_id)
        OrderLineItem.objects.create(
            order=order,
            item=item,
            size_label=size_label,
            quantity=quantity,
        )
        price = item.price or Decimal('0')
        total += price * quantity
        # Списываем со склада
        size = get_or_create_size(item, size_label)
        size.quantity -= quantity
        size.save()

    order.total = total
    order.save(update_fields=['total'])
    return order


def restore_order_stock(order: Order) -> None:
    """Вернуть остатки на склад при отмене заказа."""
    for line in order.line_items.select_related('item').all():
        size = get_or_create_size(line.item, line.size_label)
        size.quantity += line.quantity
        size.save()
