from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    RegisterView, VerifyOTPView, ResendOTPView, LoginView, ProfileView,
    ShippingAddressViewSet,
    ForgotPasswordRequestView, ResetPasswordView,GoogleLoginView, 
)

router = DefaultRouter()
router.register('addresses', ShippingAddressViewSet, basename='shipping-address')

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('resend-otp/', ResendOTPView.as_view(), name='resend-otp'),
    path('login/', LoginView.as_view(), name='login'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('forgot-password/', ForgotPasswordRequestView.as_view(), name='forgot-password'),
    path('reset-password/', ResetPasswordView.as_view(), name='reset-password'),
    path('', include(router.urls)),
    path('google/', GoogleLoginView.as_view(), name='google-login'),
] + router.urls