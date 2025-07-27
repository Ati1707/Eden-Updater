import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/logging_service.dart';

/// Dialog to display application logs for debugging
class LogsDialog extends StatefulWidget {
  const LogsDialog({super.key});

  @override
  State<LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends State<LogsDialog> {
  List<File> _logFiles = [];
  File? _selectedLogFile;
  String _logContent = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);

    try {
      final logFiles = await LoggingService.getLogFiles();
      setState(() {
        _logFiles = logFiles;
        if (logFiles.isNotEmpty) {
          _selectedLogFile = logFiles.first;
          _loadLogContent();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load log files: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLogContent() async {
    if (_selectedLogFile == null) return;

    setState(() => _isLoading = true);

    try {
      final content = await _selectedLogFile!.readAsString();
      setState(() => _logContent = content);
    } catch (e) {
      setState(() => _logContent = 'Error reading log file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _logContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log content copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Application Logs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Log file selector
            if (_logFiles.isNotEmpty) ...[
              Row(
                children: [
                  const Text('Log file: '),
                  Expanded(
                    child: DropdownButton<File>(
                      value: _selectedLogFile,
                      isExpanded: true,
                      items: _logFiles.map((file) {
                        final fileName = file.path.split('/').last;
                        return DropdownMenuItem(
                          value: file,
                          child: Text(fileName),
                        );
                      }).toList(),
                      onChanged: (file) {
                        setState(() => _selectedLogFile = file);
                        _loadLogContent();
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to clipboard',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Log content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _logFiles.isEmpty
                    ? const Center(
                        child: Text(
                          'No log files found.\nLogs are created when errors occur.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _logContent.isEmpty
                              ? 'Log file is empty'
                              : _logContent,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Info text
            Text(
              'Logs location: ${LoggingService.logFilePath ?? 'Not available'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'These logs help diagnose issues. Share them when reporting bugs.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
