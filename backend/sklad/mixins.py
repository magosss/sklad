"""Mixin для фильтрации по цеху."""
from .services import get_workshop_for_user


class WorkshopFilterMixin:
    """Склад берётся из профиля пользователя."""

    def get_workshop(self):
        return get_workshop_for_user(self.request.user)

    def get_workshop_queryset(self, model, base_qs=None):
        """Возвращает queryset, отфильтрованный по цеху пользователя."""
        workshop = self.get_workshop()
        if base_qs is not None:
            qs = base_qs
        else:
            qs = model.objects.all()
        if workshop:
            return qs.filter(workshop=workshop)
        return qs.filter(workshop__isnull=True)
