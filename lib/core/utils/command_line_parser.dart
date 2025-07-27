/// Command line argument parser
class CommandLineParser {
  final List<String> _args;

  CommandLineParser(this._args);

  bool get isAutoLaunch => _args.contains('--auto-launch');

  String? get channel {
    for (int i = 0; i < _args.length; i++) {
      if (_args[i] == '--channel' && i + 1 < _args.length) {
        return _args[i + 1];
      }
    }
    return null;
  }
}
