from rest_framework.routers import DefaultRouter
from django.urls import path
from .views import (
    AbaCallbackView, BannerViewSet, CategoryViewSet, ChatMarkReadView, ChatUnreadCountView, OrderChatListView, OrderChatSendView, OrderRouteView, OrderTrackingView, ProductViewSet,
    WishlistToggleView, WishlistListView,
    CartView, CartAddView, CartItemUpdateView, CartItemDeleteView,
    CheckoutView, OrderListView, OrderDetailView, OrderCancelView,
    AdminOrderListView, AdminOrderStatusUpdateView,
    ValidateCouponView, AbaGenerateQRView,
    AbaCheckTransactionView, DeliveryOrderListView, DeliveryOrderDetailView,
    DeliveryOrderStatusUpdateView, DeliveryUpdateLocationView,
    DeliveryStatsView,DeliveryEarningsView,
)

router = DefaultRouter()
router.register('products', ProductViewSet, basename='product')  # ✅ ប្តូរពី '' ទៅ 'products'
router.register('categories', CategoryViewSet, basename='category')
router.register('banners', BannerViewSet, basename='banner')

urlpatterns = [
    # Wishlist
    path('wishlist/', WishlistListView.as_view(), name='wishlist-list'),
    path('wishlist/<str:slug>/toggle/', WishlistToggleView.as_view(), name='wishlist-toggle'),

    # Cart
    path('cart/', CartView.as_view(), name='cart'),
    path('cart/add/', CartAddView.as_view(), name='cart-add'),
    path('cart/<int:pk>/', CartItemUpdateView.as_view(), name='cart-item-update'),
    path('cart/<int:pk>/delete/', CartItemDeleteView.as_view(), name='cart-item-delete'),

    # Coupon Validation
    path('validate-coupon/', ValidateCouponView.as_view(), name='validate-coupon'),

    # Checkout & Orders
    path('checkout/', CheckoutView.as_view(), name='checkout'),
    path('orders/', OrderListView.as_view(), name='order-list'),
    path('orders/<str:order_number>/', OrderDetailView.as_view(), name='order-detail'),
    path('orders/<str:order_number>/cancel/', OrderCancelView.as_view(), name='order-cancel'),

    # ✅ ABA PayWay
    path('aba/generate-qr/', AbaGenerateQRView.as_view(), name='aba-generate-qr'),
    path('aba/check-transaction/', AbaCheckTransactionView.as_view(), name='aba-check-transaction'),
    path('aba/callback/', AbaCallbackView.as_view(), name='aba-callback'),

    # Admin / Delivery
    path('admin/orders/', AdminOrderListView.as_view(), name='admin-order-list'),
    path('admin/orders/<str:order_number>/status/', AdminOrderStatusUpdateView.as_view(), name='admin-order-status'),

    # ✅ Delivery Routes
    path('delivery/orders/', DeliveryOrderListView.as_view(), name='delivery-order-list'),
    path('delivery/orders/<str:order_number>/', DeliveryOrderDetailView.as_view(), name='delivery-order-detail'),
    path('delivery/orders/<str:order_number>/status/', DeliveryOrderStatusUpdateView.as_view(), name='delivery-order-status'),
    path('delivery/orders/<str:order_number>/location/', DeliveryUpdateLocationView.as_view(), name='delivery-update-location'),
    path('delivery/stats/', DeliveryStatsView.as_view(), name='delivery-stats'),

    # ✅ Customer Tracking
     path('orders/<str:order_number>/tracking/', OrderTrackingView.as_view(), name='order-tracking'),

     # ✅ Delivery Earnings
    path('delivery/earnings/',DeliveryEarningsView.as_view(), name='delivery-earnings'),

     # ✅ Order Route Proxy
    path('orders/<str:order_number>/route/', OrderRouteView.as_view(), name='order-route'),

     # ✅ Chat Routes
    path('orders/<str:order_number>/chat/', OrderChatListView.as_view(), name='order-chat-list'),
    path('orders/<str:order_number>/chat/send/', OrderChatSendView.as_view(), name='order-chat-send'),

    # ✅ Chat Notification Routes
    path('chat/unread/', ChatUnreadCountView.as_view(), name='chat-unread-count'),
    path('orders/<str:order_number>/chat/read/', ChatMarkReadView.as_view(), name='chat-mark-read'),
] + router.urls