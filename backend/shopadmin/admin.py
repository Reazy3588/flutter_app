from django.contrib import admin
from unfold.admin import ModelAdmin
from django.utils.html import format_html

from products.models import Product, Category, Order
from .sites import shop_admin_site


class ShopFilterMixin:
    """ធានាថា Shop Owner ឃើញតែទិន្នន័យរបស់ហាងខ្លួនឯង"""
    admin_site = shop_admin_site
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        try:
            return qs.filter(shop=request.user.shop)
        except Exception:
            return qs.none()
    
    def save_model(self, request, obj, form, change):
        if not obj.pk and hasattr(request.user, 'shop'):
            obj.shop = request.user.shop
        super().save_model(request, obj, form, change)
    
    def has_module_permission(self, request):
        user = getattr(request, 'user', None)
        return bool(getattr(user, 'is_authenticated', False) and (getattr(user, 'is_shop_owner', False) or getattr(user, 'is_superuser', False)))


# ==================== PRODUCT ====================
class ShopProductAdmin(ShopFilterMixin, ModelAdmin):
    admin_site = shop_admin_site
    
    list_display = ('name', 'category', 'price_display', 'stock_display', 'is_active', 'created_at')
    list_filter = ('is_active', 'category', 'is_new_arrival', 'is_best_seller')
    search_fields = ('name', 'description')
    readonly_fields = ('slug', 'created_at', 'updated_at', 'sold_count')
    list_per_page = 20
    exclude = ('shop',)
    
    fieldsets = (
        ('ព័ត៌មានផលិតផល', {'fields': ('name', 'slug', 'category', 'description')}),
        ('តម្លៃ និង Stock', {'fields': ('price', 'discount_price', 'stock', 'sold_count')}),
        ('រូបភាព', {'fields': ('image',)}),
        ('ស្លាក', {'fields': ('is_new_arrival', 'is_best_seller', 'is_recommended')}),
        ('ស្ថានភាព', {'fields': ('is_active',)}),
        ('កាលបរិច្ឆេទ', {'fields': ('created_at', 'updated_at'), 'classes': ('collapse',)}),
    )
    
    @admin.display(description='តម្លៃ')
    def price_display(self, obj):
        return f"${obj.price}"
    
    @admin.display(description='Stock')
    def stock_display(self, obj):
        color = 'green' if obj.stock > 10 else 'orange' if obj.stock > 0 else 'red'
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.stock)


# ==================== CATEGORY ====================
class ShopCategoryAdmin(ShopFilterMixin, ModelAdmin):
    admin_site = shop_admin_site
    
    list_display = ('name', 'is_active', 'created_at')
    list_filter = ('is_active',)
    search_fields = ('name',)
    readonly_fields = ('slug', 'created_at')
    list_per_page = 20
    exclude = ('shop',)


# ==================== ORDER ====================
class ShopOrderAdmin(ShopFilterMixin, ModelAdmin):
    admin_site = shop_admin_site
    
    list_display = ('order_number', 'customer_name', 'status_badge', 'grand_total_display', 'payment_method', 'created_at')
    list_filter = ('status', 'payment_method', 'created_at')
    search_fields = ('order_number', 'full_name', 'phone')
    readonly_fields = ('order_number', 'created_at', 'updated_at', 'subtotal', 
                       'shipping', 'tax', 'grand_total', 'discount_amount')
    list_per_page = 20
    exclude = ('shop',)
    
    fieldsets = (
        ('ព័ត៌មាន Order', {'fields': ('order_number', 'status', 'payment_method')}),
        ('ព័ត៌មានអតិថិជន', {'fields': ('full_name', 'phone', 'address', 'city')}),
        ('តម្លៃ', {'fields': ('subtotal', 'shipping', 'tax', 'discount_amount', 'grand_total')}),
        ('កាលបរិច្ឆេទ', {'fields': ('created_at', 'updated_at'), 'classes': ('collapse',)}),
    )
    
    @admin.display(description='អតិថិជន')
    def customer_name(self, obj):
        return obj.full_name
    
    @admin.display(description='Status')
    def status_badge(self, obj):
        colors = {
            'pending': '#f59e0b',
            'confirmed': '#3b82f6',
            'shipped': '#8b5cf6',
            'delivered': '#10b981',
            'cancelled': '#ef4444',
        }
        color = colors.get(obj.status, '#666')
        return format_html(
            '<span style="background:{};color:white;padding:4px 12px;border-radius:12px;font-size:11px;font-weight:600;">{}</span>',
            color, obj.status.upper()
        )
    
    @admin.display(description='តម្លៃ')
    def grand_total_display(self, obj):
        return f"${obj.grand_total}"


# ==================== REGISTER ទៅ SHOP ADMIN SITE ====================
# ⚠️ ចំណាំ: មិន Register Coupon ទេ ព្រោះវាគ្រប់គ្រងដោយ Super Admin
shop_admin_site.register(Product, ShopProductAdmin)
shop_admin_site.register(Category, ShopCategoryAdmin)
shop_admin_site.register(Order, ShopOrderAdmin)