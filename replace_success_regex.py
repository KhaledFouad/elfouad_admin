from pathlib import Path
import re
path = Path(r'lib/presentation/history/widgets/sale_tile.dart')
text = path.read_text(encoding='utf-8')
pattern_success = r"const SnackBar\(\s*content: Text\('.*?'\),\s*\)"
text, count = re.subn(pattern_success, "const SnackBar(\n                            content: Text('??? ????? ??????? ??????? ?????.'),\n                          )", text, count=1, flags=re.DOTALL)
if count == 0:
    raise SystemExit('success snackbar not found')
pattern_error = r"SnackBar\(content: Text\('.*?\'\)\)"
text, count = re.subn(pattern_error, "SnackBar(content: Text('???? ????? ???????: '))", text, count=1)
if count == 0:
    raise SystemExit('error snackbar not found')
path.write_text(text, encoding='utf-8')
