# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('sklad', '0006_order_orderlineitem'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='status',
            field=models.CharField(
                choices=[
                    ('new', 'Новый'),
                    ('shipped', 'Отгружено'),
                    ('in_transit', 'В пути'),
                    ('ready', 'Готово к получению'),
                    ('delivered', 'Доставлено'),
                ],
                default='new',
                max_length=20,
                verbose_name='Статус',
            ),
        ),
    ]
