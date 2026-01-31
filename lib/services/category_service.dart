import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A node in the Trie data structure for fast prefix-based note lookup.
class TrieNode {
  final Map<String, TrieNode> children = {};
  final Set<String> notes = {};
  
  Map<String, dynamic> toJson() => {
    'children': children.map((k, v) => MapEntry(k, v.toJson())),
    'notes': notes.toList(),
  };
  
  static TrieNode fromJson(Map<String, dynamic> json) {
    final node = TrieNode();
    final childrenMap = json['children'] as Map<String, dynamic>? ?? {};
    for (final entry in childrenMap.entries) {
      node.children[entry.key] = TrieNode.fromJson(entry.value as Map<String, dynamic>);
    }
    // Support both 'notes' (new) and 'categories' (old) keys for backwards compatibility
    final notes = json['notes'] as List<dynamic>? ?? json['categories'] as List<dynamic>? ?? [];
    node.notes.addAll(notes.cast<String>());
    return node;
  }
}

/// Service for managing the two-tier category system.
/// 
/// CLASS A (Notes):
/// - Every unique note string from self-expenses
/// - Can exist independently OR belong to exactly one Class B
/// - Displayed in pie chart (individually if independent, aggregated if in Class B)
/// 
/// CLASS B (Categories):
/// - Explicitly created by user
/// - Can contain multiple Class A notes
/// - Cannot contain other Class B
/// - Can only be renamed (not merged or moved)
/// 
/// TRIE:
/// - Used purely for autocomplete suggestions
/// - Learns from all valid transaction notes
/// - Separate from the Class A/B assignment system
class CategoryService {
  // Storage keys
  static const String _notesMapKey = 'notes_map';           // Class A: note -> frequency
  static const String _categoriesKey = 'categories_v2';     // Class B: list of user-created categories  
  static const String _noteAssignmentKey = 'note_assignment'; // Class A -> Class B mapping
  static const String _trieKey = 'category_trie';
  static const String _migrationDoneKey = 'category_migration_done_v1';
  
  // Legacy keys for backwards compatibility
  static const String _legacyCategoryMapKey = 'category_map';
  static const String _legacyCategoryFrequencyKey = 'category_frequency';
  
  // Minimum note length to be considered valid for learning
  static const int _minNoteLength = 3;
  
  // Notes that should NEVER be learned.
  // All entries must be lowercase for case-insensitive matching.
  static final Set<String> _invalidNotes = {
    // Empty/placeholder values
    '',
    'no note',
    'none',
    '.',
    '..',
    '...',
    '--',
    '-',
    'n/a',
    'na',
    'nil',
    'null',
    'empty',
    'test',
    'xxx',
    'abc',
    '123',
    // SYSTEM-GENERATED STRINGS (CRITICAL - never learn these)
    'split transaction',
    'single transaction',
    'transaction',
    'my share',
    'you (my share)',
  };
  
  // Patterns that indicate auto-generated or placeholder text
  static final List<RegExp> _invalidPatterns = [
    RegExp(r'^\s*$'),
    RegExp(r'^[.\-_,;:!?]+$'),
    RegExp(r'^\d+$'),
    RegExp(r'\(my\s*share\)', caseSensitive: false),
    RegExp(r'\(myshare\)', caseSensitive: false),
    RegExp(r'^you\s*\(', caseSensitive: false),
    RegExp(r'^split\s+transaction', caseSensitive: false),
    RegExp(r'^single\s+transaction', caseSensitive: false),
  ];

  // In-memory Trie root (lazy loaded)
  static TrieNode? _trieRoot;

  // ============================================================
  // NOTE NORMALIZATION & VALIDATION
  // ============================================================

