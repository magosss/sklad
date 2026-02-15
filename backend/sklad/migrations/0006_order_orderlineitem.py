# Generated manually

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('sklad', '0005_add_item_price'),
    ]

    operations = [
        migrations.CreateModel(
            name='Order',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('source', models.CharField(blank=True, max_length=500, verbose_name='Источник заказа')),
                ('delivery_address', models.TextField(blank=True, verbose_name='Адрес доставки')),
                ('client_phone', models.CharField(blank=True, max_length=50, verbose_name='Телефон клиента')),
                ('total', models.DecimalField(decimal_places=2, default=0, max_digits=12, verbose_name='Итоговая сумма')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('workshop', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='orders', to='sklad.workshop')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='OrderLineItem',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('size_label', models.CharField(max_length=50)),
                ('quantity', models.IntegerField()),
                ('item', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='sklad.item')),
                ('order', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='line_items', to='sklad.order')),
            ],
        ),
    ]
