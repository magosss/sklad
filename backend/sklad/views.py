from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from .models import Item, SizeQuantity, Supply, Workshop
from .serializers import (
    ItemListSerializer,
    WorkshopSerializer,
    ItemDetailSerializer,
    ItemCreateUpdateSerializer,
    SizeQuantitySerializer,
    SupplyDetailSerializer,
    SupplyCreateSerializer,
)
from .services import get_or_create_size, get_workshop_for_user
from .mixins import WorkshopFilterMixin


@extend_schema(
    summary='Публичный список складов',
    description='Список складов (цехов) для выбора на сайте. Без авторизации.',
    tags=['Публичное API'],
)
class PublicWorkshopListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        qs = Workshop.objects.all().order_by('name')
        return Response(WorkshopSerializer(qs, many=True).data)


@extend_schema(
    summary='Публичный список товаров',
    description='Список товаров с остатками по размерам. Без авторизации. Опционально: workshop_id в query — фильтр по цеху.',
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
        qs = qs.prefetch_related('sizes').order_by('created_at')
        serializer = ItemListSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data)


@extend_schema_view(
    list=extend_schema(summary='Список товаров', description='Товары текущего цеха пользователя.'),
    retrieve=extend_schema(summary='Детали товара', description='Один товар по id со списком размеров и остатками.'),
    create=extend_schema(summary='Создать товар', description='name, item_description (опц.), photo (опц.).'),
    update=extend_schema(summary='Обновить товар', description='Полное обновление полей товара.'),
    partial_update=extend_schema(summary='Частично обновить товар', description='PATCH: обновить только переданные поля.'),
    destroy=extend_schema(summary='Удалить товар', description='Удаление товара по id.'),
)
class ItemViewSet(WorkshopFilterMixin, ModelViewSet):
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        return self.get_workshop_queryset(Item)

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
