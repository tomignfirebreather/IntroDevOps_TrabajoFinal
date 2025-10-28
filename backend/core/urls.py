from django.contrib import admin
from django.urls import path, include
from api.health import health

urlpatterns = [
    path("api/users/", include(("api.routers", "api"), namespace="api")),
    path('health/', health)
]
