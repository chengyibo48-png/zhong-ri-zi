"""Extract existing snapshot and normalization code while retaining public entry points."""
import re, shutil
from pathlib import Path
project = Path(__file__).resolve().parents[1]
path = project/'scripts/game_state.gd'
profile = project/'scripts/presentation_profile.gd'
if (project/'scripts/native_save_snapshot.gd').exists(): raise SystemExit('Extraction already applied')
backup = project/'artifacts/continuation-20261014/before'
backup.mkdir(parents=True,exist_ok=True)
for source in [path,profile]: shutil.copy2(source,backup/source.name)
text = path.read_text(encoding='utf8')
def function(name):
    match = re.search(r'^func '+re.escape(name)+r'\([^\n]+\n.*?(?=^func |\Z)',text,re.M|re.S)
    if not match: raise RuntimeError(name)
    return match
token = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\#.*?$|\b[A-Za-z_]\w*\b',re.M)
def replace_identifiers(body, substitutions):
    def replace(match):
        word=match.group()
        if match.start() and body[match.start()-1]=='.': return word
        return substitutions.get(word,word)
    return token.sub(replace,body)
members = set(re.findall(r'^var (\w+)',text,re.M)) | set(re.findall(r'^func (\w+)',text,re.M))
match = function('_make_save_data')
body = match.group().split('\n',1)[1].rstrip()
body = replace_identifiers(body,{name:'state.'+name for name in members})
module = 'extends RefCounted\n## Canonical native snapshot; disk IO and validation stay separate.\nstatic func capture(state: Node) -> Dictionary:\n'+body+'\n'
(project/'scripts/native_save_snapshot.gd').write_text(module,encoding='utf8')
text = text[:match.start()]+'func _make_save_data() -> Dictionary:\n\treturn preload("res://scripts/native_save_snapshot.gd").capture(self)\n\n'+text[match.end():]
match = function('_normalize_npc_social')
body = replace_identifiers(match.group().split('\n',1)[1].rstrip(),{'day':'current_day'})
module = 'extends RefCounted\n## Pure story, partner and marriage normalization shared by old and current saves.\nstatic func normalize(saved_stories: Variant, saved_partners: Variant, saved_marriage: Variant, current_day: int, npc_catalog: Array, content: Dictionary) -> Dictionary:\n\tvar npc_stories: Dictionary = {}\n\tvar partners: Dictionary = {}\n\tvar marriage: Dictionary = {}\n'+body+'\n\treturn {"stories":npc_stories,"partners":partners,"marriage":marriage}\n'
(project/'scripts/npc_social_profile.gd').write_text(module,encoding='utf8')
wrapper = 'func _normalize_npc_social(saved_stories: Variant = {}, saved_partners: Variant = {}, saved_marriage: Variant = {}) -> void:\n\tvar normalized := preload("res://scripts/npc_social_profile.gd").normalize(saved_stories,saved_partners,saved_marriage,day,npc_catalog,content)\n\tnpc_stories = normalized.stories\n\tpartners = normalized.partners\n\tmarriage = normalized.marriage\n\n'
text = text[:match.start()]+wrapper+text[match.end():]
match = function('_normalize_player_settings')
body = match.group().split('\n',1)[1].rstrip()
body = body.replace('\tvar defaults: Dictionary = initial_state.get("settings", {})\n\tif not player_settings is Dictionary: player_settings = {}','\tvar player_settings: Dictionary = source if source is Dictionary else {}',1)
module = '\nstatic func settings(source: Variant, defaults: Dictionary) -> Dictionary:\n'+body+'\n\treturn player_settings\n'
profile.write_text(profile.read_text(encoding='utf8').rstrip()+'\n'+module,encoding='utf8')
wrapper = 'func _normalize_player_settings() -> void:\n\tplayer_settings = PROFILE.settings(player_settings,initial_state.get("settings",{}))\n\n'
text = text[:match.start()]+wrapper+text[match.end():]
path.write_text(text,encoding='utf8')
print('Extracted snapshot, social profile and player settings; public methods retained')
