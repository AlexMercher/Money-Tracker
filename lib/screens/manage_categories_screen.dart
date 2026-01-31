import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/category_service.dart';

/// Screen for managing the two-tier category system.
/// 
/// STRUCTURE:
/// - Class B (Categories): User-created containers
/// - Class A (Notes): Individual notes, can be independent or assigned to a Class B
/// 
/// ACTIONS:
/// - Create Category (Class B)
/// - Rename Category (Class B)
/// - Delete Category (Class B) - notes become independent
/// - Move Note to Category (Class A → Class B)
/// - Remove Note from Category (Class A → Independent)
/// 
/// Access: Settings → Category Management
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<String> _categories = [];  // Class B
  List<NoteInfo> _independentNotes = [];  // Class A not in any Class B
  Map<String, List<String>> _categoryNotes = {};  // Class B -> list of Class A
  bool _isLoading = true;

  // Multi-select state (Class A notes only)
  bool _isMultiSelectMode = false;
  final Set<String> _selectedNotes = {};  // Normalized note names

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final categories = await CategoryService.getAllCategories();
      final independentNotes = await CategoryService.getIndependentNotes();
      
      // Load notes for each category
      final Map<String, List<String>> categoryNotes = {};
      for (final category in categories) {
        categoryNotes[category] = await CategoryService.getNotesInCategory(category);
      }
      
      setState(() {
        _categories = categories;
        _independentNotes = independentNotes;
        _categoryNotes = categoryNotes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ============================================================
  // MULTI-SELECT (Class A Notes Only)
  // ============================================================

  void _enterMultiSelectMode(String noteName) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedNotes.clear();
      _selectedNotes.add(noteName.toLowerCase());
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedNotes.clear();
    });
  }

  void _toggleNoteSelection(String noteName) {
    setState(() {
      final normalized = noteName.toLowerCase();
      if (_selectedNotes.contains(normalized)) {
        _selectedNotes.remove(normalized);
        // Auto-exit if nothing selected
        if (_selectedNotes.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedNotes.add(normalized);
      }
    });
  }

  bool _isNoteSelected(String noteName) {
    return _selectedNotes.contains(noteName.toLowerCase());
  }

  Future<void> _showBulkMoveDialog() async {
    if (_selectedNotes.isEmpty) return;
    
    if (_categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create a category first to move notes into.'),
          ),
        );
      }
      return;
    }
    
    final targetCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Notes to Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move ${_selectedNotes.length} note(s) to:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final noteCount = _categoryNotes[category]?.length ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(category),
                      subtitle: Text('$noteCount note(s)'),
                      onTap: () => Navigator.of(context).pop(category),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (targetCategory == null) return;
    
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Move'),
        content: Text(
          'Move ${_selectedNotes.length} note(s) to "$targetCategory"?\n\n'
          'This will assign all selected notes to the category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Require authentication
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate to move notes',
    );
    
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to move notes.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await HapticFeedback.mediumImpact();
    
    // Perform bulk move (all-or-nothing approach)
    final notesToMove = List<String>.from(_selectedNotes);
    int successCount = 0;
    
    for (final noteName in notesToMove) {
      final success = await CategoryService.assignNoteToCategory(noteName, targetCategory);
      if (success) successCount++;
    }
    
    if (mounted) {
      if (successCount == notesToMove.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount note(s) moved to "$targetCategory"'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount of ${notesToMove.length} note(s) moved'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to move notes'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      
      _exitMultiSelectMode();
      await _loadData();
    }
  }

  // ============================================================
  // CLASS B (Category) Actions
  // ============================================================

  Future<void> _showCreateCategoryDialog() async {
    final controller = TextEditingController();
    String? errorText;
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new category to group related notes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Category name',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final trimmed = value.trim();
                  String? error;
                  
                  if (trimmed.isEmpty) {
                    error = 'Name cannot be empty';
                  } else if (_categories.any((c) => 
                      c.toLowerCase() == trimmed.toLowerCase())) {
                    error = 'Category already exists';
                  }
                  
                  setDialogState(() => errorText = error);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                
                if (trimmed.isEmpty) {
                  setDialogState(() => errorText = 'Name cannot be empty');
                  return;
                }
                
                if (_categories.any((c) => 
                    c.toLowerCase() == trimmed.toLowerCase())) {
                  setDialogState(() => errorText = 'Category already exists');
                  return;
                }
                
                Navigator.of(context).pop(trimmed);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    
    controller.dispose();
    
    if (name == null || name.isEmpty) return;
    
    // Require authentication
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate to create category',
    );
    
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to create category.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await HapticFeedback.mediumImpact();
    
    final success = await CategoryService.createCategory(name);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" created'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create category'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showRenameCategoryDialog(String category) async {
    final controller = TextEditingController(text: category);
    String? errorText;
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rename Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current name: $category',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'New name',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final trimmed = value.trim();
                  String? error;
                  
                  if (trimmed.isEmpty) {
                    error = 'Name cannot be empty';
                  } else if (trimmed.toLowerCase() != category.toLowerCase() &&
                      _categories.any((c) => 
                          c.toLowerCase() == trimmed.toLowerCase())) {
                    error = 'Category already exists';
                  }
                  
                  setDialogState(() => errorText = error);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                
                if (trimmed.isEmpty) {
                  setDialogState(() => errorText = 'Name cannot be empty');
                  return;
                }
                
                if (trimmed.toLowerCase() != category.toLowerCase() &&
                    _categories.any((c) => 
                        c.toLowerCase() == trimmed.toLowerCase())) {
                  setDialogState(() => errorText = 'Category already exists');
                  return;
                }
                
                Navigator.of(context).pop(trimmed);
              },
              child: const Text('Rename'),
            ),
          ],
        ),
      ),
    );
    
    controller.dispose();
    
    if (newName == null || newName.isEmpty) return;
    if (newName.toLowerCase() == category.toLowerCase()) return;
    
    // Require authentication
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate to rename category',
    );
    
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to rename category.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await HapticFeedback.mediumImpact();
    
    final success = await CategoryService.renameCategory(category, newName);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category renamed to "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to rename category'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteCategoryDialog(String category) async {
    final notesInCategory = _categoryNotes[category] ?? [];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          notesInCategory.isEmpty
              ? 'Delete category "$category"?'
              : 'Delete category "$category"?\n\n'
                  '${notesInCategory.length} note(s) will become independent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Require authentication
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate to delete category',
    );
    
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to delete category.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await HapticFeedback.mediumImpact();
    
    final success = await CategoryService.deleteCategory(category);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$category" deleted'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete category'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showCategoryMenu(String category) {
    final notesInCategory = _categoryNotes[category] ?? [];
    
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    category,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${notesInCategory.length} note(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (notesInCategory.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('View Notes'),
                subtitle: const Text('See all notes in this category'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showNotesInCategory(category, notesInCategory);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              subtitle: const Text('Change the category name'),
              onTap: () {
                Navigator.of(context).pop();
                _showRenameCategoryDialog(category);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              subtitle: const Text('Notes will become independent'),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteCategoryDialog(category);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showNotesInCategory(String category, List<String> notes) {
    // Local multi-select state for this bottom sheet
    final Set<String> selectedInSheet = {};
    bool isSelecting = false;
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> bulkMoveFromCategory() async {
            if (selectedInSheet.isEmpty) return;
            
            // Get other categories (not the current one)
            final otherCategories = _categories.where((c) => c.toLowerCase() != category.toLowerCase()).toList();
            
            if (otherCategories.isEmpty) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Create another category to move notes into.'),
                ),
              );
              return;
            }
            
            final targetCategory = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Move Notes to Category'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move ${selectedInSheet.length} note(s) to:',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.3,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: otherCategories.length,
                          itemBuilder: (ctx, index) {
                            final cat = otherCategories[index];
                            final noteCount = _categoryNotes[cat]?.length ?? 0;
                            return ListTile(
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(cat),
                              subtitle: Text('$noteCount note(s)'),
                              onTap: () => Navigator.of(ctx).pop(cat),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
            
            if (targetCategory == null) return;
            
            // Confirmation
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirm Bulk Move'),
                content: Text(
                  'Move ${selectedInSheet.length} note(s) from "$category" to "$targetCategory"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Move'),
                  ),
                ],
              ),
            );
            
            if (confirmed != true) return;
            
            // Auth
            final authenticated = await AuthService.authenticate(
              localizedReason: 'Authenticate to move notes',
            );
            
            if (!authenticated) {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Authentication required to move notes.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            
            await HapticFeedback.mediumImpact();
            
            final notesToMove = List<String>.from(selectedInSheet);
            int successCount = 0;
            
            for (final noteName in notesToMove) {
              final success = await CategoryService.assignNoteToCategory(noteName, targetCategory);
              if (success) successCount++;
            }
            
            Navigator.of(context).pop();
            
            if (mounted) {
              if (successCount == notesToMove.length) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('$successCount note(s) moved to "$targetCategory"'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (successCount > 0) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('$successCount of ${notesToMove.length} note(s) moved'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to move notes'),
                    backgroundColor: Theme.of(this.context).colorScheme.error,
                  ),
                );
              }
              
              await _loadData();
            }
          }
          
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (isSelecting)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setSheetState(() {
                                isSelecting = false;
                                selectedInSheet.clear();
                              }),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  isSelecting 
                                      ? '${selectedInSheet.length} selected'
                                      : 'Notes in "$category"',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!isSelecting)
                                  Text(
                                    '${notes.length} note(s)',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isSelecting && notes.length > 1)
                            TextButton.icon(
                              onPressed: () => setSheetState(() => isSelecting = true),
                              icon: const Icon(Icons.checklist, size: 18),
                              label: const Text('Select'),
                            )
                          else if (isSelecting)
                            TextButton.icon(
                              onPressed: selectedInSheet.isEmpty ? null : bulkMoveFromCategory,
                              icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                              label: const Text('Move'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final isSelected = selectedInSheet.contains(note.toLowerCase());
                      return ListTile(
                        leading: isSelecting
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => setSheetState(() {
                                  final normalized = note.toLowerCase();
                                  if (selectedInSheet.contains(normalized)) {
                                    selectedInSheet.remove(normalized);
                                  } else {
                                    selectedInSheet.add(normalized);
                                  }
                                }),
                              )
                            : const Icon(Icons.description_outlined),
                        title: Text(note),
                        tileColor: isSelected 
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                        trailing: isSelecting
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _removeNoteFromCategory(note);
                                },
                              ),
                        onTap: isSelecting
                            ? () => setSheetState(() {
                                final normalized = note.toLowerCase();
                                if (selectedInSheet.contains(normalized)) {
                                  selectedInSheet.remove(normalized);
                                } else {
                                  selectedInSheet.add(normalized);
                                }
                              })
                            : null,
                        onLongPress: !isSelecting && notes.length > 1
                            ? () => setSheetState(() {
                                isSelecting = true;
                                selectedInSheet.add(note.toLowerCase());
                              })
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // CLASS A (Note) Actions
  // ============================================================

  Future<void> _showMoveNoteDialog(NoteInfo note) async {
    if (_categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create a category first to move notes into.'),
          ),
        );
      }
      return;
    }
    
    final targetCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Note to Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move "${note.name}" to:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final noteCount = _categoryNotes[category]?.length ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(category),
                      subtitle: Text('$noteCount note(s)'),
                      onTap: () => Navigator.of(context).pop(category),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (targetCategory == null) return;
    
    await HapticFeedback.lightImpact();
    
    final success = await CategoryService.assignNoteToCategory(note.name, targetCategory);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${note.name}" moved to "$targetCategory"'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to move note'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeNoteFromCategory(String noteName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Category'),
        content: Text('Make "$noteName" independent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    await HapticFeedback.lightImpact();
    
    final success = await CategoryService.removeNoteFromCategory(noteName);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$noteName" is now independent'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove note from category'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showNoteMenu(NoteInfo note) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    note.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${note.frequency} occurrence(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move to Category'),
              subtitle: const Text('Assign to a category'),
              onTap: () {
                Navigator.of(context).pop();
                _showMoveNoteDialog(note);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isMultiSelectMode ? _buildMultiSelectAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty && _independentNotes.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Explanatory text
                      if (!_isMultiSelectMode)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text(
                            'Categories group related notes for cleaner charts. '
                            'Independent notes appear separately in the pie chart.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tap notes to select, then tap "Move" to assign them to a category.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Categories Section (Class B) - NOT selectable
                      _buildSectionHeader(
                        'Categories',
                        subtitle: '${_categories.length} created',
                        trailing: _isMultiSelectMode
                            ? null
                            : TextButton.icon(
                                onPressed: _showCreateCategoryDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('New'),
                              ),
                      ),
                      if (_categories.isEmpty)
                        _buildEmptySection(
                          'No categories yet',
                          'Tap + to create your first category',
                        )
                      else
                        ..._categories.map((category) {
                          final noteCount = _categoryNotes[category]?.length ?? 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Icon(
                                  Icons.folder_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                              title: Text(category),
                              subtitle: Text('$noteCount note(s)'),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _showCategoryMenu(category),
                              ),
                            ),
                          );
                        }),
                      
                      const SizedBox(height: 24),
                      
                      // Independent Notes Section (Class A) - Selectable
                      _buildSectionHeader(
                        'Independent Notes',
                        subtitle: _isMultiSelectMode 
                            ? '${_selectedNotes.length} selected'
                            : '${_independentNotes.length} notes',
                        trailing: _independentNotes.isNotEmpty && !_isMultiSelectMode
                            ? TextButton.icon(
                                onPressed: () => setState(() {
                                  _isMultiSelectMode = true;
                                  _selectedNotes.clear();
                                }),
                                icon: const Icon(Icons.checklist, size: 18),
                                label: const Text('Select'),
                              )
                            : null,
                      ),
                      if (_independentNotes.isEmpty)
                        _buildEmptySection(
                          'No independent notes',
                          'All notes are in categories or no expenses yet',
                        )
                      else
                        ..._independentNotes.map((note) {
                          final isSelected = _isNoteSelected(note.name);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                                : null,
                            child: ListTile(
                              leading: _isMultiSelectMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleNoteSelection(note.name),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      child: Icon(
                                        Icons.description_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                              title: Text(note.name),
                              subtitle: Text('${note.frequency} expense(s)'),
                              trailing: _isMultiSelectMode
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () => _showNoteMenu(note),
                                    ),
                              onTap: _isMultiSelectMode
                                  ? () => _toggleNoteSelection(note.name)
                                  : null,
                              onLongPress: !_isMultiSelectMode
                                  ? () => _enterMultiSelectMode(note.name)
                                  : null,
                            ),
                          );
                        }),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Manage Categories'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Create Category',
          onPressed: _showCreateCategoryDialog,
        ),
      ],
    );
  }

  AppBar _buildMultiSelectAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: _exitMultiSelectMode,
      ),
      title: Text('${_selectedNotes.length} selected'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      actions: [
        TextButton.icon(
          onPressed: _selectedNotes.isEmpty ? null : _showBulkMoveDialog,
          icon: Icon(
            Icons.drive_file_move_outlined,
            color: _selectedNotes.isEmpty 
                ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5)
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          label: Text(
            'Move',
            style: TextStyle(
              color: _selectedNotes.isEmpty 
                  ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5)
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No categories or notes yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notes are learned automatically when you add self-expenses. '
              'Create categories to group related notes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateCategoryDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Category'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEmptySection(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
