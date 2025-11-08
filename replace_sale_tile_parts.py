from pathlib import Path
path = Path(r'lib/presentation/history/widgets/sale_tile.dart')
text = path.read_text(encoding='utf-8')
replacements = [
    ("title: const Text('O\ufffdO\ufffdU\ufffdUSO_ O\u0015U,O3O_O\u0015O_')",
     "title: const Text('????? ????? ????? ??????')"),
    ("content: Text(\r\n                        'O3USO\ufffdU. O\ufffdO\ufffdO\"USO\ufffd O_U?O1  O\ufffdU..\\nU\ufffdU, O\ufffdO\ufffdUSO_ O\u0015U,U.O\ufffdO\u0015O\"O1OcOY',",
     "content: Text(\r\n                        '???? ????? ????? ???? .\\n?? ???? ?????? ????????',\r\n                        textAlign: TextAlign.center,"),
    ("child: const Text('O\ufffdU,O\ufffdO\u0015O\ufffd')",
     "child: const Text('?????')"),
    ("child: const Text('O\ufffdO\ufffdU\ufffdUSO_')",
     "child: const Text('?????')"),
    ("content: Text('O\ufffdU. O\u0015U,O-O\ufffdU? U^O\ufffdU.O\ufffd O\ufffdO3U^USOc O\u0015U,U.OrO\ufffdU^U+')",
     "content: Text('??? ????? ??????? ??????? ?????.')"),
    ("SnackBar(content: Text('O\ufffdO1O\ufffdO\ufffd O\u0015U,O-O\ufffdU?: '))",
     "SnackBar(content: Text('???? ????? ???????: '))"),
    ("label: const Text('O\ufffdU. O\u0015U,O_U?O1')",
     "label: const Text('????? ??????')"),
]
for old, new in replacements:
    if old not in text:
        raise SystemExit(f'pattern not found: {old!r}')
    text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
