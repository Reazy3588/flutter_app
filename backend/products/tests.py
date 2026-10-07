from django.contrib import admin
from django.contrib.auth.models import AnonymousUser
from django.test import RequestFactory, SimpleTestCase, TestCase

from products.admin import CouponAdmin
from products.models import Coupon, Product, Category
from products.views import ProductViewSet
from shops.models import Shop


class ProductAdminPermissionTests(SimpleTestCase):
    def test_anonymous_user_has_module_permission_is_false(self):
        request = RequestFactory().get('/admin/login/')
        request.user = AnonymousUser()

        admin_obj = CouponAdmin(Coupon, admin.site)

        self.assertFalse(admin_obj.has_module_permission(request))


class ProductViewSetShopFilterTests(TestCase):
    def test_shop_owner_sees_own_shop_products_when_no_shop_param(self):
        owner = self._create_user(email='owner@example.com')
        owner_shop = Shop.get_or_create_for_user(owner)
        owner_category = Category.objects.create(shop=owner_shop, name='Owner Cat')
        owner_product = Product.objects.create(
            shop=owner_shop,
            category=owner_category,
            name='Owner Product',
            price='10.00',
            stock=5,
            slug='owner-product',
        )

        other_shop = Shop.objects.create(name='Other Shop', slug='other-shop')
        other_category = Category.objects.create(shop=other_shop, name='Other Cat')
        Product.objects.create(
            shop=other_shop,
            category=other_category,
            name='Other Product',
            price='20.00',
            stock=5,
            slug='other-product',
        )

        request = RequestFactory().get('/api/products/')
        request.user = owner
        viewset = ProductViewSet()
        viewset.request = request

        qs = viewset.get_queryset()

        self.assertIn(owner_product, qs)
        self.assertEqual(qs.count(), 1)

    def _create_user(self, email='user@example.com'):
        from accounts.models import User
        return User.objects.create_user(
            email=email,
            username=email.split('@')[0],
            password='secret123',
            full_name='Test User',
            is_shop_owner=True,
            is_active=True,
        )
