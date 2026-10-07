import django_filters
from .models import Product


class ProductFilter(django_filters.FilterSet):
    """
    Custom FilterSet so the "Filter" button in Flutter can send a real
    price range, not just an exact match:
      ?min_price=10&max_price=200
      ?min_rating=4
    """
    min_price = django_filters.NumberFilter(field_name='price', lookup_expr='gte')
    max_price = django_filters.NumberFilter(field_name='price', lookup_expr='lte')
    min_rating = django_filters.NumberFilter(field_name='rating', lookup_expr='gte')

    class Meta:
        model = Product
        fields = {
            'category__slug': ['exact'],
            'is_new_arrival': ['exact'],
            'is_best_seller': ['exact'],
            'is_recommended': ['exact'],
        }