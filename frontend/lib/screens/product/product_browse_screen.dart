import '../../services/shop_session.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/api_service.dart';
import '../../widgets/category/category_icon_grid.dart';
import '../../widgets/category/category_icon_strip.dart';
import '../../widgets/product/product_grid.dart';
import '../../widgets/product/product_filter_sheet.dart';
import 'product_detail_screen.dart';

enum _SortTab { popular, latest, bestSellers, price }

class ProductBrowseScreen extends StatefulWidget {
  final List<CategoryItem> categoryItems;
  final String? initialCategorySlug;

  const ProductBrowseScreen({
    super.key,
    required this.categoryItems,
    this.initialCategorySlug,
  });

  @override
  State<ProductBrowseScreen> createState() => _ProductBrowseScreenState();
}

class _ProductBrowseScreenState extends State<ProductBrowseScreen> {
  final _productService = ProductService();
  final _searchCtrl = TextEditingController();

  _SortTab _activeTab = _SortTab.popular;
  bool _priceAscending = true;
  String? _selectedCategorySlug;
  String? _shopSlug; // ✅ បន្ថែម

  double? _minPrice;
  double? _maxPrice;
  double? _minRating;

  bool get _hasActiveFilter =>
      _minPrice != null ||
      _maxPrice != null ||
      (_minRating != null && _minRating! > 0);

  bool _loading = true;
  String? _error;
  List<ProductModel> _products = [];

  static const Color primary = Color(0xFF1F6FEB);

  @override
  void initState() {
    super.initState();
    _selectedCategorySlug = widget.initialCategorySlug;
    _loadShopSlugAndProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ✅ ទាញយក Shop Slug មុននឹងផ្ទុក Product
  Future<void> _loadShopSlugAndProducts() async {
    _shopSlug = ShopSession.slug;
    print('🔵 ProductBrowse shop_slug: $_shopSlug');
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? ordering;
      bool? bestSeller;
      switch (_activeTab) {
        case _SortTab.popular:
          ordering = '-sold_count';
          break;
        case _SortTab.latest:
          ordering = '-created_at';
          break;
        case _SortTab.bestSellers:
          bestSeller = true;
          break;
        case _SortTab.price:
          ordering = _priceAscending ? 'price' : '-price';
          break;
      }
      final results = await _productService.getProducts(
        categorySlug: _selectedCategorySlug,
        ordering: ordering,
        isBestSeller: bestSeller,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        minRating: _minRating,
        search:
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        shopSlug: _shopSlug, // ✅ បញ្ជូន shopSlug
      );
      if (!mounted) return;
      setState(() => _products = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTabTap(_SortTab tab) {
    if (tab == _SortTab.price && _activeTab == _SortTab.price) {
      setState(() => _priceAscending = !_priceAscending);
    } else {
      setState(() => _activeTab = tab);
    }
    _loadProducts();
  }

  void _onCategoryTap(CategoryItem item) {
    setState(() {
      if (_selectedCategorySlug == item.slug) {
        _selectedCategorySlug = null;
      } else {
        _selectedCategorySlug = item.slug;
      }
    });
    _loadProducts();
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<ProductFilterValues>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProductFilterSheet(
        initial: ProductFilterValues(
          priceRange: RangeValues(_minPrice ?? 0, _maxPrice ?? 2000),
          minRating: _minRating ?? 0,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _minPrice = result.priceRange.start > 0 ? result.priceRange.start : null;
      _maxPrice = result.priceRange.end < 2000 ? result.priceRange.end : null;
      _minRating = result.minRating > 0 ? result.minRating : null;
    });
    _loadProducts();
  }

  void _clearFilters() {
    setState(() {
      _minPrice = null;
      _maxPrice = null;
      _minRating = null;
      _selectedCategorySlug = null;
      _searchCtrl.clear();
    });
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  color: Colors.grey.shade500, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _loadProducts(),
                                  decoration: InputDecoration(
                                    hintText: "Search products...",
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_searchCtrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    _loadProducts();
                                    setState(() {});
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.grey.shade500, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _openFilterSheet,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F8EF7),
                                    Color(0xFF1F6FEB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            if (_hasActiveFilter)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSortTabs(),
                ],
              ),
            ),
            if (widget.categoryItems.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: CategoryIconStrip(
                  items: widget.categoryItems,
                  selectedSlug: _selectedCategorySlug,
                  onTap: _onCategoryTap,
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSortTabs() {
    Widget tab(String label, _SortTab tab, {IconData? trailingIcon}) {
      final selected = _activeTab == tab;
      return GestureDetector(
        onTap: () => _onTabTap(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF4F8EF7), Color(0xFF1F6FEB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trailingIcon,
                  size: 15,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          tab("Popular", _SortTab.popular),
          tab("Latest", _SortTab.latest),
          tab("Best Sellers", _SortTab.bestSellers),
          tab(
            "Price",
            _SortTab.price,
            trailingIcon:
                _priceAscending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadProducts,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 52, color: primary.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            const Text(
              "No products found",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Try adjusting your filters or search",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            if (_hasActiveFilter ||
                _selectedCategorySlug != null ||
                _searchCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Clear all filters"),
                style: TextButton.styleFrom(foregroundColor: primary),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 13, color: primary),
                    const SizedBox(width: 5),
                    Text(
                      "${_products.length} products",
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            child: ProductGrid(
              products: _products,
              crossAxisCount: 4,
              childAspectRatio: 0.5,
              onProductTap: (product) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(slug: product.slug),
                ));
              },
            ),
          ),
        ),
      ],
    );
  }
}
