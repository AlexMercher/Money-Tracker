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
        return existingFriends.where((String friend) {
          return friend.toLowerCase().contains(searchText);
        }).toList();
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
}
