from django.db import models
from django.conf import settings
from django.utils.text import slugify


class Shop(models.Model):
    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='owned_shop',  # ✅ ប្តូរពី 'shop' ទៅ 'owned_shop'
        null=True,
        blank=True,
    )
    name = models.CharField(max_length=100, default="My Shop")
    slug = models.SlugField(max_length=120, unique=True, blank=True)
    logo = models.ImageField(upload_to='shop_logos/', blank=True, null=True)
    description = models.TextField(blank=True, max_length=500)

    primary_color = models.CharField(max_length=7, default="#1F6FEB")
    secondary_color = models.CharField(max_length=7, default="#1547A8")
    accent_color = models.CharField(max_length=7, default="#00D2FF")

    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True, max_length=300)

    currency = models.CharField(max_length=10, default="USD")
    language = models.CharField(max_length=10, default="en")
    is_active = models.BooleanField(default=True)

    # ✅ Field ថ្មីសម្រាប់ Telegram — ដាក់ក្នុង Class ត្រឹមត្រូវ
    telegram_chat_id = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Telegram Chat ID សម្រាប់ទទួលការជូនដំណឹង Order"
    )
    telegram_enabled = models.BooleanField(
        default=True,
        help_text="បើក/បិទ Telegram Notification"
    )

    subscription_plan = models.CharField(
        max_length=20,
        choices=[
            ('free', 'Free'),
            ('basic', 'Basic'),
            ('pro', 'Pro'),
            ('enterprise', 'Enterprise'),
        ],
        default='free'
    )
    subscription_expires_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while Shop.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)

    def __str__(self):
        if self.owner:
            return f"{self.name} ({self.owner.email})"
        return f"{self.name} (Super Admin)"

    @classmethod
    def get_or_create_for_user(cls, user):
        """រក ឬ បង្កើត Shop សម្រាប់ User"""
        try:
            return user.owned_shop
        except cls.DoesNotExist:
            shop_name = user.full_name or user.email.split('@')[0]
            shop = cls.objects.create(
                owner=user,
                name=f"{shop_name}'s Shop",
                email=user.email,
                phone=user.phone_number if hasattr(user, 'phone_number') else '',
            )
            return shop

    @classmethod
    def get_super_admin_shop(cls):
        """រក ឬ បង្កើត Shop សម្រាប់ Super Admin"""
        shop, created = cls.objects.get_or_create(
            slug='super-admin-shop',
            defaults={
                'name': 'Super Admin Shop',
                'description': 'Shop សម្រាប់ Super Admin',
                'primary_color': '#1F6FEB',
                'secondary_color': '#1547A8',
                'accent_color': '#00D2FF',
                'is_active': True,
                'subscription_plan': 'enterprise',
            }
        )
        return shop


class ShopSettings(models.Model):
    """ការកំណត់បន្ថែមសម្រាប់ហាង"""
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, related_name='settings')

    order_notification_email = models.EmailField(blank=True)
    telegram_bot_token = models.CharField(max_length=200, blank=True)
    facebook_page_url = models.URLField(blank=True)
    meta_title = models.CharField(max_length=200, blank=True)
    meta_description = models.TextField(blank=True, max_length=300)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Settings for {self.shop.name}"