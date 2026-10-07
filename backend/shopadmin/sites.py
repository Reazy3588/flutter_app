from django.contrib.admin import AdminSite
from django.utils.translation import gettext_lazy as _


class ShopOwnerAdminSite(AdminSite):
    """
    Admin Site ដាច់ដោយឡែកសម្រាប់ Shop Owner
    URL: /shop-admin/
    """
    site_header = _("Shop Owner Dashboard")
    site_title = _("Shop Admin")
    index_title = _("Manage Your Shop")
    
    enable_nav_sidebar = False
    empty_value_display = "-"
    index_template = 'shopadmin/index.html'
    
    def has_permission(self, request):
        """អនុញ្ញាតឱ្យចូលបានតែ User ដែល is_shop_owner = True ប៉ុណ្ណោះ"""
        return (
            request.user.is_active and
            request.user.is_authenticated and
            (request.user.is_shop_owner or request.user.is_superuser)
        )
    
    def each_context(self, request):
        context = super().each_context(request)
        context['command_search'] = False
        context['command_show_history'] = False
        return context


# ✅ បង្កើត Instance
shop_admin_site = ShopOwnerAdminSite(name='shop_admin')