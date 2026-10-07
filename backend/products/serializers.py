# ======== >>>>>
from rest_framework import serializers
from accounts.models import ShippingAddress
from .models import Banner, Category, OrderChat, Product, ProductImage, ProductOption, ProductOptionValue, ProductVariant, Wishlist, CartItem, Order, OrderItem, Coupon


# ===================== CATEGORY & PRODUCT =====================

class CategorySerializer(serializers.ModelSerializer):
    product_count = serializers.SerializerMethodField()
    shop_name = serializers.CharField(source='shop.name', read_only=True)
    shop_slug = serializers.CharField(source='shop.slug', read_only=True)
    image = serializers.SerializerMethodField()  # ✅ បន្ថែមនេះ

    class Meta:
        model = Category
        fields = [
            'id', 'name', 'slug', 'image', 'is_active',
            'product_count', 'shop_name', 'shop_slug'
        ]

    def get_product_count(self, obj):
        try:
            return obj.products.filter(is_active=True).count()
        except AttributeError:
            return 0

    def get_image(self, obj):  # ✅ បន្ថែមនេះ
        """✅ ផ្ញើ Full URL ជំនួស Path"""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class ProductImageSerializer(serializers.ModelSerializer):
    """Serializer សម្រាប់ Gallery Images"""
    class Meta:
        model = ProductImage
        fields = ['id', 'image']


class ProductListSerializer(serializers.ModelSerializer):
    """Lightweight serializer used for the product LIST (grid/cards)."""
    category_name = serializers.CharField(source='category.name', read_only=True)
    shop_name = serializers.CharField(source='shop.name', read_only=True)
    shop_slug = serializers.CharField(source='shop.slug', read_only=True)
    image = serializers.SerializerMethodField()  # ✅ បន្ថែមនេះ

    class Meta:
        model = Product
        fields = [
            'id', 'name', 'slug', 'price', 'discount_price', 'final_price',
            'discount_percent', 'image', 'category_name', 'in_stock',
            'is_new_arrival', 'is_best_seller', 'is_recommended',
            'rating', 'sold_count', 'shop_name', 'shop_slug',
        ]

    def get_image(self, obj):
        """✅ ផ្ញើ Full URL ជំនួស Path"""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


# ===================== PRODUCT VARIANTS =====================

class ProductOptionValueSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductOptionValue
        fields = ['id', 'value', 'position']


class ProductOptionSerializer(serializers.ModelSerializer):
    values = ProductOptionValueSerializer(many=True, read_only=True)

    class Meta:
        model = ProductOption
        fields = ['id', 'name', 'position', 'values']


class ProductVariantSerializer(serializers.ModelSerializer):
    final_price = serializers.DecimalField(
        max_digits=10, decimal_places=2, read_only=True
    )
    in_stock = serializers.BooleanField(read_only=True)
    image_url = serializers.SerializerMethodField()
    display_options = serializers.SerializerMethodField()

    class Meta:
        model = ProductVariant
        fields = [
            'id', 'options', 'display_options', 'stock', 'price',
            'final_price', 'sku', 'image', 'image_url',
            'in_stock', 'is_active',
        ]

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

    def get_display_options(self, obj):
        """
        ✅ បង្ហាញឈ្មោះ Option ពី ProductOptionValue ដែល Admin បានកែ
        """
        display = {}
        for key, value in obj.options.items():
            try:
                option = ProductOption.objects.get(product=obj.product, name=key)
                option_value = ProductOptionValue.objects.filter(
                    option=option, value=value
                ).first()
                if option_value:
                    display[key] = option_value.value
                else:
                    display[key] = value
            except ProductOption.DoesNotExist:
                display[key] = value
        return display


class ProductDetailSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(), source='category', write_only=True
    )
    gallery_images = ProductImageSerializer(many=True, read_only=True)
    options = ProductOptionSerializer(many=True, read_only=True)
    variants = serializers.SerializerMethodField()
    shop_name = serializers.CharField(source='shop.name', read_only=True)
    shop_slug = serializers.CharField(source='shop.slug', read_only=True)

    class Meta:
        model = Product
        fields = [
            'id', 'name', 'slug', 'description', 'price', 'discount_price',
            'final_price', 'discount_percent', 'image', 'stock', 'in_stock', 'is_active',
            'is_new_arrival', 'is_best_seller', 'is_recommended', 'rating', 'sold_count',
            'category', 'category_id', 'gallery_images',
            'options', 'variants',
            'shop_name', 'shop_slug',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['slug', 'created_at', 'updated_at']

    def get_variants(self, obj):
        return ProductVariantSerializer(
            obj.variants.all(),
            many=True,
            context=self.context,
        ).data


# ===================== CART =====================

class CartItemSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='product.name', read_only=True)
    slug = serializers.CharField(source='product.slug', read_only=True)
    image = serializers.SerializerMethodField()
    category_name = serializers.CharField(source='product.category.name', read_only=True)
    price = serializers.SerializerMethodField()  # ✅ ប្រើ Method
    stock = serializers.SerializerMethodField()  # ✅ ប្រើ Method
    total_price = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    variant_id = serializers.IntegerField(source='variant.id', read_only=True, allow_null=True)  # ✅
    variant_options = serializers.JSONField(source='variant.options', read_only=True, allow_null=True)  # ✅

    class Meta:
        model = CartItem
        fields = [
            'id', 'product', 'name', 'slug', 'image', 'category_name',
            'price', 'quantity', 'stock', 'total_price',
            'variant_id', 'variant_options',  # ✅ បន្ថែម
        ]

    def get_image(self, obj):
        # ✅ បើមាន Variant Image → ប្រើវា
        if obj.variant and obj.variant.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.variant.image.url)
            return obj.variant.image.url
        # ✅ បើគ្មាន → ប្រើ Product Image
        if obj.product.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.product.image.url)
            return obj.product.image.url
        return None

    def get_price(self, obj):
        # ✅ បើមាន Variant → ប្រើតម្លៃ Variant
        if obj.variant:
            return float(obj.variant.final_price)
        return float(obj.product.final_price)

    def get_stock(self, obj):
        # ✅ បើមាន Variant → ប្រើ Stock Variant
        if obj.variant:
            return obj.variant.stock
        return obj.product.stock


class CartSerializer(serializers.Serializer):
    """Summary of the whole cart: items + price calculation."""
    items = serializers.SerializerMethodField()
    subtotal = serializers.DecimalField(max_digits=10, decimal_places=2)
    shipping = serializers.DecimalField(max_digits=10, decimal_places=2)
    tax = serializers.DecimalField(max_digits=10, decimal_places=2)
    grand_total = serializers.DecimalField(max_digits=10, decimal_places=2)
    count = serializers.IntegerField()

    def get_items(self, obj):
        """✅ បញ្ជូន context ទៅ CartItemSerializer"""
        return CartItemSerializer(
            obj['items'],
            many=True,
            context=self.context
        ).data


# ===================== ORDER =====================

class OrderItemSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='product.name', read_only=True)
    slug = serializers.CharField(source='product.slug', read_only=True)
    image = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = [
            'id', 'product', 'name', 'slug', 'image',
            'quantity', 'price',
            'variant_options',  # ✅ បន្ថែមនេះ
        ]

    def get_image(self, obj):
        # ✅ បើមាន Variant Image → ប្រើវា
        if obj.variant and obj.variant.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.variant.image.url)
            return obj.variant.image.url
        # ✅ បើគ្មាន → ប្រើ Product Image
        if obj.product.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.product.image.url)
            return obj.product.image.url
        return None


# The stages an order visibly moves through, used to render an
# "Order Tracking" progress bar on the frontend.
ORDER_TRACKING_STAGES = ['pending', 'confirmed', 'shipped', 'delivered']


class OrderListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for 'My Orders' list screen."""
    item_count = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'status', 'payment_method',
            'grand_total', 'item_count', 'created_at',
        ]

    def get_item_count(self, obj):
        return obj.items.count()


class AdminOrderListSerializer(serializers.ModelSerializer):
    """
    For the staff-only Delivery/Admin screen: every order, from every
    customer, with just enough customer info to identify who it's for.
    """
    item_count = serializers.SerializerMethodField()
    customer_name = serializers.CharField(source='full_name', read_only=True)
    customer_phone = serializers.CharField(source='phone', read_only=True)
    shop_name = serializers.CharField(source='shop.name', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'status', 'payment_method',
            'customer_name', 'customer_phone', 'city', 'shop_name',
            'grand_total', 'item_count', 'created_at', 'updated_at',
        ]

    def get_item_count(self, obj):
        return obj.items.count()


class OrderDetailSerializer(serializers.ModelSerializer):
    """Full serializer for Order Detail / Order Confirmation / Order Tracking screens."""
    items = OrderItemSerializer(many=True, read_only=True)
    tracking_stages = serializers.SerializerMethodField()
    can_cancel = serializers.SerializerMethodField()
    shop_name = serializers.CharField(source='shop.name', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'status', 'payment_method',
            'full_name', 'phone', 'address', 'city', 'shop_name',
            'subtotal', 'shipping', 'tax', 'grand_total',
            'items', 'tracking_stages', 'can_cancel', 'cancellation_reason',
            'created_at', 'updated_at',
        ]

    def get_tracking_stages(self, obj):
        if obj.status == 'cancelled':
            return {"cancelled": True, "stages": ORDER_TRACKING_STAGES, "current_index": -1}
        current_index = (
            ORDER_TRACKING_STAGES.index(obj.status)
            if obj.status in ORDER_TRACKING_STAGES else 0
        )
        return {
            "cancelled": False,
            "stages": ORDER_TRACKING_STAGES,
            "current_index": current_index,
        }

    def get_can_cancel(self, obj):
        return obj.status in ('pending', 'confirmed')


# ===================== CHECKOUT =====================

class CheckoutSerializer(serializers.Serializer):
    """
    Input for POST /api/products/checkout/
    Either pass `address_id` OR pass full_name/phone/address/city manually.
    Supports dynamic coupon codes.
    """
    address_id = serializers.IntegerField(required=False)
    full_name = serializers.CharField(required=False, max_length=150)
    phone = serializers.CharField(required=False, max_length=20)
    address = serializers.CharField(required=False)
    city = serializers.CharField(required=False, max_length=100)
    payment_method = serializers.ChoiceField(choices=Order.PAYMENT_CHOICES, default='cod')

    # ✅ Coupon Code Field
    coupon_code = serializers.CharField(required=False, allow_blank=True)



    # ✅ កែ max_digits ពី 10 → 12
    customer_lat = serializers.FloatField(required=False, allow_null=True)
    customer_lng = serializers.FloatField(required=False, allow_null=True)

    def validate(self, attrs):
        # Validate address
        if not attrs.get('address_id') and not (
            attrs.get('full_name') and attrs.get('phone') and attrs.get('address')
        ):
            raise serializers.ValidationError(
                "Provide either address_id or full_name/phone/address."
            )

        # ✅ Validate Coupon (Dynamic)
                # ✅ Validate Coupon (Dynamic)
        coupon_code = attrs.get('coupon_code', '').strip()
        if coupon_code:
            try:
                from django.utils import timezone

                # ✅ ប្រើ iexact ដើម្បីស្វែងរកទាំង Uppercase និង Lowercase
                coupon = Coupon.objects.get(code__iexact=coupon_code)
                
                if not coupon.is_active:
                    raise serializers.ValidationError(
                        {"coupon_code": "This coupon is no longer active"}
                    )

                now = timezone.now()
                if now < coupon.valid_from:
                    raise serializers.ValidationError(
                        {"coupon_code": "This coupon is not yet valid"}
                    )

                if now > coupon.valid_to:
                    raise serializers.ValidationError(
                        {"coupon_code": "This coupon has expired"}
                    )

                if coupon.max_uses > 0 and coupon.used_count >= coupon.max_uses:
                    raise serializers.ValidationError(
                        {"coupon_code": "Coupon has reached its usage limit"}
                    )

                attrs['coupon'] = coupon

            except Coupon.DoesNotExist:
                raise serializers.ValidationError(
                    {"coupon_code": "Invalid coupon code"}
                )

        return attrs


    # ===================== DELIVERY SERIALIZERS =====================

class DeliveryOrderListSerializer(serializers.ModelSerializer):
    """សម្រាប់ Delivery Person មើលបញ្ជី Order"""
    item_count = serializers.SerializerMethodField()
    customer_name = serializers.CharField(source='full_name', read_only=True)
    customer_phone = serializers.CharField(source='phone', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'status', 'customer_name', 'customer_phone',
            'address', 'city', 'grand_total', 'payment_method',
            'item_count', 'created_at', 'status_updated_at',
            'delivery_lat', 'delivery_lng', 'delivery_updated_at', 'delivered_at',
        ]

    def get_item_count(self, obj):
        return obj.items.count()


class DeliveryOrderDetailSerializer(serializers.ModelSerializer):
    """សម្រាប់ Delivery Person មើលលម្អិត Order"""
    items = OrderItemSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(source='full_name', read_only=True)
    customer_phone = serializers.CharField(source='phone', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'status',
            'customer_name', 'customer_phone',
            'address', 'city',
            'subtotal', 'shipping', 'tax', 'discount_amount', 'grand_total',
            'payment_method', 'items',
            'delivery_lat', 'delivery_lng', 'delivery_updated_at', 'delivered_at',
            'created_at', 'status_updated_at',
        ]
        read_only_fields = ['order_number', 'created_at']



class OrderChatSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.full_name', read_only=True)
    sender_role = serializers.CharField(source='sender.role', read_only=True)
    sender_id = serializers.IntegerField(source='sender.id', read_only=True)
    voice_url = serializers.SerializerMethodField()

    class Meta:
        model = OrderChat
        fields = [
            'id', 'order', 'sender', 'sender_id', 'sender_name', 'sender_role',
            'message_type', 'message', 'voice_file', 'voice_url', 'voice_duration',
            'is_read', 'created_at',
        ]
        read_only_fields = ['id', 'sender', 'created_at', 'is_read']

    def get_voice_url(self, obj):
        if obj.voice_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.voice_file.url)
            return obj.voice_file.url
        return None       


# ===================== BANNER =====================

class BannerSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = Banner
        fields = [
            'id', 'title', 'subtitle', 'badge_text', 'button_text',
            'image', 'link_type', 'link_value',
        ]

    def get_image(self, obj):
        """✅ ផ្ញើ Full URL"""
        if not obj.image:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url
