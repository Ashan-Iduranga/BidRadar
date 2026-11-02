import 'package:flutter/material.dart';

import '../../core/geo/countries.dart';
import '../../core/theme/tokens.dart';

/// Currencies offered in forms. ISO 4217.
const kCurrencies = ['EUR', 'USD', 'GBP', 'LKR', 'INR', 'SEK', 'PLN', 'CZK'];

/// Searchable country list in a bottom sheet. Returns an alpha-3 code.
Future<String?> showCountryPicker(
  BuildContext context, {
  Set<String> exclude = const {},
  String title = 'Choose a country',
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _CountrySheet(exclude: exclude, title: title),
);

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.exclude, required this.title});
  final Set<String> exclude;
  final String title;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = Countries.normaliseName(_query);
    final items = kCountries.where((c) {
      if (widget.exclude.contains(c.alpha3)) return false;
      if (q.isEmpty) return true;
      return c.alpha3.toLowerCase() == q ||
          c.names.any((n) => Countries.normaliseName(n).contains(q));
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Space.md),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name or code',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No matching country.'))
                : ListView.builder(
                    controller: controller,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final c = items[i];
                      return ListTile(
                        title: Text(c.name),
                        trailing: Text(c.alpha3),
                        onTap: () => Navigator.pop(context, c.alpha3),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Read-only field that opens [showCountryPicker].
class CountryField extends StatelessWidget {
  const CountryField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Country',
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () async {
        final picked = await showCountryPicker(context);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        isEmpty: value == null,
        child: value == null ? null : Text(Countries.nameOf(value!)),
      ),
    );
  }
}
