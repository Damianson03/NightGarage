extends Node3D

const GameState = preload("res://scripts/game_state.gd")
const GOLF_MODEL_PATH := "res://assets/cars/2014_volkswagen_golf_gti_mk7.glb"
const GOLF_MODEL_SCALE := 100.0


var state = GameState.new()

var player_car: Node3D
var opponent_car: Node3D
var camera: Camera3D

var player_wheels: Array[Node3D] = []
var player_wheel_signs: Array[float] = []
var opponent_wheels: Array[Node3D] = []
var opponent_wheel_signs: Array[float] = []
var last_player_wheel_distance: float = 0.0
var last_opponent_wheel_distance: float = 0.0

var garage_panel: Control
var race_panel: Control
var result_panel: Control

var money_label: Label
var stats_label: Label
var upgrade_labels: Array[Label] = []
var upgrade_buttons: Array[Button] = []

var countdown_label: Label
var shift_label: Label
var speed_label: Label
var gear_label: Label
var rpm_label: Label
var time_label: Label
var distance_label: Label
var zero_to_100_label: Label
var rpm_bar: ProgressBar
var rpm_green_zone: ColorRect
var rpm_red_zone: ColorRect
var rpm_needle: ColorRect
var rpm_zone_label: Label
var gas_button: Button
var shift_button: Button

var result_title: Label
var result_stats: Label

var last_screen := -1


func _ready() -> void:
    _build_ui()
    _build_world()
    _apply_screen()
    _update_ui()


func _process(delta: float) -> void:
    state.update(delta)

    if state.screen != last_screen:
        _apply_screen()

    _update_world()
    _update_ui()


