extends Control

@export_group("Game Settings")
@export var n: int = 2
@export var max_rounds: int = 20
@export var step_interval: float = 2.5
@export var flash_time: float = 0.7

@export_group("Assets")
@export var audio_clips: Array[AudioStream] = []

@export_group("Required Nodes")
@export var audio_player: AudioStreamPlayer
@export var results_panel: Control
@export var results_label: Label

var grid_container: GridContainer
var n_value_label: Label
var n_up_btn: Button
var n_down_btn: Button
var steps_value_label: Label
var steps_up_btn: Button
var steps_down_btn: Button
var start_btn: Button
var visual_btn: Button
var audio_btn: Button
var game_timer: Timer
var legal_btn: Button
var legal_panel: Control
var legal_label: RichTextLabel
var support_btn: Button

const CELL_IDLE := Color(0.149, 0.169, 0.235)
const CELL_ACTIVE := Color(0.337, 0.6, 1.0)
const COLOR_BTN_NORMAL := Color(0.149, 0.169, 0.235)
const COLOR_SUCCESS := Color(0.18, 0.78, 0.35)
const COLOR_ERROR := Color(0.88, 0.24, 0.24)

var visual_btn_style: StyleBoxFlat
var audio_btn_style: StyleBoxFlat

var visual_history: Array[int] = []
var audio_history: Array[int] = []
var cells: Array[Panel] = []
var cell_styles: Array[StyleBoxFlat] = []

var current_round: int = 0
var v_responded: bool = false
var a_responded: bool = false
var v_possible_matches: int = 0; var a_possible_matches: int = 0
var v_hits: int = 0; var a_hits: int = 0
var v_false_alarms: int = 0; var a_false_alarms: int = 0


func _ready():
	print("--- SYSTEM STARTUP ---")

	grid_container = find_child("GridContainer", true, false)
	n_value_label = find_child("NValue", true, false)
	n_up_btn = find_child("NUp", true, false)
	n_down_btn = find_child("NDown", true, false)
	steps_value_label = find_child("StepsValue", true, false)
	steps_up_btn = find_child("StepsUp", true, false)
	steps_down_btn = find_child("StepsDown", true, false)
	start_btn = find_child("StartButton", true, false)
	visual_btn = find_child("VisualButton", true, false)
	audio_btn = find_child("AudioButton", true, false)
	game_timer = find_child("Timer", true, false)
	support_btn = find_child("SupportButton", true, false) 
	
	if support_btn:
		support_btn.text = "Buy me a coffee"
		support_btn.modulate = Color(1.0, 0.42, 0.52)
		support_btn.pressed.connect(func(): OS.shell_open("https://ko-fi.com/strwdr"))

	if not audio_player: audio_player = find_child("AudioStreamPlayer", true, false)
	if not results_panel: results_panel = find_child("ResultsPanel", true, false)
	if not results_label: results_label = find_child("ResultsLabel", true, false)

	legal_btn = find_child("LegalButton", true, false)
	legal_panel = find_child("LegalPanel", true, false)
	legal_label = find_child("LegalLabel", true, false)

	if start_btn: start_btn.focus_mode = Control.FOCUS_NONE
	if visual_btn: visual_btn.focus_mode = Control.FOCUS_NONE
	if audio_btn: audio_btn.focus_mode = Control.FOCUS_NONE
	if legal_btn: legal_btn.focus_mode = Control.FOCUS_NONE
	if n_up_btn: n_up_btn.focus_mode = Control.FOCUS_NONE
	if n_down_btn: n_down_btn.focus_mode = Control.FOCUS_NONE
	if steps_up_btn: steps_up_btn.focus_mode = Control.FOCUS_NONE
	if steps_down_btn: steps_down_btn.focus_mode = Control.FOCUS_NONE

	_setup_action_buttons()

	if audio_clips.is_empty():
		_load_audio_from_folder()

	if grid_container: setup_grid()

	if n_value_label: n_value_label.text = str(n)
	if steps_value_label: steps_value_label.text = str(max_rounds)

	if results_panel: results_panel.visible = false
	if legal_panel: legal_panel.visible = false

	_setup_legal_attribution()

	if start_btn: start_btn.pressed.connect(_on_start_toggle)
	if visual_btn: visual_btn.gui_input.connect(func(e): if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed(): _on_visual_input())
    if audio_btn: audio_btn.gui_input.connect(func(e): if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed(): _on_audio_input())
	if game_timer: game_timer.timeout.connect(_tick)

	if n_up_btn: n_up_btn.pressed.connect(_on_n_up)
	if n_down_btn: n_down_btn.pressed.connect(_on_n_down)
	if steps_up_btn: steps_up_btn.pressed.connect(_on_steps_up)
	if steps_down_btn: steps_down_btn.pressed.connect(_on_steps_down)

	if legal_btn: legal_btn.pressed.connect(_toggle_legal)
	if legal_label: legal_label.meta_clicked.connect(_on_legal_link_clicked)

	_update_ui_state(false)

	print("--- SYSTEM READY ---")


