from pathlib import Path
text = Path(r'lib/presentation/history/widgets/sale_tile.dart').read_text(encoding='utf-8')
start = text.index('builder: (_) => AlertDialog(')
end = text.index(');\n                  if (ok == true) {', start)
block = text[start:end]
Path('_block.txt').write_text(block, encoding='utf-8')