func _build_world() -> void:
    camera = Camera3D.new()
    add_child(camera)
    camera.current = true

    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.005, 0.008, 0.018)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.15, 0.18, 0.28)
    env.ambient_light_energy = 0.9
    world.environment = env
    add_child(world)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
    moon.light_color = Color(0.58, 0.68, 1.0)
    moon.light_energy = 1.7
    moon.shadow_enabled = false
    add_child(moon)

    var warm_light := OmniLight3D.new()
    warm_light.position = Vector3(0.0, 4.8, -4.0)
    warm_light.light_color = Color(1.0, 0.62, 0.34)
    warm_light.light_energy = 8.0
    warm_light.omni_range = 18.0
    add_child(warm_light)

    _add_box(
        Vector3(0.0, -0.10, -250.0),
        Vector3(12.0, 0.20, 520.0),
        Color(0.045, 0.05, 0.065),
        0.15,
        0.34
    )

    for z in range(0, 500, 12):
        _add_box(
            Vector3(0.0, 0.015, -float(z)),
            Vector3(0.08, 0.025, 4.2),
            Color(0.86, 0.80, 0.30),
            0.0,
            0.55
        )

    _add_box(
        Vector3(0.0, 0.025, -2.8),
        Vector3(10.0, 0.035, 0.34),
        Color(0.94, 0.94, 0.96),
        0.0,
        0.4
    )

    _add_box(
        Vector3(0.0, 0.025, -402.336),
        Vector3(10.0, 0.035, 0.48),
        Color(0.15, 0.95, 0.35),
        0.0,
        0.4
    )

    for z in range(0, 430, 26):
        _add_lamp(-6.2, -float(z))
        _add_lamp(6.2, -float(z))

    player_car = _create_golf_car(Color(0.78, 0.018, 0.028))
    player_car.position = Vector3(-1.70, 0.0, 0.0)
    add_child(player_car)
    _prepare_golf_runtime(player_car, Color(0.78, 0.018, 0.028), true)
    _add_car_headlights(player_car, 3.4)

    opponent_car = _create_golf_car(Color(0.16, 0.18, 0.21))
    opponent_car.position = Vector3(1.70, 0.0, 0.0)
    add_child(opponent_car)
    _prepare_golf_runtime(opponent_car, Color(0.16, 0.18, 0.21), false)
    _add_car_headlights(opponent_car, 2.6)

    _set_garage_camera()


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    garage_panel = Control.new()
    garage_panel.size = Vector2(1280, 720)
    layer.add_child(garage_panel)

    var garage_bg := ColorRect.new()
    garage_bg.color = Color(0.01, 0.015, 0.03, 0.58)
    garage_bg.position = Vector2(24, 22)
    garage_bg.size = Vector2(560, 660)
    garage_panel.add_child(garage_bg)

    var title := _label("NIGHT GARAGE", Vector2(48, 38), 34)
    garage_panel.add_child(title)

    var version := _label(GameState.GAME_VERSION + "  •  GOLF 7 MODEL", Vector2(50, 82), 17)
    version.modulate = Color(0.50, 0.82, 1.0)
    garage_panel.add_child(version)

    money_label = _label("", Vector2(50, 120), 24)
    garage_panel.add_child(money_label)

    var dev_cash := Button.new()
    dev_cash.text = "+500K TEST"
    dev_cash.position = Vector2(390, 112)
    dev_cash.size = Vector2(145, 42)
    dev_cash.pressed.connect(_add_dev_cash)
    garage_panel.add_child(dev_cash)

    stats_label = _label("", Vector2(50, 158), 19)
    stats_label.size = Vector2(510, 110)
    stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    garage_panel.add_child(stats_label)

    var y := 282.0
    for i in range(GameState.UPGRADE_NAMES.size()):
        var label := _label("", Vector2(50, y), 17)
        label.size = Vector2(280, 40)
        garage_panel.add_child(label)
        upgrade_labels.append(label)

        var button := Button.new()
        button.text = "KUP"
        button.position = Vector2(365, y - 4)
        button.size = Vector2(170, 42)
        button.pressed.connect(_buy_upgrade.bind(i))
        garage_panel.add_child(button)
        upgrade_buttons.append(button)

        y += 54.0

    var career := Button.new()
    career.text = "CAREER"
    career.position = Vector2(48, 610)
    career.size = Vector2(150, 52)
    career.pressed.connect(_start_career)
    garage_panel.add_child(career)

    var cash := Button.new()
    cash.text = "CASH RUN"
    cash.position = Vector2(208, 610)
    cash.size = Vector2(150, 52)
    cash.pressed.connect(_start_cash_run)
    garage_panel.add_child(cash)

    var reset := Button.new()
    reset.text = "RESET TUNING"
    reset.position = Vector2(368, 610)
    reset.size = Vector2(166, 52)
    reset.pressed.connect(_reset_tuning)
    garage_panel.add_child(reset)

    race_panel = Control.new()
    race_panel.size = Vector2(1280, 720)
    layer.add_child(race_panel)

    countdown_label = _label("3", Vector2(520, 78), 78)
    countdown_label.size = Vector2(240, 100)
    countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    race_panel.add_child(countdown_label)

    shift_label = _label("", Vector2(440, 168), 32)
    shift_label.size = Vector2(400, 50)
    shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shift_label.modulate = Color(0.45, 1.0, 0.52)
    race_panel.add_child(shift_label)

    speed_label = _label("0 km/h", Vector2(48, 38), 30)
    race_panel.add_child(speed_label)

    gear_label = _label("GEAR 1", Vector2(48, 82), 26)
    race_panel.add_child(gear_label)

    rpm_label = _label("950 RPM", Vector2(48, 120), 22)
    race_panel.add_child(rpm_label)

    time_label = _label("0.000 s", Vector2(1015, 38), 24)
    race_panel.add_child(time_label)

    distance_label = _label("0 / 402 m", Vector2(1015, 74), 20)
    race_panel.add_child(distance_label)

    zero_to_100_label = _label("0-100: --", Vector2(1015, 108), 20)
    race_panel.add_child(zero_to_100_label)

    rpm_bar = ProgressBar.new()
    rpm_bar.position = Vector2(310, 625)
    rpm_bar.size = Vector2(610, 32)
    rpm_bar.min_value = 0.0
    rpm_bar.max_value = 6200.0
    rpm_bar.show_percentage = false
    race_panel.add_child(rpm_bar)

    rpm_bar.modulate = Color(0.62, 0.72, 1.0, 0.42)

    rpm_green_zone = ColorRect.new()
    rpm_green_zone.color = Color(0.08, 0.95, 0.22, 0.72)
    rpm_green_zone.position = Vector2(310.0, 625.0)
    rpm_green_zone.size = Vector2(10.0, 32.0)
    rpm_green_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(rpm_green_zone)

    rpm_red_zone = ColorRect.new()
    rpm_red_zone.color = Color(1.0, 0.08, 0.06, 0.68)
    rpm_red_zone.position = Vector2(850.0, 625.0)
    rpm_red_zone.size = Vector2(70.0, 32.0)
    rpm_red_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(rpm_red_zone)

    rpm_needle = ColorRect.new()
    rpm_needle.color = Color(1.0, 1.0, 1.0, 1.0)
    rpm_needle.position = Vector2(310.0, 620.0)
    rpm_needle.size = Vector2(5.0, 42.0)
    rpm_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(rpm_needle)

    rpm_zone_label = _label("", Vector2(310.0, 592.0), 16)
    rpm_zone_label.size = Vector2(610.0, 28.0)
    rpm_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rpm_zone_label.modulate = Color(0.90, 0.92, 0.96)
    race_panel.add_child(rpm_zone_label)

    gas_button = Button.new()
    gas_button.text = "GAS"
    gas_button.position = Vector2(1060, 525)
    gas_button.size = Vector2(170, 145)
    gas_button.button_down.connect(_gas_down)
    gas_button.button_up.connect(_gas_up)
    race_panel.add_child(gas_button)

    shift_button = Button.new()
    shift_button.text = "SHIFT"
    shift_button.position = Vector2(870, 525)
    shift_button.size = Vector2(170, 145)
    shift_button.pressed.connect(_shift_pressed)
    race_panel.add_child(shift_button)

    var hint := _label("Trzymaj GAS przed startem. Puść, aby RPM powoli opadało.", Vector2(34, 675), 15)
    hint.modulate = Color(0.72, 0.75, 0.82)
    race_panel.add_child(hint)

    result_panel = Control.new()
    result_panel.size = Vector2(1280, 720)
    layer.add_child(result_panel)

    var result_bg := ColorRect.new()
    result_bg.color = Color(0.008, 0.012, 0.025, 0.86)
    result_bg.position = Vector2(330, 120)
    result_bg.size = Vector2(620, 480)
    result_panel.add_child(result_bg)

    result_title = _label("WYNIK", Vector2(380, 158), 42)
    result_title.size = Vector2(520, 60)
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_panel.add_child(result_title)

    result_stats = _label("", Vector2(400, 245), 24)
    result_stats.size = Vector2(480, 210)
    result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_panel.add_child(result_stats)

    var garage_button := Button.new()
    garage_button.text = "WRÓĆ DO GARAŻU"
    garage_button.position = Vector2(500, 500)
    garage_button.size = Vector2(280, 64)
    garage_button.pressed.connect(_back_to_garage)
    result_panel.add_child(garage_button)


