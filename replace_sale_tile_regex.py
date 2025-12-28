from pathlib import Path
import re
path = Path(r'lib/presentation/history/widgets/sale_tile.dart')
text = path.read_text(encoding='utf-8')
text, count = re.subn(r"title: const Text\('.*?'\)", "title: const Text('????? ????? ????? ??????')", text, count=1)
if count == 0:
    raise SystemExit('title pattern not found')
text, count = re.subn(r"content: Text\(\s*'[^']*\{totalPrice\.toStringAsFixed\(2\)\}[^']*'\s*,", "content: Text(\n                        '???? ????? ????? ???? .\\n?? ???? ?????? ????????',\n                        textAlign: TextAlign.center,", text, count=1)
if count == 0:
    raise SystemExit('content pattern not found')
text, count = re.subn(r"child: const Text\('.*?'\)", "child: const Text('?????')", text, count=1)
if count == 0:
    raise SystemExit('cancel button not found')
text, count = re.subn(r"child: const Text\('.*?'\)", "child: const Text('?????')", text, count=1)
if count == 0:
    raise SystemExit('confirm button not found')
text, count = re.subn(r"content: Text\('.*?UU,Oc'\)", "content: Text('??? ????? ??????? ??????? ?????.')", text, count=1)
if count == 0:
    raise SystemExit('success snackbar not found')
text, count = re.subn(r"SnackBar\(content: Text\('.*?O3U\^USOc: \'\)\)", "SnackBar(content: Text('???? ????? ???????: '))", text, count=1)
if count == 0:
    raise SystemExit('error snackbar not found')
text, count = re.subn(r"label: const Text\('.*?'\)", "label: const Text('????? ??????')", text, count=1)
if count == 0:
    raise SystemExit('label not found')
path.write_text(text, encoding='utf-8')
