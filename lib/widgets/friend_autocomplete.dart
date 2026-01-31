import 'package:flutter/material.dart';

/// Autocomplete widget for friend name input with case-insensitive search
class FriendAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> existingFriends;
  final Function(String) onFriendSelected;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final String? Function(String?)? validator;

  const FriendAutocomplete({
    super.key,
    required this.controller,
    required this.existingFriends,
    required this.onFriendSelected,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      displayStringForOption: (String option) => option,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.trim().isEmpty) {
          return const Iterable<String>.empty();
        }
        
        final searchText = textEditingValue.text.toLowerCase().trim();
        
        // Filter matches
        final matches = existingFriends.where((String friend) {
          return friend.toLowerCase().contains(searchText);
        }).toList();
        
        // Sort by relevance tiers:
        // Tier 1: Prefix match (name starts with query)
        // Tier 2: Word-boundary prefix (any word starts with query)
        // Tier 3: Substring match (contains query anywhere)
        // Tier 4: Alphabetical fallback within same tier
        matches.sort((a, b) {
          final aLower = a.toLowerCase();
          final bLower = b.toLowerCase();
          
          final aTier = _getRelevanceTier(aLower, searchText);
          final bTier = _getRelevanceTier(bLower, searchText);
          
          if (aTier != bTier) {
            return aTier.compareTo(bTier);
          }
          
          // Same tier: alphabetical (case-insensitive)
          return aLower.compareTo(bLower);
        });
        
        return matches;
      },
      onSelected: (String selection) {
        controller.text = selection;
        onFriendSelected(selection);
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Initialize fieldController with controller's value
        if (fieldController.text.isEmpty && controller.text.isNotEmpty) {
          fieldController.text = controller.text;
          fieldController.selection = TextSelection.fromPosition(
            TextPosition(offset: fieldController.text.length),
          );
        }
        
        // Listen to changes in fieldController and sync with main controller
        fieldController.addListener(() {
          if (controller.text != fieldController.text) {
            controller.text = fieldController.text;
            controller.selection = fieldController.selection;
          }
        });

        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: labelText ?? 'Friend Name',
            hintText: hintText ?? 'Start typing to search...',
            border: const OutlineInputBorder(),
            suffixIcon: fieldController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      fieldController.clear();
                      controller.clear();
                      onFriendSelected('');
                    },
                  )
                : const Icon(Icons.person_search),
          ),
          validator: validator,
          onChanged: (value) {
            // Notify parent about changes
            onFriendSelected(value);
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(
                          option[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(option),
                      dense: true,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Returns relevance tier for sorting (lower = higher priority).
  /// Tier 1: Name starts with query
  /// Tier 2: Any word in name starts with query
  /// Tier 3: Name contains query (substring)
  int _getRelevanceTier(String nameLower, String queryLower) {
    // Tier 1: Prefix match
    if (nameLower.startsWith(queryLower)) {
      return 1;
    }
    
    // Tier 2: Word-boundary prefix (any word starts with query)
    final words = nameLower.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.startsWith(queryLower)) {
        return 2;
      }
    }
    
    // Tier 3: Substring match (already filtered, so must contain)
    return 3;
  }
}
