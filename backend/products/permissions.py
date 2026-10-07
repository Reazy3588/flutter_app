from rest_framework.permissions import SAFE_METHODS, BasePermission


class IsAdminOrReadOnly(BasePermission):
    """
    Anyone can VIEW products/categories (GET/HEAD/OPTIONS) — no login required,
    since browsing the shop should be open to everyone.
    Only staff/admin accounts can CREATE, UPDATE, or DELETE.
    """

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        return bool(request.user and request.user.is_authenticated and request.user.is_staff)