func _setup_action_buttons():
	for btn in [visual_btn, audio_btn]:
		if not btn: continue
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_BTN_NORMAL
		style.set_corner_radius_all(12)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("disabled", style)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		if btn == visual_btn: visual_btn_style = style
		else: audio_btn_style = style


func _on_n_up():
	n = min(n + 1, 10)
	if n_value_label: n_value_label.text = str(n)

func _on_n_down():
	n = max(n - 1, 1)
	if n_value_label: n_value_label.text = str(n)

func _on_steps_up():
	max_rounds = min(max_rounds + 5, 100)
	if steps_value_label: steps_value_label.text = str(max_rounds)

func _on_steps_down():
	max_rounds = max(max_rounds - 5, 5)
	if steps_value_label: steps_value_label.text = str(max_rounds)


func _update_ui_state(is_running: bool):
	var selector_alpha = 0.5 if is_running else 1.0

	if n_up_btn:
		n_up_btn.disabled = is_running
		n_up_btn.modulate.a = selector_alpha
	if n_down_btn:
		n_down_btn.disabled = is_running
		n_down_btn.modulate.a = selector_alpha
	if n_value_label:
		n_value_label.modulate.a = selector_alpha
	if steps_up_btn:
		steps_up_btn.disabled = is_running
		steps_up_btn.modulate.a = selector_alpha
	if steps_down_btn:
		steps_down_btn.disabled = is_running
		steps_down_btn.modulate.a = selector_alpha
	if steps_value_label:
		steps_value_label.modulate.a = selector_alpha

	if visual_btn: visual_btn.disabled = true
	if audio_btn: audio_btn.disabled = true
	if visual_btn_style: visual_btn_style.bg_color = COLOR_BTN_NORMAL
	if audio_btn_style: audio_btn_style.bg_color = COLOR_BTN_NORMAL


func _load_audio_from_folder():
	print("\n[AUDIO SCAN] Scanning res://alphabet/...")
	var allowed = ["h", "k", "l", "q", "r", "s"]
	var path = "res://alphabet/"
	var dir = DirAccess.open(path)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var temp_list = []

		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".wav") or file_name.ends_with(".remap")):
				var clean_name = file_name.replace(".remap", "")
				var letter = clean_name.get_basename().split("__")[-1].to_lower()
				if letter in allowed:
					var full_path = path + clean_name
					if ResourceLoader.exists(full_path):
						var res = load(full_path)
						if res is AudioStream:
							temp_list.append({"res": res, "name": clean_name})
			file_name = dir.get_next()

		temp_list.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())

		audio_clips.clear()
		for item in temp_list:
			audio_clips.append(item["res"])

		print("[AUDIO SCAN] Total clips ready: ", audio_clips.size())
	else:
		push_error("CRITICAL: res://alphabet/ folder not found!")

