from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_http_methods
from django.utils import timezone
from django.contrib import messages

from django.db.models import Sum, Count
from datetime import timedelta
from decimal import Decimal

from products.models import Product, Category, Order, Coupon, Banner
from shops.models import Shop
from accounts.models import User


# ==================== HELPER ====================
def _get_owner_shop(user):
    """
    ✅ រក Shop របស់ Shop Owner ឱ្យបានត្រឹមត្រូវ
    """
    if hasattr(user, 'owned_shop') and user.owned_shop:
        return user.owned_shop
    if hasattr(user, 'shop') and user.shop:
        return user.shop
    if user.is_superuser:
        try:
            return Shop.get_super_admin_shop()
        except Exception:
            pass
    return None


# ==================== DECORATOR ====================
def shop_owner_required(view_func):
    """Decorator ដែលធានាថា User ជា Shop Owner"""
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect('/shop-admin/login/')
        if not (request.user.is_shop_owner or request.user.is_superuser):
            return render(request, 'shopadmin/no_access.html', status=403)
        return view_func(request, *args, **kwargs)
    return wrapper


# ==================== LOGIN / LOGOUT ====================
@require_http_methods(["GET", "POST"])
def shop_admin_login(request):
    """Login View សម្រាប់ Shop Owner"""
    if request.user.is_authenticated and (request.user.is_shop_owner or request.user.is_superuser):
        return redirect('/shop-admin/')

    error = None

    if request.method == 'POST':
        email = request.POST.get('email', '').strip()
        password = request.POST.get('password', '')

        # ✅ ស្វែងរក User តាម email ជាមុន
        try:
            user_obj = User.objects.get(email=email)
        except User.DoesNotExist:
            user_obj = None

        if user_obj is None:
            error = "Invalid email or password."
        else:
            # ✅ Authenticate ដោយប្រើ username របស់ User នោះ
            user = authenticate(request, username=user_obj.username, password=password)

            if user is not None:
                if user.is_shop_owner or user.is_superuser:
                    if not user.is_staff:
                        user.is_staff = True
                        user.save(update_fields=['is_staff'])
                    login(request, user)
                    return redirect('/shop-admin/')
                else:
                    error = "You don't have permission to access Shop Admin."
            else:
                error = "Invalid email or password."

    return render(request, 'shopadmin/login.html', {'error': error})


@require_http_methods(["GET", "POST"])
def shop_admin_logout(request):
    """Logout សម្រាប់ Shop Admin"""
    logout(request)
    return redirect('/shop-admin/login/')


