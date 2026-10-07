from shops.models import Shop

SESSION_KEY = "admin_active_shop_id"


def get_active_shop(request, allow_switch=False):
    """
    Return the ONE shop that the current admin user is working with.

    - Super Admin : the shop chosen in the dashboard dropdown (?shop=ID),
                    remembered in the session. Default = "Super Admin Shop".
    - Shop Owner  : always their own shop.
    - Others      : None
    """
    user = getattr(request, "user", None)
    if not user or not user.is_authenticated:
        return None

    if user.is_superuser:
        # Only the dashboard is allowed to change the shop (allow_switch=True),
        # so normal admin list pages never receive an unknown ?shop= parameter.
        if allow_switch and "shop" in request.GET:
            raw = request.GET.get("shop", "")
            if raw.isdigit() and Shop.objects.filter(pk=int(raw)).exists():
                request.session[SESSION_KEY] = int(raw)
            else:
                request.session.pop(SESSION_KEY, None)

        shop_id = request.session.get(SESSION_KEY)
        if shop_id:
            shop = Shop.objects.filter(pk=shop_id).first()
            if shop:
                return shop
            request.session.pop(SESSION_KEY, None)
        return Shop.get_super_admin_shop()

    if getattr(user, "is_shop_owner", False):
        # model related_name is "owned_shop" (older code used "shop")
        return getattr(user, "owned_shop", None) or getattr(user, "shop", None)

    return None