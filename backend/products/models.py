from django.db import models
from django.utils import timezone 
from django.conf import settings

from django.utils.text import slugify


class Category(models.Model):
    shop = models.ForeignKey(
        'shops.Shop',
        on_delete=models.CASCADE,
        related_name='categories',
        null=True,
        blank=True,
    )
    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=120, blank=True)  # ✅ លុប unique=True ចេញ
    image = models.ImageField(upload_to='categories/', blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Categories"
        ordering = ['name']
        unique_together = ['shop', 'name']

    def save(self, *args, **kwargs):
        """បង្កើត slug តែមួយគត់សម្រាប់ហាងនីមួយៗ"""
        if not self.slug:
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            # ✅ ពិនិត្យ slug តែក្នុងហាងតែមួយ
            while Category.objects.filter(
                shop=self.shop, slug=slug
            ).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.shop.name if self.shop else 'No Shop'})"


class Product(models.Model):
    shop = models.ForeignKey(  # ✅ បន្ថែមនេះ
        'shops.Shop',
        on_delete=models.CASCADE,
        related_name='products',
        null=True,
        blank=True,
    )
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='products')
    name = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220, unique=True, blank=True)
    description = models.TextField(blank=True)

    price = models.DecimalField(max_digits=10, decimal_places=2)
    discount_price = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)

    image = models.ImageField(upload_to='products/', blank=True, null=True)
    stock = models.PositiveIntegerField(default=0)

    # --- Tags that drive Home screen sections (Recommended / Best Seller / New) ---
    is_new_arrival = models.BooleanField(default=False)
    is_best_seller = models.BooleanField(default=False)
    is_recommended = models.BooleanField(default=False)

    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    sold_count = models.PositiveIntegerField(default=0)

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while Product.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        super().save(*args, **kwargs)

    @property
    def in_stock(self):
        return self.stock > 0

    @property
    def final_price(self):
        return self.discount_price if self.discount_price else self.price

    @property
    def discount_percent(self):
        if self.discount_price and self.price and self.discount_price < self.price:
            return round((1 - (self.discount_price / self.price)) * 100)
        return 0

    def __str__(self):
        return self.name


class ProductImage(models.Model):
    """Extra gallery images for a product (in addition to the main `image` above)."""
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='gallery_images')
    image = models.ImageField(upload_to='products/gallery/')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image for {self.product.name}"

# ===================== WISHLIST =====================
class Wishlist(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='wishlists')
    product = models.ForeignKey(
        Product, on_delete=models.CASCADE,
        related_name='wishlisted_by')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['user', 'product']   # 1 user 1 product តែម្តង
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} ♥ {self.product.name}"


# ===================== CART =====================
class CartItem(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='cart_items')
    product = models.ForeignKey(
        Product, on_delete=models.CASCADE,
        related_name='in_carts')
    variant = models.ForeignKey(  # ✅ បន្ថែមនេះ
        'ProductVariant',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='cart_items',
    )
    quantity = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['user', 'product', 'variant']  # ✅ បន្ថែម variant
        ordering = ['-created_at']

    @property
    def total_price(self):
        if self.variant:
            return self.variant.final_price * self.quantity
        return self.product.final_price * self.quantity

    def __str__(self):
        return f"{self.user.email} - {self.product.name} x{self.quantity}"


# ===================== ORDERS =====================