# ==================== DASHBOARD ====================
@shop_owner_required
def shop_owner_dashboard(request):
    """Dashboard សម្រាប់ Shop Owner — ដូច Super Admin"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/login/')

    # ═══════════════════════════════════════════════════════════
    # ✅ Statistics
    # ═══════════════════════════════════════════════════════════
    product_qs = Product.objects.filter(shop=shop)
    order_qs = Order.objects.filter(shop=shop)
    category_qs = Category.objects.filter(shop=shop)
    coupon_qs = Coupon.objects.filter(shop=shop)
    user_qs = User.objects.filter(shop=shop, role='customer')

    total_products = product_qs.count()
    total_orders = order_qs.count()
    total_users = user_qs.count()
    total_categories = category_qs.count()
    total_coupons = coupon_qs.count()

    total_revenue = order_qs.filter(status='delivered').aggregate(
        total=Sum('grand_total')
    )['total'] or Decimal('0')

    # ═══════════════════════════════════════════════════════════
    # ✅ Order Status
    # ═══════════════════════════════════════════════════════════
    completed_orders = order_qs.filter(status='delivered').count()
    pending_orders = order_qs.filter(
        status__in=['pending', 'confirmed', 'shipped']
    ).count()
    cancelled_orders = order_qs.filter(status='cancelled').count()

    # ═══════════════════════════════════════════════════════════
    # ✅ Chart Data (7 Days) — កែឱ្យត្រឹមត្រូវ
    # ═══════════════════════════════════════════════════════════
    today = timezone.now().date()
    chart_counts = []

    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        count = order_qs.filter(created_at__date=day).count()
        chart_counts.append({
            'label': day.strftime('%a'),
            'count': count,
        })

    # ✅ គណនា max_order_count ជាមុន
    max_order_count = max((p['count'] for p in chart_counts), default=0)
    safe_max = max_order_count if max_order_count > 0 else 1

    # ✅ គណនា height ក្រោយពេលមាន safe_max
    chart_points = [
        {
            'label': point['label'],
            'count': point['count'],
            'height': max(4, (point['count'] / safe_max) * 100),
        }
        for point in chart_counts
    ]

    # ═══════════════════════════════════════════════════════════
    # ✅ Recent Orders
    # ═══════════════════════════════════════════════════════════
    recent_orders = order_qs.select_related('user').order_by('-created_at')[:10]

    # ═══════════════════════════════════════════════════════════
    # ✅ Top Products
    # ═══════════════════════════════════════════════════════════
    top_products = product_qs.order_by('-sold_count')[:5]

    context = {
        'shop': shop,
        'total_products': total_products,
        'total_orders': total_orders,
        'total_users': total_users,
        'total_categories': total_categories,
        'total_coupons': total_coupons,
        'total_revenue': total_revenue,
        'completed_orders': completed_orders,
        'pending_orders': pending_orders,
        'cancelled_orders': cancelled_orders,
        'chart_points': chart_points,
        'recent_orders': recent_orders,
        'top_products': top_products,
        'title': 'Shop Dashboard',
        'active_page': 'dashboard',
    }

    return render(request, 'shopadmin/dashboard.html', context)


# ==================== PRODUCTS ====================
@shop_owner_required
def product_list(request):
    """បញ្ជី Products របស់ Shop Owner"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    products = Product.objects.filter(shop=shop).select_related('category').order_by('-created_at')

    context = {
        'products': products,
        'shop': shop,
        'title': 'Products',
        'active_page': 'products',
    }
    return render(request, 'shopadmin/product_list.html', context)


@shop_owner_required
def product_add(request):
    """បន្ថែម Product ថ្មី"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    categories = Category.objects.filter(shop=shop, is_active=True)

    if request.method == 'POST':
        try:
            name = request.POST.get('name', '').strip()
            category_id = request.POST.get('category')
            description = request.POST.get('description', '')
            price = request.POST.get('price', '0')
            discount_price = request.POST.get('discount_price') or None
            stock = request.POST.get('stock', '0')
            image = request.FILES.get('image')
            is_new_arrival = request.POST.get('is_new_arrival') == 'on'
            is_best_seller = request.POST.get('is_best_seller') == 'on'
            is_recommended = request.POST.get('is_recommended') == 'on'

            product = Product.objects.create(
                shop=shop,
                name=name,
                category_id=category_id,
                description=description,
                price=price,
                discount_price=discount_price,
                stock=stock,
                image=image,
                is_new_arrival=is_new_arrival,
                is_best_seller=is_best_seller,
                is_recommended=is_recommended,
            )
            messages.success(request, f'✅ Product "{product.name}" created successfully!')
            return redirect('/shop-admin/products/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'categories': categories,
        'shop': shop,
        'title': 'Add Product',
        'active_page': 'products',
    }
    return render(request, 'shopadmin/product_form.html', context)


@shop_owner_required
def product_edit(request, pk):
    """កែ Product"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    product = get_object_or_404(Product, pk=pk, shop=shop)
    categories = Category.objects.filter(shop=shop, is_active=True)

    if request.method == 'POST':
        try:
            product.name = request.POST.get('name', product.name)
            product.category_id = request.POST.get('category', product.category_id)
            product.description = request.POST.get('description', product.description)
            product.price = request.POST.get('price', product.price)
            product.discount_price = request.POST.get('discount_price') or None
            product.stock = request.POST.get('stock', product.stock)
            product.is_new_arrival = request.POST.get('is_new_arrival') == 'on'
            product.is_best_seller = request.POST.get('is_best_seller') == 'on'
            product.is_recommended = request.POST.get('is_recommended') == 'on'

            if request.FILES.get('image'):
                product.image = request.FILES.get('image')

            product.save()
            messages.success(request, f'✅ Product "{product.name}" updated!')
            return redirect('/shop-admin/products/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'product': product,
        'categories': categories,
        'shop': shop,
        'title': 'Edit Product',
        'active_page': 'products',
    }
    return render(request, 'shopadmin/product_form.html', context)


