# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('sklad', '0007_order_status'),
    ]

    operations = [
        migrations.AddField(
            model_name='item',
            name='wb_url',
            field=models.URLField(blank=True, max_length=500, verbose_name='Ссылка на ВБ'),
        ),
        migrations.AddField(
            model_name='item',
            name='ozon_url',
            field=models.URLField(blank=True, max_length=500, verbose_name='Ссылка на Озон'),
        ),
    ]
