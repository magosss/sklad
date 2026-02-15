from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    ItemViewSet,
    SizeQuantityListCreateView,
    SizeQuantityDetailView,
    SupplyViewSet,
    OrderViewSet,
    SizeByBarcodeView,
    PublicItemListView,
    PublicItemDetailView,
)
from .auth_views import LoginView

router = DefaultRouter()
router.register('items', ItemViewSet, basename='item')
router.register('supplies', SupplyViewSet, basename='supply')
router.register('orders', OrderViewSet, basename='order')

urlpatterns = [
    path('schema/', SpectacularAPIView.as_view(), name='schema'),
    path('schema/swagger/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('schema/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    path('public/items/', PublicItemListView.as_view(), name='public-items'),
    path('public/items/<uuid:pk>/', PublicItemDetailView.as_view(), name='public-item-detail'),
    path('auth/login/', LoginView.as_view(), name='login'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('sizes/by_barcode/', SizeByBarcodeView.as_view(), name='size-by-barcode'),
    path(
        'items/<uuid:item_pk>/sizes/',
        SizeQuantityListCreateView.as_view(),
        name='item-sizes-list'
    ),
    path(
        'items/<uuid:item_pk>/sizes/<uuid:pk>/',
        SizeQuantityDetailView.as_view(),
        name='item-size-detail'
    ),
    path('', include(router.urls)),
]
