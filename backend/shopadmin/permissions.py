from rest_framework.permissions import BasePermission


class IsShopOwner(BasePermission):
    """អនុញ្ញាតតែ Shop Owner ប៉ុណ្ណោះ"""
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_shop_owner or request.user.is_superuser)
        )