@shop_owner_required
def product_delete(request, pk):
    """លុប Product"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    product = get_object_or_404(Product, pk=pk, shop=shop)
    name = product.name
    try:
        product.delete()
        messages.success(request, f'✅ Product "{name}" deleted!')
    except Exception as e:
        messages.error(request, f'❌ Cannot delete "{name}": {str(e)}')
    return redirect('/shop-admin/products/')


# ==================== CATEGORIES ====================
@shop_owner_required
def category_list(request):
    """បញ្ជី Categories"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    categories = Category.objects.filter(shop=shop).order_by('name')

    context = {
        'categories': categories,
        'shop': shop,
        'title': 'Categories',
        'active_page': 'categories',
    }
    return render(request, 'shopadmin/category_list.html', context)


@shop_owner_required
def category_add(request):
    """បន្ថែម Category ថ្មី"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    if request.method == 'POST':
        try:
            name = request.POST.get('name', '').strip()
            image = request.FILES.get('image')
            is_active = request.POST.get('is_active') == 'on'

            category = Category.objects.create(
                shop=shop,
                name=name,
                image=image,
                is_active=is_active,
            )
            messages.success(request, f'✅ Category "{category.name}" created!')
            return redirect('/shop-admin/categories/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'shop': shop,
        'title': 'Add Category',
        'active_page': 'categories',
    }
    return render(request, 'shopadmin/category_form.html', context)


@shop_owner_required
def category_edit(request, pk):
    """កែ Category"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    category = get_object_or_404(Category, pk=pk, shop=shop)

    if request.method == 'POST':
        try:
            category.name = request.POST.get('name', category.name)
            category.is_active = request.POST.get('is_active') == 'on'
            if request.FILES.get('image'):
                category.image = request.FILES.get('image')
            category.save()
            messages.success(request, f'✅ Category "{category.name}" updated!')
            return redirect('/shop-admin/categories/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'category': category,
        'shop': shop,
        'title': 'Edit Category',
        'active_page': 'categories',
    }
    return render(request, 'shopadmin/category_form.html', context)