  /// Normalize a note for consistent storage and matching.
  /// Returns null if the note is invalid/should not be learned.
  static String? normalizeNote(String note) {
    String normalized = note.trim();
    
    if (normalized.length < _minNoteLength) {
      return null;
    }
    
    normalized = normalized.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'^[.\-_,;:!?\s]+'), '');
    normalized = normalized.replaceAll(RegExp(r'[.\-_,;:!?\s]+$'), '');
    
    if (normalized.length < _minNoteLength) {
      return null;
    }
    
    if (_invalidNotes.contains(normalized)) {
      return null;
    }
    
    for (final pattern in _invalidPatterns) {
      if (pattern.hasMatch(note)) {
        return null;
      }
    }
    
    return normalized;
  }

  /// Check if a note is valid for learning.
  static bool isValidForLearning(String note) {
    return normalizeNote(note) != null;
  }

  // ============================================================
  // TRIE OPERATIONS (for autocomplete)
  // ============================================================

  static Future<TrieNode> _loadTrie() async {
    if (_trieRoot != null) {
      return _trieRoot!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final trieJson = prefs.getString(_trieKey);
    
    if (trieJson != null) {
      try {
        _trieRoot = TrieNode.fromJson(json.decode(trieJson));
      } catch (e) {
        _trieRoot = TrieNode();
      }
    } else {
      _trieRoot = TrieNode();
    }
    
    return _trieRoot!;
  }

  static Future<void> _saveTrie() async {
    if (_trieRoot == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trieKey, json.encode(_trieRoot!.toJson()));
  }

  static void _insertIntoTrie(TrieNode root, String normalizedNote) {
    TrieNode current = root;
    
    for (int i = 0; i < normalizedNote.length; i++) {
      final char = normalizedNote[i];
      if (!current.children.containsKey(char)) {
        current.children[char] = TrieNode();
      }
      current = current.children[char]!;
      current.notes.add(normalizedNote);
    }
  }

  static Set<String> _getFromTrie(TrieNode root, String prefix) {
    TrieNode current = root;
    
    for (int i = 0; i < prefix.length; i++) {
      final char = prefix[i];
      if (!current.children.containsKey(char)) {
        return {};
      }
      current = current.children[char]!;
    }
    
    return current.notes;
  }

  // ============================================================
  // CLASS A (Notes) - Learning & Retrieval
  // ============================================================

  /// Learn a note from a transaction (adds to Trie and frequency map).
  static Future<void> learnNote(String note) async {
    final normalized = normalizeNote(note);
    if (normalized == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load notes frequency map
    final mapJson = prefs.getString(_notesMapKey);
    final Map<String, int> notesMap = mapJson != null 
        ? Map<String, int>.from(json.decode(mapJson))
        : {};
    
    // Increment frequency
    notesMap[normalized] = (notesMap[normalized] ?? 0) + 1;
    
    // Update Trie
    final trie = await _loadTrie();
    _insertIntoTrie(trie, normalized);
    
    // Save
    await prefs.setString(_notesMapKey, json.encode(notesMap));
    await _saveTrie();
  }

  /// Backwards-compatible alias for learnNote.
  static Future<void> learnCategory(String note) => learnNote(note);

  /// Get autocomplete suggestions for a prefix.
  /// Results are sorted by relevance tiers:
  /// - Tier 1: Note starts with query (prefix match)
  /// - Tier 2: Any word in note starts with query (word-boundary prefix)
  /// - Tier 3: Note contains query anywhere (substring match)
  /// - Tier 4: Alphabetical order within same tier
  static Future<List<String>> getSuggestions(String prefix) async {
    final query = prefix.trim().toLowerCase();
    if (query.isEmpty) return [];
    
    final prefs = await SharedPreferences.getInstance();
    final mapJson = prefs.getString(_notesMapKey);
    if (mapJson == null) return [];
    
    final Map<String, int> notesMap = Map<String, int>.from(json.decode(mapJson));
    
    // Filter to notes containing the query
    final matches = notesMap.keys
        .where((note) => note.contains(query))
        .toList();
    
    if (matches.isEmpty) return [];
    
    // Sort by relevance tiers, then alphabetically within tier
    matches.sort((a, b) {
      final aTier = _getRelevanceTier(a, query);
      final bTier = _getRelevanceTier(b, query);
      
      if (aTier != bTier) {
        return aTier.compareTo(bTier);
      }
      
      // Same tier: alphabetical (case-insensitive, already lowercase)
      return a.compareTo(b);
    });
    
    return matches.map(_capitalize).toList();
  }

  /// Returns relevance tier for sorting (lower = higher priority).
  /// Tier 1: Note starts with query
  /// Tier 2: Any word in note starts with query
  /// Tier 3: Note contains query (substring)
  static int _getRelevanceTier(String noteLower, String queryLower) {
    // Tier 1: Prefix match
    if (noteLower.startsWith(queryLower)) {
      return 1;
    }
    
    // Tier 2: Word-boundary prefix (any word starts with query)
    final words = noteLower.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.startsWith(queryLower)) {
        return 2;
      }
    }
    
    // Tier 3: Substring match (already filtered, so must contain)
    return 3;
  }

  /// Get all learned notes (Class A) with their frequencies.
  static Future<List<NoteInfo>> getAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    
    final mapJson = prefs.getString(_notesMapKey);
    if (mapJson == null) {
      // Try legacy format
      return _migrateFromLegacy();
    }
    
    final Map<String, int> notesMap = Map<String, int>.from(json.decode(mapJson));
    
    final notes = notesMap.entries
        .map((e) => NoteInfo(name: _capitalize(e.key), normalizedName: e.key, frequency: e.value))
        .toList();
    
    notes.sort((a, b) => b.frequency.compareTo(a.frequency));
    return notes;
  }

  /// Migrate from legacy format if needed.
  static Future<List<NoteInfo>> _migrateFromLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    
    final legacyMapJson = prefs.getString(_legacyCategoryMapKey);
    final legacyFreqJson = prefs.getString(_legacyCategoryFrequencyKey);
    
    if (legacyMapJson == null) return [];
    
    final Map<String, String> legacyMap = Map<String, String>.from(json.decode(legacyMapJson));
    final Map<String, int> legacyFreq = legacyFreqJson != null
        ? Map<String, int>.from(json.decode(legacyFreqJson))
        : {};
    
    // Convert to new format
    final Map<String, int> notesMap = {};
    for (final entry in legacyMap.entries) {
      final note = entry.key;
      final freq = legacyFreq[note] ?? 1;
      notesMap[note] = freq;
    }
    
    // Save in new format
    await prefs.setString(_notesMapKey, json.encode(notesMap));
    
    return notesMap.entries
        .map((e) => NoteInfo(name: _capitalize(e.key), normalizedName: e.key, frequency: e.value))
        .toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
  }

  /// Get frequency for a specific note.
  static Future<int> getFrequency(String note) async {
    final normalized = note.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    
    final mapJson = prefs.getString(_notesMapKey);
    if (mapJson == null) return 0;
    
    final Map<String, int> notesMap = Map<String, int>.from(json.decode(mapJson));
    return notesMap[normalized] ?? 0;
  }

  // ============================================================
  // CLASS B (Categories) - User-Created
  // ============================================================

  /// Create a new Class B category.
  /// Returns true if created, false if already exists.
  static Future<bool> createCategory(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    
    final categoriesJson = prefs.getString(_categoriesKey);
    final List<String> categories = categoriesJson != null
        ? List<String>.from(json.decode(categoriesJson))
        : [];
    
    if (categories.contains(normalized)) {
      return false; // Already exists
    }
    
    categories.add(normalized);
    await prefs.setString(_categoriesKey, json.encode(categories));
    return true;
  }

  /// Get all Class B categories.
  static Future<List<String>> getAllCategories() async {
    final prefs = await SharedPreferences.getInstance();
    
    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) return [];
    
    final List<String> categories = List<String>.from(json.decode(categoriesJson));
    return categories.map(_capitalize).toList();
  }

  /// Rename a Class B category.
  static Future<bool> renameCategory(String oldName, String newName) async {
    final normalizedOld = oldName.trim().toLowerCase();
    final normalizedNew = newName.trim().toLowerCase();
    
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) return false;
    if (normalizedOld == normalizedNew) return true;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load categories
    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) return false;
    
    final List<String> categories = List<String>.from(json.decode(categoriesJson));
    
    final index = categories.indexOf(normalizedOld);
    if (index == -1) return false; // Doesn't exist
    
    if (categories.contains(normalizedNew)) return false; // New name already exists
    
    // Update category name
    categories[index] = normalizedNew;
    
    // Update all note assignments pointing to old category
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    if (assignmentJson != null) {
      final Map<String, String> assignments = Map<String, String>.from(json.decode(assignmentJson));
      
      for (final key in assignments.keys.toList()) {
        if (assignments[key] == normalizedOld) {
          assignments[key] = normalizedNew;
        }
      }
      
      await prefs.setString(_noteAssignmentKey, json.encode(assignments));
    }
    
    await prefs.setString(_categoriesKey, json.encode(categories));
    return true;
  }

  /// Delete a Class B category (notes become independent).
  static Future<bool> deleteCategory(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    
    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) return false;
    
    final List<String> categories = List<String>.from(json.decode(categoriesJson));
    
    if (!categories.remove(normalized)) return false; // Didn't exist
    
    // Remove all note assignments to this category
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    if (assignmentJson != null) {
      final Map<String, String> assignments = Map<String, String>.from(json.decode(assignmentJson));
      
      assignments.removeWhere((_, value) => value == normalized);
      
      await prefs.setString(_noteAssignmentKey, json.encode(assignments));
    }
    
    await prefs.setString(_categoriesKey, json.encode(categories));
    return true;
  }

  /// Get all notes assigned to a specific Class B category.
  static Future<List<String>> getNotesInCategory(String categoryName) async {
    final normalizedCategory = categoryName.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    if (assignmentJson == null) return [];
    
    final Map<String, String> assignments = Map<String, String>.from(json.decode(assignmentJson));
    
    return assignments.entries
        .where((e) => e.value == normalizedCategory)
        .map((e) => _capitalize(e.key))
        .toList();
  }

  // ============================================================
  // NOTE ASSIGNMENT (Class A → Class B)
  // ============================================================

  /// Assign a Class A note to a Class B category.
  /// Returns true if successful.
  static Future<bool> assignNoteToCategory(String noteName, String categoryName) async {
    final normalizedNote = noteName.trim().toLowerCase();
    final normalizedCategory = categoryName.trim().toLowerCase();
    
    if (normalizedNote.isEmpty || normalizedCategory.isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Verify category exists
    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) return false;
    
    final List<String> categories = List<String>.from(json.decode(categoriesJson));
    if (!categories.contains(normalizedCategory)) return false;
    
    // Load assignments
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    final Map<String, String> assignments = assignmentJson != null
        ? Map<String, String>.from(json.decode(assignmentJson))
        : {};
    
    // Assign note to category
    assignments[normalizedNote] = normalizedCategory;
    
    await prefs.setString(_noteAssignmentKey, json.encode(assignments));
    return true;
  }

  /// Remove a Class A note from its Class B category (make independent).
  static Future<bool> removeNoteFromCategory(String noteName) async {
    final normalizedNote = noteName.trim().toLowerCase();
    if (normalizedNote.isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    if (assignmentJson == null) return false;
    
    final Map<String, String> assignments = Map<String, String>.from(json.decode(assignmentJson));
    
    if (!assignments.containsKey(normalizedNote)) return false;
    
    assignments.remove(normalizedNote);
    
    await prefs.setString(_noteAssignmentKey, json.encode(assignments));
    return true;
  }

  /// Get the Class B category a note is assigned to (or null if independent).
  static Future<String?> getCategoryForNote(String noteName) async {
    final normalizedNote = noteName.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    if (assignmentJson == null) return null;
    
    final Map<String, String> assignments = Map<String, String>.from(json.decode(assignmentJson));
    
    final category = assignments[normalizedNote];
    return category != null ? _capitalize(category) : null;
  }

  /// Get all independent notes (Class A not assigned to any Class B).
  static Future<List<NoteInfo>> getIndependentNotes() async {
    final allNotes = await getAllNotes();
    final prefs = await SharedPreferences.getInstance();
    
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    if (assignmentJson == null) return allNotes; // All are independent
    
    final Map<String, String> assignments = Map<String, String>.from(json.decode(assignmentJson));
    
    return allNotes.where((note) => !assignments.containsKey(note.normalizedName)).toList();
  }

  /// Get notes with their category assignments for pie chart aggregation.
  /// Returns a map: normalizedNote -> normalizedCategory (or null if independent)
  static Future<Map<String, String?>> getNoteToDisplayLabelMap() async {
    final prefs = await SharedPreferences.getInstance();
    final allNotes = await getAllNotes();
    
    final assignmentJson = prefs.getString(_noteAssignmentKey);
    final Map<String, String> assignments = assignmentJson != null
        ? Map<String, String>.from(json.decode(assignmentJson))
        : {};
    
    final Map<String, String?> result = {};
    for (final note in allNotes) {
      result[note.normalizedName] = assignments[note.normalizedName];
    }
    
    return result;
  }

  // ============================================================
  // MIGRATION
  // ============================================================

  static Future<bool> isMigrationDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationDoneKey) ?? false;
  }

  static Future<void> _markMigrationDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationDoneKey, true);
  }

  /// Migrate existing transactions to populate notes.
  static Future<int> migrateExistingTransactions(
    List<Map<String, dynamic>> Function() getAllTransactionNotes,
  ) async {
    if (await isMigrationDone()) {
      return -1;
    }
    
    int learnedCount = 0;
    
    final transactions = getAllTransactionNotes();
    
    for (final tx in transactions) {
      final note = tx['note'] as String?;
      if (note != null && isValidForLearning(note)) {
        await learnNote(note);
        learnedCount++;
      }
    }
    
    await _markMigrationDone();
    
    return learnedCount;
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Clear all data (for testing/reset).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notesMapKey);
    await prefs.remove(_categoriesKey);
    await prefs.remove(_noteAssignmentKey);
    await prefs.remove(_trieKey);
    await prefs.remove(_migrationDoneKey);
    await prefs.remove(_legacyCategoryMapKey);
    await prefs.remove(_legacyCategoryFrequencyKey);
    _trieRoot = null;
  }

  /// Reset only the migration flag (for testing).
  static Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationDoneKey);
  }

  /// Get diagnostic info (for debugging).
  static Future<Map<String, dynamic>> getTrieDiagnostics() async {
    final trie = await _loadTrie();
    final allNotes = await getAllNotes();
    final allCategories = await getAllCategories();
    
    int nodeCount = 0;
    void countNodes(TrieNode node) {
      nodeCount++;
      for (final child in node.children.values) {
        countNodes(child);
      }
    }
    countNodes(trie);
    
    return {
      'nodeCount': nodeCount,
      'noteCount': allNotes.length,
      'categoryCount': allCategories.length,
      'sampleNotes': allNotes.take(5).map((n) => n.name).toList(),
      'sampleCategories': allCategories.take(5).toList(),
      'isMigrated': await isMigrationDone(),
    };
  }
}

/// Information about a Class A note.
class NoteInfo {
  final String name;
  final String normalizedName;
  final int frequency;

  NoteInfo({
    required this.name,
    required this.normalizedName,
    required this.frequency,
  });
}