func _apply_screen() -> void:
    last_screen = state.screen

    garage_panel.visible = state.screen == GameState.Screen.GARAGE
    race_panel.visible = state.screen == GameState.Screen.COUNTDOWN or state.screen == GameState.Screen.RACING
    result_panel.visible = state.screen == GameState.Screen.RESULT

    if state.screen == GameState.Screen.GARAGE:
        _set_garage_camera()

    if state.screen == GameState.Screen.COUNTDOWN:
        player_car.position = Vector3(-1.70, 0.0, 0.0)
        opponent_car.position = Vector3(1.70, 0.0, 0.0)
        last_player_wheel_distance = 0.0
        last_opponent_wheel_distance = 0.0

    if state.screen == GameState.Screen.RESULT:
        _update_result_panel()


func _update_world() -> void:
    _update_wheel_animation()

    if state.screen == GameState.Screen.GARAGE:
        var orbit: float = float(Time.get_ticks_msec()) / 1000.0
        camera.position = Vector3(
            -5.35 + sin(orbit * 0.16) * 0.75,
            2.15,
            -6.25 + cos(orbit * 0.16) * 0.85
        )
        camera.look_at(Vector3(-1.70, 0.76, 0.0), Vector3.UP)
        return

    player_car.position.z = -state.player_distance
    opponent_car.position.z = -state.opponent_distance

    var blend := 0.0
    if state.screen == GameState.Screen.RACING:
        blend = _smoothstep(0.0, 1.35, state.race_time)

    var player_z: float = -float(state.player_distance)

    var start_pos := Vector3(-5.0, 1.55, player_z - 5.9)
    var side_pos := Vector3(7.6, 2.05, player_z + 3.0)
    var cam_pos := start_pos.lerp(side_pos, blend)

    var start_target := Vector3(-1.70, 0.72, player_z - 0.3)
    var side_target := Vector3(-0.2, 0.72, player_z - 15.0)
    var target := start_target.lerp(side_target, blend)

    camera.position = cam_pos
    camera.look_at(target, Vector3.UP)