func _setup_legal_attribution():
	if not legal_label: return
	legal_label.bbcode_enabled = true
	legal_label.fit_content = false
	legal_label.scroll_active = true 
	var text = "\n[center][b]CREDITS[/b]\n\n"
	text += "[b]DEVELOPER[/b]\n"
	text += "strwdr | [url=https://github.com/strwdr]GitHub[/url]\n"
	text += "Support: [url=https://ko-fi.com/strwdr]Ko-fi[/url]\n\n"

	text += "[b]AUDIO[/b]\n"
	text += "Pack: \"The Alphabet\"\n"
	text += "Author: [url=https://freesound.org/people/tim.kahn/]tim.kahn[/url]\n"
	text += "Source: [url=https://freesound.org/people/tim.kahn/packs/4371/]Freesound Pack 4371[/url]\n"
	text += "License: [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]\n\n"

	text += "[b]APP ICON[/b]\n"
	text += "Art: \"Brain\" (Human Mind Coll.)\n"
	text += "Author: [url=https://thenounproject.com/aomam/collection/human-mind-mixed/]AomAm[/url]\n"
	text += "Source: [url=https://thenounproject.com/term/brain/1355298/]The Noun Project[/url]\n"
	text += "License: [url=https://creativecommons.org/licenses/by/3.0/]CC BY 3.0[/url]\n"
	text += "(Changes: Color adapted)\n\n"

	text += "[b]ENGINE[/b]\n"
	text += "Built with [url=https://godotengine.org]Godot Engine[/url] (MIT License)\n\n"
	
	text += "[color=#888888](Tap outside to close)[/color][/center]"

	legal_label.text = text

func setup_grid() -> void:
	for child in grid_container.get_children(): child.queue_free()
	grid_container.columns = 3
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cells.clear()
	cell_styles.clear()
	for i in range(9):
		var style := StyleBoxFlat.new()
		style.bg_color = CELL_IDLE
		style.set_corner_radius_all(14)

		var cell := Panel.new()
		cell.add_theme_stylebox_override("panel", style)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(40, 40)
		grid_container.add_child(cell)
		cells.append(cell)
		cell_styles.append(style)

func _on_start_toggle():
	if game_timer.is_stopped():
		_start_game()
	else:
		_stop_game()

func _start_game():
	if results_panel: results_panel.visible = false
	if legal_panel: legal_panel.visible = false

	visual_history.clear(); audio_history.clear(); current_round = 0
	v_possible_matches = 0; a_possible_matches = 0
	v_hits = 0; a_hits = 0; v_false_alarms = 0; a_false_alarms = 0

	start_btn.text = "STOP"

	_update_ui_state(true)

	print("\n=== GAME STARTED (N=%d, STEPS=%d) ===" % [n, max_rounds])
	_tick()
	game_timer.start(step_interval)

func _stop_game():
	print("=== GAME ENDED ===")
	game_timer.stop()
	start_btn.text = "START"

	_update_ui_state(false)
	_clear_highlights()
	_calculate_and_show_results()

func _tick():
	if current_round >= max_rounds:
		print("Max rounds reached.")
		_stop_game()
		return

	v_responded = false; a_responded = false
	_clear_highlights()
	current_round += 1

	var v_idx = randi() % 9
	var a_size = audio_clips.size()

	var a_idx = 0
	if a_size > 0:
		a_idx = randi() % a_size

	visual_history.append(v_idx); audio_history.append(a_idx)

	# Enable matching buttons only after N steps
	var can_match = visual_history.size() > n
	if visual_btn:
		visual_btn.disabled = not can_match
		if visual_btn_style: visual_btn_style.bg_color = COLOR_BTN_NORMAL
	if audio_btn:
		audio_btn.disabled = not can_match
		if audio_btn_style: audio_btn_style.bg_color = COLOR_BTN_NORMAL

	if visual_history.size() > n:
		if visual_history[-1] == visual_history[-1 - n]: v_possible_matches += 1
		if a_size > 0 and audio_history[-1] == audio_history[-1 - n]: a_possible_matches += 1

	_highlight_cell(v_idx)
	get_tree().create_timer(flash_time).timeout.connect(func():
		if not game_timer.is_stopped():
			_clear_highlights()
	)

	if not audio_player:
		print("Round %d: ERROR - AudioPlayer not found" % current_round)
	elif a_size == 0:
		print("Round %d: ERROR - No audio clips found" % current_round)
	else:
		var clip = audio_clips[a_idx]
		audio_player.stream = clip
		audio_player.play()
		print("Round %d: Playing -> %s" % [current_round, clip.resource_path.get_file()])

