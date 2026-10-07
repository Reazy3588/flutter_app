from pathlib import Path
from django.test import SimpleTestCase


class ShopAdminTemplateRegressionTests(SimpleTestCase):
    def test_order_list_template_uses_single_line_delivery_name(self):
        template = Path('shopadmin/templates/shopadmin/order_list.html').read_text()
        self.assertNotIn(
            "{{\n            order.delivery_person.full_name|default:order.delivery_person.email\n            }}",
            template,
        )

    def test_dashboard_template_uses_single_line_welcome_tag(self):
        template = Path('shopadmin/templates/shopadmin/dashboard.html').read_text()
        self.assertNotIn(
            "{{ request.user.full_name|default:request.user.username\n        }}",
            template,
        )

    def test_shared_base_provides_legacy_page_styles(self):
        template = Path('shopadmin/templates/shopadmin/base.html').read_text()
        for selector in (
            '.page-header',
            '.table-container',
            '.form-card',
            '.btn-primary',
            '.btn-secondary',
            '.badge',
        ):
            self.assertIn(selector, template)

    def test_sidebar_has_stable_layout_contract(self):
        template = Path('shopadmin/templates/shopadmin/base.html').read_text()
        for selector in (
            '.shop-admin-shell',
            '.shop-sidebar {',
            'display: flex;',
            'flex-direction: column;',
            'overflow-y: auto;',
            'max-width: 100vw;',
        ):
            self.assertIn(selector, template)

    def test_user_initials_are_rendered_without_literal_template_syntax(self):
        template = Path('shopadmin/templates/shopadmin/base.html').read_text()
        self.assertIn(
            "{{ request.user.username|slice:':1'|upper }}",
            template,
        )
        self.assertNotIn(
            "{{\n                request.user.first_name|default:request.user.username",
            template,
        )
