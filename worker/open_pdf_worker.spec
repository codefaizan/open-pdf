# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

from PyInstaller.utils.hooks import collect_submodules, collect_all

block_cipher = None


def _venv_site_packages() -> Path:
    venv = Path(SPECPATH) / ".venv"
    win = venv / "Lib" / "site-packages"
    if win.is_dir():
        return win
    lib = venv / "lib"
    if lib.is_dir():
        matches = sorted(lib.glob("python*/site-packages"))
        if matches:
            return matches[-1]
    raise SystemExit(f"No venv site-packages under {venv}")


site_packages = _venv_site_packages()
mypyc_paths = list(site_packages.glob("*__mypyc*.so")) + list(
    site_packages.glob("*__mypyc*.pyd")
)
mypyc_binaries = [(str(path), ".") for path in mypyc_paths]

hiddenimports = (
    collect_submodules("camelot")
    + collect_submodules("openpyxl")
    + collect_submodules("playa")
    + collect_submodules("pypdfium2")
    + collect_submodules("pytesseract")
    + [path.stem.split(".")[0] for path in mypyc_paths]
)

camelot_datas, camelot_binaries, camelot_hidden = collect_all("camelot")
playa_datas, playa_binaries, playa_hidden = collect_all("playa")
pypdfium_datas, pypdfium_binaries, pypdfium_hidden = collect_all("pypdfium2")
hiddenimports += camelot_hidden + playa_hidden + pypdfium_hidden
extra_datas = camelot_datas + playa_datas + pypdfium_datas

tessdata_dir = Path(SPECPATH) / "open_pdf_worker" / "tessdata"
if not (tessdata_dir / "eng.traineddata").is_file():
    raise SystemExit(f"Missing OCR model: {tessdata_dir / 'eng.traineddata'}")
extra_datas += [(str(tessdata_dir / "eng.traineddata"), "open_pdf_worker/tessdata")]

extra_binaries = camelot_binaries + playa_binaries + pypdfium_binaries + mypyc_binaries

a = Analysis(
    ["open_pdf_worker/__main__.py"],
    pathex=[],
    binaries=extra_binaries,
    datas=extra_datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="open_pdf_worker",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name="open_pdf_worker",
)
