"""Привязать пользователя к складу: python manage.py setup_user username"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from sklad.models import Workshop, WorkshopAssignment


class Command(BaseCommand):
    help = 'Привязать пользователя к складу по умолчанию'

    def add_arguments(self, parser):
        parser.add_argument('username')
        parser.add_argument('--password', default='admin123', help='Пароль (по умолчанию admin123)')
        parser.add_argument('--create', action='store_true', help='Создать пользователя если не существует')

    def handle(self, *args, **options):
        username = options['username']
        password = options['password']
        create = options['create']

        user = User.objects.filter(username=username).first()
        if not user:
            if create:
                user = User.objects.create_user(username=username, password=password)
                self.stdout.write(self.style.SUCCESS(f'Создан пользователь {username}'))
            else:
                self.stderr.write(f'Пользователь {username} не найден. Используйте --create')
                return

        workshop, _ = Workshop.objects.get_or_create(name='Основной цех', defaults={})
        assignment, created = WorkshopAssignment.objects.get_or_create(user=user, defaults={'workshop': workshop})
        if not created:
            assignment.workshop = workshop
            assignment.save()
        self.stdout.write(self.style.SUCCESS(f'Пользователь {username} привязан к складу "{workshop.name}"'))
