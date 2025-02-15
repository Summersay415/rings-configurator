class_name Main
extends Control


static var file := "user://schedule.txt"

const MONTHS := [
	"января",
	"февраля",
	"марта",
	"апреля",
	"мая",
	"июня",
	"июля",
	"августа",
	"сентября",
	"октября",
	"ноября",
	"декабря",
]
const SCHEDULES_OF_DAY_LIMIT: int = 10
const OVERRIDES_LIMIT: int = 30

@export var schedule_of_day_scene: PackedScene
@export var override_scene: PackedScene
var schedules_of_day: Dictionary[int, ScheduleOfDay]
var overrides: Dictionary[Array, int] # день-месяц : id расписания
var _going_to_delete: int = -1


func _ready() -> void:
	get_window().min_size = Vector2i(840, 630)
	($SaveSchedule as FileDialog).current_path = OS.get_executable_path().get_base_dir()
	($AddScheduleOfDay as AcceptDialog).get_ok_button().disabled = true
	($AddScheduleOfDay as AcceptDialog).register_text_enter(
			$AddScheduleOfDay/LineEdit as LineEdit)
	
	load_from_file()
	_list()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_to_file()


func save_to_file(path: String = "user://schedule.rings") -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if not fa:
		push_error("Error saving to file at %s: %s." % [
			path,
			error_string(FileAccess.get_open_error()),
		])
		return
	# Заголовок
	fa.store_line("{nums_of_schedules} {nums_of_overrides} {ring_duration_msec} \
{lesson_mins} {lessons_in_shift}".format({
		nums_of_schedules = schedules_of_day.size(),
		nums_of_overrides = overrides.size(),
		ring_duration_msec = int((%RingDuration as Range).value * 1000),
		lesson_mins = int(($ScheduleEditor/%LessonTime as Range).value),
		lessons_in_shift = int(($ScheduleEditor/%LessonsInShift as Range).value),
	}))
	
	var mapping: Dictionary[int, int] = {0: 0} # id: idx
	var counter: int = 1
	for id: int in schedules_of_day:
		mapping[id] = counter
		counter += 1
	
	# Дни недели
	fa.store_line("%d %d %d %d %d %d %d" % [
		mapping[(%Monday as OptionButton).get_selected_id()],
		mapping[(%Tuesday as OptionButton).get_selected_id()],
		mapping[(%Wednesday as OptionButton).get_selected_id()],
		mapping[(%Thursday as OptionButton).get_selected_id()],
		mapping[(%Friday as OptionButton).get_selected_id()],
		mapping[(%Saturday as OptionButton).get_selected_id()],
		mapping[(%Sunday as OptionButton).get_selected_id()],
	])
	# Расписания
	for i: int in range(1, schedules_of_day.size() + 1):
		var schedule: ScheduleOfDay = schedules_of_day[mapping.find_key(i)]
		fa.store_line(str(schedule.rings.size()))
		fa.store_line(schedule.name)
		var first := true
		for time: Array in schedule.rings:
			if not first:
				fa.store_string(' ')
			first = false
			fa.store_string("%d %d" % time)
		fa.store_string('\n')
		
		for interval: String in schedule.interval_names:
			fa.store_line(interval)
	# Переопределения
	for date: Array in overrides:
		fa.store_line("%d %d %d" % [date[0], date[1], mapping[overrides[date]]])
	
	fa.close()


