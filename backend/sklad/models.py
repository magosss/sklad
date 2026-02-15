import uuid
from django.db import models
from django.contrib.auth.models import User


class Workshop(models.Model):
    """Цех / Склад — верхнеуровневая сущность."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class WorkshopAssignment(models.Model):
    """Привязка пользователя к складу (расширение User из django.contrib.auth)."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='workshop_assignment')
    workshop = models.ForeignKey(
        Workshop, on_delete=models.SET_NULL, null=True, blank=True, related_name='assignments'
    )


class Item(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workshop = models.ForeignKey(Workshop, on_delete=models.CASCADE, related_name='items', null=True, blank=True)
    name = models.CharField(max_length=255)
    photo = models.ImageField(upload_to='items/', null=True, blank=True)
    item_description = models.TextField(null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, verbose_name='Цена')
    wb_url = models.URLField(max_length=500, blank=True, verbose_name='Ссылка на ВБ')
    ozon_url = models.URLField(max_length=500, blank=True, verbose_name='Ссылка на Озон')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']


class SizeQuantity(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    item = models.ForeignKey(Item, on_delete=models.CASCADE, related_name='sizes')
    size_label = models.CharField(max_length=50)
    quantity = models.IntegerField(default=0)
    barcode = models.CharField(max_length=100, null=True, blank=True)

    class Meta:
        unique_together = ['item', 'size_label']


class Supply(models.Model):
    TYPE_IN = 'in'
    TYPE_OUT = 'out'
    TYPE_CHOICES = [(TYPE_IN, 'Поставка'), (TYPE_OUT, 'Отгрузка')]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workshop = models.ForeignKey(Workshop, on_delete=models.CASCADE, related_name='supplies', null=True, blank=True)
    number = models.IntegerField()
    date = models.DateTimeField(auto_now_add=True)
    type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    created_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_supplies'
    )

    class Meta:
        ordering = ['-date']


class SupplyLineItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    supply = models.ForeignKey(Supply, on_delete=models.CASCADE, related_name='line_items')
    item = models.ForeignKey(Item, on_delete=models.CASCADE)
    size_label = models.CharField(max_length=50)
    quantity = models.IntegerField()


class Order(models.Model):
    """Заказ: источник, адрес доставки, телефон, состав и итоговая сумма."""
    STATUS_NEW = 'new'
    STATUS_SHIPPED = 'shipped'
    STATUS_IN_TRANSIT = 'in_transit'
    STATUS_READY = 'ready'
    STATUS_DELIVERED = 'delivered'
    STATUS_CANCELLED = 'cancelled'
    STATUS_CHOICES = [
        (STATUS_NEW, 'Новый'),
        (STATUS_SHIPPED, 'Отгружено'),
        (STATUS_IN_TRANSIT, 'В пути'),
        (STATUS_READY, 'Готово к получению'),
        (STATUS_DELIVERED, 'Доставлено'),
        (STATUS_CANCELLED, 'Отменено'),
    ]

    workshop = models.ForeignKey(
        Workshop, on_delete=models.CASCADE, related_name='orders', null=True, blank=True
    )
    source = models.CharField(max_length=500, blank=True, verbose_name='Источник заказа')
    delivery_address = models.TextField(blank=True, verbose_name='Адрес доставки')
    client_phone = models.CharField(max_length=50, blank=True, verbose_name='Телефон клиента')
    total = models.DecimalField(
        max_digits=12, decimal_places=2, default=0, verbose_name='Итоговая сумма'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_NEW,
        verbose_name='Статус',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class OrderLineItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='line_items')
    item = models.ForeignKey(Item, on_delete=models.CASCADE)
    size_label = models.CharField(max_length=50)
    quantity = models.IntegerField()
