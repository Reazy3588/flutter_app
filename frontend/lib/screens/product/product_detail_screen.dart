import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String slug;

  const ProductDetailScreen({
    super.key,
    required this.slug,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final PageController _pageController = PageController();

  ProductModel? product;
  bool isLoading = true;
  bool adding = false;
  bool togglingWishlist = false;
  bool isFavorite = false;
  bool showFullDescription = false;
  String? error;

  int selectedImage = 0;
  int quantity = 1;

  // 360 Rotation
  double _rotationAngle = 0.0;

  // ✅ Variant Selection
  final Map<String, String> _selectedOptions = {};
  ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadDetail() async {
    try {
      final results = await Future.wait([
        _productService.getProductDetail(widget.slug),
        _productService.getWishlist().catchError((_) => <ProductModel>[]),
      ]);

      if (!mounted) return;

      final fetchedProduct = results[0] as ProductModel;
      final wishlist = results[1] as List<ProductModel>;
      final isWishlisted = wishlist.any((item) => item.id == fetchedProduct.id);

      // ✅ ជ្រើស Option ដំបូង (Black) ដោយស្វ័យប្រវត្តិ
      final Map<String, String> defaultOptions = {};
      for (final option in fetchedProduct.options) {
        if (option.values.isNotEmpty) {
          defaultOptions[option.name] = option.values.first.value;
        }
      }

      // ✅ រក Variant ដែលត្រូវនឹង Default Options
      ProductVariant? defaultVariant;
      if (defaultOptions.isNotEmpty && fetchedProduct.variants.isNotEmpty) {
        for (final variant in fetchedProduct.variants) {
          final variantOptions = variant.displayOptions ?? variant.options;
          bool isMatch = true;
          for (final entry in defaultOptions.entries) {
            if (variantOptions[entry.key]?.toString() != entry.value) {
              isMatch = false;
              break;
            }
          }
          if (isMatch) {
            defaultVariant = variant;
            break;
          }
        }
      }

      setState(() {
        product = fetchedProduct;
        isFavorite = isWishlisted;
        isLoading = false;
        _selectedOptions.addAll(defaultOptions);
        _selectedVariant = defaultVariant;
        if (fetchedProduct.inStock &&
            fetchedProduct.stock > 0 &&
            quantity > fetchedProduct.stock) {
          quantity = fetchedProduct.stock;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  // ✅ ជ្រើស Option
  void _selectOption(String optionName, String value) {
    setState(() {
      _selectedOptions[optionName] = value;
      selectedImage = 0;
      _rotationAngle = 0.0;
    });
    _findMatchingVariant();
  }

  // ✅ រក Variant ដែលត្រូវនឹង Options
  void _findMatchingVariant() {
    if (product == null) {
      setState(() => _selectedVariant = null);
      return;
    }

    if (_selectedOptions.length != product!.options.length) {
      setState(() => _selectedVariant = null);
      return;
    }

    if (product!.variants.isEmpty) {
      setState(() => _selectedVariant = null);
      return;
    }

    // ✅ ព្យាយាមរក Variant ដោយប្រើ displayOptions ឬ options
    ProductVariant? matched;
    for (final variant in product!.variants) {
      final variantOptions = variant.displayOptions ?? variant.options;

      bool isMatch = true;
      for (final entry in _selectedOptions.entries) {
        final variantValue = variantOptions[entry.key]?.toString();
        if (variantValue != entry.value) {
          isMatch = false;
          break;
        }
      }
      if (isMatch) {
        matched = variant;
        break;
      }
    }

    setState(() {
      _selectedVariant = matched;
      if (matched != null) {
        if (matched.stock > 0 && quantity > matched.stock) {
          quantity = matched.stock;
        }
      }
    });
  }

  // ✅ Stock បច្ចុប្បន្ន
  int get _currentStock {
    if (_selectedVariant != null) return _selectedVariant!.stock;
    return product?.stock ?? 0;
  }

  // ✅ តម្លៃបច្ចុប្បន្ន
  double get _currentPrice {
    if (_selectedVariant != null && _selectedVariant!.price != null) {
      return _selectedVariant!.finalPrice;
    }
    return product?.finalPrice ?? 0;
  }

  // ✅ ពិនិត្យថាតើ Variant ត្រូវបានជ្រើសគ្រប់
  bool get _isVariantComplete {
    if (product == null) return false;
    if (product!.options.isEmpty) return true;
    if (_selectedOptions.length != product!.options.length) return false;
    if (product!.variants.isEmpty) return true;
    return _selectedVariant != null;
  }

  Future<void> _toggleFavorite() async {
    if (product == null || togglingWishlist) return;
    HapticFeedback.lightImpact();
    final previousState = isFavorite;
    setState(() {
      isFavorite = !isFavorite;
      togglingWishlist = true;
    });

    try {
      final updatedStatus = await _cartService.toggleWishlist(product!.slug);
      if (!mounted) return;
      setState(() {
        isFavorite = updatedStatus;
        togglingWishlist = false;
      });
      _showSnack(
        updatedStatus ? 'Added to your Wishlist' : 'Removed from your Wishlist',
        updatedStatus ? const Color(0xFFEF4444) : const Color(0xFF334155),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isFavorite = previousState;
        togglingWishlist = false;
      });
    }
  }

  Future<void> addToCart() async {
    if (product == null || adding) return;

    if (!_isVariantComplete) {
      _showSnack('⚠️ Please select all options', const Color(0xFFF59E0B));
      return;
    }

    if (_selectedVariant != null && !_selectedVariant!.inStock) {
      _showSnack('⚠️ This variant is out of stock', const Color(0xFFEF4444));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => adding = true);
    try {
      final count = await _cartService.addToCart(
        product!.slug,
        quantity: quantity,
        variantId: _selectedVariant?.id, // ✅ បញ្ជូន variantId
      );
      if (mounted) {
        _showSnack(
          'Added $quantity × "${product!.name}" to cart',
          const Color(0xFF10B981),
        );
        await loadDetail();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        _showSnack(
          msg.contains('stock') || msg.contains('Out of')
              ? '⚠️ ${product!.name} — ${_extractStockError(msg)}'
              : 'Error: $msg',
          const Color(0xFFEF4444),
        );
      }
    }
    if (mounted) setState(() => adding = false);
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _extractStockError(String msg) {
    final reg = RegExp(r'"error":"([^"]+)"');
    final match = reg.firstMatch(msg);
    if (match != null) return match.group(1)!;
    if (msg.contains('Out of stock')) return 'Out of stock!';
    return 'Not enough stock available';
  }

  List<String> get images {
    if (product == null) return [];

    final List<String> result = [];

    // ✅ បើជ្រើស Variant ហើយវាមានរូបភាព → បង្ហាញរូបនោះជាមុន
    if (_selectedVariant != null &&
        _selectedVariant!.imageUrl != null &&
        _selectedVariant!.imageUrl!.isNotEmpty) {
      result.add(_selectedVariant!.imageUrl!);
    } else if (product!.image != null && product!.image!.isNotEmpty) {
      result.add(product!.image!);
    }

    // បន្ថែមរូបភាព Gallery
    result.addAll(
      product!.galleryImages.where(
        (image) => image.isNotEmpty && image != product!.image,
      ),
    );

    return result;
  }

  void _changeQuantity(int delta) {
    if (product == null) return;
    final maxStock = _currentStock;
    final newQty = quantity + delta;

    if (newQty < 1) return;
    if (maxStock > 0 && newQty > maxStock) {
      HapticFeedback.vibrate();
      _showSnack(
        'Maximum available stock is $maxStock items',
        const Color(0xFFF59E0B),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => quantity = newQty);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1F6FEB)),
        ),
      );
    }

    if (error != null || product == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 54, color: Color(0xFFEF4444)),
                ),
                const SizedBox(height: 20),
                const Text('Failed to load product',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      error = null;
                    });
                    loadDetail();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6FEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = product!;
    final imageList = images;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroCarousel(p, imageList)),
              if (imageList.length > 1)
                SliverToBoxAdapter(child: _buildThumbnailsStrip(imageList)),
              SliverToBoxAdapter(child: _buildProductHeaderCard(p)),

              // ✅ បន្ថែម Variant Selector
              if (p.options.isNotEmpty)
                SliverToBoxAdapter(child: _buildVariantSelector()),

              if (p.inStock)
                SliverToBoxAdapter(child: _buildQuantitySelectorCard(p)),
              SliverToBoxAdapter(child: _buildTrustHighlights()),
              SliverToBoxAdapter(child: _buildDescriptionCard(p)),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildTopBar(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(p),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VARIANT SELECTOR
  // ============================================================
  Widget _buildVariantSelector() {
    if (product == null || product!.options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: product!.options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Option Header
                Row(
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedOptions[option.name] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F6FEB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _selectedOptions[option.name]!,
                          style: const TextStyle(
                            color: Color(0xFF1F6FEB),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Option Values - Button Selector
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: option.values.map((val) {
                    final isSelected =
                        _selectedOptions[option.name] == val.value;
                    return GestureDetector(
                      onTap: () => _selectOption(option.name, val.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1F6FEB)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1F6FEB)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF1F6FEB)
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              val.value,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _circleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
        Row(
          children: [
            _circleIconButton(
              icon: Icons.share_outlined,
              onTap: () {
                HapticFeedback.lightImpact();
                _showSnack('Sharing "${product?.name}"', Colors.black87);
              },
            ),
            const SizedBox(width: 10),
            _circleIconButton(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: isFavorite
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0F172A),
              onTap: _toggleFavorite,
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // HERO CAROUSEL (360 Rotatable)
  // ============================================================
  Widget _buildHeroCarousel(ProductModel p, List<String> imageList) {
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = (screenHeight * 0.44).clamp(340.0, 430.0);

    return Container(
      height: carouselHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 70, bottom: 44),
            child: imageList.isNotEmpty
                ? GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _rotationAngle += details.delta.dx * 0.01;
                      });
                    },
                    child: Center(
                      child: Transform.rotate(
                        angle: _rotationAngle,
                        child: InteractiveViewer(
                          panEnabled: false,
                          scaleEnabled: true,
                          minScale: 0.8,
                          maxScale: 2.5,
                          child: Image.network(
                            imageList[selectedImage],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF1F6FEB)));
                            },
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_rounded,
                                    size: 80, color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_outlined,
                        size: 90, color: Color(0xFFCBD5E1))),
          ),
          Positioned(
            left: 20,
            top: MediaQuery.of(context).padding.top + 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.hasDiscount)
                  _badge(
                    '-${p.discountPercent}% OFF',
                    const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  ),
                if (p.isBestSeller)
                  _badge(
                    'BEST SELLER',
                    const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                    icon: Icons.bolt_rounded,
                  ),
                if (p.isNewArrival && !p.isBestSeller)
                  _badge(
                    'NEW ARRIVAL',
                    const LinearGradient(
                        colors: [Color(0xFF1F6FEB), Color(0xFF1547A8)]),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.threesixty, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Drag to rotate',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          if (imageList.length > 1)
            Positioned(
              right: 18,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x8A0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedImage + 1}/${imageList.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Gradient gradient, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFFFBBF24)),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // THUMBNAILS
  // ============================================================
  Widget _buildThumbnailsStrip(List<String> imageList) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: imageList.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final isSelected = selectedImage == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedImage = index;
                  _rotationAngle = 0.0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1F6FEB)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    imageList[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================
  Widget _buildProductHeaderCard(ProductModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sell_outlined,
                        size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(p.categoryName,
                        style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _buildStockPill(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.28,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(p.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('·  ${p.soldCount} Sold',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B))),
              const Spacer(),
              if (p.isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.thumb_up_alt_rounded,
                          size: 12, color: Color(0xFF4F46E5)),
                      SizedBox(width: 4),
                      Text('Recommended',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${_currentPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: p.hasDiscount
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              if (p.hasDiscount && _selectedVariant?.price == null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('\$${p.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Save \$${(p.price - p.finalPrice).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockPill() {
    final int stock = _currentStock;
    final bool inStock = stock > 0;
    final bool lowStock = inStock && stock <= 5;

    final Color bgColor = inStock
        ? (lowStock ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5))
        : const Color(0xFFFEE2E2);
    final Color textColor = inStock
        ? (lowStock ? const Color(0xFFB45309) : const Color(0xFF047857))
        : const Color(0xFFDC2626);
    final Color dotColor = inStock
        ? (lowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
        : const Color(0xFFEF4444);

    final String label = !inStock
        ? 'Out of Stock'
        : (lowStock ? 'Only $stock left' : 'In Stock ($stock)');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // QUANTITY SELECTOR
  // ============================================================
  Widget _buildQuantitySelectorCard(ProductModel p) {
    final maxStock = _currentStock;
    final bool canDecrease = quantity > 1;
    final bool canIncrease = maxStock <= 0 || quantity < maxStock;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quantity',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(
                  maxStock > 0
                      ? '$maxStock available in stock'
                      : 'Select quantity',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _stepButton(
                    icon: Icons.remove_rounded,
                    enabled: canDecrease,
                    onTap: () => _changeQuantity(-1)),
                Container(
                  constraints: const BoxConstraints(minWidth: 42),
                  alignment: Alignment.center,
                  child: Text('$quantity',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                ),
                _stepButton(
                    icon: Icons.add_rounded,
                    enabled: canIncrease,
                    onTap: () => _changeQuantity(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  // ============================================================
  // TRUST HIGHLIGHTS
  // ============================================================
  Widget _buildTrustHighlights() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _trustCard(
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  title: '100% Original',
                  subtitle: 'Guaranteed Authentic'),
              const SizedBox(width: 12),
              _trustCard(
                  icon: Icons.local_shipping_rounded,
                  iconColor: const Color(0xFF1F6FEB),
                  bgColor: const Color(0xFFEFF6FF),
                  title: 'Free Delivery',
                  subtitle: 'Orders \$50 & above'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _trustCard(
                  icon: Icons.replay_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF5F3FF),
                  title: '7 Days Return',
                  subtitle: 'Hassle-free refund'),
              const SizedBox(width: 12),
              _trustCard(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  title: 'Warranty',
                  subtitle: 'Official Guarantee'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trustCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================
  Widget _buildDescriptionCard(ProductModel p) {
    final rawDescription = p.description?.trim().isNotEmpty == true
        ? p.description!.trim()
        : 'No detailed description provided for this product.';

    final shouldTrim = rawDescription.length > 200;
    final displayText = (!showFullDescription && shouldTrim)
        ? '${rawDescription.substring(0, 200)}...'
        : rawDescription;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 20, color: Color(0xFF1F6FEB)),
              SizedBox(width: 8),
              Text('Product Details',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topLeft,
            child: Text(displayText,
                style: const TextStyle(
                    fontSize: 14, height: 1.65, color: Color(0xFF334155))),
          ),
          if (shouldTrim)
            GestureDetector(
              onTap: () =>
                  setState(() => showFullDescription = !showFullDescription),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(showFullDescription ? 'Read less' : 'Read more',
                        style: const TextStyle(
                            color: Color(0xFF1F6FEB),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(
                        showFullDescription
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF1F6FEB),
                        size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTION BAR
  // ============================================================
  Widget _buildBottomActionBar(ProductModel p) {
    final subtotal = _currentPrice * quantity;
    final bool canAdd = _isVariantComplete && _currentStock > 0;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total ($quantity item${quantity > 1 ? 's' : ''})',
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('\$${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: canAdd && !adding ? addToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F6FEB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: adding
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              canAdd
                                  ? Icons.shopping_bag_outlined
                                  : Icons.remove_shopping_cart_outlined,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            !_isVariantComplete
                                ? 'Select Options'
                                : (canAdd ? 'Add to Cart' : 'Out of Stock'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CIRCLE ICON BUTTON
  // ============================================================
  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}