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
var fps_label: Label
var rpm_bar: ProgressBar
var rpm_yellow_low_zone: ColorRect
var rpm_green_zone: ColorRect
var rpm_yellow_high_zone: ColorRect
var rpm_red_zone: ColorRect
var rpm_needle: ColorRect
var rpm_zone_label: Label
var gas_button: Button
var shift_button: Button
var race_hint: Label

var race_progress_track: ColorRect
var player_progress_marker: Label
var opponent_progress_marker: Label

var result_title: Label
var result_stats: Label

var last_screen := -1
var finish_camera_transform: Transform3D = Transform3D.IDENTITY
var finish_camera_locked := false
var camera_gap_shift_z: float = 0.0
var player_suspension_pitch_deg: float = 0.0
var player_suspension_pitch_velocity: float = 0.0
var previous_player_speed_ms: float = 0.0
var player_visual_model: Node3D
var material_cache: Dictionary = {}


func _ready() -> void:
    _build_ui()
    _build_world()
    _apply_screen()
    _update_ui()


func _process(delta: float) -> void:
    state.update(delta)

    if state.screen != last_screen:
        # Freeze the exact racing-camera view from the moment the player
        # reaches the finish. Cars will keep moving through this fixed shot.
        if state.screen == GameState.Screen.RESULT and last_screen == GameState.Screen.RACING:
            finish_camera_transform = camera.global_transform
            finish_camera_locked = true

        _apply_screen()

    _update_world(delta)
    _update_ui()


func _build_world() -> void:
    camera = Camera3D.new()
    add_child(camera)
    camera.current = true

    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.004, 0.006, 0.014)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.16, 0.20, 0.30)
    env.ambient_light_energy = 1.0
    world.environment = env
    add_child(world)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-46.0, -24.0, 0.0)
    moon.light_color = Color(0.56, 0.67, 1.0)
    moon.light_energy = 1.9
    moon.shadow_enabled = false
    add_child(moon)

    var warm_light := OmniLight3D.new()
    warm_light.position = Vector3(0.0, 4.8, -4.0)
    warm_light.light_color = Color(1.0, 0.62, 0.34)
    warm_light.light_energy = 8.0
    warm_light.omni_range = 18.0
    add_child(warm_light)

    _build_drag_strip_environment()

    player_car = _create_golf_car(Color(0.78, 0.018, 0.028))
    player_car.position = Vector3(1.70, 0.0, 0.0)
    add_child(player_car)
    _prepare_golf_runtime(player_car, Color(0.78, 0.018, 0.028), true)
    _add_car_headlights(player_car, 3.4)

    opponent_car = _create_golf_car(Color(0.16, 0.18, 0.21))
    opponent_car.position = Vector3(-1.70, 0.0, 0.0)
    add_child(opponent_car)
    _prepare_golf_runtime(opponent_car, Color(0.16, 0.18, 0.21), false)
    _add_car_headlights(opponent_car, 2.6)

    _set_garage_camera()


