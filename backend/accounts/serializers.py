from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.db import models  # ✅ បន្ថែមសម្រាប់ Q object
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import PhoneOTP, ShippingAddress

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    """
    Step 1 of Sign Up: user submits Full Name, Phone, Email, Password.
    """
    password = serializers.CharField(write_only=True, min_length=6, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, min_length=6)
    shop_slug = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ['full_name', 'phone_number', 'email', 'password', 'password2', 'shop_slug']

    def validate_phone_number(self, value):
        """✅ ពិនិត្យ Phone តែក្នុង Shop តែមួយ (ចំពោះ User ដែល Verify រួច)"""
        shop_slug = self.initial_data.get('shop_slug')
        if value and shop_slug:
            from shops.models import Shop
            try:
                shop = Shop.objects.get(slug=shop_slug)
                # ✅ ពិនិត្យតែ User ដែល is_active=True
                if User.objects.filter(phone_number=value, shop=shop, is_active=True).exists():
                    raise serializers.ValidationError(
                        "This phone number is already registered in this shop."
                    )
            except Shop.DoesNotExist:
                pass
        return value

    def validate_email(self, value):
        """✅ ពិនិត្យ Email តែក្នុង Shop តែមួយ (ចំពោះ User ដែល Verify រួច)"""
        shop_slug = self.initial_data.get('shop_slug')
        if value and shop_slug:
            from shops.models import Shop
            try:
                shop = Shop.objects.get(slug=shop_slug)
                if User.objects.filter(email=value, shop=shop, is_active=True).exists():
                    raise serializers.ValidationError(
                        "This email is already registered in this shop."
                    )
            except Shop.DoesNotExist:
                pass
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password2": "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password2')
        password = validated_data.pop('password')
        shop_slug = validated_data.pop('shop_slug', None)

        # ✅ បង្កើត Username តែមួយគត់
        username = validated_data['email'].split('@')[0]
        base_username = username
        counter = 1
        while User.objects.filter(username=username).exists():
            username = f"{base_username}{counter}"
            counter += 1

        # ✅ ភ្ជាប់ User ជាមួយ Shop
        shop = None
        if shop_slug:
            try:
                from shops.models import Shop
                shop = Shop.objects.get(slug=shop_slug)
            except Shop.DoesNotExist:
                pass

        user = User(
            username=username,
            is_active=False,
            shop=shop,
            role='customer',
            **validated_data
        )
        user.set_password(password)
        user.save()
        return user


class VerifyOTPSerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    code = serializers.CharField(max_length=6, min_length=6)
    shop_slug = serializers.CharField(required=False, allow_blank=True)  # ✅ បន្ថែម

    def validate(self, attrs):
        phone_number = attrs['phone_number']
        code = attrs['code']

        otp = PhoneOTP.objects.filter(
            phone_number=phone_number, code=code, purpose=PhoneOTP.PURPOSE_SIGNUP
        ).order_by('-created_at').first()

        if otp is None:
            raise serializers.ValidationError("Invalid OTP code.")
        if not otp.is_valid():
            raise serializers.ValidationError("OTP code has expired. Please request a new one.")

        attrs['otp'] = otp
        return attrs


class ResendOTPSerializer(serializers.Serializer):
    phone_number = serializers.CharField()


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField(help_text="Email or phone number")
    password = serializers.CharField(write_only=True)
    shop_slug = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        identifier = attrs['identifier']
        password = attrs['password']
        shop_slug = attrs.get('shop_slug')

        # ✅ បើមាន shop_slug → ស្វែងរក User តែក្នុង Shop នោះ
        if shop_slug:
            from shops.models import Shop
            try:
                shop = Shop.objects.get(slug=shop_slug)
                user = User.objects.filter(
                    models.Q(email=identifier) | models.Q(phone_number=identifier),
                    shop=shop
                ).first()
            except Shop.DoesNotExist:
                raise serializers.ValidationError("Shop not found.")
        else:
            # បើគ្មាន shop_slug ទេ វានឹងរកឃើញ Account ដំបូងគេ
            user = User.objects.filter(
                models.Q(email=identifier) | models.Q(phone_number=identifier)
            ).first()

        if user is None or not user.check_password(password):
            raise serializers.ValidationError("Invalid credentials.")

        if not user.is_active or not user.is_phone_verified:
            raise serializers.ValidationError(
                "Account is not verified yet. Please verify your phone number OTP first."
            )

        attrs['user'] = user
        return attrs

    def get_tokens(self, user):
        refresh = RefreshToken.for_user(user)
        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }


