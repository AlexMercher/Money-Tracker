import 'package:flutter_test/flutter_test.dart';

/// Unit tests for friend autocomplete relevance sorting logic.
/// 
/// The sorting follows tiered relevance:
/// - Tier 1: Prefix match (name starts with query)
/// - Tier 2: Word-boundary prefix (any word starts with query)
/// - Tier 3: Substring match (contains query anywhere)
/// - Tier 4: Alphabetical within same tier
void main() {
  group('Friend Autocomplete Relevance Sorting', () {
    // Helper function that mirrors the sorting logic in FriendAutocomplete
    List<String> sortByRelevance(List<String> friends, String query) {
      final searchText = query.toLowerCase().trim();
      
      // Empty query returns empty (mirrors widget behavior)
      if (searchText.isEmpty) {
        return [];
      }
      
      // Filter matches
      final matches = friends.where((String friend) {
        return friend.toLowerCase().contains(searchText);
      }).toList();
      
      // Sort by relevance tiers
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
    }
    
    test('Tier 1: Prefix matches come first', () {
      final friends = ['Ishan', 'Shashank', 'Aadarsh', 'Amit'];
      final result = sortByRelevance(friends, 'A');
      
      // Aadarsh and Amit start with 'A', should come first
      expect(result[0], 'Aadarsh');
      expect(result[1], 'Amit');
      // Ishan and Shashank contain 'a' but don't start with it
      expect(result.length, 4);
    });
    
    test('Tier 1: Case-insensitive prefix matching', () {
      final friends = ['alice', 'ADAM', 'Bob'];
      final result = sortByRelevance(friends, 'a');
      
      // ADAM and alice start with 'a', alphabetically: ADAM before alice
      expect(result[0], 'ADAM');
      expect(result[1], 'alice');
      expect(result.length, 2);
    });
    
    test('Tier 2: Word-boundary prefix matches before substring', () {
      final friends = ['John Smith', 'Smithson', 'Blacksmith'];
      final result = sortByRelevance(friends, 'smi');
      
      // 'Smithson' starts with 'smi' (Tier 1)
      expect(result[0], 'Smithson');
      // 'John Smith' has word 'Smith' starting with 'smi' (Tier 2)
      expect(result[1], 'John Smith');
      // 'Blacksmith' contains 'smi' but not at word boundary (Tier 3)
      expect(result[2], 'Blacksmith');
    });
    
    test('Tier 3: Substring matches come last', () {
      final friends = ['Shashank', 'Ishan', 'Roshan'];
      final result = sortByRelevance(friends, 'sha');
      
      // Shashank starts with 'sha' (Tier 1)
      expect(result[0], 'Shashank');
      // Ishan and Roshan contain 'sha' but not at start or word boundary (Tier 3)
      expect(result[1], 'Ishan');
      expect(result[2], 'Roshan');
    });
    
    test('Same tier sorted alphabetically', () {
      final friends = ['Zara', 'Anna', 'Alex', 'Amy'];
      final result = sortByRelevance(friends, 'A');
      
      // Alex, Amy, Anna start with 'A' (Tier 1), should be alphabetical
      // Zara contains 'a' (Tier 3)
      expect(result[0], 'Alex');
      expect(result[1], 'Amy');
      expect(result[2], 'Anna');
      expect(result[3], 'Zara'); // Contains 'a' but doesn't start with it
      expect(result.length, 4);
    });
    
    test('Mixed tiers sorted correctly', () {
      final friends = ['Ishan', 'Shashank', 'Aadarsh', 'Ravi Sharma', 'Natasha'];
      final result = sortByRelevance(friends, 'sha');
      
      // Tier 1: Shashank (starts with 'sha')
      expect(result[0], 'Shashank');
      // Tier 2: Ravi Sharma (word 'Sharma' starts with 'sha')
      expect(result[1], 'Ravi Sharma');
      // Tier 3: Ishan, Natasha (contain 'sha' but not at boundary) - alphabetical
      expect(result[2], 'Ishan');
      expect(result[3], 'Natasha');
    });
    
    test('Empty query returns empty list', () {
      final friends = ['Alice', 'Bob'];
      final result = sortByRelevance(friends, '');
      expect(result, isEmpty);
    });
    
    test('No matches returns empty list', () {
      final friends = ['Alice', 'Bob'];
      final result = sortByRelevance(friends, 'xyz');
      expect(result, isEmpty);
    });
    
    test('Query with spaces is trimmed', () {
      final friends = ['Alice', 'Bob'];
      final result = sortByRelevance(friends, '  ali  ');
      expect(result.length, 1);
      expect(result[0], 'Alice');
    });
    
    test('Multi-word names with word boundary matching', () {
      final friends = ['Anna Maria', 'Maria Anna', 'Annamaria'];
      final result = sortByRelevance(friends, 'mar');
      
      // Tier 1: Maria Anna (starts with 'Mar')
      expect(result[0], 'Maria Anna');
      // Tier 2: Anna Maria (word 'Maria' starts with 'mar')
      expect(result[1], 'Anna Maria');
      // Tier 3: Annamaria (contains 'mar' but not at word boundary)
      expect(result[2], 'Annamaria');
    });
  });
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
