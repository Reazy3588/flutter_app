from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from rest_framework import status
from django.contrib.auth import get_user_model
from django.db.models import Count, Sum
from django.utils import timezone
from datetime import timedelta

from shops.models import Shop
from shops.serializers import ShopSerializer
from products.models import Category, Coupon, Order, Product


import json
from decimal import Decimal
from datetime import timedelta
 
from django.db.models import Sum, Count
from django.db.models.functions import TruncDate
from django.utils import timezone
 
from products.models import Product, Order
from shops.models import Shop
from accounts.models import User

from django.shortcuts import render
from shops.utils import get_active_shop

User = get_user_model()


class SuperAdminDashboardView(APIView):
    """
    GET /api/superadmin/dashboard/
    ផ្ទាំងគ្រប់គ្រងរបស់ Super Admin
    """
    permission_classes = [IsAdminUser]
    
    def get(self, request):
        total_tenants = Shop.objects.count()
        active_tenants = Shop.objects.filter(is_active=True).count()
        total_users = User.objects.count()
        
        total_orders = Order.objects.count()
        total_revenue = Order.objects.filter(
            status='delivered'
        ).aggregate(total=Sum('grand_total'))['total'] or 0
        
        thirty_days_ago = timezone.now() - timedelta(days=30)
        new_tenants = Shop.objects.filter(created_at__gte=thirty_days_ago).count()
        new_orders = Order.objects.filter(created_at__gte=thirty_days_ago).count()
        
        recent_tenants = Shop.objects.order_by('-created_at')[:10]
        
        return Response({
            'stats': {
                'total_tenants': total_tenants,
                'active_tenants': active_tenants,
                'total_users': total_users,
                'total_orders': total_orders,
                'total_revenue': float(total_revenue),
                'new_tenants_30d': new_tenants,
                'new_orders_30d': new_orders,
            },
            'recent_tenants': ShopSerializer(recent_tenants, many=True).data,
        })


class CreateTenantView(APIView):
    """
    POST /api/superadmin/create-tenant/
    បង្កើត Tenant ថ្មី (អតិថិជនថ្មី)
    """
    permission_classes = [IsAdminUser]
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        full_name = request.data.get('full_name', '')
        phone_number = request.data.get('phone_number', '')
        shop_name = request.data.get('shop_name', 'My Shop')
        
        if not email or not password:
            return Response(
                {"error": "Email and password are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if User.objects.filter(email=email).exists():
            return Response(
                {"error": "Email already exists"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = User.objects.create_user(
            email=email,
            password=password,
            full_name=full_name,
            phone_number=phone_number,
            username=email.split('@')[0],
            is_shop_owner=True,  # ✅ កំណត់ថាជា Shop Owner
        )
            
            shop = Shop.objects.create(
            owner=user,
            name=shop_name,
            subscription_plan='free',
        )
            
            return Response({
                'message': 'Tenant created successfully',
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'full_name': user.full_name,
                },
                'shop': ShopSerializer(shop).data,
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class TenantListView(APIView):
    """
    GET /api/superadmin/tenants/
    មើលបញ្ជី Tenants ទាំងអស់
    """
    permission_classes = [IsAdminUser]
    
    def get(self, request):
        tenants = Shop.objects.select_related('owner').all()
        
        is_active = request.query_params.get('is_active')
        if is_active is not None:
            tenants = tenants.filter(is_active=is_active.lower() == 'true')
        
        plan = request.query_params.get('plan')
        if plan:
            tenants = tenants.filter(subscription_plan=plan)
        
        search = request.query_params.get('search')
        if search:
            tenants = tenants.filter(name__icontains=search) | \
                      tenants.filter(owner__email__icontains=search)
        
        serializer = ShopSerializer(tenants, many=True)
        return Response({
            'count': tenants.count(),
            'results': serializer.data,
        })


class TenantDetailView(APIView):
    """
    GET /api/superadmin/tenants/<id>/
    PATCH /api/superadmin/tenants/<id>/
    DELETE /api/superadmin/tenants/<id>/
    """
    permission_classes = [IsAdminUser]
    
    def get_tenant(self, pk):
        try:
            return Shop.objects.select_related('owner').get(pk=pk)
        except Shop.DoesNotExist:
            return None
    
    def get(self, request, pk):
        tenant = self.get_tenant(pk)
        if not tenant:
            return Response(
                {"error": "Tenant not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        return Response(ShopSerializer(tenant).data)
    
    def patch(self, request, pk):
        tenant = self.get_tenant(pk)
        if not tenant:
            return Response(
                {"error": "Tenant not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        allowed_fields = ['is_active', 'subscription_plan', 'subscription_expires_at']
        for field in allowed_fields:
            if field in request.data:
                setattr(tenant, field, request.data[field])
        
        tenant.save()
        return Response(ShopSerializer(tenant).data)
    
    def delete(self, request, pk):
        tenant = self.get_tenant(pk)
        if not tenant:
            return Response(
                {"error": "Tenant not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        tenant.is_active = False
        tenant.save()
        
        return Response({"message": "Tenant deactivated successfully"})



def dashboard_callback(request, context):
    """
    Unfold dashboard callback.
    Shows data for ONE shop only (the one selected in the dropdown),
    never all shops mixed together.
    """
    user = request.user

    # Shops available in the dropdown (Super Admin only)
    all_shops = Shop.objects.order_by("name") if user.is_superuser else Shop.objects.none()

    # The single shop being viewed
    selected_shop = get_active_shop(request, allow_switch=True)

    if selected_shop is not None:
        product_qs = Product.objects.filter(shop=selected_shop)
        order_qs = Order.objects.filter(shop=selected_shop)
        category_qs = Category.objects.filter(shop=selected_shop)
        coupon_qs = Coupon.objects.filter(shop=selected_shop)
    else:
        product_qs = Product.objects.none()
        order_qs = Order.objects.none()
        category_qs = Category.objects.none()
        coupon_qs = Coupon.objects.none()

    # ==================== STATS ====================
    total_products = product_qs.count()
    total_orders = order_qs.count()
    total_categories = category_qs.count()
    total_coupons = coupon_qs.count()
    # customers who ordered from THIS shop
    total_users = order_qs.exclude(user__isnull=True).values("user").distinct().count()

    total_revenue = order_qs.filter(status="delivered").aggregate(
        total=Sum("grand_total")
    )["total"] or Decimal("0")

    pending_orders = order_qs.filter(status="pending").count()
    completed_orders = order_qs.filter(status="delivered").count()
    cancelled_orders = order_qs.filter(status="cancelled").count()

    # ==================== CHART DATA (7 days) ====================
    today = timezone.now().date()
    chart_labels, chart_data = [], []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        chart_labels.append(day.strftime("%a"))
        chart_data.append(order_qs.filter(created_at__date=day).count())

    # ==================== RECENT ORDERS / TOP PRODUCTS ====================
    recent_orders = order_qs.select_related("user", "shop").order_by("-created_at")[:5]
    top_products = product_qs.order_by("-sold_count")[:5]

    context.update({
        "all_shops": all_shops,
        "selected_shop": selected_shop,
        "selected_shop_id": selected_shop.pk if selected_shop else None,
        "total_products": total_products,
        "total_orders": total_orders,
        "total_users": total_users,
        "total_categories": total_categories,
        "total_coupons": total_coupons,
        "total_revenue": total_revenue,
        "pending_orders": pending_orders,
        "completed_orders": completed_orders,
        "cancelled_orders": cancelled_orders,
        "chart_labels": chart_labels,
        "chart_data": chart_data,
        "recent_orders": recent_orders,
        "top_products": top_products,
    })
    return context