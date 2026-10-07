from django.db import models
import requests as http_requests 
from django.db import transaction
from django.db.models import Sum 
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, viewsets
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from rest_framework.response import Response
from decimal import Decimal
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser



from django.utils import timezone
from datetime import timedelta
from .telegram_service import TelegramService


from accounts.models import ShippingAddress
from .models import Banner, Category, Product, ProductVariant, Wishlist, CartItem, Order, OrderItem, Coupon
from .filters import ProductFilter
from .permissions import IsAdminOrReadOnly
from .serializers import (
    BannerSerializer,
    CategorySerializer,
    DeliveryOrderDetailSerializer,
    OrderChatSerializer,
    ProductListSerializer,
    ProductDetailSerializer,
    CartItemSerializer,
    CartSerializer,
    OrderListSerializer,
    OrderDetailSerializer,
    CheckoutSerializer,
    AdminOrderListSerializer,
    DeliveryOrderListSerializer,
    DeliveryOrderDetailSerializer,
)


# ===================== CATEGORIES & PRODUCTS =====================

# ===================== CATEGORIES =====================

class CategoryViewSet(viewsets.ModelViewSet):
    serializer_class = CategorySerializer
    permission_classes = [AllowAny]
    lookup_field = 'slug'

    def get_queryset(self):
        qs = Category.objects.filter(is_active=True).select_related('shop')

        # ✅ បើមាន ?shop= → Filter តាម Shop នោះ
        shop_slug = self.request.query_params.get('shop')
        if shop_slug:
            return qs.filter(shop__slug=shop_slug)

        # ✅ បើគ្មាន ?shop= → Filter តាម User
        user = getattr(self.request, 'user', None)
        if user is not None and user.is_authenticated:
            if getattr(user, 'is_superuser', False):
                try:
                    from shops.models import Shop
                    super_admin_shop = Shop.get_super_admin_shop()
                    return qs.filter(shop=super_admin_shop)
                except Exception:
                    return qs.none()
            if getattr(user, 'is_shop_owner', False):
                try:
                    return qs.filter(shop=user.shop)
                except Exception:
                    return qs.none()

        # ✅ Public default → បង្ហាញតែ Super Admin Shop
        from shops.models import Shop
        try:
            super_admin_shop = Shop.get_super_admin_shop()
            return qs.filter(shop=super_admin_shop)
        except Exception:
            return qs


# ===================== BANNERS =====================

class BannerViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/products/banners/?shop=<slug>  (Public)"""
    serializer_class = BannerSerializer
    permission_classes = [AllowAny]
    pagination_class = None  # ត្រឡប់ list ផ្ទាល់

    def get_queryset(self):
        qs = Banner.objects.filter(is_active=True).select_related('shop')

        shop_slug = self.request.query_params.get('shop')
        if shop_slug:
            return qs.filter(shop__slug=shop_slug)

        user = getattr(self.request, 'user', None)
        if user is not None and user.is_authenticated and getattr(user, 'is_shop_owner', False):
            try:
                return qs.filter(shop=user.shop)
            except Exception:
                return qs.none()

        from shops.models import Shop
        try:
            return qs.filter(shop=Shop.get_super_admin_shop())
        except Exception:
            return qs


# ===================== PRODUCTS =====================

class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductListSerializer
    permission_classes = [AllowAny]
    lookup_field = 'slug'

    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = ProductFilter
    search_fields = ['name', 'description']
    ordering_fields = ['price', 'created_at', 'sold_count', 'rating']

    def get_queryset(self):
        qs = Product.objects.filter(is_active=True).select_related('category', 'shop')
        user = getattr(self.request, 'user', None)
        shop_slug = self.request.query_params.get('shop')

        # ✅ បើជា Detail View (retrieve) → ស្វែងរកគ្រប់ Shop
        if self.action == 'retrieve':
            return qs

        # ✅ បើមាន ?shop= → Filter តាម Shop នោះ
        if shop_slug:
            return qs.filter(shop__slug=shop_slug)

        # ✅ បើជា List View → Filter តាម User
        if user is not None and user.is_authenticated:
            if getattr(user, 'is_superuser', False):
                try:
                    from shops.models import Shop
                    super_admin_shop = Shop.get_super_admin_shop()
                    return qs.filter(shop=super_admin_shop)
                except Exception:
                    return qs.none()
            if getattr(user, 'is_shop_owner', False):
                try:
                    return qs.filter(shop=user.shop)
                except Exception:
                    return qs.none()

        # ✅ Public default → បង្ហាញតែ Super Admin Shop
        from shops.models import Shop
        try:
            super_admin_shop = Shop.get_super_admin_shop()
            return qs.filter(shop=super_admin_shop)
        except Exception:
            return qs

    def get_serializer_class(self):
        if self.action == 'list':
            return ProductListSerializer
        return ProductDetailSerializer


# ===================== WISHLIST =====================

class WishlistToggleView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, slug):
        try:
            product = Product.objects.get(slug=slug)
        except Product.DoesNotExist:
            return Response({"error": "Product not found"}, status=status.HTTP_404_NOT_FOUND)

        wish, created = Wishlist.objects.get_or_create(user=request.user, product=product)
        if not created:
            wish.delete()
            return Response({"wishlisted": False})
        return Response({"wishlisted": True})


class WishlistListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        items = (Wishlist.objects.filter(user=request.user)
                 .select_related('product', 'product__category')
                 .order_by('-created_at'))
        return Response(
            ProductListSerializer([w.product for w in items], many=True).data
        )


# ===================== CART =====================

def _cart_summary(user):
    items = CartItem.objects.filter(user=user).select_related('product', 'product__category')
    subtotal = sum((i.total_price for i in items), Decimal('0'))
    shipping = Decimal('2.00') if subtotal > 0 else Decimal('0')
    tax = round(subtotal * Decimal('0.01'), 2)  # ✅ 1%
    return {
        "items": items,
        "subtotal": subtotal,
        "shipping": shipping,
        "tax": tax,
        "grand_total": round(subtotal + shipping + tax, 2),
        "count": items.count(),
    }


class CartView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # ✅ បញ្ជូន request ទៅ Serializer
        serializer = CartSerializer(
            _cart_summary(request.user),
            context={'request': request}
        )
        return Response(serializer.data)


class CartAddView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        slug = request.data.get('slug')
        variant_id = request.data.get('variant_id')  # ✅ បន្ថែមនេះ
        quantity = int(request.data.get('quantity', 1))
        
        try:
            product = Product.objects.get(slug=slug, is_active=True)
        except Product.DoesNotExist:
            return Response({"error": "Product not found"}, status=status.HTTP_404_NOT_FOUND)

        # ✅ រក Variant បើមាន
        variant = None
        if variant_id:
            try:
                variant = ProductVariant.objects.get(id=variant_id, product=product)
            except ProductVariant.DoesNotExist:
                return Response({"error": "Variant not found"}, status=status.HTTP_404_NOT_FOUND)

        # ✅ ពិនិត្យ Stock
        available_stock = variant.stock if variant else product.stock
        if available_stock <= 0:
            return Response({"error": "This item is out of stock."}, status=400)

        item, created = CartItem.objects.get_or_create(
            user=request.user, product=product, variant=variant,
            defaults={"quantity": quantity},
        )
        if not created:
            item.quantity += quantity

        if item.quantity > available_stock:
            return Response(
                {"error": f"Only {available_stock} item(s) in stock."},
                status=400
            )

        item.save()
        return Response(
            {"message": "Added to cart",
             "count": CartItem.objects.filter(user=request.user).count()},
            status=status.HTTP_201_CREATED,
        )

class CartItemUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        """Update quantity"""
        try:
            item = CartItem.objects.get(pk=pk, user=request.user)
        except CartItem.DoesNotExist:
            return Response({"error": "Item not found"}, status=status.HTTP_404_NOT_FOUND)

        quantity = int(request.data.get('quantity', 1))
        if quantity <= 0:
            item.delete()
            return Response({"message": "Item removed"})

        if quantity > item.product.stock:
            return Response({"error": f"Only {item.product.stock} item(s) in stock."}, status=400)

        item.quantity = quantity
        item.save()
        return Response(CartItemSerializer(item).data)

    def delete(self, request, pk):
        """✅ បន្ថែម Method DELETE ក្នុង Class តែមួយ"""
        try:
            item = CartItem.objects.get(pk=pk, user=request.user)
        except CartItem.DoesNotExist:
            return Response({"error": "Item not found"}, status=status.HTTP_404_NOT_FOUND)
        
        item.delete()
        return Response(
            {"message": "Item deleted successfully"},
            status=status.HTTP_200_OK
        )


class CartItemDeleteView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        try:
            item = CartItem.objects.get(pk=pk, user=request.user)
        except CartItem.DoesNotExist:
            return Response(
                {"error": "Item not found in your cart."},
                status=status.HTTP_404_NOT_FOUND
            )
        
        item.delete()
        return Response(
            {"message": "Item deleted successfully", "count": CartItem.objects.filter(user=request.user).count()},
            status=status.HTTP_200_OK
        )


# ==================== VALIDATE COUPON ====================

class ValidateCouponView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        code = request.data.get('code', '').strip()
        
        if not code:
            return Response({
                "valid": False,
                "error": "Please enter a coupon code"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # ✅ ប្រើ iexact ដើម្បីស្វែងរកទាំង Uppercase និង Lowercase
            coupon = Coupon.objects.get(code__iexact=code)
        except Coupon.DoesNotExist:
            return Response({
                "valid": False,
                "error": "Invalid coupon code"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if not coupon.is_active:
            return Response({
                "valid": False,
                "error": "This coupon is no longer active"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        now = timezone.now()
        if now < coupon.valid_from:
            return Response({
                "valid": False,
                "error": "This coupon is not yet valid"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if now > coupon.valid_to:
            return Response({
                "valid": False,
                "error": "This coupon has expired"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if coupon.max_uses > 0 and coupon.used_count >= coupon.max_uses:
            return Response({
                "valid": False,
                "error": "Coupon has reached its usage limit"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if coupon.min_order_amount > 0:
            cart_total = sum(
                (i.total_price for i in CartItem.objects.filter(user=request.user)),
                Decimal('0')
            )
            if cart_total < coupon.min_order_amount:
                return Response({
                    "valid": False,
                    "error": f"Minimum order amount is ${coupon.min_order_amount}"
                }, status=status.HTTP_400_BAD_REQUEST)
        
        return Response({
            "valid": True,
            "code": coupon.code,
            "discount_amount": float(coupon.discount_amount),
            "message": f"Coupon applied! You save ${coupon.discount_amount}"
        })


# ==================== CHECKOUT ====================

# products/views.py

class CheckoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        cart_items = list(
            CartItem.objects.filter(user=request.user)
            .select_related('product', 'variant')
        )
        if not cart_items:
            return Response(
                {"error": "Your cart is empty."},
                status=status.HTTP_400_BAD_REQUEST
            )

        for item in cart_items:
            available = item.variant.stock if item.variant else item.product.stock
            if item.quantity > available:
                return Response(
                    {"error": f"'{item.product.name}' only has {available} left in stock."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # ✅ បន្ថែម Variable ថ្មីសម្រាប់ GPS
        customer_lat = None
        customer_lng = None

        if data.get('address_id'):
            try:
                addr = ShippingAddress.objects.get(pk=data['address_id'], user=request.user)
            except ShippingAddress.DoesNotExist:
                return Response(
                    {"error": "Shipping address not found."},
                    status=status.HTTP_404_NOT_FOUND
                )
            full_name = addr.full_name
            phone = addr.phone_number
            address = addr.address_line
            city = addr.city
            # ✅ ទាញ GPS ពី Address
            customer_lat = addr.latitude
            customer_lng = addr.longitude
        else:
            full_name = data['full_name']
            phone = data['phone']
            address = data['address']
            city = data.get('city') or 'Phnom Penh'
            # ✅ ទាញ GPS ពី Request
            customer_lat = data.get('customer_lat')
            customer_lng = data.get('customer_lng')

        summary = _cart_summary(request.user)

        discount = Decimal('0')
        coupon = data.get('coupon')
        if coupon:
            discount = coupon.discount_amount

        grand_total = summary['grand_total'] - discount
        if grand_total < 0:
            grand_total = Decimal('0')

        # ✅ យក Shop ពី Product ដំបូង
        shop = cart_items[0].product.shop

        with transaction.atomic():
            order = Order.objects.create(
                user=request.user,
                shop=shop,
                payment_method=data['payment_method'],
                full_name=full_name,
                phone=phone,
                address=address,
                city=city,
                subtotal=summary['subtotal'],
                shipping=summary['shipping'],
                tax=summary['tax'],
                coupon=coupon,
                discount_amount=discount,
                grand_total=grand_total,
                # ✅ Save GPS Location
                customer_lat=customer_lat,
                customer_lng=customer_lng,
            )
            for item in cart_items:
                unit_price = item.variant.final_price if item.variant else item.product.final_price
                variant_options = item.variant.options if item.variant else {}

                OrderItem.objects.create(
                    order=order,
                    product=item.product,
                    variant=item.variant,
                    variant_options=variant_options,
                    quantity=item.quantity,
                    price=unit_price,
                )

                if item.variant:
                    item.variant.stock -= item.quantity
                    item.variant.save(update_fields=['stock'])
                else:
                    item.product.stock -= item.quantity
                item.product.sold_count += item.quantity
                item.product.save(update_fields=['stock', 'sold_count'])

            if coupon:
                coupon.used_count += 1
                coupon.save(update_fields=['used_count'])

            cart_items_ids = [i.id for i in cart_items]
            CartItem.objects.filter(id__in=cart_items_ids).delete()

        # ✅ ផ្ញើ Telegram Notification
        try:
            TelegramService.notify_new_order(order)
        except Exception as e:
            print(f"⚠️ Telegram notification failed: {e}")

        return Response(OrderDetailSerializer(order).data, status=status.HTTP_201_CREATED)



    


class OrderListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Order.objects.filter(user=request.user).prefetch_related('items')
        status_filter = request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response(OrderListSerializer(qs, many=True).data)


class OrderDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, order_number):
        try:
            order = Order.objects.prefetch_related('items').get(
                order_number=order_number, user=request.user)
        except Order.DoesNotExist:
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(OrderDetailSerializer(order).data)


class OrderCancelView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, order_number):
        try:
            order = Order.objects.prefetch_related('items').get(
                order_number=order_number, user=request.user)
        except Order.DoesNotExist:
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)

        if order.status not in ('pending', 'confirmed'):
            return Response(
                {"error": f"An order that is already '{order.status}' can no longer be cancelled."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reason = request.data.get('reason', '')

        with transaction.atomic():
            for item in order.items.all():
                item.product.stock += item.quantity
                item.product.save(update_fields=['stock'])
            order.status = 'cancelled'
            order.cancellation_reason = reason
            order.save(update_fields=['status', 'cancellation_reason'])

        return Response(OrderDetailSerializer(order).data)


DELIVERY_STATUS_FLOW = ['pending', 'confirmed', 'shipped', 'delivered']


class AdminOrderListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        qs = Order.objects.select_related('user').prefetch_related('items').all()
        status_filter = request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response(AdminOrderListSerializer(qs, many=True).data)


DELIVERY_MIN_WAIT_MINUTES = 5


class AdminOrderStatusUpdateView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, order_number):
        try:
            order = Order.objects.prefetch_related('items').get(order_number=order_number)
        except Order.DoesNotExist:
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        if new_status not in ('shipped', 'delivered', 'cancelled'):
            return Response(
                {"error": "Status must be one of 'shipped', 'delivered', 'cancelled'."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.status in ('delivered', 'cancelled'):
            return Response(
                {"error": f"This order is already '{order.status}' and can no longer be changed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_status == 'shipped':
            if order.status != 'pending':
                return Response(
                    {"error": f"Order is already '{order.status}'."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            order.status = 'shipped'
            order.save(update_fields=['status', 'updated_at'])
            return Response(OrderDetailSerializer(order).data)

        if new_status == 'delivered':
            if order.status != 'shipped':
                return Response(
                    {"error": "Order must be 'shipped' before it can be marked delivered."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            elapsed = timezone.now() - order.updated_at
            remaining = timedelta(minutes=DELIVERY_MIN_WAIT_MINUTES) - elapsed
            if remaining.total_seconds() > 0:
                remaining_seconds = int(remaining.total_seconds())
                return Response(
                    {
                        "error": f"Too early — wait {remaining_seconds}s more before confirming arrival.",
                        "remaining_seconds": remaining_seconds,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            order.status = 'delivered'
            order.save(update_fields=['status', 'updated_at'])
            return Response(OrderDetailSerializer(order).data)

        if new_status == 'cancelled':
            if order.status not in ('pending', 'shipped'):
                return Response(
                    {"error": f"Order at '{order.status}' can no longer be cancelled."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            with transaction.atomic():
                for item in order.items.all():
                    item.product.stock += item.quantity
                    item.product.save(update_fields=['stock'])
                order.status = 'cancelled'
                order.save(update_fields=['status', 'updated_at'])
            return Response(OrderDetailSerializer(order).data)

        # ==================== ABA PAYWAY ====================

from .aba_payway_service import AbaPaywayService


class AbaGenerateQRView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        tran_id = request.data.get('tran_id')

        if not amount or not tran_id:
            return Response(
                {"error": "amount and tran_id are required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = request.user
            result = AbaPaywayService.generate_qr(
                amount=float(amount),
                tran_id=tran_id,
                first_name=user.first_name or "Customer",
                last_name=user.last_name or "User",
                email=user.email or "test@example.com",
                phone=getattr(user, 'phone_number', '') or "012345678",
                callback_url="https://gecko-deploy-subtext.ngrok-free.dev/api/products/aba/callback/",
            )

            # ✅ Debug: បង្ហាញ Result ទាំងមូល
            print(f"🔵 Full ABA Result: {result}")

            status_code = str(result.get('status', {}).get('code'))

            # ✅ ABA ឆ្លើយ "code": "0" (String មួយខ្ទង់) ពេល Success
            # មិនមែន "00" ឬ integer 0 ទេ — ត្រូវប្រៀបធៀបជា string "0"
            if status_code == '0':
                return Response({
                    "success": True,
                    # ✅ ABA ឆ្លើយជា camelCase: qrString / qrImage
                    "qr_string": result.get('qrString'),
                    "qr_image": result.get('qrImage'),
                    "abapay_deeplink": result.get('abapay_deeplink'),
                    "tran_id": tran_id,
                    "amount": amount,
                })
            else:
                return Response({
                    "success": False,
                    "error": result.get('status', {}).get('message', 'Unknown error'),
                    "raw": result,
                }, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            import traceback
            print(f"❌ ABA Exception: {traceback.format_exc()}")
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class AbaCheckTransactionView(APIView):
    """
    POST /api/products/aba/check-transaction/
    ពិនិត្យថាតើ User បង់ប្រាក់ហើយឬនៅ
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        tran_id = request.data.get('tran_id')

        if not tran_id:
            return Response(
                {"error": "tran_id is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            result = AbaPaywayService.check_transaction(tran_id)

            # Check status
            data = result.get('data', {})
            payment_status = data.get('payment_status', 'PENDING')

            return Response({
                "success": True,
                "payment_status": payment_status,  # APPROVED / PENDING / REJECTED
                "is_paid": payment_status == 'APPROVED',
                "raw": result,
            })

        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class AbaCallbackView(APIView):
    """
    POST /api/products/aba/callback/
    ABA ហៅ URL នេះពេលបង់ប្រាក់ជោគជ័យ
    """
    permission_classes = [AllowAny]

    def post(self, request):
        print(f"🔔 ABA Callback Received: {request.data}")
        # ទីនេះអ្នកអាច Update Order Status
        return Response({"status": "ok"})


# ==================== DELIVERY VIEWS ====================

class DeliveryOrderListView(APIView):
    """
    GET /api/products/delivery/orders/
    បង្ហាញ Order ដែល Assign ឱ្យ Delivery Person នេះ
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        if user.role != 'delivery' and not user.is_superuser:
            return Response(
                {"error": "You are not a delivery person."},
                status=status.HTTP_403_FORBIDDEN
            )

        # ✅ Super Admin ឃើញ Order ទាំងអស់
        if user.is_superuser:
            qs = Order.objects.all()
        else:
            qs = Order.objects.filter(delivery_person=user)

        qs = qs.select_related('user').prefetch_related('items').order_by('-created_at')

        status_filter = request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)

        return Response(DeliveryOrderListSerializer(qs, many=True).data)


class DeliveryOrderDetailView(APIView):
    """
    GET /api/products/delivery/orders/<order_number>/
    មើលលម្អិត Order
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, order_number):
        user = request.user

        # ✅ Super Admin អាចមើល Order ណាក៏បាន
        if user.is_superuser:
            try:
                order = Order.objects.prefetch_related('items').get(
                    order_number=order_number
                )
            except Order.DoesNotExist:
                return Response(
                    {"error": "Order not found."},
                    status=status.HTTP_404_NOT_FOUND
                )
        else:
            # ✅ Delivery Person មើលតែ Order ដែល Assign ឱ្យគាត់
            try:
                order = Order.objects.prefetch_related('items').get(
                    order_number=order_number,
                    delivery_person=user
                )
            except Order.DoesNotExist:
                return Response(
                    {"error": "Order not found or not assigned to you."},
                    status=status.HTTP_404_NOT_FOUND
                )

        return Response(DeliveryOrderDetailSerializer(order).data)


# products/views.py

class DeliveryOrderStatusUpdateView(APIView):
    """
    POST /api/products/delivery/orders/<order_number>/status/
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, order_number):
        user = request.user

        # ✅ រក Order
        if user.is_superuser:
            try:
                order = Order.objects.get(order_number=order_number)
            except Order.DoesNotExist:
                return Response(
                    {"error": "Order not found."},
                    status=status.HTTP_404_NOT_FOUND
                )
        else:
            try:
                order = Order.objects.get(
                    order_number=order_number,
                    delivery_person=user
                )
            except Order.DoesNotExist:
                return Response(
                    {"error": "Order not found or not assigned to you."},
                    status=status.HTTP_404_NOT_FOUND
                )

        new_status = request.data.get('status')
        allowed = ('shipped', 'delivered', 'cancelled')
        if new_status not in allowed:
            return Response(
                {"error": f"Status must be one of {allowed}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.status in ('delivered', 'cancelled'):
            return Response(
                {"error": f"This order is already '{order.status}'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ✅ Flow ត្រឹមត្រូវ
        if new_status == 'shipped':
            if order.status not in ('pending', 'confirmed'):
                return Response(
                    {"error": "Order must be 'pending' or 'confirmed' before 'shipped'."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            order.status = 'shipped'
            if not order.delivery_person and not user.is_superuser:
                order.delivery_person = user
            order.save(update_fields=['status', 'delivery_person', 'updated_at'])

        elif new_status == 'delivered':
            if order.status != 'shipped':
                return Response(
                    {"error": "Order must be 'shipped' before 'delivered'."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            order.status = 'delivered'
            order.delivered_at = timezone.now()
            order.save(update_fields=['status', 'delivered_at', 'updated_at'])

            # ✅ បង្កើត DeliveryEarning ស្វ័យប្រវត្តិ
            if order.delivery_person:
                from .models import DeliveryEarning
                DeliveryEarning.objects.get_or_create(
                    order=order,
                    defaults={
                        'delivery_person': order.delivery_person,
                        'amount': order.delivery_fee,  # ✅ $0.50
                        'base_fee': order.delivery_fee,
                        'status': 'pending',
                    }
                )

        elif new_status == 'cancelled':
            reason = request.data.get('reason', '')
            with transaction.atomic():
                for item in order.items.all():
                    if item.product:
                        item.product.stock += item.quantity
                        item.product.save(update_fields=['stock'])
                order.status = 'cancelled'
                order.cancellation_reason = reason
                order.save(update_fields=['status', 'cancellation_reason', 'updated_at'])

        return Response(DeliveryOrderDetailSerializer(order).data)


class DeliveryUpdateLocationView(APIView):
    """
    POST /api/products/delivery/orders/<order_number>/location/
    Body: { "lat": 11.5564, "lng": 104.9282 }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, order_number):
        user = request.user

        # ✅ Super Admin ឬ Delivery Person ដែល Assign
        try:
            if user.is_superuser:
                order = Order.objects.get(order_number=order_number)
            else:
                order = Order.objects.get(
                    order_number=order_number,
                    delivery_person=user
                )
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found or not assigned to you."},
                status=status.HTTP_404_NOT_FOUND
            )

        lat = request.data.get('lat')
        lng = request.data.get('lng')

        if lat is None or lng is None:
            return Response(
                {"error": "lat and lng are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.delivery_lat = lat
        order.delivery_lng = lng
        order.delivery_updated_at = timezone.now()
        order.save(update_fields=['delivery_lat', 'delivery_lng', 'delivery_updated_at'])

        return Response({
            "message": "Location updated.",
            "lat": float(order.delivery_lat),
            "lng": float(order.delivery_lng),
            "updated_at": order.delivery_updated_at,
        })


class DeliveryStatsView(APIView):
    """
    GET /api/products/delivery/stats/
    បង្ហាញ Stats សម្រាប់ Delivery Person
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        if user.role != 'delivery' and not user.is_superuser:
            return Response(
                {"error": "You are not a delivery person."},
                status=status.HTTP_403_FORBIDDEN
            )

        # ✅ Super Admin ឃើញ Stats ទូទៅ
        if user.is_superuser:
            orders = Order.objects.all()
        else:
            orders = Order.objects.filter(delivery_person=user)

        stats = {
            'total': orders.count(),
            'pending': orders.filter(status__in=['pending', 'confirmed']).count(),
            'in_transit': orders.filter(status='shipped').count(),
            'delivered': orders.filter(status='delivered').count(),
            'cancelled': orders.filter(status='cancelled').count(),
            'total_earned': float(
                orders.filter(status='delivered').aggregate(
                    total=Sum('grand_total')
                )['total'] or 0
            ),
        }

        return Response(stats)


# products/views.py

class OrderTrackingView(APIView):
    """
    GET /api/products/orders/<order_number>/tracking/
    Customer មើល Location របស់ Delivery Person
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, order_number):
        try:
            order = Order.objects.select_related('delivery_person').get(
                order_number=order_number,
                user=request.user
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        data = {
            'order_number': order.order_number,
            'status': order.status,
            'delivery_person': {
                'name': order.delivery_person.full_name if order.delivery_person else None,
                'phone': order.delivery_person.phone_number if order.delivery_person else None,
            } if order.delivery_person else None,
            'delivery_lat': float(order.delivery_lat) if order.delivery_lat else None,
            'delivery_lng': float(order.delivery_lng) if order.delivery_lng else None,
            'delivery_updated_at': order.delivery_updated_at,
            'delivered_at': order.delivered_at,
            # ✅ Customer Location ពិត
            'customer_lat': float(order.customer_lat) if order.customer_lat else None,
            'customer_lng': float(order.customer_lng) if order.customer_lng else None,
            'customer_address': f"{order.address}, {order.city}",
        }

        return Response(data)




class DeliveryEarningsView(APIView):
    """
    GET /api/products/delivery/earnings/
    បង្ហាញចំណូលរបស់ Delivery Person
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        if user.role != 'delivery' and not user.is_superuser:
            return Response(
                {"error": "You are not a delivery person."},
                status=status.HTTP_403_FORBIDDEN
            )

        from .models import DeliveryEarning

        earnings = DeliveryEarning.objects.filter(delivery_person=user)

        # ✅ សរុប
        total_earned = earnings.aggregate(
            total=Sum('amount')
        )['total'] or Decimal('0')

        pending = earnings.filter(status='pending').aggregate(
            total=Sum('amount')
        )['total'] or Decimal('0')

        paid = earnings.filter(status='paid').aggregate(
            total=Sum('amount')
        )['total'] or Decimal('0')

        # ✅ ថ្ងៃនេះ
        today = timezone.now().date()
        today_earned = earnings.filter(
            earned_at__date=today
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')

        # ✅ សប្តាហ៍នេះ
        week_start = today - timedelta(days=today.weekday())
        week_earned = earnings.filter(
            earned_at__date__gte=week_start
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')

        # ✅ ខែនេះ
        month_start = today.replace(day=1)
        month_earned = earnings.filter(
            earned_at__date__gte=month_start
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')

        return Response({
            'total_earned': float(total_earned),
            'pending': float(pending),
            'paid': float(paid),
            'today': float(today_earned),
            'this_week': float(week_earned),
            'this_month': float(month_earned),
            'total_orders': earnings.count(),
        })    


class OrderRouteView(APIView):
    """
    GET /api/products/orders/<order_number>/route/
    Proxy ទៅ OSRM API ដើម្បីជៀសវាង CORS
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, order_number):
        try:
            order = Order.objects.get(
                order_number=order_number,
                user=request.user
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        # ✅ ត្រូវការទាំង ២ Location
        if not (order.delivery_lat and order.delivery_lng and
                order.customer_lat and order.customer_lng):
            return Response(
                {"error": "Delivery or Customer location not available."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # ✅ ហៅ OSRM API ពី Backend
            osrm_url = (
                f"https://router.project-osrm.org/route/v1/driving/"
                f"{order.delivery_lng},{order.delivery_lat};"
                f"{order.customer_lng},{order.customer_lat}"
                f"?overview=full&geometries=geojson"
            )

            response = http_requests.get(osrm_url, timeout=10)

            if response.status_code == 200:
                data = response.json()

                if data.get('routes') and len(data['routes']) > 0:
                    route = data['routes'][0]

                    # ✅ បម្លែង Coordinates ទៅ [lat, lng]
                    coordinates = route['geometry']['coordinates']
                    points = [
                        [coord[1], coord[0]]  # [lat, lng]
                        for coord in coordinates
                    ]

                    return Response({
                        'success': True,
                        'points': points,
                        'distance': route['distance'],  # គិតជា meters
                        'duration': route['duration'],  # គិតជា seconds
                    })

            return Response(
                {"error": "Failed to fetch route from OSRM."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )        



class OrderChatListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, order_number):
        try:
            order = Order.objects.get(
                models.Q(user=request.user) | models.Q(delivery_person=request.user),
                order_number=order_number,
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        from .models import OrderChat
        chats = OrderChat.objects.filter(order=order).order_by('created_at')
        chats.exclude(sender=request.user).update(is_read=True)

        return Response(
            OrderChatSerializer(
                chats, many=True, context={'request': request}
            ).data
        )


class OrderChatSendView(APIView):
    """
    POST /api/products/orders/<order_number>/chat/send/
    Body: { 
      "message_type": "text" | "voice",
      "message": "...",  # សម្រាប់ text
      "voice_file": File,  # សម្រាប់ voice
      "voice_duration": 10  # គិតជាវិនាទី
    }
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request, order_number):
        message_type = request.data.get('message_type', 'text')
        message = request.data.get('message', '').strip()
        voice_file = request.FILES.get('voice_file')
        voice_duration = int(request.data.get('voice_duration', 0))

        # ✅ ពិនិត្យ
        if message_type == 'text' and not message:
            return Response(
                {"error": "Message cannot be empty."},
                status=status.HTTP_400_BAD_REQUEST
            )
        if message_type == 'voice' and not voice_file:
            return Response(
                {"error": "Voice file is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            order = Order.objects.get(
                models.Q(user=request.user) | models.Q(delivery_person=request.user),
                order_number=order_number,
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        from .models import OrderChat
        chat = OrderChat.objects.create(
            order=order,
            sender=request.user,
            message_type=message_type,
            message=message,
            voice_file=voice_file,
            voice_duration=voice_duration,
        )

        return Response(
            OrderChatSerializer(chat, context={'request': request}).data,
            status=status.HTTP_201_CREATED
        ) 


class ChatUnreadCountView(APIView):
    """
    GET /api/products/chat/unread/
    ទាញចំនួនសារដែលមិនទាន់អាន ទាំងអស់
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from .models import OrderChat
        from django.db.models import Q, Count
        
        # ✅ រាប់សារដែលមិនទាន់អាន ក្នុង Order ដែល User ពាក់ព័ន្ធ
        unread = OrderChat.objects.filter(
            Q(order__user=request.user) | Q(order__delivery_person=request.user),
            is_read=False,
        ).exclude(sender=request.user)
        
        # ✅ Group by order
        orders = unread.values(
            'order__order_number',
            'order__id',
        ).annotate(
            count=Count('id')
        ).order_by('-count')
        
        return Response({
            'total': unread.count(),
            'orders': list(orders),
        })


class ChatMarkReadView(APIView):
    """
    POST /api/products/orders/<order_number>/chat/read/
    សម្គាល់សារទាំងអស់ថាបានអាន
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, order_number):
        from .models import OrderChat
        from django.db.models import Q
        
        try:
            order = Order.objects.get(
                Q(user=request.user) | Q(delivery_person=request.user),
                order_number=order_number,
            )
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        # ✅ Mark as read (សារដែលមិនមែនជារបស់ខ្លួន)
        OrderChat.objects.filter(
            order=order,
            is_read=False,
        ).exclude(sender=request.user).update(is_read=True)

        return Response({"message": "Marked as read"})    