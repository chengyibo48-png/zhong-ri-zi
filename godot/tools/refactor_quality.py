"""Extract existing pure presentation normalization and file transactions verbatim."""
import re
from pathlib import Path
project = Path(__file__).resolve().parents[1]
state_path = project/'scripts/game_state.gd'
text = state_path.read_text(encoding='utf-8-sig')
constants = ['VISUAL_FX_DEFAULT','UI_ART_DEFAULT','APPEARANCE_DEFAULT','FEEDBACK_PREFS_DEFAULT','FEEDBACK_TYPES','FEEDBACK_LINKS']
module = 'extends RefCounted\n## Pure profile normalization shared by creation, loading and settings.\nconst JS_TEXT = preload("res://scripts/js_string.gd")\n'
for name in constants:
    match = re.search(r'^const '+name+r' := .*$',text,re.M)
    if match is None: raise RuntimeError(name)
    module += match.group(0)+'\n'
    text = text[:match.start()]+'const '+name+' = PROFILE.'+name+text[match.end():]
functions = {
 '_normalize_visual_fx':('visual_fx','source, legacy_feedback, legacy_settings'),
 '_normalize_ui_art':('ui_art','source'),
 '_normalize_appearance':('appearance','source'),
 '_feedback_default':('feedback_default',''),
 '_normalize_feedback':('feedback','source, day, item_catalog')}
for old,(new,args) in functions.items():
    match = re.search(r'^func '+old+r'\([^\n]+\n.*?(?=^func |\Z)',text,re.M|re.S)
    if match is None: raise RuntimeError(old)
    original = match.group(0)
    extracted = original.replace('func '+old+'(', 'static func '+new+'(',1).replace('_feedback_default()', 'feedback_default()')
    if old == '_normalize_feedback':
        extracted = extracted.replace('source: Variant)', 'source: Variant, current_day: int, item_catalog: Dictionary)')
        extracted = extracted.replace('get("day", day)', 'get("day", current_day)').replace(' > day ', ' > current_day ')
    module += '\n'+extracted
    wrapper = original.splitlines()[0]+'\n\treturn PROFILE.'+new+'('+args+')\n\n'
    text = text[:match.start()]+wrapper+text[match.end():]
(project/'scripts/presentation_profile.gd').write_text(module,encoding='utf8')
text = text.replace('extends Node\n','extends Node\nconst PROFILE = preload("res://scripts/presentation_profile.gd")\n',1)
start = text.index('func _save_path_absolute(')
end = text.index('func _queue_autosave()',start)
text = text[:start]+'''func _save_path_absolute(path: String) -> String:
	return preload("res://scripts/save_repository.gd").absolute(path)

func _write_json_atomically(path: String, data: Dictionary) -> bool:
	var restored := _save_path_absolute(path) == _recovered_save_path
	var ok: bool = preload("res://scripts/save_repository.gd").write(path,data,restored)
	if ok and restored: _recovered_save_path = ""
	return ok

'''+text[end:]
start = text.index('func _read_save_json(')
end = text.index('func load_game_data(',start)
text = text[:start]+'''func _read_save_json(path: String) -> Variant:
	return preload("res://scripts/save_repository.gd").read(path)

'''+text[end:]
start = text.index('\tif not parsed is Dictionary or int(parsed.get("version", 0))')
end = text.index('\tvar atlas_rules =',start)
text = text[:start]+'''\tif not preload("res://scripts/native_save_rules.gd").valid(parsed):
		return false
'''+text[end:]
state_path.write_text(text,encoding='utf8')
print('Extracted pure profiles and atomic file repository; native preflight added.')
