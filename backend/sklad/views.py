from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from .models import Item, Order, SizeQuantity, Supply
from .serializers import (
    ItemListSerializer,
    ItemDetailSerializer,
    ItemCreateUpdateSerializer,
    PublicItemListSerializer,
    PublicItemDetailSerializer,
    SizeQuantitySerializer,
    SupplyDetailSerializer,
    SupplyCreateSerializer,
    OrderListSerializer,
    OrderDetailSerializer,
    OrderCreateSerializer,
    OrderStatusSerializer,
)
from .services import get_or_create_size, get_workshop_for_user, restore_order_stock
from .mixins import WorkshopFilterMixin


@extend_schema(
    summary='Публичный список товаров',
    description='Без авторизации. Поля: id, name, photo, price, wb_url, ozon_url, workshop, sizes (без created_at, updated_at, item_description). Query: workshop_id — фильтр по цеху.',
    tags=['Публичное API'],
)
class PublicItemListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        workshop_id = request.query_params.get('workshop_id')
        if workshop_id:
            qs = Item.objects.filter(workshop_id=workshop_id)
        else:
            qs = Item.objects.all()
        qs = qs.select_related('workshop').prefetch_related('sizes').order_by('created_at')
        serializer = PublicItemListSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data)


@extend_schema(
    summary='Публичные полные данные товара по id',
    description='Без авторизации. Вся информация по товару: name, photo, item_description, price, wb_url, ozon_url, workshop, created_at, updated_at, sizes.',
    tags=['Публичное API'],
)
class PublicItemDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk):
        try:
            item = Item.objects.select_related('workshop').prefetch_related('sizes').get(pk=pk)
        except Item.DoesNotExist:
            return Response({'detail': 'Не найден'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PublicItemDetailSerializer(item, context={'request': request})
        return Response(serializer.data)


@extend_schema_view(
    list=extend_schema(summary='Список товаров', description='Товары текущего цеха пользователя.'),
    retrieve=extend_schema(summary='Детали товара', description='Один товар по id со списком размеров и остатками.'),
    create=extend_schema(summary='Создать товар', description='name, item_description (опц.), photo (опц.), price, wb_url, ozon_url (опц.).'),
    update=extend_schema(summary='Обновить товар', description='Полное обновление полей товара (в т.ч. wb_url, ozon_url).'),
    partial_update=extend_schema(summary='Частично обновить товар', description='PATCH: обновить только переданные поля (name, photo, item_description, price, wb_url, ozon_url и др.).'),
    destroy=extend_schema(summary='Удалить товар', description='Удаление товара по id.'),
)
class ItemViewSet(WorkshopFilterMixin, ModelViewSet):
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        return self.get_workshop_queryset(Item).select_related('workshop').prefetch_related('sizes')

    def get_serializer_class(self):
        if self.action in ('list',):
            return ItemListSerializer
        if self.action in ('retrieve',):
            return ItemDetailSerializer
        return ItemCreateUpdateSerializer

    def perform_create(self, serializer):
        workshop = self.get_workshop()
        serializer.save(workshop=workshop)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


@extend_schema_view(
    get=extend_schema(summary='Список размеров товара', description='Все размеры и остатки по товару item_pk.', tags=['Размеры и остатки']),
    post=extend_schema(summary='Добавить размер', description='Тело: size_label (обяз.), barcode (опц.).', tags=['Размеры и остатки']),
)
class SizeQuantityListCreateView(WorkshopFilterMixin, APIView):
    parser_classes = [JSONParser]

    def get_item_queryset(self):
        return self.get_workshop_queryset(Item)

    def get(self, request, item_pk):
        try:
            item = self.get_item_queryset().get(pk=item_pk)
        except Item.DoesNotExist:
            return Response({'detail': 'Товар не найден'}, status=status.HTTP_404_NOT_FOUND)
        sizes = SizeQuantity.objects.filter(item_id=item_pk)
        return Response(SizeQuantitySerializer(sizes, many=True).data)

    def post(self, request, item_pk):
        try:
            item = self.get_item_queryset().get(pk=item_pk)
        except Item.DoesNotExist:
            return Response({'detail': 'Товар не найден'}, status=status.HTTP_404_NOT_FOUND)
        data = request.data if hasattr(request, 'data') and request.data is not None else {}
        if not isinstance(data, dict):
            data = {}
        size_label = data.get('size_label')
        barcode = data.get('barcode') or None
        if not size_label:
            return Response({'size_label': ['Обязательное поле']}, status=status.HTTP_400_BAD_REQUEST)
        size = get_or_create_size(item, str(size_label).strip())
        size.barcode = barcode
        size.save()
        return Response(SizeQuantitySerializer(size).data, status=status.HTTP_201_CREATED)


@extend_schema(
    summary='Поиск по штрихкоду',
    description='Query: barcode. Возвращает item_id и size_label. Только товары цеха пользователя.',
    tags=['Размеры и остатки'],
)
class SizeByBarcodeView(WorkshopFilterMixin, APIView):
    def get(self, request):
        barcode = request.query_params.get('barcode', '').strip()
        if not barcode:
            return Response({'detail': 'barcode required'}, status=status.HTTP_400_BAD_REQUEST)
        workshop = self.get_workshop()
        qs = SizeQuantity.objects.select_related('item').filter(barcode=barcode)
        if workshop:
            qs = qs.filter(item__workshop=workshop)
        else:
            qs = qs.filter(item__workshop__isnull=True)
        try:
            size = qs.get()
            return Response({
                'item_id': str(size.item_id),
                'size_label': size.size_label,
            })
        except SizeQuantity.DoesNotExist:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)


@extend_schema_view(
    patch=extend_schema(summary='Изменить размер', description='Тело: size_label, quantity, barcode (опц.).', tags=['Размеры и остатки']),
    delete=extend_schema(summary='Удалить размер', description='Удаление размера по item_pk и pk.', tags=['Размеры и остатки']),
)
class SizeQuantityDetailView(WorkshopFilterMixin, APIView):
    parser_classes = [JSONParser]

    def get_item_queryset(self):
        return self.get_workshop_queryset(Item)

    def patch(self, request, item_pk, pk):
        try:
            self.get_item_queryset().get(pk=item_pk)
            size = SizeQuantity.objects.get(pk=pk, item_id=item_pk)
        except SizeQuantity.DoesNotExist:
            return Response({'detail': 'Размер не найден'}, status=status.HTTP_404_NOT_FOUND)
        data = request.data or {}
        for key in ('size_label', 'quantity', 'barcode'):
            if key in data:
                setattr(size, key, data[key])
        size.save()
        return Response(SizeQuantitySerializer(size).data)

    def delete(self, request, item_pk, pk):
        try:
            self.get_item_queryset().get(pk=item_pk)
            size = SizeQuantity.objects.get(pk=pk, item_id=item_pk)
        except SizeQuantity.DoesNotExist:
            return Response(status=status.HTTP_204_NO_CONTENT)
        size.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


@extend_schema_view(
    list=extend_schema(summary='Список поставок', description='Поставки цеха. Query: item_id — фильтр по товару.'),
    retrieve=extend_schema(summary='Детали поставки', description='Одна поставка с составом (line_items) и created_by_username.'),
    create=extend_schema(summary='Создать поставку/отгрузку', description='Тело: type (in|out), lines: [{item_id, size_label, quantity}].'),
    tags=['Поставки'],
)
class SupplyViewSet(WorkshopFilterMixin, ModelViewSet):
    def get_queryset(self):
        qs = self.get_workshop_queryset(Supply)
        item_id = self.request.query_params.get('item_id')
        if item_id:
            qs = qs.filter(line_items__item_id=item_id).distinct()
        return qs.prefetch_related('line_items').order_by('-date')[:100]

    def get_serializer_class(self):
        if self.action in ('list', 'retrieve',):
            return SupplyDetailSerializer
        if self.action in ('create',):
            return SupplyCreateSerializer
        return SupplyDetailSerializer

    def create(self, request, *args, **kwargs):
        serializer = SupplyCreateSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        supply = serializer.save()
        return Response(
            SupplyDetailSerializer(supply).data,
            status=status.HTTP_201_CREATED
        )


@extend_schema_view(
    list=extend_schema(summary='Список заказов', description='Заказы цеха. Query: item_id — фильтр по товару.'),
    retrieve=extend_schema(summary='Детали заказа', description='Заказ с составом (line_items), суммой, адресом и телефоном.'),
    create=extend_schema(
        summary='Создать заказ',
        description='Тело: source, delivery_address, client_phone, lines: [{item_id, size_label, quantity}]. Остатки на складе списываются. total считается по ценам товаров.',
    ),
    partial_update=extend_schema(summary='Частично обновить заказ', description='PATCH: можно изменить любые поля, в т.ч. status. При статусе «Отменено» остатки возвращаются на склад.'),
    tags=['Заказы'],
)
class OrderViewSet(WorkshopFilterMixin, ModelViewSet):
    def get_queryset(self):
        qs = self.get_workshop_queryset(Order)
        item_id = self.request.query_params.get('item_id')
        if item_id:
            qs = qs.filter(line_items__item_id=item_id).distinct()
        return qs.prefetch_related('line_items').order_by('-created_at')[:100]

    def get_serializer_class(self):
        if self.action in ('list',):
            return OrderListSerializer
        if self.action in ('retrieve',):
            return OrderDetailSerializer
        if self.action in ('create',):
            return OrderCreateSerializer
        return OrderDetailSerializer

    def create(self, request, *args, **kwargs):
        serializer = OrderCreateSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        order = serializer.save()
        return Response(
            OrderDetailSerializer(order).data,
            status=status.HTTP_201_CREATED,
        )

    def perform_update(self, serializer):
        instance = serializer.instance
        old_status = instance.status
        serializer.save()
        instance.refresh_from_db()
        if old_status != Order.STATUS_CANCELLED and instance.status == Order.STATUS_CANCELLED:
            restore_order_stock(instance)

    @extend_schema(
        summary='Сменить статус заказа',
        description='Тело: {"status": "new" | "shipped" | "in_transit" | "ready" | "delivered" | "cancelled"}. При смене на «Отменено» остатки возвращаются на склад.',
        request=OrderStatusSerializer,
        responses={200: OrderDetailSerializer},
    )
    @action(detail=True, methods=['post'], url_path='set-status')
    def set_status(self, request, pk=None):
        order = self.get_object()
        ser = OrderStatusSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        new_status = ser.validated_data['status']
        old_status = order.status
        order.status = new_status
        order.save(update_fields=['status'])
        order.refresh_from_db()
        if old_status != Order.STATUS_CANCELLED and new_status == Order.STATUS_CANCELLED:
            restore_order_stock(order)
        return Response(OrderDetailSerializer(order).data)
