from django.shortcuts import render, redirect
from django.db.models import Sum
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

from shops.models import Shop


def shop_owner_dashboard(request):
    """Dashboard សម្រាប់ Shop Owner"""
    user = request.user
    
    if not user.is_authenticated:
        return redirect('/shop-admin/login/')
    
    if not (user.is_shop_owner or user.is_superuser):
        return render(request, 'shopadmin/no_access.html', status=403)
    
    # ✅ បង្កើត Shop ដោយស្វ័យប្រវត្តិ
    shop = Shop.get_or_create_for_user(user)
    
    from products.models import Product, Category, Order
    
    total_products = Product.objects.filter(shop=shop).count()
    total_categories = Category.objects.filter(shop=shop).count()
    total_orders = Order.objects.filter(shop=shop).count()
    pending_orders = Order.objects.filter(shop=shop, status='pending').count()
    
    total_revenue = Order.objects.filter(
        shop=shop, status='delivered'
    ).aggregate(total=Sum('grand_total'))['total'] or Decimal('0')
    
    recent_orders = Order.objects.filter(shop=shop).order_by('-created_at')[:10]
    
    context = {
        'shop': shop,
        'total_products': total_products,
        'total_categories': total_categories,
        'total_orders': total_orders,
        'pending_orders': pending_orders,
        'total_revenue': total_revenue,
        'recent_orders': recent_orders,
        'title': 'Shop Dashboard',
    }
    
    return render(request, 'shopadmin/index.html', context)