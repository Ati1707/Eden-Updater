import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
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
bool _isLoading = true;

@override
void initState() {
super.initState();
_loadLogFiles();
}

Future<void> _loadLogFiles() async {
setState(() => _isLoading = true);
final files = await LoggingService.getLogFiles();
setState(() {
_logFiles = files;
if (files.isNotEmpty) {
_selectedLogFile = files.first;
_loadLogContent();
} else {
_logContent = 'No log files found.';
_isLoading = false;
}
});
}

Future<void> _loadLogContent() async {
if (_selectedLogFile == null) return;
setState(() => _isLoading = true);
try {
final content = await _selectedLogFile!.readAsString();
setState(() => _logContent = content.isEmpty ? 'Log file is empty.' : content);
} catch (e) {
setState(() => _logContent = 'Error reading log file: $e');
} finally {
if(mounted) setState(() => _isLoading = false);
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
const Text('Application Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
const Spacer(),
IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
],
),
const SizedBox(height: 16),

// Log file selector
if (_logFiles.isNotEmpty)
Row(
children: [
Expanded(
child: DropdownButton<File>(
value: _selectedLogFile,
isExpanded: true,
underline: Container(height: 1, color: Colors.grey.shade700),
items: _logFiles.map((file) {
return DropdownMenuItem(value: file, child: Text(path.basename(file.path)));
}).toList(),
onChanged: (file) {
if (file != null) {
setState(() => _selectedLogFile = file);
_loadLogContent();
}
},
),
),
IconButton(onPressed: _copyToClipboard, icon: const Icon(Icons.copy), tooltip: 'Copy log to clipboard'),
],
),
const SizedBox(height: 16),

// Log content
Expanded(
child: Container(
decoration: BoxDecoration(
border: Border.all(color: Colors.grey.shade700),
borderRadius: BorderRadius.circular(8),
color: Colors.black.withValues(alpha: 0.2),
),
child: _isLoading
? const Center(child: CircularProgressIndicator())
    : _logFiles.isEmpty
? const Center(child: Text('No log files available.'))
    : SingleChildScrollView(
padding: const EdgeInsets.all(12),
reverse: true, // Show latest logs first
child: SelectableText(_logContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
),
),
),

const SizedBox(height: 16),
Text(
'These logs help diagnose issues. Share them when reporting bugs.',
style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
),
],
),
),
);
}
}