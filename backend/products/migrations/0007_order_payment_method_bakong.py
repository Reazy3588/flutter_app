from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('products', '0006_order_cancellation_reason'),
    ]

    operations = [
        migrations.AlterField(
            model_name='order',
            name='payment_method',
            field=models.CharField(
                choices=[
                    ('cod', 'Cash on Delivery'),
                    ('aba', 'ABA Pay'),
                    ('acleda', 'ACLEDA'),
                    ('bakong', 'Bakong (KHQR)'),
                ],
                default='cod',
                max_length=20,
            ),
        ),
    ]