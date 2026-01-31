import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../services/pdf_service.dart';

/// Screen to view and manage saved PDF reports
class PdfManagerScreen extends StatefulWidget {
  const PdfManagerScreen({super.key});

  @override
  State<PdfManagerScreen> createState() => _PdfManagerScreenState();
}

class _PdfManagerScreenState extends State<PdfManagerScreen> {
  List<FileSystemEntity> _pdfFiles = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedPdfs = {};

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    setState(() {
      _isLoading = true;
    });

    final files = await PdfService.getSavedPdfs();
    
    setState(() {
      _pdfFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _openPdf(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deletePdf(String filePath, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await PdfService.deletePdf(filePath);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF deleted successfully')),
          );
          _loadPdfs(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to delete PDF'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSelectedPdfs() async {
    if (_selectedPdfs.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDFs'),
        content: Text('Delete ${_selectedPdfs.length} selected PDF(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int deleted = 0;
      for (final path in _selectedPdfs) {
        final success = await PdfService.deletePdf(path);
        if (success) deleted++;
      }

      setState(() {
        _selectedPdfs.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleted PDF(s) deleted successfully')),
        );
        _loadPdfs();
      }
    }
  }

  Future<void> _deleteAllPdfs() async {
    if (_pdfFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All PDFs'),
        content: Text('Are you sure you want to delete all ${_pdfFiles.length} PDF(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int deleted = 0;
      for (final file in _pdfFiles) {
        final success = await PdfService.deletePdf(file.path);
        if (success) deleted++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleted PDF(s) deleted successfully')),
        );
        _loadPdfs();
      }
    }
  }

  String _getFileName(String path) {
    return path.split('/').last.replaceAll('.pdf', '').replaceAll('_', ' ');
  }

  String _getFormattedDate(FileSystemEntity file) {
    try {
      final stat = file.statSync();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(stat.modified);
    } catch (e) {
      return 'Unknown date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedPdfs.length} selected')
            : const Text('PDF Reports'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedPdfs.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  if (_selectedPdfs.length == _pdfFiles.length) {
                    _selectedPdfs.clear();
                  } else {
                    _selectedPdfs.clear();
                    _selectedPdfs.addAll(_pdfFiles.map((f) => f.path));
                  }
                });
              },
              tooltip: _selectedPdfs.length == _pdfFiles.length
                  ? 'Deselect All'
                  : 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedPdfs.isEmpty ? null : _deleteSelectedPdfs,
              tooltip: 'Delete Selected',
            ),
          ] else ...[
            if (_pdfFiles.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = true;
                  });
                },
                tooltip: 'Select',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPdfs,
              tooltip: 'Refresh',
            ),
            if (_pdfFiles.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete_all') {
                    _deleteAllPdfs();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Builder(
                      builder: (context) {
                        final errorColor = Theme.of(context).colorScheme.error;
                        return Row(
                          children: [
                            Icon(Icons.delete_sweep, color: errorColor),
                            const SizedBox(width: 8),
                            Text('Clear All', style: TextStyle(color: errorColor)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfFiles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPdfs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pdfFiles.length,
                    itemBuilder: (context, index) {
                      final file = _pdfFiles[index];
                      final fileName = _getFileName(file.path);
                      final fileDate = _getFormattedDate(file);
                      final fileSize = PdfService.getFileSize(File(file.path));
                      final isSelected = _selectedPdfs.contains(file.path);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : null,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedPdfs.add(file.path);
                                      } else {
                                        _selectedPdfs.remove(file.path);
                                      }
                                    });
                                  },
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                ),
                          title: Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        fileDate,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.storage,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      fileSize,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: _isSelectionMode
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'open':
                                        _openPdf(file.path);
                                        break;
                                      case 'delete':
                                        _deletePdf(file.path, fileName);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Row(
                                        children: [
                                          Icon(Icons.open_in_new, size: 18),
                                          SizedBox(width: 8),
                                          Text('Open'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Builder(
                                        builder: (context) {
                                          final errorColor = Theme.of(context).colorScheme.error;
                                          return Row(
                                            children: [
                                              Icon(Icons.delete, size: 18, color: errorColor),
                                              const SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: errorColor)),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedPdfs.remove(file.path);
                                } else {
                                  _selectedPdfs.add(file.path);
                                }
                              });
                            } else {
                              _openPdf(file.path);
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedPdfs.add(file.path);
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No PDF Reports',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export transaction history from friend details to create PDF reports',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