func _update_ui() -> void:
    if state.screen == GameState.Screen.GARAGE:
        _update_garage_ui()
        return

    if state.screen == GameState.Screen.COUNTDOWN or state.screen == GameState.Screen.RACING:
        speed_label.text = "%d km/h" % int(round(state.speed_kmh))
        gear_label.text = "GEAR %d%s" % [state.gear, "  (SHIFTING)" if state.shifting else ""]
        rpm_label.text = "%d RPM" % int(round(state.rpm))
        time_label.text = "%.3f s" % state.race_time
        distance_label.text = "%d / 402 m" % int(round(state.player_distance))
        rpm_bar.value = state.rpm
        _update_rpm_zones()

        if state.zero_to_100_time > 0.0:
            zero_to_100_label.text = "0-100: %.2f s" % state.zero_to_100_time
        else:
            zero_to_100_label.text = "0-100: --"

        if state.screen == GameState.Screen.COUNTDOWN:
            countdown_label.visible = true
            countdown_label.text = str(maxi(1, int(ceil(minf(float(state.countdown), 3.0)))))
        else:
            countdown_label.visible = state.race_time < 0.55
            countdown_label.text = "GO"

        shift_label.text = state.shift_message if state.shift_message_time > 0.0 else ""
        shift_button.disabled = state.screen != GameState.Screen.RACING or state.shifting or state.gear >= GameState.MAX_GEARS


func _update_rpm_zones() -> void:
    if rpm_green_zone == null or rpm_red_zone == null or rpm_needle == null or rpm_zone_label == null:
        return

    var meter_x: float = 310.0
    var meter_y: float = 625.0
    var meter_width: float = 610.0
    var meter_height: float = 32.0
    var meter_max_rpm: float = float(rpm_bar.max_value)
    var zone_low: float = 0.0
    var zone_high: float = 0.0

    if state.screen == GameState.Screen.COUNTDOWN:
        zone_low = float(state.launch_green_low())
        zone_high = float(state.launch_green_high())
        rpm_zone_label.text = "STREFA STARTU: %d-%d RPM" % [int(round(zone_low)), int(round(zone_high))]
    else:
        zone_low = float(state.green_low())
        zone_high = float(state.green_high())
        rpm_zone_label.text = "STREFA ZMIANY: %d-%d RPM" % [int(round(zone_low)), int(round(zone_high))]

    zone_low = clampf(zone_low, 0.0, meter_max_rpm)
    zone_high = clampf(zone_high, zone_low, meter_max_rpm)

    var green_start_ratio: float = zone_low / meter_max_rpm
    var green_end_ratio: float = zone_high / meter_max_rpm
    var green_x: float = meter_x + meter_width * green_start_ratio
    var green_width: float = maxf(4.0, meter_width * (green_end_ratio - green_start_ratio))
    rpm_green_zone.position = Vector2(green_x, meter_y)
    rpm_green_zone.size = Vector2(green_width, meter_height)

    var red_x: float = meter_x + meter_width * green_end_ratio
    var red_width: float = maxf(4.0, (meter_x + meter_width) - red_x)
    rpm_red_zone.position = Vector2(red_x, meter_y)
    rpm_red_zone.size = Vector2(red_width, meter_height)

    var rpm_ratio: float = clampf(float(state.rpm) / meter_max_rpm, 0.0, 1.0)
    var needle_x: float = meter_x + meter_width * rpm_ratio
    rpm_needle.position = Vector2(needle_x - 2.5, meter_y - 5.0)

    if state.rpm >= zone_low and state.rpm <= zone_high:
        rpm_label.modulate = Color(0.20, 1.0, 0.28)
    elif state.rpm > zone_high:
        rpm_label.modulate = Color(1.0, 0.18, 0.12)
    else:
        rpm_label.modulate = Color(1.0, 1.0, 1.0)