class Coupon(models.Model):
    shop = models.ForeignKey(  # ✅ បន្ថែម Field នេះ
        'shops.Shop',
        on_delete=models.CASCADE,
        related_name='coupons',
        null=True,
        blank=True,
        help_text="ហាងដែលជាម្ចាស់ Coupon នេះ (ទុកទំនេរ = សម្រាប់ Super Admin)"
    )
    code = models.CharField(
        max_length=50,
        unique=True,
        help_text="កូដបញ្ចុះតម្លៃ (ឧទាហរណ៍: SAVE10, HH11)"
    )
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        help_text="ចំនួនទឹកប្រាក់ដែលបញ្ចុះ"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="តើកូដនេះកំពុងដំណើរការឬអត់?"
    )
    valid_from = models.DateTimeField(help_text="កាលបរិច្ឆេទចាប់ផ្តើម")
    valid_to = models.DateTimeField(help_text="កាលបរិច្ឆេទផុតកំណត់")
    min_order_amount = models.DecimalField(
        max_digits=10, decimal_places=2, default=0,
        help_text="ចំនួនទឹកប្រាក់អប្បបរមា (0 = គ្មានកំណត់)"
    )
    max_uses = models.PositiveIntegerField(
        default=0,
        help_text="ចំនួនអតិបរមានៃការប្រើប្រាស់ (0 = គ្មានកំណត់)"
    )
    used_count = models.PositiveIntegerField(
        default=0,
        help_text="ចំនួនដងដែលបានប្រើរួច"
    )
    created_at = models.DateTimeField(auto_now_add=True, null=True)
    updated_at = models.DateTimeField(auto_now=True, null=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Coupon"
        verbose_name_plural = "Coupons"

    def __str__(self):
        return f"{self.code} (-${self.discount_amount})"

    @property
    def is_available(self):
        if not self.is_active:
            return False
        now = timezone.now()
        if not (self.valid_from <= now <= self.valid_to):
            return False
        if self.max_uses > 0 and self.used_count >= self.max_uses:
            return False
        return True
    
class Order(models.Model):
    shop = models.ForeignKey(  # ✅ បន្ថែមនេះ
        'shops.Shop',
        on_delete=models.CASCADE,
        related_name='orders',
        null=True,
        blank=True,
    )

    delivery_fee = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.50,  # ✅ $0.50 ក្នុងមួយ Order
        help_text="កម្រៃដែល Delivery Person ទទួលបាន"
    )
    is_delivery_paid = models.BooleanField(
        default=False,
        help_text="តើបានបើកប្រាក់ឱ្យ Delivery ហើយឬនៅ?"
    )
    delivery_paid_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="ពេលវេលាដែលបានបើកប្រាក់"
    )

    # ✅ កែ max_digits ពី 10 → 12
    customer_lat = models.FloatField(null=True, blank=True)
    customer_lng = models.FloatField(null=True, blank=True)
    delivery_lat = models.FloatField(null=True, blank=True)
    delivery_lng = models.FloatField(null=True, blank=True)

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('shipped', 'Shipped'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]
    PAYMENT_CHOICES = [
    ('cod', 'Cash on Delivery'),
    ('aba', 'ABA Pay'),
    ('acleda', 'ACLEDA'),
    ('bakong', 'Bakong (KHQR)'),


    
]


    order_number = models.CharField(max_length=20, unique=True, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='orders')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    payment_method = models.CharField(max_length=20, choices=PAYMENT_CHOICES, default='cod')

    # Address info
    full_name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20)
    address = models.TextField()
    city = models.CharField(max_length=50, default='Phnom Penh')

    # Totals (snapshot ពេលបង្កើត order)
    subtotal = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    shipping = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    grand_total = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    cancellation_reason = models.CharField(max_length=255, blank=True)


    # ✅ បន្ថែម Field ថ្មីសម្រាប់ Delivery
    delivery_person = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='delivery_orders',
        help_text="អ្នកដឹកជញ្ជូនដែលទទួលបន្ទុក Order នេះ"
    )
    delivery_lat = models.DecimalField(
        max_digits=10, decimal_places=7,
        null=True, blank=True,
        help_text="រយៈទទឹង GPS បច្ចុប្បន្នរបស់អ្នកដឹក"
    )
    delivery_lng = models.DecimalField(
        max_digits=10, decimal_places=7,
        null=True, blank=True,
        help_text="រយៈបណ្តោយ GPS បច្ចុប្បន្នរបស់អ្នកដឹក"
    )
    delivery_updated_at = models.DateTimeField(
        null=True, blank=True,
        help_text="ពេលវេលាចុងក្រោយដែល Update GPS"
    )
    delivered_at = models.DateTimeField(
        null=True, blank=True,
        help_text="ពេលវេលាដែលដឹកជញ្ជូនរួច"
    )


    # coupon discount
    coupon = models.ForeignKey(Coupon, on_delete=models.SET_NULL, null=True, blank=True)
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    # Timer when oder
    status_updated_at = models.DateTimeField(auto_now=True) 

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.order_number:
            import uuid
            self.order_number = f"ORD-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.order_number} - {self.user.email}"


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order, on_delete=models.CASCADE,
        related_name='items')
    product = models.ForeignKey(  # ✅ កែនៅទីនេះ
        Product,
        on_delete=models.SET_NULL,  # ✅ ប្តូរពី PROTECT ទៅ SET_NULL
        null=True, blank=True,       # ✅ បន្ថែមនេះ
    )
    variant = models.ForeignKey(
        'ProductVariant',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='order_items',
    )
    variant_options = models.JSONField(
        default=dict, blank=True,
        help_text='ឧ. {"Color": "ក្រហម"}',
    )
    quantity = models.PositiveIntegerField(default=1)
    price = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        # ✅ ពិនិត្យ product ថា null មែនទេ
        product_name = self.product.name if self.product else "Deleted Product"
        return f"{product_name} x{self.quantity}"

    # ===================== PRODUCT VARIANTS =====================

