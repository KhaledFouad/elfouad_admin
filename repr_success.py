from pathlib import Path
text = Path(r'lib/presentation/history/widgets/sale_tile.dart').read_text(encoding='utf-8')
old_success = "                          const SnackBar(\r\n                            content: Text('O?U. O\u0015U,O-O?U? U^O?U.O? O?O3U^USOc O\u0015U,U.OrO?U^U+')\r\n                          ),\r\n"
if old_success not in text:
    raise SystemExit('old success not found')
text = text.replace(old_success, "                          const SnackBar(\r\n                            content: Text('??? ????? ??????? ??????? ?????.')\r\n                          ),\r\n", 1)
old_error = "                          SnackBar(content: Text('O?O1O?O? O\u0015U,O-O?U?: ')),\r\n"
if old_error not in text:
    raise SystemExit('old error not found')
text = text.replace(old_error, "                          SnackBar(content: Text('???? ????? ???????: ')),\r\n", 1)
old_label = "                label: const Text('O?U. O\u0015U,O_U?O1'),\r\n"
if old_label not in text:
    raise SystemExit('label not found')
text = text.replace(old_label, "                label: const Text('????? ??????'),\r\n", 1)
Path(r'lib/presentation/history/widgets/sale_tile.dart').write_text(text, encoding='utf-8')