func _build_drag_strip_environment() -> void:
    # Mobile-optimized PBR setup. The main asphalt keeps the real diffuse,
    # normal and roughness maps, while secondary surfaces use fewer texture
    # samples. Large road slabs are split into short chunks so lights and
    # geometry can be culled locally instead of treating the whole 520 m road
    # as one giant object.
    var shoulder_material := _get_cached_pbr_material(
        "road_shoulder_mobile",
        "res://assets/pbr/road_real/asphalt_02_diff_1k.jpg",
        "",
        "",
        "",
        Vector3(2.45, 6.0, 1.0),
        Color(0.72, 0.73, 0.76),
        0.0,
        0.94,
        0.0
    )
    var road_material := _get_cached_pbr_material(
        "road_main_mobile",
        "res://assets/pbr/road_real/asphalt_02_diff_1k.jpg",
        "res://assets/pbr/road_real/asphalt_02_nor_gl_1k.png",
        "res://assets/pbr/road_real/asphalt_02_rough_1k.png",
        "",
        Vector3(3.2, 6.0, 1.0),
        Color(0.98, 0.98, 1.0),
        0.0,
        0.84,
        1.35
    )
    var lane_material := _get_cached_pbr_material(
        "road_lane_mobile",
        "res://assets/pbr/road_real/asphalt_02_diff_1k.jpg",
        "res://assets/pbr/road_real/asphalt_02_nor_gl_1k.png",
        "",
        "",
        Vector3(0.72, 6.0, 1.0),
        Color(0.72, 0.74, 0.82),
        0.02,
        0.30,
        1.15
    )
    var launch_material := _get_cached_pbr_material(
        "road_launch_mobile",
        "res://assets/pbr/road_real/asphalt_02_diff_1k.jpg",
        "res://assets/pbr/road_real/asphalt_02_nor_gl_1k.png",
        "",
        "",
        Vector3(0.78, 5.0, 1.0),
        Color(0.67, 0.69, 0.77),
        0.02,
        0.24,
        1.20
    )
    var concrete_material := _get_cached_pbr_material(
        "track_concrete_mobile",
        "res://assets/pbr/road/concrete_albedo.png",
        "res://assets/pbr/road/concrete_normal.png",
        "",
        "",
        Vector3(2.0, 8.0, 1.0),
        Color(0.92, 0.92, 0.95),
        0.0,
        0.90,
        0.75
    )

    # Foundation stays well below all visible road surfaces.
    _add_box(
        Vector3(0.0, -0.62, -250.0),
        Vector3(92.0, 0.90, 560.0),
        Color(0.018, 0.020, 0.026),
        0.0,
        0.98
    )

    # 26 x 20 m chunks. This removes the previous three full-length
    # overlapping asphalt planes and dramatically reduces light overdraw.
    for segment_index in range(26):
        var segment_z: float = 5.0 - float(segment_index) * 20.0
        _add_plane(Vector3(0.0, -0.010, segment_z), Vector2(12.6, 20.08), road_material)
        _add_plane(Vector3(-11.15, -0.035, segment_z), Vector2(9.70, 20.08), shoulder_material)
        _add_plane(Vector3(11.15, -0.035, segment_z), Vector2(9.70, 20.08), shoulder_material)

    # Separate launch and race-groove sections so they do not stack on top of
    # another glossy lane layer for the whole track.
    var lane_positions: Array[float] = [-1.70, 1.70]
    for lane_index in range(lane_positions.size()):
        var lane_x: float = lane_positions[lane_index]
        for launch_index in range(4):
            var launch_z: float = 0.0 - float(launch_index) * 18.0
            _add_plane(Vector3(lane_x, -0.004, launch_z), Vector2(2.55, 18.04), launch_material)

        for groove_index in range(18):
            var groove_z: float = -78.0 - float(groove_index) * 20.0
            _add_plane(Vector3(lane_x, -0.006, groove_z), Vector2(2.30, 20.04), lane_material)

    # Track lines.
    _add_box(
        Vector3(-5.65, 0.014, -245.0),
        Vector3(0.10, 0.018, 515.0),
        Color(0.93, 0.94, 0.96),
        0.0,
        0.48
    )
    _add_box(
        Vector3(5.65, 0.014, -245.0),
        Vector3(0.10, 0.018, 515.0),
        Color(0.93, 0.94, 0.96),
        0.0,
        0.48
    )

    for z in range(6, 408, 12):
        _add_box(
            Vector3(0.0, 0.014, -float(z)),
            Vector3(0.09, 0.018, 4.0),
            Color(0.96, 0.84, 0.26),
            0.0,
            0.44
        )

    # Tar seams and fine joints.
    var seam_positions: Array[float] = [-3.35, -1.08, 1.08, 3.35]
    for seam_index in range(seam_positions.size()):
        var seam_x: float = seam_positions[seam_index]
        _add_box(
            Vector3(seam_x, 0.001, -225.0),
            Vector3(0.08, 0.010, 470.0),
            Color(0.022, 0.022, 0.028),
            0.0,
            0.20
        )

    _add_checkered_band(-2.90, 11.6, 0.34)
    _add_checkered_band(-402.34, 11.6, 0.44)

    _add_box(Vector3(0.0, 0.020, -1.15), Vector3(11.3, 0.015, 0.10), Color(1.0, 1.0, 1.0), 0.0, 0.32)
    _add_box(Vector3(0.0, 0.020, -1.95), Vector3(11.3, 0.015, 0.10), Color(1.0, 1.0, 1.0), 0.0, 0.32)
    _add_box(Vector3(0.0, 0.020, -5.80), Vector3(11.4, 0.015, 0.10), Color(0.90, 0.90, 0.92), 0.0, 0.38)

    _add_start_tree(0.0, -3.80)
    _add_finish_gantry(-402.34)
    _build_trackside_barriers(concrete_material)
    _build_trackside_fences()
    _build_trackside_props()

    # Keep all lamp models, but only every second pair uses a real OmniLight.
    # The previous road was one 520 m mesh touched by ~40 OmniLights.
    for lamp_index in range(20):
        var lamp_z: float = -float(lamp_index) * 22.0
        var use_real_light: bool = (lamp_index % 2) == 0
        _add_lamp(-7.9, lamp_z, use_real_light)
        _add_lamp(7.9, lamp_z, use_real_light)