class ProductOption(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='options',
    )
    name = models.CharField(max_length=50, help_text="ឧ. Color, Size, Storage")
    position = models.PositiveIntegerField(default=0, help_text="លំដាប់បង្ហាញ")

    class Meta:
        ordering = ['position']
        unique_together = ['product', 'name']

    def __str__(self):
        return f"{self.product.name} - {self.name}"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # ✅ បង្កើត Variants ដោយស្វ័យប្រវត្តិ
        self._auto_generate_variants()

    def _auto_generate_variants(self):
        """បង្កើត Variants ដោយស្វ័យប្រវត្តិពី Options ទាំងអស់"""
        from itertools import product as itertools_product
        
        # រក Options ទាំងអស់របស់ Product
        options = ProductOption.objects.filter(product=self.product).prefetch_related('values')
        
        if not options.exists():
            return
        
        # បង្កើតបន្សំ Options ទាំងអស់
        option_names = [opt.name for opt in options]
        option_values = [list(opt.values.values_list('value', flat=True)) for opt in options]
        
        if not all(option_values):
            return  # បើ Options ណាមួយគ្មាន Values → មិនបង្កើត
        
        combinations = list(itertools_product(*option_values))
        
        for combo in combinations:
            options_dict = dict(zip(option_names, combo))
            
            # ពិនិត្យថាតើ Variant នេះមានរួចហើយឬអត់
            exists = ProductVariant.objects.filter(
                product=self.product,
                options=options_dict,
            ).exists()
            
            if not exists:
                ProductVariant.objects.create(
                    product=self.product,
                    options=options_dict,
                    stock=self.product.stock,
                    price=self.product.price,
                    is_active=True,
                )


class ProductOptionValue(models.Model):
    option = models.ForeignKey(
        ProductOption,
        on_delete=models.CASCADE,
        related_name='values',
    )
    value = models.CharField(max_length=50, help_text="ឧ. ក្រហម, S, M, L")
    position = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['position']
        unique_together = ['option', 'value']

    def __str__(self):
        return f"{self.option.name}: {self.value}"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # ✅ Update Variants ពេលបន្ថែម Value
        self.option._auto_generate_variants()


