from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import path, include


def api_root(request):
    return JsonResponse({
        "message": "Ecommerce API is running",
        "endpoints": {
            "admin": "/admin/",
            "shop_admin": "/shop-admin/",
            "auth": "/api/auth/",
            "products": "/api/products/",
            "shops": "/api/shops/",
            "superadmin": "/api/superadmin/",
        }
    })


urlpatterns = [
    path('', api_root),
    
    # Super Admin Panel
    path('admin/', admin.site.urls),
    
    # Shop Owner Panel (Web Admin + API)
    path('shop-admin/', include('shopadmin.urls')),
    
    # APIs សម្រាប់ Flutter
    path('api/auth/', include('accounts.urls')),
    path('api/products/', include('products.urls')),
    path('api/accounts/', include('accounts.urls')),
    path('api/shops/', include('shops.urls')),
    path('api/superadmin/', include('superadmin.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)