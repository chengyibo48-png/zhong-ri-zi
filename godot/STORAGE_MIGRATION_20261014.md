# 项目临时数据迁移到 D 盘（2026-10-14）

- 已迁移 2,351 个目录、8,167 个文件，共 23.97 GiB。
- C 盘迁移前可用 8.15 GiB，迁移后可用 32.27 GiB。
- 来源：当前用户的 `AppData/Local/Temp/zrz-*` 项目检查目录；包含旧回归夹具、隔离测试存档、画面预览和导出检查数据。
- 目标：`D:\.codex\游戏2\godot\.build\temp-archive\20261014`，完整保留原内容。每个文件核对 SHA-256 后才移除 C 盘原件。
- 详细目录及文件哈希保存在目标目录的 `_manifests/`；汇总收据见 [主迁移记录](artifacts/temp-migration-20261014.json) 和 [早期检查迁移记录](artifacts/temp-migration-extra-20261014.json)。

## 后续检查

`project_temporary.py` 将项目临时根目录设为 `.build/runtime-tmp/`。`verify_migration.py`、`run_isolated.py`、`verify_windows_package.py`、`verify_actual_exe.py` 都使用该目录，并同时隔离 TEMP、TMP、APPDATA 和 LOCALAPPDATA。正常结束及受控失败时自动清理临时数据，日志仍保存在项目 `artifacts/` 中。

已核对五个 Python 文件的语法，以及 D 盘临时目录创建、写入和退出清理。SDK、JDK、导出模板和发行包均位于项目 D 盘目录。

`.build/temp-archive/` 是保留的旧检查数据，会占用约 24 GiB；不进入 Windows、Web 或安卓发行包。
