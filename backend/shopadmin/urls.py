from django.urls import path

from . import staff_views
from . import views

app_name = 'shop_admin'

urlpatterns = [
    # Auth
    path('login/', views.shop_admin_login, name='login'),
    path('logout/', views.shop_admin_logout, name='logout'),

    # Dashboard
    path('', views.shop_owner_dashboard, name='index'),
    path('dashboard/', views.shop_owner_dashboard, name='dashboard'),

    # Products
    path('products/', views.product_list, name='product-list'),
    path('products/add/', views.product_add, name='product-add'),
    path('products/<int:pk>/edit/', views.product_edit, name='product-edit'),
    path('products/<int:pk>/delete/', views.product_delete, name='product-delete'),

    # Categories
    path('categories/', views.category_list, name='category-list'),
    path('categories/add/', views.category_add, name='category-add'),
    path('categories/<int:pk>/edit/', views.category_edit, name='category-edit'),
    path('categories/<int:pk>/delete/', views.category_delete, name='category-delete'),

    # Banners
    path('banners/', views.banner_list, name='banner-list'),
    path('banners/add/', views.banner_add, name='banner-add'),
    path('banners/<int:pk>/edit/', views.banner_edit, name='banner-edit'),
    path('banners/<int:pk>/delete/', views.banner_delete, name='banner-delete'),

    # Orders
    path('orders/', views.order_list, name='order-list'),
    path('orders/<str:order_number>/', views.order_detail, name='order-detail'),
    path('orders/<str:order_number>/status/', views.order_update_status, name='order-update-status'),

    # Coupons
    path('coupons/', views.coupon_list, name='coupon-list'),
    path('coupons/add/', views.coupon_add, name='coupon-add'),
    path('coupons/<int:pk>/delete/', views.coupon_delete, name='coupon-delete'),

    # Theme Settings
    path('theme/', views.theme_settings, name='theme-settings'),

    # ✅ Telegram Settings
    path('telegram/', views.telegram_settings, name='telegram-settings'),

    # ✅ Staff & Delivery
    path('staff/', staff_views.staff_list, name='staff-list'),
    path('staff/add/', staff_views.staff_add, name='staff-add'),
    path('staff/<int:pk>/edit/', staff_views.staff_edit, name='staff-edit'),
    path('staff/<int:pk>/delete/', staff_views.staff_delete, name='staff-delete'),

    # ✅ Assign Delivery
    path('orders/<str:order_number>/assign/', views.assign_delivery, name='assign-delivery'),
]