func _add_checkered_band(z: float, width: float, depth: float) -> void:
    var segment_width: float = width / 12.0
    for i in range(12):
        var x: float = -width * 0.5 + segment_width * (float(i) + 0.5)
        var white_first: bool = (i % 2) == 0
        _add_box(
            Vector3(x, 0.026, z),
            Vector3(segment_width - 0.02, 0.020, depth),
            Color(0.95, 0.95, 0.96) if white_first else Color(0.08, 0.08, 0.10),
            0.0,
            0.30
        )


func _add_start_tree(x: float, z: float) -> void:
    _add_box(Vector3(x, 1.78, z), Vector3(0.14, 3.25, 0.14), Color(0.14, 0.14, 0.16), 0.36, 0.52)
    _add_box(Vector3(x, 3.18, z), Vector3(0.44, 0.22, 0.18), Color(0.12, 0.12, 0.13), 0.28, 0.46)

    var light_offsets: Array[float] = [2.84, 2.44, 2.12, 1.80, 1.48, 1.16]
    var light_colors: Array[Color] = [
        Color(0.88, 0.96, 1.0),
        Color(0.88, 0.96, 1.0),
        Color(1.0, 0.72, 0.12),
        Color(1.0, 0.72, 0.12),
        Color(1.0, 0.72, 0.12),
        Color(0.18, 0.95, 0.30)
    ]

    for i in range(light_offsets.size()):
        _add_box(
            Vector3(x, light_offsets[i], z - 0.10),
            Vector3(0.26, 0.16, 0.09),
            light_colors[i],
            0.0,
            0.16
        )


func _add_finish_gantry(z: float) -> void:
    _add_box(Vector3(-6.2, 2.85, z), Vector3(0.22, 5.6, 0.22), Color(0.18, 0.18, 0.20), 0.40, 0.46)
    _add_box(Vector3(6.2, 2.85, z), Vector3(0.22, 5.6, 0.22), Color(0.18, 0.18, 0.20), 0.40, 0.46)
    _add_box(Vector3(0.0, 5.55, z), Vector3(12.9, 0.22, 0.24), Color(0.20, 0.20, 0.22), 0.38, 0.40)
    _add_box(Vector3(0.0, 4.72, z), Vector3(7.8, 1.05, 0.16), Color(0.055, 0.058, 0.066), 0.20, 0.28)

    for i in range(8):
        var x: float = -3.15 + float(i) * 0.90
        _add_box(
            Vector3(x, 4.72, z - 0.01),
            Vector3(0.76, 0.82, 0.10),
            Color(0.96, 0.96, 0.97) if (i % 2) == 0 else Color(0.10, 0.10, 0.12),
            0.0,
            0.24
        )


func _build_trackside_barriers(concrete_material: Material) -> void:
    for side in [-1.0, 1.0]:
        var x: float = side * 6.55
        _add_box_material(
            Vector3(x, 0.42, -245.0),
            Vector3(0.36, 0.82, 515.0),
            concrete_material
        )
        _add_box(
            Vector3(x, 0.86, -245.0),
            Vector3(0.38, 0.10, 515.0),
            Color(0.96, 0.18, 0.18) if side < 0.0 else Color(0.20, 0.52, 1.0),
            0.0,
            0.48
        )

        for z in range(8, 420, 20):
            _add_box(
                Vector3(x, 0.55, -float(z)),
                Vector3(0.06, 0.08, 0.42),
                Color(1.0, 0.70, 0.18),
                0.0,
                0.20
            )


func _build_trackside_fences() -> void:
    for side in [-1.0, 1.0]:
        var fence_x: float = side * 8.85
        for z in range(0, 430, 10):
            _add_box(
                Vector3(fence_x, 1.15, -float(z)),
                Vector3(0.08, 2.3, 0.08),
                Color(0.32, 0.34, 0.38),
                0.24,
                0.74
            )

        for y in [0.52, 1.12, 1.72]:
            _add_box(
                Vector3(fence_x, y, -210.0),
                Vector3(0.04, 0.04, 425.0),
                Color(0.42, 0.44, 0.48),
                0.14,
                0.80
            )


