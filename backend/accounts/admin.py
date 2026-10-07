from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.forms import UserCreationForm, UserChangeForm
from unfold.admin import ModelAdmin
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from .models import User, PhoneOTP, ShippingAddress


class CustomUserCreationForm(UserCreationForm):
    class Meta:
        model = User
        fields = ('email', 'username', 'full_name', 'phone_number',
                  'shop', 'role', 'is_shop_owner', 'is_shop_staff', 'is_staff')


class CustomUserChangeForm(UserChangeForm):
    class Meta:
        model = User
        fields = '__all__'


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    form = CustomUserChangeForm
    add_form = CustomUserCreationForm

    list_display = ('email', 'username', 'full_name', 'phone_number',
                    'shop_display', 'role_badge', 'is_active', 'date_joined')
    list_filter = ('shop', 'role', 'is_shop_owner', 'is_shop_staff', 'is_active', 'is_phone_verified')
    search_fields = ('email', 'full_name', 'phone_number', 'username')
    ordering = ('-date_joined',)
    list_per_page = 20

    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('ព័ត៌មានផ្ទាល់ខ្លួន', {
            'fields': ('first_name', 'last_name', 'email', 'full_name',
                       'phone_number', 'address', 'profile_photo')
        }),
        ('Shop & Role', {
            'fields': ('shop', 'role')
        }),
        ('សិទ្ធិ', {
            'fields': ('is_active', 'is_staff', 'is_superuser',
                       'is_phone_verified', 'is_shop_owner', 'is_shop_staff',
                       'groups', 'user_permissions')
        }),
        ('កាលបរិច្ឆេទសំខាន់', {
            'fields': ('last_login', 'date_joined'),
            'classes': ('collapse',)
        }),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'username', 'full_name', 'phone_number',
                       'shop', 'role', 'password1', 'password2',
                       'is_shop_owner', 'is_shop_staff', 'is_staff'),
        }),
    )

    @admin.display(description='Shop')
    def shop_display(self, obj):
        if obj.shop:
            return format_html(
                '<span style="color:#1F6FEB;font-weight:600;">{}</span>',
                obj.shop.name
            )
        return mark_safe('<span style="color:#666;">—</span>')

    @admin.display(description='Role')
    def role_badge(self, obj):
        colors = {
            'customer': ('#E0F2FE', '#0369A1', 'Customer'),
            'delivery': ('#FEF3C7', '#B45309', 'Delivery'),
            'shop_owner': ('#EDE9FE', '#6D28D9', 'Shop Owner'),
            'shop_staff': ('#D1FAE5', '#065F46', 'Shop Staff'),
            'super_admin': ('#FEE2E2', '#991B1B', 'Super Admin'),
        }
        bg, fg, label = colors.get(obj.role, ('#F3F4F6', '#6B7280', 'Unknown'))
        return format_html(
            '<span style="background:{};color:{};padding:4px 12px;'
            'border-radius:20px;font-size:11px;font-weight:700;">{}</span>',
            bg, fg, label
        )
    def get_queryset(self, request):
        """
        ✅ Filter User តាម Shop និង Role
        - Super Admin → ឃើញ User ក្នុង Shop របស់ខ្លួន + Shop Owner ទាំងអស់
        - Shop Owner → ឃើញតែ User ក្នុង Shop ខ្លួនឯង
        - User ធម្មតា → ឃើញតែខ្លួនឯង
        """
        from django.db.models import Q
        qs = super().get_queryset(request)
        user = request.user

        # ✅ Super Admin → ឃើញ User ក្នុង Shop របស់ខ្លួន + Shop Owner ទាំងអស់
        if user.is_superuser:
            if hasattr(user, 'shop') and user.shop:
                return qs.filter(
                    Q(shop=user.shop) | Q(role='shop_owner')
                ).distinct()
            # បើ Super Admin គ្មាន Shop → ឃើញតែ Shop Owner ទាំងអស់
            return qs.filter(role='shop_owner')

        # ✅ Shop Owner → ឃើញតែ User ក្នុង Shop ខ្លួនឯង
        if getattr(user, 'is_shop_owner', False):
            shop = None
            if hasattr(user, 'owned_shop') and user.owned_shop:
                shop = user.owned_shop
            elif hasattr(user, 'shop') and user.shop:
                shop = user.shop

            if shop:
                return qs.filter(shop=shop)
            return qs.none()

        # ✅ User ធម្មតា → ឃើញតែខ្លួនឯង
        return qs.filter(pk=user.pk)


# ✅ Register PhoneOTP — នេះជាអ្វីដែលខ្វះ!
@admin.register(PhoneOTP)
class PhoneOTPAdmin(ModelAdmin):
    list_display = ('phone_number', 'code', 'purpose', 'is_used', 'created_at')
    list_filter = ('purpose', 'is_used')
    search_fields = ('phone_number', 'code')


# ✅ Register ShippingAddress
@admin.register(ShippingAddress)
class ShippingAddressAdmin(ModelAdmin):
    list_display = ('full_name', 'phone_number', 'city', 'is_default', 'user')
    list_filter = ('is_default', 'city')
    search_fields = ('full_name', 'phone_number', 'address_line')