func load_from_file() -> void:
	if not FileAccess.file_exists(file):
		return
	var fa := FileAccess.open(file, FileAccess.READ)
	if not fa:
		push_error("Error opening file at %s: %s." % [
			file,
			error_string(FileAccess.get_open_error()),
		])
		return
	# Парсинг заголовка
	var header: PackedStringArray = fa.get_line().split(' ')
	if header.size() != 5:
		push_error("Corrupted header.")
		fa.close()
		return
	var days_of_week: PackedStringArray = fa.get_line().split(' ')
	var nums_of_schedules := int(header[0])
	var nums_of_overrides := int(header[1])
	(%RingDuration as Range).value = int(header[2]) / 1000.0
	($ScheduleEditor/%LessonTime as Range).value = int(header[3])
	($ScheduleEditor/%LessonsInShift as Range).value = int(header[4])
	
	var mapping: Dictionary[int, int] = {0: 0} # id: idx
	for i: int in range(1, nums_of_schedules + 1):
		mapping[i] = generate_id()
	# Расписания
	for i: int in range(1, nums_of_schedules + 1):
		var schedule := ScheduleOfDay.new()
		schedule.interval_names.clear()
		schedule.rings.clear()
		var rings := int(fa.get_line())
		schedule.name = fa.get_line()
		var rings_times: PackedStringArray = fa.get_line().split(' ')
		for j: int in rings:
			schedule.rings.append([int(rings_times[j * 2]), int(rings_times[j * 2 + 1])])
		for j: int in rings + 1:
			schedule.interval_names.append(fa.get_line())
		schedules_of_day[mapping[i]] = schedule
	# Переопределения
	for i: int in nums_of_overrides:
		var override: PackedStringArray = fa.get_line().split(' ')
		overrides[[int(override[0]), int(override[1])]] = mapping[int(override[2])]
	# Дни недели
	_update_schedule_menus()
	(%Monday as OptionButton).select((%Monday as OptionButton).get_item_index(
			mapping[int(days_of_week[0])]))
	(%Tuesday as OptionButton).select((%Tuesday as OptionButton).get_item_index(
			mapping[int(days_of_week[1])]))
	(%Wednesday as OptionButton).select((%Wednesday as OptionButton).get_item_index(
			mapping[int(days_of_week[2])]))
	(%Thursday as OptionButton).select((%Thursday as OptionButton).get_item_index(
			mapping[int(days_of_week[3])]))
	(%Friday as OptionButton).select((%Friday as OptionButton).get_item_index(
			mapping[int(days_of_week[4])]))
	(%Saturday as OptionButton).select((%Saturday as OptionButton).get_item_index(
			mapping[int(days_of_week[5])]))
	(%Sunday as OptionButton).select((%Sunday as OptionButton).get_item_index(
			mapping[int(days_of_week[6])]))


func generate_id() -> int:
	if schedules_of_day.size() >= 100:
		return -1
	var id: int = randi() % 999 + 1
	while id in schedules_of_day:
		id = randi() % 999 + 1
	return id


func _list() -> void:
	for i: int in range(1, %SchedulesList.get_child_count() - 1):
		var schedule: HBoxContainer = %SchedulesList.get_child(i)
		%SchedulesList.remove_child(schedule)
		schedule.queue_free()
	
	for id: int in schedules_of_day:
		_list_schedule_of_day(id)
	
	for date: Array in overrides:
		_list_override(date)
	
	_update_schedule_menus()


func _check_for_taken() -> void:
	(%AddOverrideConfirm as BaseButton).disabled = [int(%Day.value), %Month.selected] in overrides


func _update_schedule_menus():
	for button: OptionButton in get_tree().get_nodes_in_group(&"ScheduleMenu"):
		var was_selected: int = button.get_selected_id()
		button.clear()
		
		button.add_item("Пустое расписание", 0)
		for id: int in schedules_of_day:
			button.add_item(schedules_of_day[id].name, id)
		
		if was_selected == 0 or not was_selected in schedules_of_day:
			button.select(0)
		else:
			button.select(button.get_item_index(was_selected))


func _list_schedule_of_day(id: int) -> void:
	var schedule_of_day: HBoxContainer = schedule_of_day_scene.instantiate()
	(schedule_of_day.get_node(^"Name") as Label).text = schedules_of_day[id].name
	(schedule_of_day.get_node(^"Edit") as BaseButton).pressed.connect(
			_on_schedule_of_day_edit_pressed.bind(id))
	(schedule_of_day.get_node(^"Delete") as BaseButton).pressed.connect(
			_on_schedule_of_day_delete_pressed.bind(id))
	(schedule_of_day.get_node(^"Copy") as BaseButton).pressed.connect(
			_on_schedule_of_day_copy_pressed.bind(id))
	schedule_of_day.name = str(id)
	%SchedulesList.add_child(schedule_of_day)
	%SchedulesList.move_child(schedule_of_day, -2)
	for button: Button in get_tree().get_nodes_in_group(&"AddSchedule"):
		button.disabled = schedules_of_day.size() >= SCHEDULES_OF_DAY_LIMIT


func _list_override(date: Array) -> void:
	var override: HBoxContainer = override_scene.instantiate()
	(override.get_node(^"Name") as Label).text = "%d %s" % [date[0], MONTHS[date[1]]]
	(override.get_node(^"Delete") as BaseButton).pressed.connect(
			_on_override_delete_pressed.bind(date))
	override.name = "%d_%d" % [date[0], date[1]]
	%OverridesList.add_child(override)
	
	var option := OptionButton.new()
	option.add_to_group(&"ScheduleMenu")
	option.name = "%d_%dMenu" % [date[0], date[1]]
	
	option.add_item("Пустое расписание", 0)
	for id: int in schedules_of_day:
		option.add_item(schedules_of_day[id].name, id)
	%OverridesList.add_child(option)
	option.select(option.get_item_index(overrides[date]))
	
	(%NoOverrides as CanvasItem).hide()
	(%AddOverride as BaseButton).disabled = overrides.size() >= OVERRIDES_LIMIT