@shop_owner_required
def category_delete(request, pk):
    """លុប Category"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    category = get_object_or_404(Category, pk=pk, shop=shop)
    name = category.name
    category.delete()
    messages.success(request, f'✅ Category "{name}" deleted!')
    return redirect('/shop-admin/categories/')


# ==================== BANNERS ====================
def _banner_link_options(shop):
    """បញ្ជី Category/Product សម្រាប់ជ្រើស Link របស់ Banner"""
    categories = Category.objects.filter(shop=shop, is_active=True).order_by('name')
    products = Product.objects.filter(shop=shop, is_active=True).order_by('name')
    return categories, products


def _apply_banner_post(request, banner):
    banner.title = request.POST.get('title', '').strip()
    banner.subtitle = request.POST.get('subtitle', '').strip()
    banner.badge_text = request.POST.get('badge_text', '').strip()
    banner.button_text = request.POST.get('button_text', '').strip() or 'Shop Now'
    try:
        banner.sort_order = int(request.POST.get('sort_order') or 0)
    except ValueError:
        banner.sort_order = 0
    banner.is_active = request.POST.get('is_active') == 'on'

    # link ជា "category:<slug>" ឬ "product:<slug>" ឬ ទទេ
    link = request.POST.get('link', '')
    if ':' in link:
        link_type, link_value = link.split(':', 1)
        if link_type in ('category', 'product'):
            banner.link_type, banner.link_value = link_type, link_value
        else:
            banner.link_type, banner.link_value = 'none', ''
    else:
        banner.link_type, banner.link_value = 'none', ''

    if request.FILES.get('image'):
        banner.image = request.FILES['image']


@shop_owner_required
def banner_list(request):
    shop = _get_owner_shop(request.user)
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    banners = Banner.objects.filter(shop=shop)
    return render(request, 'shopadmin/banner_list.html', {
        'banners': banners,
        'shop': shop,
        'title': 'Banners',
        'active_page': 'banners',
    })


@shop_owner_required
def banner_add(request):
    shop = _get_owner_shop(request.user)
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    if request.method == 'POST':
        try:
            if not request.FILES.get('image'):
                raise ValueError('Please choose a banner image')
            banner = Banner(shop=shop)
            _apply_banner_post(request, banner)
            banner.save()
            messages.success(request, '✅ Banner created!')
            return redirect('/shop-admin/banners/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    categories, products = _banner_link_options(shop)
    return render(request, 'shopadmin/banner_form.html', {
        'shop': shop,
        'categories': categories,
        'products': products,
        'title': 'Add Banner',
        'active_page': 'banners',
    })


@shop_owner_required
def banner_edit(request, pk):
    shop = _get_owner_shop(request.user)
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    banner = get_object_or_404(Banner, pk=pk, shop=shop)

    if request.method == 'POST':
        try:
            _apply_banner_post(request, banner)
            banner.save()
            messages.success(request, '✅ Banner updated!')
            return redirect('/shop-admin/banners/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    categories, products = _banner_link_options(shop)
    return render(request, 'shopadmin/banner_form.html', {
        'banner': banner,
        'current_link': (
            f'{banner.link_type}:{banner.link_value}'
            if banner.link_type != 'none' else ''
        ),
        'shop': shop,
        'categories': categories,
        'products': products,
        'title': 'Edit Banner',
        'active_page': 'banners',
    })


@shop_owner_required
def banner_delete(request, pk):
    shop = _get_owner_shop(request.user)
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    banner = get_object_or_404(Banner, pk=pk, shop=shop)
    banner.delete()
    messages.success(request, '✅ Banner deleted!')
    return redirect('/shop-admin/banners/')


# ==================== ORDERS ====================
@shop_owner_required
def order_list(request):
    """បញ្ជី Orders"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    status_filter = request.GET.get('status', '')

    orders = Order.objects.filter(shop=shop).prefetch_related('items').order_by('-created_at')
    if status_filter:
        orders = orders.filter(status=status_filter)

    context = {
        'orders': orders,
        'shop': shop,
        'status_filter': status_filter,
        'title': 'Orders',
        'active_page': 'orders',
    }
    return render(request, 'shopadmin/order_list.html', context)


@shop_owner_required
def order_detail(request, order_number):
    """មើលលម្អិត Order"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    order = get_object_or_404(Order, order_number=order_number, shop=shop)

    context = {
        'order': order,
        'shop': shop,
        'title': f'Order {order.order_number}',
        'active_page': 'orders',
    }
    return render(request, 'shopadmin/order_detail.html', context)


@shop_owner_required
@require_http_methods(["POST"])
def order_update_status(request, order_number):
    """ផ្លាស់ប្តូរ Status នៃ Order"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    order = get_object_or_404(Order, order_number=order_number, shop=shop)

    new_status = request.POST.get('status')
    if new_status in ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']:
        order.status = new_status
        order.save(update_fields=['status', 'updated_at'])
        messages.success(request, f'✅ Order status updated to {new_status}!')

    return redirect(f'/shop-admin/orders/{order_number}/')


# ==================== COUPONS ====================
@shop_owner_required
def coupon_list(request):
    """បញ្ជី Coupons"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    coupons = Coupon.objects.all().order_by('-created_at')

    context = {
        'coupons': coupons,
        'shop': shop,
        'title': 'Coupons',
        'active_page': 'coupons',
    }
    return render(request, 'shopadmin/coupon_list.html', context)


@shop_owner_required
def coupon_add(request):
    """បន្ថែម Coupon ថ្មី"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    if request.method == 'POST':
        try:
            from django.utils.dateparse import parse_datetime

            code = request.POST.get('code', '').strip().upper()
            discount_amount = request.POST.get('discount_amount', '0')
            min_order_amount = request.POST.get('min_order_amount', '0')
            max_uses = request.POST.get('max_uses', '0')
            valid_from = parse_datetime(request.POST.get('valid_from', ''))
            valid_to = parse_datetime(request.POST.get('valid_to', ''))
            is_active = request.POST.get('is_active') == 'on'

            coupon = Coupon.objects.create(
                code=code,
                discount_amount=discount_amount,
                min_order_amount=min_order_amount,
                max_uses=max_uses,
                valid_from=valid_from,
                valid_to=valid_to,
                is_active=is_active,
            )
            messages.success(request, f'✅ Coupon "{coupon.code}" created!')
            return redirect('/shop-admin/coupons/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'shop': shop,
        'title': 'Add Coupon',
        'active_page': 'coupons',
    }
    return render(request, 'shopadmin/coupon_form.html', context)


