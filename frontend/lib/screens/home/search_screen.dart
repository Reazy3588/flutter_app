import '../../services/shop_session.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/api_service.dart';
import '../../widgets/product/product_grid.dart';
import '../product/product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _productService = ProductService();
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  List<ProductModel> _results = [];
  bool _isSearching = false;
  String? _shopSlug; // ✅ បន្ថែម

  @override
  void initState() {
    super.initState();
    _loadShopSlug(); // ✅ ទាញយក Shop Slug មុន
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // ✅ ទាញយក Shop Slug ពី SharedPreferences
  Future<void> _loadShopSlug() async {
    _shopSlug = ShopSession.slug;
    print('🔵 SearchScreen shop_slug: $_shopSlug');
    _loadAllProducts();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      _debounce?.cancel();
      _loadAllProducts();
      setState(() {});
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(text);
    });

    setState(() {});
  }

  Future<void> _loadAllProducts() async {
    setState(() {
      _loading = true;
      _error = null;
      _isSearching = false;
    });
    try {
      final results = await _productService.getProducts(
        ordering: '-created_at',
        shopSlug: _shopSlug, // ✅ បញ្ជូន shopSlug
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _loadAllProducts();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _isSearching = true;
    });
    try {
      final results = await _productService.getProducts(
        search: q,
        shopSlug: _shopSlug, // ✅ បញ្ជូន shopSlug
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _ModernBackButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                  decoration: const InputDecoration(
                    hintText: "Search products...",
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    _loadAllProducts();
                  },
                  child: const Icon(Icons.close, color: Colors.grey, size: 18),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadAllProducts,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _isSearching
                  ? 'No results for "${_controller.text}"'
                  : 'No products available',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(
                _isSearching ? Icons.search : Icons.grid_view_rounded,
                size: 18,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                _isSearching
                    ? '${_results.length} results for "${_controller.text}"'
                    : 'All Products (${_results.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ProductGrid(
              products: _results,
              shrinkWrap: false,
              physics: const AlwaysScrollableScrollPhysics(),
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

class _ModernBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ModernBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ),
    );
  }
}