func _on_schedule_of_day_copy_pressed(id: int) -> void:
	var max_length: int = ($AddScheduleOfDay/LineEdit as LineEdit).max_length
	var count: int = 2
	var count_size: int = str(count).length()
	var new_name: String = schedules_of_day[id].name.rstrip("1234567890")
	if new_name.length() + count_size > max_length:
		new_name = new_name.left(-count_size + max_length - new_name.length()) + str(count)
	else:
		new_name += str(count)
	while schedules_of_day.values().any(func(s: ScheduleOfDay) -> bool: return s.name == new_name):
		count += 1
		count_size = str(count).length()
		new_name = schedules_of_day[id].name.rstrip("1234567890")
		if new_name.length() + count_size > max_length:
			new_name = new_name.left(-count_size + max_length - new_name.length()) + str(count)
		else:
			new_name += str(count)
	
	var new_id: int = generate_id()
	if new_id < 0:
		return
	var new_schedule := ScheduleOfDay.new()
	new_schedule.name = new_name
	new_schedule.interval_names.clear()
	new_schedule.rings.clear()
	
	for time: Array in schedules_of_day[id].rings:
		new_schedule.rings.append(time.duplicate())
	for interval_name: String in schedules_of_day[id].interval_names:
		new_schedule.interval_names.append(interval_name)
	
	schedules_of_day[new_id] = new_schedule
	_list_schedule_of_day(new_id)
	_update_schedule_menus()


func _on_schedule_of_day_edit_pressed(id: int) -> void:
	($ScheduleEditor as ScheduleEditor).edit_schedule(schedules_of_day[id])


func _on_schedule_of_day_delete_pressed(id: int) -> void:
	_going_to_delete = id
	($DeleteScheduleOfDay as AcceptDialog).dialog_text = \
			'Удалить расписание "%s"?' % schedules_of_day[id].name
	($DeleteScheduleOfDay as Window).popup_centered()


func _on_override_delete_pressed(date: Array) -> void:
	overrides.erase(date)
	%OverridesList.get_node("%d_%d" % [date[0], date[1]]).queue_free()
	%OverridesList.get_node("%d_%dMenu" % [date[0], date[1]]).queue_free()
	_update_schedule_menus()
	if overrides.size() == 0:
		(%NoOverrides as CanvasItem).show()
	(%AddOverride as BaseButton).disabled = overrides.size() >= OVERRIDES_LIMIT


func _on_add_schedule_of_day_confirmed() -> void:
	var new_name: String = ($AddScheduleOfDay/LineEdit as LineEdit).text.strip_edges()
	($AddScheduleOfDay/LineEdit as LineEdit).clear()
	
	var new_id: int = generate_id()
	if new_id < 0:
		return
	var new_schedule := ScheduleOfDay.new()
	new_schedule.name = new_name
	schedules_of_day[new_id] = new_schedule
	_list_schedule_of_day(new_id)
	_update_schedule_menus()
	($AddScheduleOfDay as Window).hide()
	
	($ScheduleEditor as ScheduleEditor).edit_schedule(new_schedule)


func _on_month_item_selected(index: int) -> void:
	match index:
		0, 2, 4, 6, 7, 9, 11:
			(%Day as Range).max_value = 31
		3, 5, 8, 10:
			(%Day as Range).max_value = 30
		1:
			(%Day as Range).max_value = 29
	_check_for_taken()


func _on_add_override_pressed() -> void:
	var date := [int(%Day.value), %Month.selected]
	overrides[date] = (%ScheduleOverride as OptionButton).get_selected_id()
	_list_override(date)
	($AddOverride as Window).hide()


func _on_line_edit_text_changed(new_text: String) -> void:
	var allowed := true
	new_text = new_text.strip_edges().strip_escapes()
	if new_text.is_empty():
		allowed = false
	else:
		for id: int in schedules_of_day:
			if schedules_of_day[id].name == new_text:
				allowed = false
				break
	($AddScheduleOfDay as AcceptDialog).get_ok_button().disabled = not allowed


func _on_delete_schedule_of_day_confirmed() -> void:
	schedules_of_day.erase(_going_to_delete)
	%SchedulesList.get_node(str(_going_to_delete)).queue_free()
	for date: Array in overrides:
		if overrides[date] == _going_to_delete:
			overrides[date] = 0
	_update_schedule_menus()
	for button: Button in get_tree().get_nodes_in_group(&"AddSchedule"):
		button.disabled = schedules_of_day.size() >= SCHEDULES_OF_DAY_LIMIT


func _on_load_schedule_file_selected(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	file = path
	get_tree().reload_current_scene()