func _update_garage_ui() -> void:
    money_label.text = "KASA: " + state.money_text()

    stats_label.text = (
        "Volkswagen Golf VII 1.2 TSI 85 KM  •  5MT\n"
        + "Moc: %.0f KM    Masa: %.0f kg    Rating: %d\n" % [state.horsepower(), state.weight_kg(), state.rating()]
        + "Seria: 0-100 km/h 11.9 s  •  Vmax 179 km/h  •  zmiana biegu %.2f s" % state.shift_duration()
    )

    for i in range(upgrade_labels.size()):
        var level: int = state.upgrades[i]
        var cost: int = int(state.upgrade_cost(i))
        upgrade_labels[i].text = "%s  LVL %d/5" % [GameState.UPGRADE_NAMES[i], level]

        if level >= 5:
            upgrade_buttons[i].text = "MAX"
            upgrade_buttons[i].disabled = true
        else:
            upgrade_buttons[i].text = "KUP  %d $" % cost
            upgrade_buttons[i].disabled = state.money < cost


func _update_result_panel() -> void:
    result_title.text = "WYGRANA" if state.last_win else "PRZEGRANA"
    result_title.modulate = Color(0.35, 1.0, 0.45) if state.last_win else Color(1.0, 0.35, 0.35)

    var zero_text := "--"
    if state.zero_to_100_time > 0.0:
        zero_text = "%.2f s" % state.zero_to_100_time

    result_stats.text = (
        "%s\n\n" % state.mode_name()
        + "1/4 mili: %.3f s\n" % state.player_finish_time
        + "0-100 km/h: %s\n" % zero_text
        + "Vmax w przejeździe: %d km/h\n" % int(round(state.max_speed_seen))
        + "Nagroda: %d $" % state.last_reward
    )


func _start_career() -> void:
    state.start_race(GameState.Mode.CAREER)
    _apply_screen()


func _start_cash_run() -> void:
    state.start_race(GameState.Mode.CASH_RUN)
    _apply_screen()


func _buy_upgrade(index: int) -> void:
    state.buy_upgrade(index)
    _update_garage_ui()


func _reset_tuning() -> void:
    state.reset_upgrades()
    _update_garage_ui()


func _add_dev_cash() -> void:
    state.add_dev_cash()
    _update_garage_ui()


func _back_to_garage() -> void:
    state.go_garage()
    _apply_screen()


func _gas_down() -> void:
    state.set_gas(true)


func _gas_up() -> void:
    state.set_gas(false)


func _shift_pressed() -> void:
    state.shift()


func _set_garage_camera() -> void:
    camera.position = Vector3(-5.35, 2.15, -6.25)
    camera.look_at(Vector3(-1.70, 0.76, 0.0), Vector3.UP)


func _create_golf_car(body_color: Color) -> Node3D:
    if not ResourceLoader.exists(GOLF_MODEL_PATH):
        return _create_golf_placeholder(body_color)

    var model_resource: Resource = load(GOLF_MODEL_PATH)
    if not (model_resource is PackedScene):
        return _create_golf_placeholder(body_color)

    var packed_scene: PackedScene = model_resource as PackedScene
    var imported_node: Node = packed_scene.instantiate()
    if not (imported_node is Node3D):
        imported_node.queue_free()
        return _create_golf_placeholder(body_color)

    var wrapper := Node3D.new()
    wrapper.name = "Golf7Car"

    var imported_model: Node3D = imported_node as Node3D
    imported_model.name = "Golf7Model"
    imported_model.scale = Vector3.ONE * GOLF_MODEL_SCALE
    imported_model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
    imported_model.position = Vector3(0.0, 0.055, 0.0)

    wrapper.add_child(imported_model)
    wrapper.set_meta("real_golf_model", true)
    return wrapper


