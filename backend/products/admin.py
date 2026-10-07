from django.contrib import admin
from unfold.admin import ModelAdmin, StackedInline, TabularInline
from django.utils.safestring import mark_safe
from .models import Banner, Category, Product, ProductImage, Wishlist, CartItem, Order, OrderItem, Coupon
from .forms import ProductAdminForm
from django.utils.html import format_html
from shops.utils import get_active_shop


# ==================== SHOP FILTER MIXIN ====================
class ShopFilterMixin:
    """
    Super Admin  -> sees ONLY the shop selected on the dashboard dropdown
    Shop Owner   -> sees ONLY their own shop
    """

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        shop = get_active_shop(request)
        if shop is None:
            return qs.none()
        return qs.filter(shop=shop)

    def save_model(self, request, obj, form, change):
        user = getattr(request, "user", None)
        shop = get_active_shop(request)
        if getattr(user, "is_superuser", False):
            if not obj.shop_id and shop:
                obj.shop = shop
        elif shop:
            obj.shop = shop
        super().save_model(request, obj, form, change)

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        form._request = request
        return form


# ==================== CATEGORY ====================
@admin.register(Category)
class CategoryAdmin(ShopFilterMixin, ModelAdmin):
    list_display = ('name', 'shop_display', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('name',)
    readonly_fields = ('slug', 'created_at')
    list_per_page = 20

    @admin.display(description='Shop')
    def shop_display(self, obj):
        if obj.shop:
            if obj.shop.owner:
                return mark_safe(
                    f'<a href="/admin/shops/shop/{obj.shop.pk}/change/" '
                    f'style="color: #8B5CF6; font-weight: 600;">{obj.shop.name}</a>'
                )
            return mark_safe(
                f'<span style="color: #1F6FEB; font-weight: 600;">{obj.shop.name}</span>'
            )
        return mark_safe('<span style="color: #666;">—</span>')


# ==================== PRODUCT ====================
@admin.register(Product)
class ProductAdmin(ShopFilterMixin, ModelAdmin):
    form = ProductAdminForm

    list_display = ('name', 'shop_display', 'category', 'price', 'stock', 'is_active', 'created_at')
    list_filter = ('is_active', 'category', 'is_new_arrival', 'is_best_seller')
    search_fields = ('name', 'description')
    readonly_fields = ('slug', 'created_at', 'updated_at', 'sold_count')
    list_per_page = 20

    @admin.display(description='Shop')
    def shop_display(self, obj):
        if obj.shop:
            if obj.shop.owner:
                return mark_safe(
                    f'<a href="/admin/shops/shop/{obj.shop.pk}/change/" '
                    f'style="color: #8B5CF6; font-weight: 600;">{obj.shop.name}</a>'
                )
            return mark_safe(
                f'<span style="color: #1F6FEB; font-weight: 600;">{obj.shop.name}</span>'
            )
        return mark_safe('<span style="color: #666;">—</span>')


# ==================== ORDER ====================
@admin.register(Order)
class OrderAdmin(ModelAdmin):
    list_display = [
        'order_number', 'user', 'status', 'delivery_person',
        'grand_total', 'created_at'
    ]
    list_filter = ['status', 'payment_method', 'delivery_person']
    search_fields = ['order_number', 'full_name', 'phone']
    
    fieldsets = (
        ('Order Info', {
            'fields': ('order_number', 'user', 'shop', 'status', 'payment_method')
        }),
        ('Customer Info', {
            'fields': ('full_name', 'phone', 'address', 'city')
        }),
        ('Customer Location', {
            'fields': ('customer_lat', 'customer_lng')
        }),
        ('Delivery Info', {
            'fields': (
                'delivery_person',
                'delivery_lat', 'delivery_lng',
                'delivery_updated_at', 'delivered_at'
            )
        }),
        ('Delivery Payment', {
            'fields': ('delivery_fee', 'is_delivery_paid', 'delivery_paid_at')
        }),
        ('Totals', {
            'fields': ('subtotal', 'shipping', 'tax', 'discount_amount', 'grand_total')
        }),
        ('Coupon & Cancellation', {
            'fields': ('coupon', 'cancellation_reason')
        }),
    )

    readonly_fields = ('order_number', 'created_at', 'updated_at', 'status_updated_at')

    # ═══════════════════════════════════════════════════════════
    # ✅ FILTER QUERYSET តាម SHOP
    # ═══════════════════════════════════════════════════════════
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        user = request.user
        shop = get_active_shop(request)

        # Super Admin / Shop Owner -> ONLY the active shop
        if user.is_superuser or getattr(user, "is_shop_owner", False):
            return qs.filter(shop=shop) if shop else qs.none()

        # normal user -> own orders
        return qs.filter(user=user)

    def save_model(self, request, obj, form, change):
        if not obj.shop_id:
            shop = get_active_shop(request)
            if shop:
                obj.shop = shop

        # Assign delivery person -> status confirmed
        if obj.delivery_person and obj.status == 'pending':
            obj.status = 'confirmed'

        super().save_model(request, obj, form, change)

    @admin.display(description='Shop')
    def shop_display(self, obj):
        if obj.shop:
            if obj.shop.owner:
                return mark_safe(
                    f'<a href="/admin/shops/shop/{obj.shop.pk}/change/" '
                    f'style="color: #8B5CF6; font-weight: 600;">{obj.shop.name}</a>'
                )
            return mark_safe(
                f'<span style="color: #1F6FEB; font-weight: 600;">{obj.shop.name}</span>'
            )
        return mark_safe('<span style="color: #666;">—</span>')


# ==================== OTHER MODELS ====================
@admin.register(ProductImage)
class ProductImageAdmin(ModelAdmin):
    list_display = ('product', 'image', 'created_at')
    search_fields = ('product__name',)


@admin.register(Wishlist)
class WishlistAdmin(ModelAdmin):
    list_display = ('user', 'product', 'created_at')
    search_fields = ('user__email', 'product__name')


@admin.register(CartItem)
class CartItemAdmin(ModelAdmin):
    list_display = ('user', 'product', 'quantity', 'created_at')
    search_fields = ('user__email', 'product__name')


@admin.register(OrderItem)
class OrderItemAdmin(ModelAdmin):
    list_display = ('order', 'product', 'quantity', 'price')
    search_fields = ('order__order_number', 'product__name')

    # Order items of the active shop only
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        user = request.user
        shop = get_active_shop(request)

        if user.is_superuser or getattr(user, "is_shop_owner", False):
            return qs.filter(order__shop=shop) if shop else qs.none()

        return qs.filter(order__user=user)


@admin.register(Coupon)
class CouponAdmin(ShopFilterMixin, ModelAdmin):
    list_display = ('code', 'shop_display', 'discount_amount', 'is_active', 'valid_from', 'valid_to')
    list_filter = ('is_active', 'valid_from', 'valid_to')
    search_fields = ('code',)
    list_per_page = 20

    @admin.display(description='Shop')
    def shop_display(self, obj):
        if obj.shop:
            return mark_safe(
                f'<span style="color: #1F6FEB; font-weight: 600;">{obj.shop.name}</span>'
            )
        return mark_safe('<span style="color: #8B5CF6; font-weight: 600;">Super Admin</span>')

    # Coupons of the active shop only (filtering done by ShopFilterMixin)
    def get_queryset(self, request):
        return super().get_queryset(request)

    # ✅ Shop Owner អាចបង្កើតបាន
    def has_module_permission(self, request):
        user = getattr(request, 'user', None)
        return bool(getattr(user, 'is_superuser', False) or (getattr(user, 'is_authenticated', False) and getattr(user, 'is_shop_owner', False)))

    def has_view_permission(self, request, obj=None):
        user = getattr(request, 'user', None)
        return bool(getattr(user, 'is_superuser', False) or (getattr(user, 'is_authenticated', False) and getattr(user, 'is_shop_owner', False)))

    def has_add_permission(self, request):
        user = getattr(request, 'user', None)
        return bool(getattr(user, 'is_superuser', False) or (getattr(user, 'is_authenticated', False) and getattr(user, 'is_shop_owner', False)))

    def has_change_permission(self, request, obj=None):
        user = getattr(request, 'user', None)
        return bool(getattr(user, 'is_superuser', False) or (getattr(user, 'is_authenticated', False) and getattr(user, 'is_shop_owner', False)))

    def has_delete_permission(self, request, obj=None):
        user = getattr(request, 'user', None)
        return bool(getattr(user, 'is_superuser', False) or (getattr(user, 'is_authenticated', False) and getattr(user, 'is_shop_owner', False)))

    # New coupon -> attach to the active shop
    def save_model(self, request, obj, form, change):
        if not obj.pk:
            shop = get_active_shop(request)
            if shop:
                obj.shop = shop
        super().save_model(request, obj, form, change)


# ==================== BANNER ====================
@admin.register(Banner)
class BannerAdmin(ShopFilterMixin, ModelAdmin):
    list_display = ('banner_preview', 'title', 'link_type', 'is_active', 'sort_order', 'created_at')
    list_display_links = ('banner_preview', 'title')
    list_editable = ('is_active', 'sort_order')
    list_filter = ('is_active', 'link_type')
    search_fields = ('title', 'subtitle')
    exclude = ('shop',)          # shop កំណត់ដោយស្វ័យប្រវត្តិតាម Shop ដែលកំពុងប្រើ
    readonly_fields = ('created_at',)
    list_per_page = 20

    @admin.display(description='Preview')
    def banner_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" style="height:44px;width:105px;object-fit:cover;border-radius:8px;" />',
                obj.image.url,
            )
        return '—'