func _build_trackside_props() -> void:
    # Sponsor-style light panels and billboard blocks.
    for z in [ -36.0, -92.0, -148.0, -214.0, -286.0, -348.0 ]:
        _add_billboard(-11.9, z, Color(0.18, 0.40, 1.0), Color(0.96, 0.96, 0.98))
        _add_billboard(11.9, z - 14.0, Color(1.0, 0.26, 0.22), Color(0.96, 0.96, 0.98))

    # Industrial buildings / city silhouettes.
    var left_blocks: Array[Vector3] = [
        Vector3(-16.0, 2.1, -52.0),
        Vector3(-17.5, 3.0, -134.0),
        Vector3(-16.2, 2.5, -224.0),
        Vector3(-18.4, 3.4, -330.0)
    ]
    var left_sizes: Array[Vector3] = [
        Vector3(6.4, 4.2, 20.0),
        Vector3(8.4, 6.0, 28.0),
        Vector3(7.0, 5.0, 22.0),
        Vector3(9.2, 6.8, 32.0)
    ]
    for i in range(left_blocks.size()):
        _add_box(left_blocks[i], left_sizes[i], Color(0.050, 0.055, 0.070), 0.10, 0.88)

    var right_blocks: Array[Vector3] = [
        Vector3(16.6, 2.4, -76.0),
        Vector3(18.0, 3.3, -176.0),
        Vector3(15.8, 2.7, -274.0),
        Vector3(17.0, 3.7, -362.0)
    ]
    var right_sizes: Array[Vector3] = [
        Vector3(7.4, 4.8, 26.0),
        Vector3(8.8, 6.6, 30.0),
        Vector3(6.8, 5.4, 22.0),
        Vector3(9.6, 7.4, 34.0)
    ]
    for i in range(right_blocks.size()):
        _add_box(right_blocks[i], right_sizes[i], Color(0.045, 0.050, 0.064), 0.10, 0.90)

    # Shipping containers and utility boxes close to the strip.
    var container_colors: Array[Color] = [
        Color(0.72, 0.16, 0.12),
        Color(0.12, 0.44, 0.88),
        Color(0.78, 0.62, 0.18),
        Color(0.18, 0.56, 0.34)
    ]
    var positions: Array[Vector3] = [
        Vector3(-12.6, 0.50, -122.0),
        Vector3(-12.6, 0.50, -126.5),
        Vector3(12.8, 0.50, -242.0),
        Vector3(12.8, 0.50, -246.5)
    ]
    for i in range(positions.size()):
        _add_box(positions[i], Vector3(2.4, 1.0, 4.2), container_colors[i % container_colors.size()], 0.04, 0.88)


