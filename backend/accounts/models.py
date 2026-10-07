import random
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class User(AbstractUser):
    """
    Custom user model.
    Login can be done with EMAIL or PHONE NUMBER + password.
    Username is kept (required by AbstractUser) but auto-generated from phone/email.
    """
    # ✅ លុប unique=True ចេញ — ពិនិត្យ unique_together ជំនួស
    phone_number = models.CharField(
        max_length=20,
        null=True,
        blank=True,
    )
    # ✅ លុប unique=True ចេញ — ពិនិត្យ unique_together ជំនួស
    email = models.EmailField()

    full_name = models.CharField(max_length=150, blank=True)
    address = models.CharField(max_length=255, blank=True)
    profile_photo = models.ImageField(upload_to='profile_photos/', blank=True, null=True)

    is_phone_verified = models.BooleanField(default=False)

    is_shop_owner = models.BooleanField(
        default=False,
        help_text="តើ User នេះជាម្ចាស់ហាងឬអត់?"
    )
    is_shop_staff = models.BooleanField(
        default=False,
        help_text="តើ User នេះជាបុគ្គលិករបស់ហាងឬអត់?"
    )

    # ✅ Shop ដែល User នេះបានបង្កើត Account
    shop = models.ForeignKey(
        'shops.Shop',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='users',
        help_text="Shop ដែល User នេះបានបង្កើត Account"
    )

    # ✅ Role
    ROLE_CHOICES = [
        ('customer', 'Customer'),
        ('delivery', 'Delivery'),
        ('shop_owner', 'Shop Owner'),
        ('shop_staff', 'Shop Staff'),
        ('super_admin', 'Super Admin'),
    ]
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default='customer',
        help_text="Role របស់ User ក្នុងប្រព័ន្ធ"
    )

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email']  # ✅ ប្តូរទៅ email វិញ

    class Meta:
        # ✅ Phone និង Email ត្រូវតែមានតែមួយក្នុង Shop តែមួយ
        unique_together = [
            ['phone_number', 'shop'],
            ['email', 'shop'],
        ]

    def __str__(self):
        return f"{self.full_name or self.username} ({self.phone_number or 'No Phone'})"


# ✅ Function សម្រាប់ OTP
def generate_otp_code():
    """បង្កើត OTP Code ៦ តួ"""
    return str(random.randint(100000, 999999))


def default_otp_expiry():
    """កំណត់ពេលផុតកំណត់ OTP"""
    return timezone.now() + timedelta(minutes=getattr(settings, 'OTP_EXPIRY_MINUTES', 5))


class PhoneOTP(models.Model):
    """
    Stores an OTP code sent to a phone number so it can be verified
    during Sign Up (and can be reused for Forgot Password later).
    """
    PURPOSE_SIGNUP = 'signup'
    PURPOSE_RESET = 'reset'
    PURPOSE_CHOICES = [
        (PURPOSE_SIGNUP, 'Signup Verification'),
        (PURPOSE_RESET, 'Password Reset'),
    ]

    phone_number = models.CharField(max_length=20)
    code = models.CharField(max_length=6, default=generate_otp_code)
    purpose = models.CharField(max_length=10, choices=PURPOSE_CHOICES, default=PURPOSE_SIGNUP)
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(default=default_otp_expiry)

    class Meta:
        ordering = ['-created_at']

    def is_valid(self):
        return (not self.is_used) and timezone.now() <= self.expires_at

    def __str__(self):
        return f"OTP {self.code} for {self.phone_number} ({self.purpose})"


class ShippingAddress(models.Model):
    """
    A saved delivery address for a user.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='shipping_addresses',
    )
    label = models.CharField(max_length=50, blank=True, help_text="e.g. Home, Office")
    full_name = models.CharField(max_length=150)
    phone_number = models.CharField(max_length=20)
    address_line = models.CharField(max_length=255)
    city = models.CharField(max_length=100, default='Phnom Penh')
     # ✅ ប្តូរទៅ FloatField
    latitude = models.FloatField(
        null=True, blank=True,
        help_text="រយៈទទឹង GPS របស់អាសយដ្ឋាននេះ"
    )
    longitude = models.FloatField(
        null=True, blank=True,
        help_text="រយៈបណ្តោយ GPS របស់អាសយដ្ឋាននេះ"
    )
    
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_default', '-created_at']
        verbose_name_plural = "Shipping Addresses"

    def save(self, *args, **kwargs):
        if self.is_default:
            ShippingAddress.objects.filter(user=self.user, is_default=True).exclude(pk=self.pk).update(is_default=False)
        super().save(*args, **kwargs)
        if not ShippingAddress.objects.filter(user=self.user, is_default=True).exists():
            ShippingAddress.objects.filter(pk=self.pk).update(is_default=True)

    def __str__(self):
        return f"{self.full_name} - {self.address_line} ({self.user.email})"