func _highlight_cell(idx: int):
	if idx < 0 or idx >= cell_styles.size(): return
	cell_styles[idx].bg_color = CELL_ACTIVE

func _clear_highlights():
	for style in cell_styles:
		style.bg_color = CELL_IDLE


func _on_visual_input():
	if v_responded or visual_history.size() <= n: return

	v_responded = true
	if visual_btn: visual_btn.disabled = true

	var is_match = visual_history[-1] == visual_history[-1 - n]
	if is_match:
		v_hits += 1
		_feedback(visual_btn_style, true)
	else:
		v_false_alarms += 1
		_feedback(visual_btn_style, false)

func _on_audio_input():
	if a_responded or audio_history.size() <= n: return

	a_responded = true
	if audio_btn: audio_btn.disabled = true

	var is_match = audio_history[-1] == audio_history[-1 - n]
	if is_match:
		a_hits += 1
		_feedback(audio_btn_style, true)
	else:
		a_false_alarms += 1
		_feedback(audio_btn_style, false)

func _feedback(style: StyleBoxFlat, success: bool):
	if not style: return
	style.bg_color = COLOR_SUCCESS if success else COLOR_ERROR

	var tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(style, "bg_color", COLOR_BTN_NORMAL, 0.3)


func _calculate_and_show_results():
	if not results_panel or not results_label: return
	results_panel.visible = true

	var v_acc = 0.0; var v_total = v_possible_matches + v_false_alarms
	if v_total > 0: v_acc = (float(v_hits) / float(v_total)) * 100.0
	else: v_acc = 100.0 if v_false_alarms == 0 else 0.0

	var a_acc = 0.0; var a_total = a_possible_matches + a_false_alarms
	if a_total > 0: a_acc = (float(a_hits) / float(a_total)) * 100.0
	else: a_acc = 100.0 if a_false_alarms == 0 else 0.0

	var txt = "SESSION COMPLETE (N=%d)\n\n" % n
	txt += "VISUAL\nMatches: %d/%d | Wrong: %d\nAccuracy: %.1f%%\n\n" % [v_hits, v_possible_matches, v_false_alarms, v_acc]
	txt += "AUDIO\nMatches: %d/%d | Wrong: %d\nAccuracy: %.1f%%" % [a_hits, a_possible_matches, a_false_alarms, a_acc]

	results_label.text = txt

func _toggle_legal():
	if not legal_panel: return
	legal_panel.visible = not legal_panel.visible
	if legal_panel.visible and results_panel:
		results_panel.visible = false

func _on_legal_link_clicked(meta):
	OS.shell_open(str(meta))

func _input(event):
	if event is InputEventScreenTouch and not event.pressed:
		var hover_fix = InputEventMouseMotion.new()
		hover_fix.position = Vector2(-1, -1)
		hover_fix.global_position = Vector2(-1, -1)
		Input.parse_input_event(hover_fix)

	if event is InputEventMouseButton and event.pressed:

		if results_panel and results_panel.visible:
			results_panel.visible = false
			get_viewport().set_input_as_handled()
			return

		if legal_panel and legal_panel.visible:
			var panel_rect = legal_panel.get_global_rect()
			if not panel_rect.has_point(event.global_position):
				legal_panel.visible = false
				get_viewport().set_input_as_handled()