func _add_billboard(x: float, z: float, panel_color: Color, frame_color: Color) -> void:
    _add_box(Vector3(x, 1.8, z), Vector3(0.18, 3.6, 0.18), Color(0.18, 0.18, 0.20), 0.34, 0.56)
    _add_box(Vector3(x, 3.95, z), Vector3(4.4, 2.2, 0.18), frame_color, 0.04, 0.40)
    _add_box(Vector3(x, 3.95, z - 0.02), Vector3(4.0, 1.8, 0.08), panel_color, 0.20, 0.18)


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

    var version := _label(GameState.GAME_VERSION + "  •  SUSPENSION + LAUNCH LIFT", Vector2(50, 82), 17)
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

    # Full 1/4-mile progress strip. Both markers are separated vertically,
    # so they remain readable even when the cars are side by side.
    var progress_back := ColorRect.new()
    progress_back.color = Color(0.015, 0.020, 0.035, 0.78)
    progress_back.position = Vector2(244.0, 4.0)
    progress_back.size = Vector2(792.0, 42.0)
    progress_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(progress_back)

    race_progress_track = ColorRect.new()
    race_progress_track.color = Color(0.72, 0.76, 0.84, 0.72)
    race_progress_track.position = Vector2(280.0, 21.0)
    race_progress_track.size = Vector2(720.0, 5.0)
    race_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(race_progress_track)

    var start_cap := ColorRect.new()
    start_cap.color = Color(0.92, 0.94, 1.0, 0.92)
    start_cap.position = Vector2(278.0, 14.0)
    start_cap.size = Vector2(4.0, 19.0)
    start_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(start_cap)

    var finish_cap := ColorRect.new()
    finish_cap.color = Color(0.92, 0.94, 1.0, 0.92)
    finish_cap.position = Vector2(998.0, 14.0)
    finish_cap.size = Vector2(4.0, 19.0)
    finish_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(finish_cap)

    var start_text := _label("START", Vector2(224.0, 12.0), 13)
    start_text.size = Vector2(54.0, 22.0)
    start_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    start_text.modulate = Color(0.72, 0.75, 0.82)
    race_panel.add_child(start_text)

    var finish_text := _label("META", Vector2(1008.0, 12.0), 13)
    finish_text.size = Vector2(48.0, 22.0)
    finish_text.modulate = Color(0.72, 0.75, 0.82)
    race_panel.add_child(finish_text)

    player_progress_marker = _label("TY▼", Vector2(262.0, -2.0), 14)
    player_progress_marker.size = Vector2(42.0, 22.0)
    player_progress_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_progress_marker.modulate = Color(1.0, 0.28, 0.24)
    race_panel.add_child(player_progress_marker)

    opponent_progress_marker = _label("R▲", Vector2(266.0, 25.0), 14)
    opponent_progress_marker.size = Vector2(34.0, 20.0)
    opponent_progress_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent_progress_marker.modulate = Color(0.30, 0.78, 1.0)
    race_panel.add_child(opponent_progress_marker)

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

    fps_label = _label("FPS: --", Vector2(1110, 142), 17)
    fps_label.modulate = Color(0.72, 0.86, 0.72)
    race_panel.add_child(fps_label)

    rpm_bar = ProgressBar.new()
    rpm_bar.position = Vector2(310, 625)
    rpm_bar.size = Vector2(610, 32)
    rpm_bar.min_value = 0.0
    rpm_bar.max_value = 6200.0
    rpm_bar.show_percentage = false
    race_panel.add_child(rpm_bar)

    rpm_bar.modulate = Color(0.62, 0.72, 1.0, 0.42)

    rpm_yellow_low_zone = ColorRect.new()
    rpm_yellow_low_zone.color = Color(1.0, 0.72, 0.04, 0.70)
    rpm_yellow_low_zone.position = Vector2(310.0, 625.0)
    rpm_yellow_low_zone.size = Vector2(10.0, 32.0)
    rpm_yellow_low_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(rpm_yellow_low_zone)

    rpm_green_zone = ColorRect.new()
    rpm_green_zone.color = Color(0.08, 0.95, 0.22, 0.78)
    rpm_green_zone.position = Vector2(310.0, 625.0)
    rpm_green_zone.size = Vector2(10.0, 32.0)
    rpm_green_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(rpm_green_zone)

    rpm_yellow_high_zone = ColorRect.new()
    rpm_yellow_high_zone.color = Color(1.0, 0.72, 0.04, 0.70)
    rpm_yellow_high_zone.position = Vector2(310.0, 625.0)
    rpm_yellow_high_zone.size = Vector2(10.0, 32.0)
    rpm_yellow_high_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_panel.add_child(rpm_yellow_high_zone)

    rpm_red_zone = ColorRect.new()
    rpm_red_zone.color = Color(1.0, 0.08, 0.06, 0.74)
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
    gas_button.position = Vector2(1060, 350)
    gas_button.size = Vector2(170, 130)
    gas_button.button_down.connect(_gas_down)
    gas_button.button_up.connect(_gas_up)
    race_panel.add_child(gas_button)

    shift_button = Button.new()
    shift_button.text = "SHIFT"
    shift_button.position = Vector2(1060, 535)
    shift_button.size = Vector2(170, 140)
    shift_button.pressed.connect(_shift_pressed)
    race_panel.add_child(shift_button)

    race_hint = _label("Naciśnij GAS, aby rozpocząć odliczanie.", Vector2(34, 675), 15)
    race_hint.modulate = Color(0.72, 0.75, 0.82)
    race_panel.add_child(race_hint)

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
        player_car.position = Vector3(1.70, 0.0, 0.0)
        opponent_car.position = Vector3(-1.70, 0.0, 0.0)
        last_player_wheel_distance = 0.0
        last_opponent_wheel_distance = 0.0
        finish_camera_locked = false
        camera_gap_shift_z = 0.0
        player_suspension_pitch_deg = 0.0
        player_suspension_pitch_velocity = 0.0
        previous_player_speed_ms = 0.0
        _apply_player_suspension_pose()

    if state.screen == GameState.Screen.RACING:
        state.set_gas(false)

    if state.screen == GameState.Screen.RESULT:
        _update_result_panel()


