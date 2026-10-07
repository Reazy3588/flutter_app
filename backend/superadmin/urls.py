from django.urls import path
from .views import (
    SuperAdminDashboardView,
    CreateTenantView,
    TenantListView,
    TenantDetailView,
)

urlpatterns = [
    path('dashboard/', SuperAdminDashboardView.as_view(), name='superadmin-dashboard'),
    path('create-tenant/', CreateTenantView.as_view(), name='superadmin-create-tenant'),
    path('tenants/', TenantListView.as_view(), name='superadmin-tenants'),
    path('tenants/<int:pk>/', TenantDetailView.as_view(), name='superadmin-tenant-detail'),
]