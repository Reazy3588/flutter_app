import '../../services/shop_session.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/chat_notification_service.dart'; // ✅ បន្ថែម
import '../product/product_browse_screen.dart';
import '../product/product_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../cart/wishlist_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/login_screen.dart';
import 'search_screen.dart';
import '../../widgets/app_bar/home_search_bar.dart';
import '../../widgets/app_bar/home_header.dart';
import '../../models/banner_model.dart';
import '../../services/banner_service.dart';
import '../../widgets/common/promo_banner.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/category/category_icon_grid.dart';
import '../../widgets/category/category_icon_mapper.dart';
import '../../widgets/product/product_grid.dart';
import '../../widgets/nav/main_bottom_nav.dart';
import '../../models/cart.dart';
import '../orders/my_orders_screen.dart';
import '../delivery/delivery_home_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel? user;
  final ShopTheme? shopTheme;
  const HomeScreen({super.key, this.user, this.shopTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final _productService = ProductService();
  final _cartService = CartService();
  final _authService = AuthService();
  final _chatService = ChatNotificationService(); // ✅ បន្ថែម
  final _bannerService = BannerService();
  List<BannerModel> _banners = [];

  bool _loading = true;
  String? _error;
  String? _shopSlug;
  String? _shopName;
  List<CategoryItem> _categoryItems = [];

  List<ProductModel> _recommended = [];
  List<ProductModel> _bestSellers = [];
  List<ProductModel> _newArrivals = [];
  List<ProductModel> _allProducts = [];

  final Set<int> _wishlistedIds = {};
  int _cartCount = 0;

  bool get _isLoggedIn => widget.user != null;

  Color get _primary =>
      widget.shopTheme?.primaryColor ?? const Color(0xFF1F6FEB);

  @override
  void initState() {
    super.initState();

    // ✅ បើជា Delivery → បង្ហាញ DeliveryHomeScreen
    if (widget.user?.role == 'delivery') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DeliveryHomeScreen(user: widget.user!),
          ),
        );
      });
      return;
    }

    _loadShopSlug();

    // ✅ ចាប់ផ្តើម Chat Polling
    if (_isLoggedIn) {
      _chatService.startPolling();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadShopSlug() async {
    _shopSlug = ShopSession.slug;
    _shopName = ShopSession.shopName;

    if (widget.user?.shopSlug != null && widget.user!.shopSlug!.isNotEmpty) {
      _shopSlug = widget.user!.shopSlug;
      _shopName = widget.user!.shopName;
      await ShopSession.setSlug(_shopSlug!, name: _shopName);
    }

    if (widget.shopTheme != null && widget.shopTheme!.slug.isNotEmpty) {
      _shopSlug = widget.shopTheme!.slug;
      _shopName = widget.shopTheme!.name;
    }

    print('🔵 HomeScreen loaded with shop: $_shopSlug');
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = <Future>[
        _productService.getCategories(shopSlug: _shopSlug),
        _productService.getRecommended(shopSlug: _shopSlug),
        _productService.getBestSellers(shopSlug: _shopSlug),
        _productService.getNewArrivals(shopSlug: _shopSlug),
        _productService.getProducts(
            shopSlug: _shopSlug, ordering: '-created_at'),
      ];

      if (_isLoggedIn) {
        futures.add(_cartService.getCart());
      }

      // ✅ Banner ពី backend (មិនគាំង បើ error)
      final banners = await _bannerService.getBanners(shopSlug: _shopSlug);

      final results = await Future.wait(futures);

      if (!mounted) return;

      final categories = results[0] as List<CategoryModel>;
      final recommended = results[1] as List<ProductModel>;
      final bestSellers = results[2] as List<ProductModel>;
      final newArrivals = results[3] as List<ProductModel>;
      final allProducts = results[4] as List<ProductModel>;

      int cartCount = 0;
      if (_isLoggedIn && results.length > 5) {
        final cart = results[5] as Cart;
        cartCount = cart.count;
      }

      setState(() {
        _banners = banners;
        _categoryItems = categories
            .map((c) => CategoryItem(
                  label: c.name,
                  icon: iconForCategoryName(c.name),
                  image: c.image,
                  slug: c.slug,
                ))
            .toList();
        _recommended = recommended;
        _bestSellers = bestSellers;
        _newArrivals = newArrivals;
        _allProducts = allProducts;
        _cartCount = cartCount;
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

  Future<bool> _requireLogin() async {
    if (_isLoggedIn) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Login Required"),
        content: const Text("Please login or sign up to continue."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: const Text("Login"),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginScreen(shopTheme: widget.shopTheme),
        ),
      );
    }
    return false;
  }

  void _openProductDetail(ProductModel product) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(slug: product.slug),
        ))
        .then((_) => _loadData());
  }

  Future<void> _addToCart(ProductModel product) async {
    if (!await _requireLogin()) return;
    try {
      final count = await _cartService.addToCart(product.slug);
      if (!mounted) return;
      setState(() => _cartCount = count);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ ${product.name} added to cart"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ ${extractErrorMessage(e)}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    if (!await _requireLogin()) return;

    final wasWishlisted = _wishlistedIds.contains(product.id);
    setState(() {
      wasWishlisted
          ? _wishlistedIds.remove(product.id)
          : _wishlistedIds.add(product.id);
    });
    try {
      await _cartService.toggleWishlist(product.slug);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        wasWishlisted
            ? _wishlistedIds.add(product.id)
            : _wishlistedIds.remove(product.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("❌ ${extractErrorMessage(e)}"),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openCart() async {
    if (!await _requireLogin()) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CartScreen()));
    try {
      final cart = await _cartService.getCart();
      if (mounted) setState(() => _cartCount = cart.count);
    } catch (_) {}
  }

  void _openCategory(CategoryItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductBrowseScreen(
        categoryItems: _categoryItems,
        initialCategorySlug: item.slug,
      ),
    ));
  }

  void _onBannerTap(BannerModel b) {
    if (b.linkType == 'product' && b.linkValue.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductDetailScreen(slug: b.linkValue),
      ));
    } else if (b.linkType == 'category' && b.linkValue.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductBrowseScreen(
          categoryItems: _categoryItems,
          initialCategorySlug: b.linkValue,
        ),
      ));
    } else {
      _openBrowseAll();
    }
  }

  void _openBrowseAll() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductBrowseScreen(categoryItems: _categoryItems),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 252, 252, 252),
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            _buildTabBody(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _chatService,
                builder: (context, child) {
                  return MainBottomNav(
                    selectedIndex: _currentTab,
                    onTap: (i) => setState(() => _currentTab = i),
                    chatUnreadCount: _chatService.unreadCount, // ✅ បន្ថែម
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_currentTab) {
      case 1:
        return ProductBrowseScreen(
          categoryItems: _categoryItems,
        );

      case 2:
        return WishlistScreen(
          onExplore: () {
            setState(() => _currentTab = 0);
          },
        );

      case 3:
        if (!_isLoggedIn) {
          return LoginScreen(shopTheme: widget.shopTheme);
        }
        return const MyOrdersScreen();

      case 4:
        if (!_isLoggedIn) {
          return LoginScreen(shopTheme: widget.shopTheme);
        }
        return ProfileScreen(user: widget.user!);

      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              HomeHeader(
                userName: widget.user?.fullName,
                shopName: _shopName,
                photoUrl: widget.user?.profilePhoto,
                primary: _primary,
                onAvatarTap: () => setState(() => _currentTab = 4),
              ),
              const SizedBox(height: 12),
              HomeSearchBar(
                onSearchTap: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()));
                },
                onCameraTap: () {},
                onCartTap: _openCart,
                cartItemCount: _cartCount,
              ),
            ],
          ),
        ),
        Expanded(
            child: RefreshIndicator(
          onRefresh: _loadData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16, 4, isWide ? 32 : 16, 130),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PromoBanner(
                        banners: _banners,
                        onBannerTap: _onBannerTap,
                        accent: _primary,
                        title: "Discover the perfect\nshopping journey!",
                        onButtonTap: _openBrowseAll,
                      ),
                      const SizedBox(height: 20),
                      const SectionHeader(
                          title: "Categories", icon: Icons.grid_view_rounded),
                      const SizedBox(height: 8),
                      if (_loading && _categoryItems.isEmpty)
                        const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()))
                      else
                        CategoryIconGrid(
                            items: _categoryItems, onTap: _openCategory),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: "Recommended",
                        icon: Icons.thumb_up_alt_outlined,
                        products: _recommended,
                      ),
                      _buildSection(
                        title: "Best Seller",
                        icon: Icons.local_fire_department_outlined,
                        products: _bestSellers,
                      ),
                      _buildSection(
                        title: "New Arrival",
                        icon: Icons.fiber_new_outlined,
                        products: _newArrivals,
                      ),
                      _buildSection(
                        title: "All Products",
                        icon: Icons.shopping_bag_outlined,
                        products: _allProducts,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<ProductModel> products,
  }) {
    if (_loading && products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title, icon: icon),
            const SizedBox(height: 12),
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          icon: icon,
          actionText: "See more",
          onActionTap: _openBrowseAll,
        ),
        const SizedBox(height: 8),
        ProductGrid(
          products: products,
          wishlistedIds: _wishlistedIds,
          onProductTap: _openProductDetail,
          onAddTap: _addToCart,
          onWishlistTap: _toggleWishlist,
          crossAxisCount: 4,
          childAspectRatio: 0.5,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