func _update_world(delta: float) -> void:
    _update_wheel_animation()

    if state.screen == GameState.Screen.GARAGE:
        camera_gap_shift_z = 0.0
        player_suspension_pitch_deg = 0.0
        player_suspension_pitch_velocity = 0.0
        previous_player_speed_ms = 0.0
        _apply_player_suspension_pose()
        var orbit: float = float(Time.get_ticks_msec()) / 1000.0
        camera.position = Vector3(
            5.35 + sin(orbit * 0.16) * 0.75,
            2.15,
            -6.25 + cos(orbit * 0.16) * 0.85
        )
        camera.look_at(Vector3(1.70, 0.76, 0.0), Vector3.UP)
        return

    player_car.position.z = -state.player_distance
    opponent_car.position.z = -state.opponent_distance
    _update_player_suspension(delta)

    # Once the player crosses the finish, the camera stays fixed there while
    # the cars continue driving out of frame behind the results overlay.
    if state.screen == GameState.Screen.RESULT:
        if finish_camera_locked:
            camera.global_transform = finish_camera_transform
        else:
            camera.position = Vector3(8.15, 1.88, -GameState.RACE_DISTANCE_M + 2.65)
            camera.look_at(
                Vector3(0.20, 0.76, -GameState.RACE_DISTANCE_M - 12.0),
                Vector3.UP
            )
        return

    var blend: float = 0.0
    if state.screen == GameState.Screen.RACING:
        blend = _smoothstep(0.0, 1.55, state.race_time)

    var player_z: float = -float(state.player_distance)

    # Positive gap = rival is ahead. Negative gap = player is ahead.
    # The camera itself stays anchored to the player's Golf. Only the aiming
    # direction changes, so the player's whole car remains visible.
    var gap_m: float = float(state.opponent_distance - state.player_distance)
    var visible_gap_m: float = clampf(gap_m, -12.0, 12.0)
    var desired_aim_shift_z: float = -visible_gap_m * 0.38

    # Smooth angular response instead of snapping toward the rival.
    var camera_response: float = clampf(delta * 3.8, 0.0, 1.0)
    camera_gap_shift_z = lerpf(
        camera_gap_shift_z,
        desired_aim_shift_z,
        camera_response
    )

    # CSR-style opening shot: camera is in front of the player and on the
    # player's right side, so we see the front and right flank of the Golf.
    var start_pos: Vector3 = Vector3(6.35, 1.48, player_z - 6.35)

    # Race camera remains locked to the player's car. Do not move it forward
    # or backward because of the race gap; that could push the player out of
    # the frame. Rival tracking is handled by the look-at target below.
    var side_pos: Vector3 = Vector3(
        8.15,
        1.88,
        player_z + 2.65
    )
    var cam_pos: Vector3 = start_pos.lerp(side_pos, blend)

    var start_target: Vector3 = Vector3(1.70, 0.74, player_z - 0.35)

    # Look across the lanes toward the rival. Longitudinal aim is symmetric:
    # losing -> clearly look forward, winning -> clearly look backward.
    # Around an even race the camera points only slightly ahead.
    var rival_bias_x: float = lerpf(1.70, -1.70, 0.52)
    var side_target: Vector3 = Vector3(
        rival_bias_x,
        0.76,
        player_z - 1.35 + camera_gap_shift_z
    )
    var target: Vector3 = start_target.lerp(side_target, blend)

    camera.position = cam_pos
    camera.look_at(target, Vector3.UP)


func _update_player_suspension(delta: float) -> void:
    if player_visual_model == null:
        return

    var current_speed_ms: float = float(state.speed_kmh) / 3.6
    var safe_delta: float = maxf(delta, 0.001)
    var longitudinal_accel: float = (current_speed_ms - previous_player_speed_ms) / safe_delta
    previous_player_speed_ms = current_speed_ms

    var target_pitch_deg: float = 0.0

    if state.screen == GameState.Screen.COUNTDOWN:
        # While staging, revving toward the green launch zone lightly loads the
        # rear suspension and raises the nose. The strongest preload is inside
        # the green zone, then it eases slightly if the engine is over-revved.
        if state.gas_held:
            var green_low: float = float(state.launch_green_low())
            var green_high: float = float(state.launch_green_high())
            var red_start: float = float(state.launch_red_start())
            var launch_rpm: float = float(state.rpm)

            if launch_rpm < green_low:
                var approach: float = clampf(
                    (launch_rpm - GameState.IDLE_RPM) / maxf(1.0, green_low - GameState.IDLE_RPM),
                    0.0,
                    1.0
                )
                target_pitch_deg = lerpf(0.0, -0.38, approach)
            elif launch_rpm <= green_high:
                target_pitch_deg = -0.52
            else:
                var over_rev: float = clampf(
                    (launch_rpm - green_high) / maxf(1.0, red_start - green_high),
                    0.0,
                    1.0
                )
                target_pitch_deg = lerpf(-0.52, -0.30, over_rev)

    elif state.screen == GameState.Screen.RACING and not state.player_finished:
        if state.shifting:
            # During the torque interruption the body settles back toward level.
            target_pitch_deg = 0.0
        else:
            # The imported Golf is rotated 180 degrees around Y, so NEGATIVE X
            # pitch raises its front and lowers the rear in world view.
            var positive_accel: float = maxf(0.0, longitudinal_accel)
            target_pitch_deg = clampf(-positive_accel * 0.26, -1.35, 0.0)

            # Keep a visible but subtle rear squat during the hard launch phase,
            # even if frame-to-frame acceleration becomes noisy.
            if state.race_time < 1.1 and state.speed_kmh > 3.0:
                target_pitch_deg = minf(target_pitch_deg, -0.72)

    # Spring-damper response: fast enough to read during a gear change, but not
    # so fast that the body snaps between poses.
    var spring_strength: float = 72.0
    var damping: float = 15.5

    if state.shifting:
        spring_strength = 105.0
        damping = 18.5
    elif state.screen == GameState.Screen.COUNTDOWN:
        spring_strength = 58.0
        damping = 14.0

    var spring_accel: float = (
        (target_pitch_deg - player_suspension_pitch_deg) * spring_strength
        - player_suspension_pitch_velocity * damping
    )

    player_suspension_pitch_velocity += spring_accel * safe_delta
    player_suspension_pitch_deg += player_suspension_pitch_velocity * safe_delta
    player_suspension_pitch_deg = clampf(player_suspension_pitch_deg, -1.45, 0.18)

    _apply_player_suspension_pose()


