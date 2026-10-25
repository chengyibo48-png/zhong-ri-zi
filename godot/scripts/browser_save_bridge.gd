extends RefCounted
var callback: JavaScriptObject

func choose(receive: Callable) -> void:
	callback = JavaScriptBridge.create_callback(func(args: Array): receive.call(str(args[0])))
	JavaScriptBridge.eval("""
window.zrzPickSave = function(done) {
 const input = document.createElement('input');
 input.type = 'file'; input.accept = '.json,application/json';
 input.onchange = async function() {
  const file = input.files[0]; if (!file) return;
  if (file.size > 16 * 1024 * 1024) { done('__ZRZ_TOO_LARGE__'); return; }
  try { done(await file.text()); } catch (_) { done(''); }
 };
 input.click();
};
""", true)
	JavaScriptBridge.get_interface("window").zrzPickSave(callback)

func download(text: String, filename: String) -> bool:
	if text.is_empty() or text.to_utf8_buffer().size() > preload("res://scripts/native_save_schema.gd").MAX_BYTES: return false
	JavaScriptBridge.eval("""
window.zrzDownloadSave = function(text, name) {
 const url = URL.createObjectURL(new Blob([text], {type:'application/json'}));
 const anchor = document.createElement('a'); anchor.href = url; anchor.download = name;
 document.body.appendChild(anchor); anchor.click(); anchor.remove();
 setTimeout(() => URL.revokeObjectURL(url), 60000);
};
""", true)
	JavaScriptBridge.get_interface("window").zrzDownloadSave(text, filename)
	return true
