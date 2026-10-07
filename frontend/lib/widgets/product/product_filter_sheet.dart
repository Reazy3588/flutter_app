import 'package:flutter/material.dart';

/// The values a filter sheet session can produce — plain data, so the
/// caller (ProductBrowseScreen) decides how to use them (call the API).
class ProductFilterValues {
  final RangeValues priceRange;
  final double minRating;

  const ProductFilterValues(
      {required this.priceRange, required this.minRating});
}

/// Bottom sheet opened by the "Filter" button — lets the user pick a
/// price range and a minimum rating, then returns the values via
/// Navigator.pop so the caller can re-fetch products with them.
class ProductFilterSheet extends StatefulWidget {
  final double maxPossiblePrice;
  final ProductFilterValues initial;

  const ProductFilterSheet({
    super.key,
    this.maxPossiblePrice = 2000,
    this.initial = const ProductFilterValues(
        priceRange: RangeValues(0, 2000), minRating: 0),
  });

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late RangeValues _priceRange;
  late double _minRating;

  @override
  void initState() {
    super.initState();
    _priceRange = widget.initial.priceRange;
    _minRating = widget.initial.minRating;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Filter",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _priceRange = RangeValues(0, widget.maxPossiblePrice);
                    _minRating = 0;
                  });
                },
                child: const Text("Reset"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Price Range",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: widget.maxPossiblePrice,
            divisions: 40,
            labels: RangeLabels(
              '\$${_priceRange.start.round()}',
              '\$${_priceRange.end.round()}',
            ),
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$${_priceRange.start.round()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text('\$${_priceRange.end.round()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Minimum Rating",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [0.0, 3.0, 3.5, 4.0, 4.5].map((r) {
              final selected = _minRating == r;
              return ChoiceChip(
                label: Text(r == 0 ? "Any" : "$r★"),
                selected: selected,
                onSelected: (_) => setState(() => _minRating = r),
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selected
                      ? Theme.of(context).primaryColor
                      : Colors.black87,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
                side: BorderSide(
                    color: selected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  ProductFilterValues(
                      priceRange: _priceRange, minRating: _minRating),
                );
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("Apply Filter"),
            ),
          ),
        ],
      ),
    );
  }
}