func _apply_player_suspension_pose() -> void:
    if player_visual_model == null:
        return

    player_visual_model.rotation_degrees = Vector3(
        player_suspension_pitch_deg,
        180.0,
        0.0
    )

    # Tiny vertical compensation keeps the body visually planted while pitching.
    player_visual_model.position.y = 0.055 - absf(player_suspension_pitch_deg) * 0.0035


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
        fps_label.text = "FPS: %d" % int(Engine.get_frames_per_second())
        rpm_bar.value = state.rpm
        _update_race_progress()
        _update_rpm_zones()

        if state.zero_to_100_time > 0.0:
            zero_to_100_label.text = "0-100: %.2f s" % state.zero_to_100_time
        else:
            zero_to_100_label.text = "0-100: --"

        var is_countdown: bool = state.screen == GameState.Screen.COUNTDOWN
        gas_button.visible = is_countdown
        shift_button.visible = not is_countdown
        race_hint.visible = is_countdown

        if is_countdown:
            countdown_label.visible = true

            if state.countdown_started:
                countdown_label.text = str(maxi(1, int(ceil(minf(float(state.countdown), 3.0)))))
                race_hint.text = "Odliczanie trwa. ŻÓŁTA 0%  •  ZIELONA +1%  •  CZERWONA -1%"
            else:
                countdown_label.text = "GAS"
                race_hint.text = "Naciśnij GAS, aby rozpocząć 3-2-1. Pierwszego odliczania nie da się zatrzymać."
        else:
            countdown_label.visible = state.race_time < 0.55
            countdown_label.text = "GO"

        shift_label.text = state.shift_message if state.shift_message_time > 0.0 else ""
        shift_button.disabled = (
            state.screen != GameState.Screen.RACING
            or state.race_time < 0.45
            or state.shifting
            or state.gear >= GameState.MAX_GEARS
        )


func _update_race_progress() -> void:
    if player_progress_marker == null or opponent_progress_marker == null:
        return

    var track_x: float = 280.0
    var track_width: float = 720.0
    var race_distance: float = float(GameState.RACE_DISTANCE_M)

    var player_ratio: float = clampf(
        float(state.player_distance) / race_distance,
        0.0,
        1.0
    )
    var opponent_ratio: float = clampf(
        float(state.opponent_distance) / race_distance,
        0.0,
        1.0
    )

    var player_x: float = track_x + track_width * player_ratio
    var opponent_x: float = track_x + track_width * opponent_ratio

    # Separate rows mean both markers remain visible in a dead heat.
    player_progress_marker.position = Vector2(player_x - 21.0, -2.0)
    opponent_progress_marker.position = Vector2(opponent_x - 17.0, 25.0)


