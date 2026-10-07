from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('products', '0005_cartitem_updated_at_order_orderitem'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='cancellation_reason',
            field=models.CharField(blank=True, max_length=255),
        ),
    ]
