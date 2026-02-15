from rest_framework import serializers
from .models import Item, Order, OrderLineItem, SizeQuantity, Supply, SupplyLineItem, Workshop


class WorkshopSerializer(serializers.ModelSerializer):
    class Meta:
        model = Workshop
        fields = ['id', 'name']


class SizeQuantitySerializer(serializers.ModelSerializer):
    class Meta:
        model = SizeQuantity
        fields = ['id', 'size_label', 'quantity', 'barcode']
        extra_kwargs = {
            'size_label': {'help_text': 'Обозначение размера (например S, M, 42)'},
            'quantity': {'help_text': 'Остаток на складе'},
            'barcode': {'help_text': 'Штрихкод размера'},
        }


def _item_photo_url(obj, request):
    if not obj.photo:
        return None
    url = obj.photo.url
    path = url if url.startswith('/') else f'/{url}'
    return request.build_absolute_uri(path) if request else url


class ItemListSerializer(serializers.ModelSerializer):
    sizes = SizeQuantitySerializer(many=True, read_only=True)
    photo = serializers.SerializerMethodField()
    workshop = WorkshopSerializer(read_only=True)

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'wb_url', 'ozon_url', 'workshop', 'created_at', 'updated_at', 'sizes']

    def get_photo(self, obj):
        return _item_photo_url(obj, self.context.get('request'))


class PublicItemListSerializer(serializers.ModelSerializer):
    """Публичный список: без created_at, updated_at, item_description."""
    sizes = SizeQuantitySerializer(many=True, read_only=True)
    photo = serializers.SerializerMethodField()
    workshop = WorkshopSerializer(read_only=True)

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'price', 'wb_url', 'ozon_url', 'workshop', 'sizes']

    def get_photo(self, obj):
        return _item_photo_url(obj, self.context.get('request'))


class ItemDetailSerializer(serializers.ModelSerializer):
    sizes = SizeQuantitySerializer(many=True, read_only=True)
    photo = serializers.SerializerMethodField()
    workshop = WorkshopSerializer(read_only=True)

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'wb_url', 'ozon_url', 'workshop', 'created_at', 'updated_at', 'sizes']

    def get_photo(self, obj):
        return _item_photo_url(obj, self.context.get('request'))


class PublicItemDetailSerializer(serializers.ModelSerializer):
    """Публичная полная информация по товару по id."""
    sizes = SizeQuantitySerializer(many=True, read_only=True)
    photo = serializers.SerializerMethodField()
    workshop = WorkshopSerializer(read_only=True)

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'wb_url', 'ozon_url', 'workshop', 'created_at', 'updated_at', 'sizes']

    def get_photo(self, obj):
        return _item_photo_url(obj, self.context.get('request'))


class ItemCreateUpdateSerializer(serializers.ModelSerializer):
    photo = serializers.ImageField(required=False, allow_null=True, help_text='Фото товара')

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'wb_url', 'ozon_url', 'created_at', 'updated_at']
        extra_kwargs = {
            'name': {'help_text': 'Название товара'},
            'item_description': {'help_text': 'Описание (необязательно)', 'required': False},
            'price': {'help_text': 'Цена (необязательно)', 'required': False},
            'wb_url': {'help_text': 'Ссылка на Wildberries', 'required': False},
            'ozon_url': {'help_text': 'Ссылка на Озон', 'required': False},
        }

    def to_representation(self, instance):
        """Возвращаем полный URL фото в ответе."""
        data = super().to_representation(instance)
        if instance.photo:
            request = self.context.get('request')
            if request:
                url = instance.photo.url
                path = url if url.startswith('/') else f'/{url}'
                data['photo'] = request.build_absolute_uri(path)
            else:
                data['photo'] = instance.photo.url
        return data


class SupplyLineItemSerializer(serializers.ModelSerializer):
    item_id = serializers.UUIDField(source='item.id', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)

    class Meta:
        model = SupplyLineItem
        fields = ['id', 'item_id', 'item_name', 'size_label', 'quantity']


class SupplyLineItemCreateSerializer(serializers.Serializer):
    item_id = serializers.UUIDField(help_text='UUID товара')
    size_label = serializers.CharField(help_text='Обозначение размера (S, M, 42 и т.д.)')
    quantity = serializers.IntegerField(min_value=1, help_text='Количество (≥ 1)')


class SupplyListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Supply
        fields = ['id', 'number', 'date', 'type']


class SupplyDetailSerializer(serializers.ModelSerializer):
    line_items = SupplyLineItemSerializer(many=True, read_only=True)
    created_by_username = serializers.SerializerMethodField()

    class Meta:
        model = Supply
        fields = ['id', 'number', 'date', 'type', 'line_items', 'created_by_username']

    def get_created_by_username(self, obj):
        return obj.created_by.username if obj.created_by else None


class SupplyCreateSerializer(serializers.Serializer):
    type = serializers.ChoiceField(
        choices=['in', 'out'],
        help_text='in — поставка на склад, out — отгрузка'
    )
    lines = SupplyLineItemCreateSerializer(
        many=True,
        help_text='Список позиций: item_id, size_label, quantity'
    )

    def create(self, validated_data):
        from .services import create_supply
        request = self.context.get('request')
        user = request.user if request else None
        try:
            return create_supply(
                supply_type=validated_data['type'],
                lines=[(l['item_id'], l['size_label'], l['quantity']) for l in validated_data['lines']],
                created_by=user,
            )
        except ValueError as e:
            raise serializers.ValidationError({'detail': str(e)})


# --- Orders ---

class OrderLineItemSerializer(serializers.ModelSerializer):
    item_id = serializers.UUIDField(source='item.id', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)

    class Meta:
        model = OrderLineItem
        fields = ['id', 'item_id', 'item_name', 'size_label', 'quantity']


class OrderLineItemCreateSerializer(serializers.Serializer):
    item_id = serializers.UUIDField(help_text='UUID товара')
    size_label = serializers.CharField(help_text='Обозначение размера')
    quantity = serializers.IntegerField(min_value=1, help_text='Количество (≥ 1)')


class OrderListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = ['id', 'source', 'delivery_address', 'client_phone', 'total', 'status', 'created_at']


class OrderDetailSerializer(serializers.ModelSerializer):
    line_items = OrderLineItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'source', 'delivery_address', 'client_phone',
            'total', 'status', 'created_at', 'line_items',
        ]


class OrderStatusSerializer(serializers.Serializer):
    """Тело запроса смены статуса заказа."""
    status = serializers.ChoiceField(
        choices=Order.STATUS_CHOICES,
        help_text='new, shipped, in_transit, ready, delivered, cancelled',
    )


class OrderCreateSerializer(serializers.Serializer):
    source = serializers.CharField(required=False, allow_blank=True, help_text='Источник заказа')
    delivery_address = serializers.CharField(required=False, allow_blank=True, help_text='Адрес доставки')
    client_phone = serializers.CharField(required=False, allow_blank=True, help_text='Телефон клиента')
    lines = OrderLineItemCreateSerializer(many=True, help_text='Позиции: item_id, size_label, quantity')

    def create(self, validated_data):
        from .services import create_order, get_workshop_for_user
        request = self.context.get('request')
        workshop = getattr(request, 'user', None) and get_workshop_for_user(request.user)
        return create_order(
            workshop=workshop,
            source=validated_data.get('source', '') or '',
            delivery_address=validated_data.get('delivery_address', '') or '',
            client_phone=validated_data.get('client_phone', '') or '',
            lines=[
                (l['item_id'], l['size_label'], l['quantity'])
                for l in validated_data['lines']
            ],
        )