func _update_rpm_zones() -> void:
    if (
        rpm_yellow_low_zone == null
        or rpm_green_zone == null
        or rpm_yellow_high_zone == null
        or rpm_red_zone == null
        or rpm_needle == null
        or rpm_zone_label == null
    ):
        return

    var meter_x: float = 310.0
    var meter_y: float = 625.0
    var meter_width: float = 610.0
    var meter_height: float = 32.0
    var meter_max_rpm: float = float(rpm_bar.max_value)
    var zone_low: float = 0.0
    var zone_high: float = 0.0
    var red_from: float = 0.0

    if state.screen == GameState.Screen.COUNTDOWN:
        zone_low = float(state.launch_green_low())
        zone_high = float(state.launch_green_high())
        red_from = float(state.launch_red_start())
    else:
        zone_low = float(state.green_low())
        zone_high = float(state.green_high())
        red_from = float(state.red_start())

    zone_low = clampf(zone_low, 0.0, meter_max_rpm)
    zone_high = clampf(zone_high, zone_low, meter_max_rpm)
    red_from = clampf(red_from, zone_high, meter_max_rpm)

    var green_start_ratio: float = zone_low / meter_max_rpm
    var green_end_ratio: float = zone_high / meter_max_rpm
    var red_start_ratio: float = red_from / meter_max_rpm

    var green_x: float = meter_x + meter_width * green_start_ratio
    var green_end_x: float = meter_x + meter_width * green_end_ratio
    var red_x: float = meter_x + meter_width * red_start_ratio
    var meter_end_x: float = meter_x + meter_width

    rpm_yellow_low_zone.position = Vector2(meter_x, meter_y)
    rpm_yellow_low_zone.size = Vector2(maxf(4.0, green_x - meter_x), meter_height)

    rpm_green_zone.position = Vector2(green_x, meter_y)
    rpm_green_zone.size = Vector2(maxf(4.0, green_end_x - green_x), meter_height)

    rpm_yellow_high_zone.position = Vector2(green_end_x, meter_y)
    rpm_yellow_high_zone.size = Vector2(maxf(4.0, red_x - green_end_x), meter_height)

    rpm_red_zone.position = Vector2(red_x, meter_y)
    rpm_red_zone.size = Vector2(maxf(4.0, meter_end_x - red_x), meter_height)

    var rpm_ratio: float = clampf(float(state.rpm) / meter_max_rpm, 0.0, 1.0)
    var needle_x: float = meter_x + meter_width * rpm_ratio
    rpm_needle.position = Vector2(needle_x - 2.5, meter_y - 5.0)

    rpm_zone_label.text = "ŻÓŁTA 0%   •   ZIELONA +1%   •   ŻÓŁTA 0%   •   CZERWONA -1%"

    if state.rpm >= zone_low and state.rpm <= zone_high:
        rpm_label.modulate = Color(0.20, 1.0, 0.28)
    elif state.rpm >= red_from:
        rpm_label.modulate = Color(1.0, 0.18, 0.12)
    else:
        rpm_label.modulate = Color(1.0, 0.82, 0.16)


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
    # Prevent the touch that was holding GAS at launch from immediately
    # becoming a SHIFT press when the controls swap on screen.
    if state.screen != GameState.Screen.RACING or state.race_time < 0.45:
        return

    state.shift()


func _set_garage_camera() -> void:
    camera.position = Vector3(5.35, 2.15, -6.25)
    camera.look_at(Vector3(1.70, 0.76, 0.0), Vector3.UP)


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

    if is_player:
        player_visual_model = model

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


func _add_lamp(x: float, z: float, use_real_light: bool) -> void:
    _add_box(Vector3(x, 2.7, z), Vector3(0.12, 5.4, 0.12), Color(0.14, 0.15, 0.18), 0.42, 0.56)
    _add_box(Vector3(x, 5.28, z - 0.56), Vector3(0.64, 0.10, 1.16), Color(0.16, 0.16, 0.18), 0.34, 0.52)
    _add_box(Vector3(x, 5.10, z - 1.10), Vector3(0.34, 0.14, 0.34), Color(1.0, 0.78, 0.48), 0.0, 0.20)

    if not use_real_light:
        return

    var light := OmniLight3D.new()
    light.position = Vector3(x, 5.0, z - 1.00)
    light.light_color = Color(1.0, 0.76, 0.46)
    light.light_energy = 4.0
    light.omni_range = 13.5
    light.shadow_enabled = false
    add_child(light)


func _get_cached_pbr_material(
    cache_key: String,
    albedo_path: String,
    normal_path: String,
    roughness_path: String,
    ao_path: String,
    uv_scale: Vector3,
    tint: Color,
    metallic: float,
    roughness_value: float,
    normal_strength: float
) -> StandardMaterial3D:
    if material_cache.has(cache_key):
        return material_cache[cache_key] as StandardMaterial3D

    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = metallic
    material.roughness = roughness_value
    material.uv1_scale = uv_scale
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    material.texture_repeat = true

    if ResourceLoader.exists(albedo_path):
        material.albedo_texture = load(albedo_path)
    if ResourceLoader.exists(normal_path):
        material.normal_enabled = true
        material.normal_texture = load(normal_path)
        material.normal_scale = normal_strength
    if ResourceLoader.exists(roughness_path):
        material.roughness_texture = load(roughness_path)
    if ao_path != "" and ResourceLoader.exists(ao_path):
        material.ao_enabled = true
        material.ao_texture = load(ao_path)
        material.ao_light_affect = 0.6

    material_cache[cache_key] = material
    return material


func _add_plane(position_value: Vector3, size_value: Vector2, material: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = size_value
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance


func _add_box_material(position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size_value
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance


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
