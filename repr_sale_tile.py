from pathlib import Path
import re
text = Path(r'lib/presentation/history/widgets/sale_tile.dart').read_text(encoding='utf-8')
match = re.search(r"title: const Text\('(.*?)'\)", text)
Path('_repr.txt').write_text(repr(match.group(0)), encoding='utf-8')
