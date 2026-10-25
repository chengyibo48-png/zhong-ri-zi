"""Read package version from the export presets, shared by all delivery tools."""
import os, re
from datetime import datetime, timedelta, timezone
from pathlib import Path
PROJECT = Path(__file__).resolve().parents[1]
presets = (PROJECT/'export_presets.cfg').read_text(encoding='utf8')
desktop = re.search(r'application/file_version="(\d+\.\d+\.\d+)\.\d+"',presets)
android = re.search(r'version/name="(\d+\.\d+\.\d+)"',presets)
if not desktop: raise ValueError('Missing desktop package version')
VERSION = desktop.group(1)
if android and android.group(1) != VERSION: raise ValueError('Desktop and Android versions differ')
code = re.search(r'version/code=(\d+)',presets)
VERSION_CODE = int(code.group(1)) if code else sum(int(part)*factor for part,factor in zip(VERSION.split('.'),[1000000,1000,1]))
RELEASE_DATE = os.environ.get('ZRZ_RELEASE_DATE',datetime.now(timezone(timedelta(hours=8))).strftime('%Y%m%d'))
if not re.fullmatch(r'\d{8}',RELEASE_DATE): raise ValueError('Invalid release date')
RELEASE_DIR = PROJECT/'build/releases'/f'{RELEASE_DATE}-{VERSION}'
