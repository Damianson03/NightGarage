extends Node3D

const GameState = preload("res://scripts/game_state.gd")

var state = GameState.new()

var player_car: Node3D
var opponent_car: Node3D
var camera: Camera3D

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
var gas_button: Button
var shift_button: Button

var result_title: Label
var result_stats: Label

var last_screen := -1


func _ready() -> void:
    # Build UI first. Even if the 3D scene has a device-specific problem,
    # the app will no longer stay on a completely black screen.
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

    player_car = _create_golf_placeholder(Color(0.78, 0.035, 0.045))
    player_car.position = Vector3(-1.70, 0.0, 0.0)
    add_child(player_car)

    opponent_car = _create_golf_placeholder(Color(0.14, 0.16, 0.20))
    opponent_car.position = Vector3(1.70, 0.0, 0.0)
    add_child(opponent_car)

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

    var version := _label(GameState.GAME_VERSION + "  •  GAMEPLAY BASE", Vector2(50, 82), 17)
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

    if state.screen == GameState.Screen.RESULT:
        _update_result_panel()


func _update_world() -> void:
    if state.screen == GameState.Screen.GARAGE:
        var orbit := Time.get_ticks_msec() / 1000.0
        camera.position = Vector3(
            sin(orbit * 0.18) * 5.2,
            2.5,
            7.5 + cos(orbit * 0.18) * 1.0
        )
        camera.look_at(Vector3(-1.70, 0.65, 0.0), Vector3.UP)
        return

    player_car.position.z = -state.player_distance
    opponent_car.position.z = -state.opponent_distance

    var blend := 0.0
    if state.screen == GameState.Screen.RACING:
        blend = _smoothstep(0.0, 1.35, state.race_time)

    var player_z := -state.player_distance

    var start_pos := Vector3(-4.2, 1.65, player_z + 6.3)
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

        if state.zero_to_100_time > 0.0:
            zero_to_100_label.text = "0-100: %.2f s" % state.zero_to_100_time
        else:
            zero_to_100_label.text = "0-100: --"

        if state.screen == GameState.Screen.COUNTDOWN:
            countdown_label.visible = true
            countdown_label.text = str(max(1, int(ceil(min(state.countdown, 3.0)))))
        else:
            countdown_label.visible = state.race_time < 0.55
            countdown_label.text = "GO"

        shift_label.text = state.shift_message if state.shift_message_time > 0.0 else ""
        shift_button.disabled = state.screen != GameState.Screen.RACING or state.shifting or state.gear >= GameState.MAX_GEARS


func _update_garage_ui() -> void:
    money_label.text = "KASA: " + state.money_text()

    stats_label.text = (
        "Volkswagen Golf VII 1.2 TSI 85 KM  •  5MT\n"
        + "Moc: %.0f KM    Masa: %.0f kg    Rating: %d\n" % [state.horsepower(), state.weight_kg(), state.rating()]
        + "Seria: 0-100 km/h 11.9 s  •  Vmax 179 km/h  •  zmiana biegu %.2f s" % state.shift_duration()
    )

    for i in range(upgrade_labels.size()):
        var level: int = state.upgrades[i]
        var cost := state.upgrade_cost(i)
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
    camera.position = Vector3(4.7, 2.5, 7.8)
    camera.look_at(Vector3(-1.70, 0.65, 0.0), Vector3.UP)


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
    _add_box(
        Vector3(x, 2.6, z),
        Vector3(0.10, 5.2, 0.10),
        Color(0.12, 0.13, 0.17),
        0.65,
        0.65
    )


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
    var t := clamp((value - edge0) / max(0.0001, edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
