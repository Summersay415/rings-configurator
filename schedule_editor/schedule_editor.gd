class_name ScheduleEditor
extends Window


const RINGS_LIMIT: int = 40

@export var interval_scene: PackedScene
@export var ring_scene: PackedScene
var _editing_schedule: ScheduleOfDay


func edit_schedule(schedule: ScheduleOfDay) -> void:
	_editing_schedule = schedule
	title = 'Редактирование "%s"' % _editing_schedule.name
	(%RenameEdit as LineEdit).text = _editing_schedule.name
	
	for child: HBoxContainer in %RingsAndIntervalsList.get_children():
		%RingsAndIntervalsList.remove_child(child)
		child.queue_free()
	
	(%LessonTime as Range).value = _editing_schedule.lesson_time
	(%LessonsInShift as Range).value = _editing_schedule.lessons_in_shift
	
	var first_interval: HBoxContainer = interval_scene.instantiate()
	(first_interval.get_node(^"Duration") as CanvasItem).hide()
	(first_interval.get_node(^"LineEdit") as LineEdit).text = _editing_schedule.interval_names[0]
	(first_interval.get_node(^"LineEdit") as LineEdit).text_changed.connect(
			_on_interval_line_edit_text_changed.bind(0))
	first_interval.name = &"IntervalFirst"
	%RingsAndIntervalsList.add_child(first_interval)
	
	for i: int in _editing_schedule.rings.size():
		_list_ring(i)
	(%AddRing as BaseButton).disabled = _editing_schedule.rings.size() >= RINGS_LIMIT \
			or _editing_schedule.rings[-1] == [23, 59]
	
	popup_centered()


func _list_ring(idx: int) -> void:
	var ring: HBoxContainer = ring_scene.instantiate()
	ring.name = "Ring%d" % randi()
	(ring.get_node(^"Hours") as Range).value = _editing_schedule.rings[idx][0]
	(ring.get_node(^"Mins") as Range).value = _editing_schedule.rings[idx][1]
	(ring.get_node(^"Hours") as Range).value_changed.connect(_on_hours_value_changed.bind(idx))
	(ring.get_node(^"Mins") as Range).value_changed.connect(_on_mins_value_changed.bind(idx))
	(ring.get_node(^"Delete") as BaseButton).pressed.connect(_on_delete_ring_pressed.bind(idx))
	if %RingsAndIntervalsList.get_child_count() == 1:
		%RingsAndIntervalsList.add_child(ring, true)
		var last_interval: HBoxContainer = interval_scene.instantiate()
		(last_interval.get_node(^"Duration") as CanvasItem).hide()
		(last_interval.get_node(^"LineEdit") as LineEdit).text = _editing_schedule.interval_names[-1]
		(last_interval.get_node(^"LineEdit") as LineEdit).text_changed.connect(
				_on_interval_line_edit_text_changed.bind(-1))
		last_interval.name = &"IntervalLast"
		%RingsAndIntervalsList.add_child(last_interval)
	else:
		var interval: HBoxContainer = interval_scene.instantiate()
		(interval.get_node(^"LineEdit") as LineEdit).text = _editing_schedule.interval_names[idx]
		(interval.get_node(^"LineEdit") as LineEdit).text_changed.connect(
				_on_interval_line_edit_text_changed.bind(idx))
		interval.name = "Interval%d" % randi()
		%RingsAndIntervalsList.add_child(interval, true)
		%RingsAndIntervalsList.add_child(ring, true)
		%RingsAndIntervalsList.move_child(%RingsAndIntervalsList/IntervalLast, -1)
	_update_limits(idx)
	_update_duration(idx)


func _update_limits(idx: int) -> void:
	var ring: HBoxContainer = %RingsAndIntervalsList.get_child(idx * 2 + 1)
	var hours: SpinBox = ring.get_node(^"Hours")
	var mins: SpinBox = ring.get_node(^"Mins")
	mins.min_value = 0
	mins.max_value = 59
	var previous_time: Array = [0, 0]
	var next_time: Array = [24, 0]
	if idx != 0:
		previous_time = _editing_schedule.rings[idx - 1]
	if idx != _editing_schedule.rings.size() - 1:
		next_time = _editing_schedule.rings[idx + 1]
	hours.min_value = previous_time[0] + (1 if previous_time[1] == 59 else 0)
	hours.max_value = next_time[0] - (1 if next_time[1] == 0 else 0)
	if _editing_schedule.rings[idx][0] == hours.min_value:
		mins.min_value = (previous_time[1] + 1) % 60
	if _editing_schedule.rings[idx][0] == hours.max_value:
		mins.max_value = (59 + next_time[1]) % 60


func _update_duration(idx: int) -> void:
	if idx == 0:
		return
	var interval: HBoxContainer = %RingsAndIntervalsList.get_child(idx * 2)
	var duration: int = (_editing_schedule.rings[idx][0] * 60 + _editing_schedule.rings[idx][1]) \
			- (_editing_schedule.rings[idx - 1][0] * 60 + _editing_schedule.rings[idx - 1][1])
	(interval.get_node(^"Duration") as Label).text = "Длительность: %d мин" % duration


func _on_hours_value_changed(value: float, idx: int) -> void:
	_editing_schedule.rings[idx][0] = int(value)
	if idx != 0:
		_update_limits(idx - 1)
		_update_duration(idx)
	if idx != _editing_schedule.rings.size() - 1:
		_update_limits(idx + 1)
		_update_duration(idx + 1)
	
	_update_limits(idx)
	(%AddRing as BaseButton).disabled = _editing_schedule.rings[-1] == [23, 59]