class ProductVariant(models.Model):
    """
    បន្សំ Variant ជាក់លាក់ (ឧ. ក្រហម + S) ជាមួយ Stock និង Price ផ្ទាល់ខ្លួន
    """
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='variants',
    )
    # ឧ. {"Color": "ក្រហម", "Size": "S"}
    options = models.JSONField(
        default=dict,
        help_text='ឧ. {"Color": "ក្រហម", "Size": "S"}',
    )
    stock = models.PositiveIntegerField(default=0)
    price = models.DecimalField(
        max_digits=10, decimal_places=2,
        null=True, blank=True,
        help_text="តម្លៃផ្ទាល់ខ្លួន (បើ null → ប្រើតម្លៃ Product ដើម)",
    )
    sku = models.CharField(max_length=100, blank=True, help_text="លេខកូដ Variant")
    image = models.ImageField(
        upload_to='variants/', blank=True, null=True,
        help_text="រូបភាពផ្ទាល់ខ្លួន (បើ null → ប្រើរូបភាព Product ដើម)",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['id']

    def __str__(self):
        options_str = ', '.join([f"{k}: {v}" for k, v in self.options.items()])
        return f"{self.product.name} ({options_str})"

    @property
    def final_price(self):
        return self.price if self.price else self.product.final_price

    @property
    def in_stock(self):
        return self.stock > 0


class DeliveryEarning(models.Model):
    """កំណត់ត្រាចំណូលរបស់ Delivery Person"""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('paid', 'Paid'),
        ('cancelled', 'Cancelled'),
    ]

    delivery_person = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='delivery_earnings',
    )
    order = models.OneToOneField(
        Order,
        on_delete=models.CASCADE,
        related_name='delivery_earning',
    )
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="ចំនួនទឹកប្រាក់ដែលទទួលបាន"
    )
    base_fee = models.DecimalField(
        max_digits=10, decimal_places=2, default=0.50,
        help_text="កម្រៃគោលក្នុងមួយ Order"
    )
    tip = models.DecimalField(
        max_digits=10, decimal_places=2, default=0,
        help_text="ប្រាក់រង្វាន់ពី Customer"
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
    )
    earned_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-earned_at']

    def __str__(self):
        return f"{self.delivery_person.email} - ${self.amount}"    


class OrderChat(models.Model):
    """Chat Message រវាង Customer និង Delivery Person"""
    MESSAGE_TYPE_CHOICES = [
        ('text', 'Text'),
        ('voice', 'Voice'),
        ('image', 'Image'),
    ]
    
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='chats',
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='order_chats',
    )
    message_type = models.CharField(
        max_length=10,
        choices=MESSAGE_TYPE_CHOICES,
        default='text',
    )
    message = models.TextField(blank=True)
    voice_file = models.FileField(
        upload_to='chat_voice/',
        null=True, blank=True,
    )
    voice_duration = models.PositiveIntegerField(
        default=0,
        help_text="Duration in seconds",
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.sender.email}: {self.message[:50]}"   


class Banner(models.Model):
    """Banner ស្លាយនៅទំព័រ Home របស់ App (ដាក់តាម Shop នីមួយៗ)"""
    LINK_CHOICES = [
        ('none', 'No link (open Shop)'),
        ('category', 'Category'),
        ('product', 'Product'),
    ]

    shop = models.ForeignKey(
        'shops.Shop',
        on_delete=models.CASCADE,
        related_name='banners',
        null=True,
        blank=True,
    )
    title = models.CharField(max_length=120, blank=True)
    subtitle = models.CharField(max_length=160, blank=True)
    badge_text = models.CharField(max_length=40, blank=True)
    button_text = models.CharField(max_length=40, default='Shop Now')
    image = models.ImageField(
        upload_to='banners/',
        help_text='Recommended size: 1200 x 500 px',
    )
    link_type = models.CharField(max_length=10, choices=LINK_CHOICES, default='none')
    link_value = models.CharField(
        max_length=220, blank=True,
        help_text='Category slug ឬ Product slug (តាម Link type)',
    )
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['sort_order', '-created_at']

    def __str__(self):
        return self.title or f'Banner #{self.pk}'