func _prepare_golf_runtime(car_root: Node3D, paint_color: Color, is_player: bool) -> void:
    if not bool(car_root.get_meta("real_golf_model", false)):
        return

    var model_node: Node = car_root.find_child("Golf7Model", true, false)
    if not (model_node is Node3D):
        return

    var model: Node3D = model_node as Node3D
    _optimize_golf_visuals(model, paint_color)

    var wheel_names: Array[String] = [
        "3DWheel Front L",
        "3DWheel Front R",
        "3DWheel Rear L",
        "3DWheel Rear R"
    ]
    var wheel_signs: Array[float] = [1.0, -1.0, 1.0, -1.0]

    for index in range(wheel_names.size()):
        var found_node: Node = model.find_child(wheel_names[index], true, false)
        if not (found_node is Node3D):
            continue

        var wheel: Node3D = found_node as Node3D
        _merge_wheel_geometry(wheel)

        if is_player:
            player_wheels.append(wheel)
            player_wheel_signs.append(wheel_signs[index])
        else:
            opponent_wheels.append(wheel)
            opponent_wheel_signs.append(wheel_signs[index])


func _optimize_golf_visuals(model: Node3D, paint_color: Color) -> void:
    var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)

    for node in mesh_nodes:
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var lower_name: String = String(mesh_instance.name).to_lower()

        if (
            lower_name.contains("interior")
            or lower_name.contains("engine")
            or lower_name.contains("windowinside")
            or lower_name.contains("calliper")
        ):
            mesh_instance.visible = false
            continue

        if lower_name.contains("paint_geo") or lower_name.contains("paint_material"):
            _tint_mesh_materials(mesh_instance, paint_color, false)
        elif lower_name.contains("window_geo") or lower_name.contains("window_material"):
            _tint_mesh_materials(mesh_instance, Color(0.012, 0.016, 0.024, 1.0), true)


func _tint_mesh_materials(mesh_instance: MeshInstance3D, tint: Color, opaque_window: bool) -> void:
    if mesh_instance.mesh == null:
        return

    var surface_count: int = mesh_instance.mesh.get_surface_count()
    for surface_index in range(surface_count):
        var active_material: Material = mesh_instance.get_active_material(surface_index)
        if not (active_material is BaseMaterial3D):
            continue

        var copied_resource: Resource = active_material.duplicate(true)
        if not (copied_resource is BaseMaterial3D):
            continue

        var copied_material: BaseMaterial3D = copied_resource as BaseMaterial3D
        copied_material.albedo_color = tint

        if opaque_window:
            copied_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
            copied_material.metallic = 0.18
            copied_material.roughness = 0.10
        else:
            copied_material.metallic = 0.58
            copied_material.roughness = 0.18

        mesh_instance.set_surface_override_material(surface_index, copied_material)


func _merge_wheel_geometry(wheel: Node3D) -> void:
    var mesh_nodes: Array[Node] = wheel.find_children("*", "MeshInstance3D", true, false)
    if mesh_nodes.is_empty():
        return

    var surface_tool := SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

    var first_material: Material = null
    var appended_surfaces: int = 0
    var wheel_inverse: Transform3D = wheel.global_transform.affine_inverse()

    for node in mesh_nodes:
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
            continue

        var source_mesh: Mesh = mesh_instance.mesh
        var relative_transform: Transform3D = wheel_inverse * mesh_instance.global_transform
        var surface_count: int = source_mesh.get_surface_count()

        for surface_index in range(surface_count):
            if source_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
                continue

            if first_material == null:
                first_material = mesh_instance.get_active_material(surface_index)

            surface_tool.append_from(source_mesh, surface_index, relative_transform)
            appended_surfaces += 1

    if appended_surfaces == 0:
        return

    if first_material != null:
        surface_tool.set_material(first_material)

    var merged_mesh: ArrayMesh = surface_tool.commit()
    if merged_mesh == null:
        return

    var merged_instance := MeshInstance3D.new()
    merged_instance.name = "MergedWheel"
    merged_instance.mesh = merged_mesh
    wheel.add_child(merged_instance)

    for node in mesh_nodes:
        if is_instance_valid(node):
            node.queue_free()


func _add_car_headlights(car_root: Node3D, energy: float) -> void:
    if not bool(car_root.get_meta("real_golf_model", false)):
        return

    var x_positions: Array[float] = [-0.62, 0.62]
    for x_value in x_positions:
        var headlight := SpotLight3D.new()
        headlight.position = Vector3(x_value, 0.64, -2.05)
        headlight.light_color = Color(0.76, 0.86, 1.0)
        headlight.light_energy = energy
        headlight.spot_range = 14.0
        headlight.spot_angle = 30.0
        headlight.shadow_enabled = false
        car_root.add_child(headlight)


