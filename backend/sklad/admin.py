from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User
from .models import Item, SizeQuantity, Supply, SupplyLineItem, Workshop, WorkshopAssignment


class WorkshopAssignmentInline(admin.StackedInline):
    model = WorkshopAssignment
    can_delete = False
    verbose_name = 'Склад'
    verbose_name_plural = 'Склад'


class UserAdminWithWorkshop(BaseUserAdmin):
    inlines = [WorkshopAssignmentInline]
    list_display = ['username', 'email', 'get_workshop', 'is_staff']

    def get_workshop(self, obj):
        try:
            return obj.workshop_assignment.workshop
        except Exception:
            return '-'

    get_workshop.short_description = 'Склад'


admin.site.unregister(User)
admin.site.register(User, UserAdminWithWorkshop)


@admin.register(Workshop)
class WorkshopAdmin(admin.ModelAdmin):
    list_display = ['name', 'created_at']


@admin.register(WorkshopAssignment)
class WorkshopAssignmentAdmin(admin.ModelAdmin):
    list_display = ['user', 'workshop']


class SizeQuantityInline(admin.TabularInline):
    model = SizeQuantity
    extra = 0


class SupplyLineItemInline(admin.TabularInline):
    model = SupplyLineItem
    extra = 0


@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    inlines = [SizeQuantityInline]
    list_display = ['name', 'price', 'workshop', 'created_at']
    list_filter = ['workshop']


@admin.register(Supply)
class SupplyAdmin(admin.ModelAdmin):
    inlines = [SupplyLineItemInline]
    list_display = ['number', 'type', 'workshop', 'created_by', 'date']
    list_filter = ['workshop']
