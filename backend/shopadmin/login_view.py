from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login
from django.views.decorators.http import require_http_methods


@require_http_methods(["GET", "POST"])
def shop_admin_login(request):
    """Login View សម្រាប់ Shop Owner"""
    
    if request.user.is_authenticated and request.user.is_shop_owner:
        return redirect('/shop-admin/')
    
    error = None
    
    if request.method == 'POST':
        email = request.POST.get('email', '').strip()
        password = request.POST.get('password', '')
        
        user = authenticate(request, username=email, password=password)
        
        if user is not None:
            if user.is_shop_owner or user.is_superuser:
                # ✅ កំណត់ is_staff = True ដោយស្វ័យប្រវត្តិ
                if not user.is_staff:
                    user.is_staff = True
                    user.save(update_fields=['is_staff'])
                
                login(request, user)
                return redirect('/shop-admin/')
            else:
                error = "You don't have permission to access this page."
        else:
            error = "Invalid email or password."
    
    return render(request, 'shopadmin/login.html', {'error': error})