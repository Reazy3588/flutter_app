from django import forms
from .models import Product


class ProductAdminForm(forms.ModelForm):
    """
    Custom Form សម្រាប់ Product Admin
    """
    class Meta:
        model = Product
        fields = '__all__'