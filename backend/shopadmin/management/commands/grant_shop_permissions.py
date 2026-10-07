from django.core.management.base import BaseCommand
from django.contrib.auth.models import Permission
from django.contrib.contenttypes.models import ContentType
from accounts.models import User
from products.models import Product, Category, Order


class Command(BaseCommand):
    help = 'ផ្តល់ Permissions ដល់ Shop Owner ទាំងអស់'
    
    def handle(self, *args, **kwargs):
        models = [Product, Category, Order]
        actions = ['add', 'change', 'delete', 'view']
        
        shop_owners = User.objects.filter(is_shop_owner=True)
        
        for user in shop_owners:
            # កំណត់ is_staff
            if not user.is_staff:
                user.is_staff = True
                user.save(update_fields=['is_staff'])
            
            # ផ្តល់ Permissions
            for model in models:
                content_type = ContentType.objects.get_for_model(model)
                for action in actions:
                    codename = f'{action}_{model._meta.model_name}'
                    try:
                        permission = Permission.objects.get(
                            content_type=content_type,
                            codename=codename
                        )
                        user.user_permissions.add(permission)
                    except Permission.DoesNotExist:
                        pass
            
            self.stdout.write(
                self.style.SUCCESS(f'✅ Permissions granted to {user.email}')
            )
        
        self.stdout.write(
            self.style.SUCCESS(f'\n🎉 Total: {shop_owners.count()} shop owners updated')
        )