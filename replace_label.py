from pathlib import Path
import re
path = Path(r'lib/presentation/history/widgets/sale_tile.dart')
text = path.read_text(encoding='utf-8')
text, count = re.subn(r"label: const Text\('.*?'\)", "label: const Text('????? ??????')", text, count=1)
if count == 0:
    raise SystemExit('label not found')
path.write_text(text, encoding='utf-8')