func _on_mins_value_changed(value: float, idx: int) -> void:
	_editing_schedule.rings[idx][1] = int(value)
	if idx != 0:
		_update_limits(idx - 1)
		_update_duration(idx)
	if idx != _editing_schedule.rings.size() - 1:
		_update_limits(idx + 1)
		_update_duration(idx + 1)
	(%AddRing as BaseButton).disabled = _editing_schedule.rings[-1] == [23, 59]


func _on_interval_line_edit_text_changed(text: String, idx: int) -> void:
	var normal_text: String = text.strip_edges().strip_escapes()
	if normal_text.is_empty():
		return
	_editing_schedule.interval_names[idx] = text


func _on_delete_ring_pressed(idx: int) -> void:
	if _editing_schedule.rings.size() == 1:
		return
	
	_editing_schedule.rings.remove_at(idx)
	_editing_schedule.interval_names.remove_at(idx + 1 * int(idx != _editing_schedule.rings.size()))
	
	var child: HBoxContainer = %RingsAndIntervalsList.get_child(idx * 2 + 1)
	%RingsAndIntervalsList.remove_child(child)
	child.queue_free()
	child = %RingsAndIntervalsList.get_child(idx * 2 + 1 * int(idx != _editing_schedule.rings.size()))
	%RingsAndIntervalsList.remove_child(child)
	child.queue_free()
	for i: int in %RingsAndIntervalsList.get_child_count():
		var curr_idx: int = roundi((i - 1) / 2.0)
		if curr_idx < idx:
			continue
		var current_child: HBoxContainer = %RingsAndIntervalsList.get_child(i)
		if current_child.name.begins_with("Ring"):
			(current_child.get_node(^"Hours") as Range).value_changed.disconnect(
					_on_hours_value_changed)
			(current_child.get_node(^"Mins") as Range).value_changed.disconnect(
					_on_mins_value_changed)
			(current_child.get_node(^"Delete") as BaseButton).pressed.disconnect(
					_on_delete_ring_pressed)
			(current_child.get_node(^"Hours") as Range).value_changed.connect(
					_on_hours_value_changed.bind(curr_idx))
			(current_child.get_node(^"Mins") as Range).value_changed.connect(
					_on_mins_value_changed.bind(curr_idx))
			(current_child.get_node(^"Delete") as BaseButton).pressed.connect(
					_on_delete_ring_pressed.bind(curr_idx))
		elif current_child.name.begins_with("Interval"):
			(current_child.get_node(^"LineEdit") as LineEdit).text_changed.disconnect(
					_on_interval_line_edit_text_changed)
			if current_child.name == &"LastInterval":
				(current_child.get_node(^"LineEdit") as LineEdit).text_changed.connect(
						_on_interval_line_edit_text_changed.bind(-1))
			else:
				(current_child.get_node(^"LineEdit") as LineEdit).text_changed.connect(
						_on_interval_line_edit_text_changed.bind(curr_idx))
	
	for i: int in range(maxi(0, idx - 1), mini(idx + 1, _editing_schedule.rings.size())):
		_update_duration(i)
		_update_limits(i)
	
	(%AddRing as BaseButton).disabled = _editing_schedule.rings.size() >= RINGS_LIMIT \
			or _editing_schedule.rings[-1] == [23, 59]


func _on_add_ring_pressed() -> void:
	var new_idx: int = _editing_schedule.rings.size()
	var new_time: int = mini(_editing_schedule.rings[-1][0] * 60 + _editing_schedule.rings[-1][1]
			+ (_editing_schedule.lesson_time if new_idx % 2 == 1 else 5), 1439)
	var num_of_lesson: int = floori(new_idx / 2.0) + 1
	var shift: int = 1 if num_of_lesson <= _editing_schedule.lessons_in_shift else 2
	if shift == 2:
		num_of_lesson -= _editing_schedule.lessons_in_shift
	var new_name: String = ("S%d: Lesson %d" if new_idx % 2 == 1 else "S%d: Break to L%d") % [
		shift,
		num_of_lesson,
	]
	var new_timing: Array = [floori(new_time / 60.0), new_time % 60]
	_editing_schedule.rings.append(new_timing)
	_editing_schedule.interval_names.insert(new_idx, new_name)
	
	(%AddRing as BaseButton).disabled = _editing_schedule.rings.size() >= RINGS_LIMIT \
			or _editing_schedule.rings[-1] == [23, 59]
	
	_list_ring(new_idx)


func _on_rename_edit_text_submitted(new_text: String) -> void:
	var allowed := true
	new_text = new_text.strip_edges().strip_escapes()
	if new_text.is_empty():
		allowed = false
	else:
		for id: int in (get_parent() as Main).schedules_of_day:
			if (get_parent() as Main).schedules_of_day[id].name == new_text:
				allowed = false
				break
	if not allowed:
		(%RenameEdit as LineEdit).text = _editing_schedule.name
		return
	_editing_schedule.name = (%RenameEdit as LineEdit).text
	title = 'Редактирование "%s"' % _editing_schedule.name
	(get_parent().get_node(^"%SchedulesList").get_node(
			str((get_parent() as Main).schedules_of_day.find_key(_editing_schedule))
	).get_node(^"Name") as Label).text = new_text


func _on_lesson_time_value_changed(value: float) -> void:
	_editing_schedule.lesson_time = int(value)


func _on_lessons_in_shift_value_changed(value: float) -> void:
	_editing_schedule.lessons_in_shift = int(value)
