from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline
from django.utils.safestring import mark_safe
from .models import Shop, ShopSettings
from products.models import Category, Product, Order


# ==================== INLINES ====================
class CategoryInline(TabularInline):
    model = Category
    extra = 0
    fields = ('name', 'slug', 'is_active', 'created_at')
    readonly_fields = ('slug', 'created_at')
    show_change_link = True
    per_page = 10
    tab = True


class ProductInline(TabularInline):
    model = Product
    extra = 0
    fields = ('name', 'category', 'price', 'stock', 'is_active', 'created_at')
    readonly_fields = ('created_at',)
    show_change_link = True
    per_page = 10
    tab = True


class OrderInline(TabularInline):
    model = Order
    extra = 0
    fields = ('order_number', 'full_name', 'status', 'grand_total', 'created_at')
    readonly_fields = ('order_number', 'created_at')
    show_change_link = True
    per_page = 10
    tab = True


# ==================== SHOP ADMIN ====================
@admin.register(Shop)
class ShopAdmin(ModelAdmin):
    list_display = (
        'name', 'owner_email', 'slug', 'subscription_plan',
        'is_active', 'created_at'
    )
    list_filter = ('is_active', 'subscription_plan', 'created_at')
    search_fields = ('name', 'owner__email', 'slug')
    readonly_fields = ('created_at', 'updated_at')
    list_per_page = 20
    
    fieldsets = (
        ('ព័ត៌មានហាង', {
            'fields': ('owner', 'name', 'slug', 'logo', 'description')
        }),
        ('ការកំណត់ Theme', {
            'fields': ('primary_color', 'secondary_color', 'accent_color')
        }),
        ('ព័ត៌មានទំនាក់ទំនង', {
            'fields': ('phone', 'email', 'address')
        }),
        ('ការកំណត់', {
            'fields': ('currency', 'language', 'is_active')
        }),
        ('ការគិតថ្លៃ', {
            'fields': ('subscription_plan', 'subscription_expires_at')
        }),
        ('កាលបរិច្ឆេទ', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    inlines = [CategoryInline, ProductInline, OrderInline]
    
    @admin.display(description='Owner Email')
    def owner_email(self, obj):
        if obj.owner:
            return obj.owner.email
        return mark_safe('<span style="color: #666;">—</span>')


# ==================== SHOP SETTINGS ====================
@admin.register(ShopSettings)
class ShopSettingsAdmin(ModelAdmin):
    list_display = ('shop', 'order_notification_email', 'created_at')
    search_fields = ('shop__name',)
    readonly_fields = ('created_at', 'updated_at')