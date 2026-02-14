from rest_framework import serializers
from .models import Item, SizeQuantity, Supply, SupplyLineItem, Workshop


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


class ItemListSerializer(serializers.ModelSerializer):
    sizes = SizeQuantitySerializer(many=True, read_only=True)
    photo = serializers.SerializerMethodField()

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'created_at', 'updated_at', 'sizes']

    def get_photo(self, obj):
        if not obj.photo:
            return None
        request = self.context.get('request')
        if request:
            url = obj.photo.url
            path = url if url.startswith('/') else f'/{url}'
            return request.build_absolute_uri(path)
        return obj.photo.url


class ItemDetailSerializer(serializers.ModelSerializer):
    sizes = SizeQuantitySerializer(many=True, read_only=True)
    photo = serializers.SerializerMethodField()

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'created_at', 'updated_at', 'sizes']

    def get_photo(self, obj):
        if not obj.photo:
            return None
        request = self.context.get('request')
        if request:
            url = obj.photo.url
            path = url if url.startswith('/') else f'/{url}'
            return request.build_absolute_uri(path)
        return obj.photo.url


class ItemCreateUpdateSerializer(serializers.ModelSerializer):
    photo = serializers.ImageField(required=False, allow_null=True, help_text='Фото товара')

    class Meta:
        model = Item
        fields = ['id', 'name', 'photo', 'item_description', 'price', 'created_at', 'updated_at']
        extra_kwargs = {
            'name': {'help_text': 'Название товара'},
            'item_description': {'help_text': 'Описание (необязательно)', 'required': False},
            'price': {'help_text': 'Цена (необязательно)', 'required': False},
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
