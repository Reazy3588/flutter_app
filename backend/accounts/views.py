import requests as http_requests
from django.utils.crypto import get_random_string
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework import generics, permissions, status, viewsets
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import PhoneOTP, ShippingAddress, generate_otp_code, default_otp_expiry
from .serializers import (
    RegisterSerializer,
    VerifyOTPSerializer,
    ResendOTPSerializer,
    LoginSerializer,
    UserSerializer,
    ShippingAddressSerializer,
    ForgotPasswordRequestSerializer,
    ResetPasswordSerializer,
)
from .utils import send_otp_sms

User = get_user_model()


# ==================== REGISTER ====================

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(
            data=request.data,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        otp = PhoneOTP.objects.create(
            phone_number=user.phone_number,
            code=generate_otp_code(),
            purpose=PhoneOTP.PURPOSE_SIGNUP,
            expires_at=default_otp_expiry(),
        )
        send_otp_sms(user.phone_number, otp.code, purpose="signup")

        data = {
            "message": "Registered successfully. OTP sent to your phone number.",
            "phone_number": user.phone_number,
        }
        if getattr(settings, 'OTP_DEBUG_MODE', False):
            data["debug_otp_code"] = otp.code

        return Response(data, status=status.HTTP_201_CREATED)


# ==================== VERIFY OTP ====================

# accounts/views.py

# ... (Import ដើមដូចដើម) ...

class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        otp = serializer.validated_data['otp']
        phone_number = serializer.validated_data['phone_number']
        shop_slug = serializer.validated_data.get('shop_slug')  # ✅ បន្ថែម

        otp.is_used = True
        otp.save(update_fields=['is_used'])

        # ✅ រក User ដែលទើបបង្កើត (is_active=False)
        query = User.objects.filter(
            phone_number=phone_number,
            is_active=False
        )
        
        # ✅ បើមាន shop_slug → រកតែក្នុង Shop នោះ
        if shop_slug:
            from shops.models import Shop
            try:
                shop = Shop.objects.get(slug=shop_slug)
                query = query.filter(shop=shop)
            except Shop.DoesNotExist:
                pass
        
        user = query.order_by('-date_joined').first()

        if user is None:
            return Response(
                {"detail": "User not found or already verified."},
                status=status.HTTP_404_NOT_FOUND
            )

        user.is_active = True
        user.is_phone_verified = True
        user.save(update_fields=['is_active', 'is_phone_verified'])

        refresh = RefreshToken.for_user(user)
        return Response({
            "message": "Phone number verified. You are now logged in.",
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
        })


# ... (View ផ្សេងទៀតរក្សាដើម) ...


# ==================== RESEND OTP ====================

class ResendOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ResendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data['phone_number']

        if not User.objects.filter(phone_number=phone_number).exists():
            return Response(
                {"detail": "Phone number not registered."},
                status=status.HTTP_404_NOT_FOUND
            )

        otp = PhoneOTP.objects.create(
            phone_number=phone_number,
            code=generate_otp_code(),
            purpose=PhoneOTP.PURPOSE_SIGNUP,
            expires_at=default_otp_expiry(),
        )
        send_otp_sms(phone_number, otp.code, purpose="signup")

        data = {"message": "OTP resent."}
        if getattr(settings, 'OTP_DEBUG_MODE', False):
            data["debug_otp_code"] = otp.code
        return Response(data)


# ==================== LOGIN ====================

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        tokens = serializer.get_tokens(user)

        return Response({
            **tokens,
            "user": UserSerializer(user).data,
        })


# ==================== PROFILE ====================

class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


# ==================== SHIPPING ADDRESS ====================

class ShippingAddressViewSet(viewsets.ModelViewSet):
    serializer_class = ShippingAddressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ShippingAddress.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'], url_path='set-default')
    def set_default(self, request, pk=None):
        address = self.get_object()
        address.is_default = True
        address.save()
        return Response(ShippingAddressSerializer(address).data)


# ==================== FORGOT PASSWORD ====================

class ForgotPasswordRequestView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ForgotPasswordRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data['phone_number']

        otp = PhoneOTP.objects.create(
            phone_number=phone_number,
            code=generate_otp_code(),
            purpose=PhoneOTP.PURPOSE_RESET,
            expires_at=default_otp_expiry(),
        )
        send_otp_sms(phone_number, otp.code, purpose="reset")

        data = {
            "message": "A password reset code has been sent to your phone number.",
            "phone_number": phone_number,
        }
        if getattr(settings, 'OTP_DEBUG_MODE', False):
            data["debug_otp_code"] = otp.code

        return Response(data)


class ResetPasswordView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        otp = serializer.validated_data['otp']
        user = serializer.validated_data['user']
        new_password = serializer.validated_data['new_password']

        otp.is_used = True
        otp.save(update_fields=['is_used'])

        user.set_password(new_password)
        user.save(update_fields=['password'])

        refresh = RefreshToken.for_user(user)
        return Response({
            "message": "Password reset successfully. You are now logged in.",
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
        })


# ==================== GOOGLE LOGIN ====================

class GoogleLoginView(APIView):
    """
    POST /api/auth/google/
    Body: { 
      "token": "google_id_token" OR "access_token": "...",
      "shop_slug": "ans-shop"  # ✅ បន្ថែម
    }
    """
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('token')
        access_token = request.data.get('access_token')
        shop_slug = request.data.get('shop_slug')  # ✅ បន្ថែម

        try:
            email = None
            full_name = ''

            if token:
                idinfo = id_token.verify_oauth2_token(
                    token,
                    google_requests.Request(),
                    settings.GOOGLE_CLIENT_ID
                )
                email = idinfo.get('email')
                full_name = idinfo.get('name', '')

            elif access_token:
                response = http_requests.get(
                    'https://www.googleapis.com/oauth2/v3/userinfo',
                    headers={'Authorization': f'Bearer {access_token}'}
                )
                if response.status_code == 200:
                    userinfo = response.json()
                    email = userinfo.get('email')
                    full_name = userinfo.get('name', '')
                else:
                    return Response(
                        {"error": "Invalid access token"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            else:
                return Response(
                    {"error": "Google token is required"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not email:
                return Response(
                    {"error": "Email not provided by Google"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ═══════════════════════════════════════════════════════════
            # ✅ រក Shop ពី shop_slug
            # ═══════════════════════════════════════════════════════════
            shop = None
            if shop_slug:
                try:
                    from shops.models import Shop
                    shop = Shop.objects.get(slug=shop_slug)
                except Shop.DoesNotExist:
                    pass

            # ═══════════════════════════════════════════════════════════
            # ✅ រក ឬ បង្កើត User
            # ═══════════════════════════════════════════════════════════
            try:
                # ព្យាយាមរក User ក្នុង Shop នេះជាមុន
                if shop:
                    user = User.objects.get(email=email, shop=shop)
                else:
                    user = User.objects.get(email=email)
                created = False
            except User.DoesNotExist:
                base_username = email.split('@')[0]
                username = base_username
                counter = 1
                while User.objects.filter(username=username).exists():
                    username = f"{base_username}{counter}"
                    counter += 1

                user = User.objects.create(
                    email=email,
                    username=username,
                    full_name=full_name,
                    phone_number=None,
                    is_active=True,
                    is_phone_verified=True,
                    shop=shop,           # ✅ បន្ថែម
                    role='customer',     # ✅ បន្ថែម
                )
                user.set_unusable_password()
                user.save(update_fields=['password'])
                created = True

            refresh = RefreshToken.for_user(user)

            return Response({
                "message": "Login successful",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
                "is_new_user": created,
                "needs_password": not user.has_usable_password(),
            })

        except ValueError as e:
            return Response(
                {"error": f"Invalid Google token: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            import traceback
            traceback.print_exc()
            return Response(
                {"error": f"Login failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )