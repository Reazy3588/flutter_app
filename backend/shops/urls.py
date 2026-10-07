from django.urls import path
from .views import ShopThemeView, MyShopView, ShopSettingsView

urlpatterns = [
    path('<slug:slug>/theme/', ShopThemeView.as_view(), name='shop-theme'),
    path('me/', MyShopView.as_view(), name='my-shop'),
    path('me/settings/', ShopSettingsView.as_view(), name='my-shop-settings'),
]