class UserSerializer(serializers.ModelSerializer):
    shop_slug = serializers.SerializerMethodField()
    shop_name = serializers.SerializerMethodField()

    password = serializers.CharField(
        write_only=True,
        required=False,
        min_length=6,
        style={'input_type': 'password'}
    )
    password2 = serializers.CharField(
        write_only=True,
        required=False,
        min_length=6,
        style={'input_type': 'password'}
    )

    class Meta:
        model = User
        fields = [
            'id', 'username', 'full_name', 'email', 'phone_number',
            'address', 'profile_photo', 'is_phone_verified',
            'is_staff', 'is_shop_owner', 'is_shop_staff',
            'role',  # ✅ បន្ថែមនេះ
            'shop_slug', 'shop_name',
            'password', 'password2',
            'date_joined',
        ]
        read_only_fields = ['id', 'is_phone_verified', 'is_staff', 'date_joined']

    def validate_phone_number(self, value):
        """✅ ពិនិត្យ Phone តែក្នុង Shop តែមួយ (សម្រាប់ Update Profile)"""
        if value:
            user = self.instance
            if user and user.shop:
                # ពិនិត្យតែក្នុង Shop តែមួយ
                if User.objects.filter(phone_number=value, shop=user.shop).exclude(pk=user.pk).exists():
                    raise serializers.ValidationError("This phone number is already registered in this shop.")
            else:
                # បើគ្មាន Shop → ពិនិត្យ Global
                if User.objects.filter(phone_number=value).exclude(pk=user.pk if user else None).exists():
                    raise serializers.ValidationError("This phone number is already registered.")
        return value

    def validate(self, attrs):
        password = attrs.get('password')
        password2 = attrs.get('password2')

        if password or password2:
            if password != password2:
                raise serializers.ValidationError({"password2": "Passwords do not match."})

        return attrs

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        validated_data.pop('password2', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if password:
            instance.set_password(password)

        instance.save()
        return instance

    def get_shop_slug(self, obj):
        if obj.is_shop_owner:
            try:
                return obj.owned_shop.slug
            except Exception:
                return None
        return None

    def get_shop_name(self, obj):
        if obj.is_shop_owner:
            try:
                return obj.owned_shop.name
            except Exception:
                return None
        return None


class ShippingAddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShippingAddress
        fields = [
            'id', 'label', 'full_name', 'phone_number',
            'address_line', 'city', 'is_default',
            'latitude', 'longitude',  # ✅ បន្ថែម GPS
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']

    def validate_phone_number(self, value):
        if not value.strip():
            raise serializers.ValidationError("Phone number is required.")
        return value

    def validate_address_line(self, value):
        if not value.strip():
            raise serializers.ValidationError("Address is required.")
        return value


class ForgotPasswordRequestSerializer(serializers.Serializer):
    phone_number = serializers.CharField()

    def validate_phone_number(self, value):
        if not User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("No account found with this phone number.")
        return value


class ResetPasswordSerializer(serializers.Serializer):
    phone_number = serializers.CharField()
    code = serializers.CharField(max_length=6, min_length=6)
    new_password = serializers.CharField(write_only=True, min_length=6, validators=[validate_password])
    new_password2 = serializers.CharField(write_only=True, min_length=6)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password2']:
            raise serializers.ValidationError({"new_password2": "Passwords do not match."})

        phone_number = attrs['phone_number']
        code = attrs['code']

        otp = PhoneOTP.objects.filter(
            phone_number=phone_number, code=code, purpose=PhoneOTP.PURPOSE_RESET
        ).order_by('-created_at').first()

        if otp is None:
            raise serializers.ValidationError("Invalid reset code.")
        if not otp.is_valid():
            raise serializers.ValidationError("Reset code has expired. Please request a new one.")

        user = User.objects.filter(phone_number=phone_number).first()
        if user is None:
            raise serializers.ValidationError("No account found with this phone number.")

        attrs['otp'] = otp
        attrs['user'] = user
        return attrs