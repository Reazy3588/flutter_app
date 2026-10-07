from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.contrib.auth.hashers import make_password
from django.views.decorators.http import require_http_methods
from accounts.models import User
from shops.models import Shop
from .views import shop_owner_required


def _get_owner_shop(user):
    """
    ✅ រក Shop របស់ Shop Owner ឱ្យបានត្រឹមត្រូវ
    - បើ User ជា Shop Owner ដែលមាន owned_shop → ប្រើ owned_shop
    - បើ User មាន shop → ប្រើ shop
    - បើជា Super Admin → ប្រើ super-admin-shop ឬ shop របស់គាត់
    """
    # បើជា Shop Owner → យក owned_shop ជាមុន
    if hasattr(user, 'owned_shop') and user.owned_shop:
        return user.owned_shop
    
    # បើមាន shop ធម្មតា
    if hasattr(user, 'shop') and user.shop:
        return user.shop
    
    # បើជា Super Admin → យក super admin shop
    if user.is_superuser:
        try:
            return Shop.get_super_admin_shop()
        except Exception:
            pass
    
    return None


@shop_owner_required
def staff_list(request):
    """បញ្ជី Staff, Delivery និង Customer ក្នុង Shop"""
    shop = _get_owner_shop(request.user)
    
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')
    
    # ✅ បង្ហាញ User ទាំងអស់ក្នុង Shop នោះ (រួមទាំង Customer)
    staffs = User.objects.filter(
        shop=shop
    ).order_by('-date_joined')
    
    context = {
        'staffs': staffs,
        'shop': shop,
        'title': 'Staff & Delivery',
        'active_page': 'staff',
    }
    return render(request, 'shopadmin/staff_list.html', context)


@shop_owner_required
def staff_add(request):
    """បន្ថែម Staff ថ្មី"""
    shop = _get_owner_shop(request.user)
    
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')
    
    if request.method == 'POST':
        try:
            email = request.POST.get('email', '').strip()
            full_name = request.POST.get('full_name', '').strip()
            phone_number = request.POST.get('phone_number', '').strip()
            password = request.POST.get('password', '')
            role = request.POST.get('role', 'shop_staff')
            
            # ✅ ពិនិត្យ Email ស្ទួនក្នុង Shop តែមួយ
            if User.objects.filter(email=email, shop=shop).exists():
                messages.error(request, f'❌ Email "{email}" already exists in this shop!')
                return redirect('/shop-admin/staff/add/')
            
            # ✅ ពិនិត្យ Phone ស្ទួនក្នុង Shop តែមួយ
            if phone_number and User.objects.filter(phone_number=phone_number, shop=shop).exists():
                messages.error(request, f'❌ Phone "{phone_number}" already exists in this shop!')
                return redirect('/shop-admin/staff/add/')
            
            # បង្កើត Username
            username = email.split('@')[0]
            base_username = username
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f"{base_username}{counter}"
                counter += 1
            
            # បង្កើត User
            user = User.objects.create(
                email=email,
                username=username,
                full_name=full_name,
                phone_number=phone_number,
                shop=shop,
                role=role,
                is_active=True,
                is_phone_verified=True,
                is_shop_staff=(role == 'shop_staff'),
            )
            user.set_password(password)
            user.save()
            
            messages.success(request, f'✅ Staff "{full_name}" created!')
            return redirect('/shop-admin/staff/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')
    
    context = {
        'shop': shop,
        'title': 'Add Staff',
        'active_page': 'staff',
    }
    return render(request, 'shopadmin/staff_form.html', context)


@shop_owner_required
def staff_edit(request, pk):
    """កែ Staff"""
    shop = _get_owner_shop(request.user)
    
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')
    
    staff = get_object_or_404(User, pk=pk, shop=shop)
    
    if request.method == 'POST':
        try:
            staff.full_name = request.POST.get('full_name', staff.full_name)
            staff.phone_number = request.POST.get('phone_number', staff.phone_number)
            staff.role = request.POST.get('role', staff.role)
            staff.is_shop_staff = (staff.role == 'shop_staff')
            
            password = request.POST.get('password', '')
            if password:
                staff.set_password(password)
            
            staff.save()
            messages.success(request, f'✅ Staff "{staff.full_name}" updated!')
            return redirect('/shop-admin/staff/')
        except Exception as e:
            messages.error(request, f'❌ Error: {str(e)}')
    
    context = {
        'staff': staff,
        'shop': shop,
        'title': 'Edit Staff',
        'active_page': 'staff',
    }
    return render(request, 'shopadmin/staff_form.html', context)


@shop_owner_required
def staff_delete(request, pk):
    """លុប Staff"""
    shop = _get_owner_shop(request.user)
    
    if not shop:
        messages.error(request, "❌ You don't have a shop yet")
        return redirect('/shop-admin/')
    
    staff = get_object_or_404(User, pk=pk, shop=shop)
    name = staff.full_name
    
    # ✅ មិនឱ្យលុប Shop Owner ខ្លួនឯង
    if staff.pk == request.user.pk:
        messages.error(request, "❌ You cannot delete yourself!")
        return redirect('/shop-admin/staff/')
    
    staff.delete()
    messages.success(request, f'✅ Staff "{name}" deleted!')
    return redirect('/shop-admin/staff/')