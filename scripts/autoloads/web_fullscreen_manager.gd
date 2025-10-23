extends Node

## ============================================
## WEB FULLSCREEN MANAGER
## ============================================
##
## Provides fullscreen toggle for web builds, especially mobile browsers
## Uses JavaScript bridge to call browser fullscreen API

var is_fullscreen: bool = false
var is_mobile: bool = false

func _ready():
	# Only works in web builds
	if not OS.has_feature("web"):
		queue_free()
		return

	# Detect if running on mobile
	_detect_mobile()

	print("[WebFullscreenManager] Initialized - Mobile: %s" % is_mobile)

func _detect_mobile() -> void:
	"""Detect if running on mobile device via JavaScript"""
	if OS.has_feature("web"):
		var js_code = """
		(function() {
			return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
		})();
		"""
		is_mobile = JavaScriptBridge.eval(js_code, true)
		print("[WebFullscreenManager] Mobile detection result: %s" % is_mobile)

func toggle_fullscreen() -> void:
	"""Toggle fullscreen mode"""
	if not OS.has_feature("web"):
		push_warning("[WebFullscreenManager] Fullscreen only available in web builds")
		return

	if is_fullscreen:
		exit_fullscreen()
	else:
		enter_fullscreen()

func enter_fullscreen() -> void:
	"""Request fullscreen mode"""
	if not OS.has_feature("web"):
		return

	var js_code = """
	(function() {
		var elem = document.documentElement;
		if (elem.requestFullscreen) {
			elem.requestFullscreen();
		} else if (elem.webkitRequestFullscreen) {
			elem.webkitRequestFullscreen(); // Safari
		} else if (elem.mozRequestFullScreen) {
			elem.mozRequestFullScreen(); // Firefox
		} else if (elem.msRequestFullscreen) {
			elem.msRequestFullscreen(); // IE/Edge
		}
	})();
	"""
	JavaScriptBridge.eval(js_code, true)
	is_fullscreen = true
	print("[WebFullscreenManager] Entered fullscreen")

func exit_fullscreen() -> void:
	"""Exit fullscreen mode"""
	if not OS.has_feature("web"):
		return

	var js_code = """
	(function() {
		if (document.exitFullscreen) {
			document.exitFullscreen();
		} else if (document.webkitExitFullscreen) {
			document.webkitExitFullscreen(); // Safari
		} else if (document.mozCancelFullScreen) {
			document.mozCancelFullScreen(); // Firefox
		} else if (document.msExitFullscreen) {
			document.msExitFullscreen(); // IE/Edge
		}
	})();
	"""
	JavaScriptBridge.eval(js_code, true)
	is_fullscreen = false
	print("[WebFullscreenManager] Exited fullscreen")

func is_mobile_device() -> bool:
	"""Check if running on mobile device"""
	return is_mobile
