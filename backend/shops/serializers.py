from rest_framework import serializers
from .models import Shop, ShopSettings


class ShopSerializer(serializers.ModelSerializer):
    owner_email = serializers.CharField(source='owner.email', read_only=True)
    
    class Meta:
        model = Shop
        fields = [
            'id', 'owner', 'owner_email', 'name', 'slug', 'logo', 'description',
            'primary_color', 'secondary_color', 'accent_color',
            'phone', 'email', 'address', 'currency', 'language',
            'is_active', 'subscription_plan', 'subscription_expires_at',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'slug', 'owner', 'created_at', 'updated_at']


class ShopPublicSerializer(serializers.ModelSerializer):
    """សម្រាប់ Flutter App ទាញយក Theme"""
    logo_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Shop
        fields = [
            'name', 'slug', 'logo_url', 'description',
            'primary_color', 'secondary_color', 'accent_color',
            'phone', 'email', 'address', 'currency', 'language'
        ]
    
    def get_logo_url(self, obj):
        if obj.logo:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.logo.url)
            return obj.logo.url
        return None


class ShopUpdateSerializer(serializers.ModelSerializer):
    """សម្រាប់ Shop Owner កែព័ត៌មានហាង"""
    class Meta:
        model = Shop
        fields = [
            'name', 'logo', 'description',
            'primary_color', 'secondary_color', 'accent_color',
            'phone', 'email', 'address', 'currency', 'language'
        ]
    
    def validate_primary_color(self, value):
        if not value.startswith('#') or len(value) != 7:
            raise serializers.ValidationError("Color must be in #RRGGBB format")
        return value


class ShopSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShopSettings
        fields = '__all__'
        read_only_fields = ['id', 'shop', 'created_at', 'updated_at']