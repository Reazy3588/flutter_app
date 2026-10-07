from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from .models import Shop, ShopSettings
from .serializers import (
    ShopSerializer,
    ShopPublicSerializer,
    ShopUpdateSerializer,
    ShopSettingsSerializer,
)


class ShopThemeView(APIView):
    """
    GET /api/shops/<slug>/theme/
    ទាញយក Theme របស់ហាង — ប្រើសម្រាប់ Flutter App
    មិនត្រូវការ Login (AllowAny)
    """
    permission_classes = [AllowAny]
    
    def get(self, request, slug):
        try:
            shop = Shop.objects.get(slug=slug, is_active=True)
        except Shop.DoesNotExist:
            return Response(
                {"error": "Shop not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = ShopPublicSerializer(shop, context={'request': request})
        return Response(serializer.data)


class MyShopView(APIView):
    """
    GET /api/shops/me/ — មើលព័ត៌មានហាងខ្លួនឯង
    PATCH /api/shops/me/ — កែព័ត៌មានហាងខ្លួនឯង
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    
    def get_shop(self, user):
        try:
            return Shop.objects.get(owner=user)
        except Shop.DoesNotExist:
            return None
    
    def get(self, request):
        shop = self.get_shop(request.user)
        if not shop:
            return Response(
                {"error": "You don't have a shop yet"},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = ShopSerializer(shop)
        return Response(serializer.data)
    
    def patch(self, request):
        shop = self.get_shop(request.user)
        if not shop:
            return Response(
                {"error": "You don't have a shop yet"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = ShopUpdateSerializer(
            shop,
            data=request.data,
            partial=True
        )
        if serializer.is_valid():
            serializer.save()
            return Response(ShopSerializer(shop).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ShopSettingsView(APIView):
    """
    GET /api/shops/me/settings/ — មើលការកំណត់
    PATCH /api/shops/me/settings/ — កែការកំណត់
    """
    permission_classes = [IsAuthenticated]
    
    def get_settings(self, user):
        try:
            shop = Shop.objects.get(owner=user)
            settings, created = ShopSettings.objects.get_or_create(shop=shop)
            return settings
        except Shop.DoesNotExist:
            return None
    
    def get(self, request):
        settings = self.get_settings(request.user)
        if not settings:
            return Response(
                {"error": "You don't have a shop yet"},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = ShopSettingsSerializer(settings)
        return Response(serializer.data)
    
    def patch(self, request):
        settings = self.get_settings(request.user)
        if not settings:
            return Response(
                {"error": "You don't have a shop yet"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = ShopSettingsSerializer(
            settings,
            data=request.data,
            partial=True
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)