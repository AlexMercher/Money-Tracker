import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';
import '../services/theme_service.dart';

/// Screen for managing user profile information
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiController = TextEditingController();
  final _budgetController = TextEditingController();
  bool _isLoading = true;
  User? _currentUser;
  bool _phoneExceedsLimit = false;
  String _initialPhoneNumber = '';
  String _initialName = '';
  String _initialUpiId = '';
  String _initialBudget = '';
  bool _hasChanges = false;
  double _currentMonthUsage = 0.0;
  bool _carryBudget = false;
  bool _initialCarryBudget = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _calculateMonthlyUsage();
    _phoneController.addListener(_onPhoneChanged);
    _nameController.addListener(_checkForChanges);
    _upiController.addListener(_checkForChanges);
    _budgetController.addListener(_checkForChanges);
  }

  Future<void> _calculateMonthlyUsage() async {
    final friends = HiveService.getAllFriends();
    final now = DateTime.now();
    double usage = 0.0;

    for (final friend in friends) {
      for (final transaction in friend.transactions) {
        if (transaction.date.year == now.year && transaction.date.month == now.month) {
          // Logic:
          // Lent (Money Out) -> Increases usage
          // Borrowed (Liability) -> Increases usage (per user requirement)
          // Self Spent (Lent type) -> Increases usage
          // Self Gained (Borrowed type) -> Decreases usage (Credit)
          
          if (friend.id == 'self') {
             if (transaction.type == TransactionType.lent) {
               usage += transaction.amount; // Spent
             } else {
               usage -= transaction.amount; // Gained (Credit)
             }
          } else {
            // For friends, both Lent and Borrowed reduce budget (increase usage)
            usage += transaction.amount;
          }
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _currentMonthUsage = usage;
      });
    }
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.replaceAll(' ', '');
    
    // Check if exceeds 10 digits
    if (text.length > 10) {
      setState(() {
        _phoneExceedsLimit = true;
      });
    } else {
      if (_phoneExceedsLimit) {
        setState(() {
          _phoneExceedsLimit = false;
        });
      }
    }
    
    _checkForChanges();
  }

  void _checkForChanges() {
    final currentName = _nameController.text.trim();
    final currentPhone = _phoneController.text.replaceAll(' ', '');
    final currentUpi = _upiController.text.trim();
    final currentBudget = _budgetController.text.trim();
    
    final hasChanges = currentName != _initialName ||
                       currentPhone != _initialPhoneNumber ||
                       currentUpi != _initialUpiId ||
                       currentBudget != _initialBudget ||
                       _carryBudget != _initialCarryBudget;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _showPhoneNumberWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Verify Your Number'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please ensure this phone number matches the one linked to your bank account and UPI ID.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy Notice',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All your data is stored locally on your device and never shared externally.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    final user = await HiveService.getUserProfile();
    
    if (user != null) {
      _nameController.text = user.name;
      // Format phone number with space after 5 digits
      final phone = user.phoneNumber;
      if (phone.length == 10) {
        _phoneController.text = '${phone.substring(0, 5)} ${phone.substring(5)}';
      } else {
        _phoneController.text = phone;
      }
      _upiController.text = user.upiId;
      _budgetController.text = user.monthlyBudget > 0 ? user.monthlyBudget.toStringAsFixed(0) : '';
      _carryBudget = user.carryBudgetToNextMonth;
      _currentUser = user;
      _initialPhoneNumber = user.phoneNumber;
      _initialName = user.name;
      _initialUpiId = user.upiId;
      _initialBudget = _budgetController.text;
      _initialCarryBudget = user.carryBudgetToNextMonth;
    }

    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional check for phone number length
    final phone = _phoneController.text.replaceAll(' ', '');
    if (phone.isNotEmpty && phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be exactly 10 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if phone number was changed
    final phoneChanged = phone.isNotEmpty && phone != _initialPhoneNumber;
    
    setState(() {
      _isLoading = true;
    });

    final user = User(
      name: _nameController.text.trim(),
      phoneNumber: phone,
      upiId: _upiController.text.trim(),
      monthlyBudget: double.tryParse(_budgetController.text.trim()) ?? 0.0,
      carryBudgetToNextMonth: _carryBudget,
    );

    await HiveService.saveUserProfile(user);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentUser = user;
        _initialPhoneNumber = phone;
        _initialName = user.name;
        _initialUpiId = user.upiId;
        _initialBudget = _budgetController.text;
        _initialCarryBudget = _carryBudget;
        _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Show warning dialog if phone number was changed
      if (phoneChanged) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showPhoneNumberWarning();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _hasChanges ? _saveProfile : null,
              icon: Icon(
                Icons.save,
                color: _hasChanges ? null : Colors.grey,
              ),
              tooltip: _hasChanges ? 'Save Profile' : 'No changes to save',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.1)
                                : Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _currentUser?.name ?? 'Setup Your Profile',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your information will be used in PDFs and transactions',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Budget Monitor
                    if (_currentUser != null && _currentUser!.monthlyBudget > 0) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.pie_chart, 
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Monthly Budget Status',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: (_currentMonthUsage / _currentUser!.monthlyBudget).clamp(0.0, 1.0),
                                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey.shade800 
                                    : Colors.grey.shade200,
                                color: _currentMonthUsage > _currentUser!.monthlyBudget 
                                    ? Colors.red 
                                    : Theme.of(context).primaryColor,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Used: ₹${_currentMonthUsage.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: _currentMonthUsage > _currentUser!.monthlyBudget 
                                          ? Colors.red 
                                          : Theme.of(context).textTheme.bodyMedium?.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Budget: ₹${_currentUser!.monthlyBudget.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                              if (_currentMonthUsage > _currentUser!.monthlyBudget)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Budget Exceeded by ₹${(_currentMonthUsage - _currentUser!.monthlyBudget).toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Remaining: ₹${(_currentUser!.monthlyBudget - _currentMonthUsage).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.greenAccent
                                          : Theme.of(context).primaryColor,
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Profile Form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Information',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Name field
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name *',
                                hintText: 'Enter your full name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Phone number field
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '98765 43210',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _phoneExceedsLimit ? Colors.red : Colors.grey,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _phoneExceedsLimit ? Colors.red : Colors.grey,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _phoneExceedsLimit ? Colors.red : Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.phone,
                                  color: _phoneExceedsLimit ? Colors.red : null,
                                ),
                                prefixText: '+91 ',
                                errorText: _phoneExceedsLimit ? 'Maximum 10 digits allowed' : null,
                                errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final digitsOnly = value.replaceAll(' ', '');
                                  if (digitsOnly.length != 10) {
                                    return 'Phone number must be exactly 10 digits';
                                  }
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // UPI ID field
                            TextFormField(
                              controller: _upiController,
                              decoration: const InputDecoration(
                                labelText: 'UPI ID',
                                hintText: 'example@upi',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_balance_wallet),
                                helperText: 'Optional - for payment references',
                                helperStyle: TextStyle(fontSize: 11),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Budget Field
                            TextFormField(
                              controller: _budgetController,
                              decoration: const InputDecoration(
                                labelText: 'Monthly Budget (Optional)',
                                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                border: OutlineInputBorder(),
                                hintText: 'e.g., 5000',
                                prefixText: '₹',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),

                            CheckboxListTile(
                              value: _carryBudget,
                              onChanged: (val) {
                                setState(() {
                                  _carryBudget = val ?? false;
                                  _checkForChanges();
                                });
                              },
                              title: const Text('Use same budget next month'),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_hasChanges) ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_hasChanges ? 'Save Profile' : 'No Changes'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Theme Settings Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Consumer<ThemeService>(
                              builder: (context, themeService, child) {
                                final isDark = themeService.themeMode == ThemeMode.dark;
                                return SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Dark Mode'),
                                  subtitle: Text(
                                    isDark ? 'Dark theme is enabled' : 'Light theme is enabled',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  secondary: Icon(
                                    isDark ? Icons.dark_mode : Icons.light_mode,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  value: isDark,
                                  onChanged: (value) async {
                                    await themeService.toggleTheme();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.removeListener(_checkForChanges);
    _upiController.removeListener(_checkForChanges);
    _nameController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    super.dispose();
  }
}
