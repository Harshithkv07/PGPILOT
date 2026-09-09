import 'package:flutter/material.dart';

/// Search box with a clear button that actually appears.
///
/// Each screen was rolling its own, and the students list had a suffix icon
/// driven by controller text with nothing rebuilding the field — so the clear
/// button never showed up. Owning the controller here keeps that fixed in one
/// place.
class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Seeds the field, for a query that outlives the widget (a provider that
  /// keeps the query across tab switches, say).
  final String initialValue;

  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialValue = '',
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: _clear,
              ),
      ),
      onChanged: (value) {
        widget.onChanged(value);
        // Drives the clear button's visibility.
        setState(() {});
      },
    );
  }
}