@shop_owner_required
def coupon_delete(request, pk):
    """លុប Coupon"""
    coupon = get_object_or_404(Coupon, pk=pk)
    code = coupon.code
    coupon.delete()
    messages.success(request, f'✅ Coupon "{code}" deleted!')
    return redirect('/shop-admin/coupons/')


# ==================== THEME SETTINGS ====================
@shop_owner_required
def theme_settings(request):
    """កែ Theme របស់ហាង (Logo, ឈ្មោះ, ពណ៌)"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    if request.method == 'POST':
        try:
            shop.name = request.POST.get('name', shop.name)
            shop.description = request.POST.get('description', shop.description)
            shop.primary_color = request.POST.get('primary_color', shop.primary_color)
            shop.secondary_color = request.POST.get('secondary_color', shop.secondary_color)
            shop.accent_color = request.POST.get('accent_color', shop.accent_color)
            shop.phone = request.POST.get('phone', shop.phone)
            shop.email = request.POST.get('email', shop.email)
            shop.address = request.POST.get('address', shop.address)

            if request.FILES.get('logo'):
                shop.logo = request.FILES.get('logo')

            shop.save()
            messages.success(request, '✅ Shop settings updated successfully!')
            return redirect('/shop-admin/theme/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'shop': shop,
        'title': 'Theme Settings',
        'active_page': 'theme',
    }
    return render(request, 'shopadmin/theme_settings.html', context)


# ==================== TELEGRAM SETTINGS ====================
@shop_owner_required
def telegram_settings(request):
    """កែ Telegram Settings របស់ហាង"""
    shop = _get_owner_shop(request.user)

    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')

    if request.method == 'POST':
        try:
            shop.telegram_chat_id = request.POST.get('telegram_chat_id', '').strip()
            shop.telegram_enabled = request.POST.get('telegram_enabled') == 'on'
            shop.save(update_fields=['telegram_chat_id', 'telegram_enabled'])
            messages.success(request, '✅ Telegram settings updated!')
            return redirect('/shop-admin/telegram/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')

    context = {
        'shop': shop,
        'title': 'Telegram Settings',
        'active_page': 'telegram',
    }
    return render(request, 'shopadmin/telegram_settings.html', context)

# ==================== ASSIGN DELIVERY ====================

@shop_owner_required
def assign_delivery(request, order_number):
    """Assign Order ទៅ Delivery Person"""
    shop = _get_owner_shop(request.user)
    
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')
    
    order = get_object_or_404(Order, order_number=order_number, shop=shop)
    
    if request.method == 'POST':
        delivery_id = request.POST.get('delivery_id')
        
        if not delivery_id:
            messages.error(request, '❌ Please select a delivery person.')
            return redirect(f'/shop-admin/orders/{order_number}/')
        
        try:
            delivery = User.objects.get(
                pk=delivery_id,
                shop=shop,
                role='delivery',
            )
            order.delivery_person = delivery
            # ✅ Update Status ទៅ confirmed ដោយស្វ័យប្រវត្តិ
            if order.status == 'pending':
                order.status = 'confirmed'
            order.save(update_fields=['delivery_person', 'status', 'updated_at'])
            
            messages.success(
                request,
                f'✅ Order {order.order_number} assigned to {delivery.full_name or delivery.email}'
            )
        except User.DoesNotExist:
            messages.error(request, '❌ Delivery person not found in this shop.')
        
        return redirect(f'/shop-admin/orders/{order_number}/')
    
    # បង្ហាញបញ្ជី Delivery Person
    delivery_persons = User.objects.filter(
        shop=shop,
        role='delivery',
        is_active=True,
    )
    
    context = {
        'order': order,
        'delivery_persons': delivery_persons,
        'shop': shop,
        'title': f'Assign Delivery - {order.order_number}',
        'active_page': 'orders',
    }
    return render(request, 'shopadmin/assign_delivery.html', context)