func _update_wheel_animation() -> void:
    if state.screen == GameState.Screen.GARAGE:
        last_player_wheel_distance = float(state.player_distance)
        last_opponent_wheel_distance = float(state.opponent_distance)
        return

    var player_distance_now: float = float(state.player_distance)
    var opponent_distance_now: float = float(state.opponent_distance)

    var player_delta: float = maxf(0.0, player_distance_now - last_player_wheel_distance)
    var opponent_delta: float = maxf(0.0, opponent_distance_now - last_opponent_wheel_distance)

    _rotate_registered_wheels(player_wheels, player_wheel_signs, player_delta)
    _rotate_registered_wheels(opponent_wheels, opponent_wheel_signs, opponent_delta)

    last_player_wheel_distance = player_distance_now
    last_opponent_wheel_distance = opponent_distance_now


func _rotate_registered_wheels(wheels: Array[Node3D], signs: Array[float], distance_delta: float) -> void:
    if distance_delta <= 0.0:
        return

    var wheel_count: int = mini(wheels.size(), signs.size())
    var spin_angle: float = distance_delta / GameState.WHEEL_RADIUS_M

    for index in range(wheel_count):
        var wheel: Node3D = wheels[index]
        if is_instance_valid(wheel):
            wheel.rotate_x(spin_angle * signs[index])


func _create_golf_placeholder(body_color: Color) -> Node3D:
    var root := Node3D.new()

    _add_box_to(root, Vector3(0.0, 0.42, 0.0), Vector3(1.78, 0.42, 4.15), body_color, 0.45, 0.24)
    _add_box_to(root, Vector3(0.0, 0.75, -0.95), Vector3(1.64, 0.22, 1.02), body_color.lightened(0.08), 0.45, 0.24)
    _add_box_to(root, Vector3(0.0, 1.02, 0.18), Vector3(1.38, 0.48, 1.95), Color(0.025, 0.045, 0.075), 0.2, 0.12)
    _add_box_to(root, Vector3(0.0, 1.31, 0.28), Vector3(1.16, 0.12, 1.25), body_color.darkened(0.14), 0.45, 0.24)

    _add_box_to(root, Vector3(-0.52, 0.56, -2.08), Vector3(0.34, 0.12, 0.07), Color(0.75, 0.90, 1.0), 0.0, 0.1)
    _add_box_to(root, Vector3(0.52, 0.56, -2.08), Vector3(0.34, 0.12, 0.07), Color(0.75, 0.90, 1.0), 0.0, 0.1)

    _add_box_to(root, Vector3(-0.54, 0.58, 2.08), Vector3(0.30, 0.14, 0.07), Color(1.0, 0.04, 0.03), 0.0, 0.1)
    _add_box_to(root, Vector3(0.54, 0.58, 2.08), Vector3(0.30, 0.14, 0.07), Color(1.0, 0.04, 0.03), 0.0, 0.1)

    for wheel_z in [-1.28, 1.30]:
        _add_box_to(root, Vector3(-0.93, 0.26, wheel_z), Vector3(0.25, 0.54, 0.62), Color(0.015, 0.015, 0.02), 0.0, 0.45)
        _add_box_to(root, Vector3(0.93, 0.26, wheel_z), Vector3(0.25, 0.54, 0.62), Color(0.015, 0.015, 0.02), 0.0, 0.45)

    return root


func _add_lamp(x: float, z: float) -> void:
    _add_box(Vector3(x, 2.6, z), Vector3(0.10, 5.2, 0.10), Color(0.12, 0.13, 0.17), 0.65, 0.65)

    var light := OmniLight3D.new()
    light.position = Vector3(x, 5.0, z)
    light.light_color = Color(1.0, 0.75, 0.48)
    light.light_energy = 3.2
    light.omni_range = 10.0
    add_child(light)


func _add_box(position_value: Vector3, size_value: Vector3, color: Color, metallic: float, roughness: float) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size_value
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    mesh_instance.material_override = material

    add_child(mesh_instance)
    return mesh_instance


func _add_box_to(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color, metallic: float, roughness: float) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size_value
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    mesh_instance.material_override = material

    parent.add_child(mesh_instance)
    return mesh_instance


func _label(text_value: String, position_value: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = position_value
    label.add_theme_font_size_override("font_size", font_size)
    return label


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
    var t: float = clampf((value - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
