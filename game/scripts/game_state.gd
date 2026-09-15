extends RefCounted

const GAME_VERSION := "v0.4.3"
const SAVE_PATH := "user://night_garage_save.cfg"

# Volkswagen Golf VII 1.2 TSI 85 PS / 5MT baseline.
const BASE_HP := 85.0
const BASE_WEIGHT_KG := 1205.0
const BASE_TOP_SPEED_KMH := 179.0
const TARGET_ZERO_TO_100 := 11.9

const IDLE_RPM := 950.0
const REV_LIMIT_RPM := 6000.0
const SHIFT_GREEN_LOW := 5150.0
const SHIFT_GREEN_HIGH := 5450.0
const SHIFT_RED_START := 5750.0
const GREEN_POWER_MULTIPLIER := 1.01
const RED_POWER_MULTIPLIER := 0.99

const FINAL_DRIVE := 4.06
const WHEEL_RADIUS_M := 0.31725
const DRIVETRAIN_EFFICIENCY := 0.884
const AIR_DENSITY := 1.225
const CDA := 0.63215
const ROLLING_RESISTANCE := 0.012
const GRAVITY := 9.81
const FIRST_GEAR_TRACTION := 0.56
const SECOND_GEAR_TRACTION := 0.32
const RACE_DISTANCE_M := 402.336
const POST_FINISH_DRIVE_SECONDS := 4.0

const GEAR_RATIOS: Array[float] = [3.77, 1.96, 1.28, 0.88, 0.67]
const MAX_GEARS := 5

const UPGRADE_NAMES := [
    "SILNIK",
    "TURBO",
    "SKRZYNIA",
    "ECU",
    "OPONY",
    "MASA"
]

const UPGRADE_BASE_COST: Array[int] = [22000, 28000, 18000, 16000, 14000, 17000]

enum Screen {
    GARAGE,
    COUNTDOWN,
    RACING,
    RESULT
}

enum Mode {
    CAREER,
    CASH_RUN
}

var screen: int = Screen.GARAGE
var mode: int = Mode.CASH_RUN

var money: int = 1_000_000
var career_stage: int = 1
var wins: int = 0
var upgrades: Array[int] = [0, 0, 0, 0, 0, 0]

var gas_held := false
var countdown_started := false
var rpm := IDLE_RPM
var gear := 1
var speed_kmh := 0.0
var player_distance := 0.0
var opponent_distance := 0.0
var race_time := 0.0
var countdown := 3.2
var launch_quality := 0.0
var launch_penalty := 0.0
var launch_rpm_at_go := 4550.0
var timing_power_multiplier := 1.0

var shift_message := ""
var shift_message_time := 0.0
var shifting := false
var pending_gear := 1
var shift_timer := 0.0
var active_shift_duration := 0.0
var shift_start_rpm := IDLE_RPM

var player_finished := false
var opponent_finished := false
var player_finish_time := 0.0
var opponent_finish_time := 0.0
var post_finish_drive_time := 0.0
var zero_to_100_time := -1.0
var max_speed_seen := 0.0

var last_win := false
var last_reward := 0

var opponent_speed_kmh := 0.0
var opponent_performance := 1.0
var opponent_max_speed := BASE_TOP_SPEED_KMH


func _init() -> void:
    load_save()


func load_save() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return

    money = int(cfg.get_value("player", "money", money))
    career_stage = int(cfg.get_value("player", "career_stage", career_stage))
    wins = int(cfg.get_value("player", "wins", wins))

    for i in range(upgrades.size()):
        upgrades[i] = int(cfg.get_value("upgrades", "level_%d" % i, upgrades[i]))


func save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("player", "money", money)
    cfg.set_value("player", "career_stage", career_stage)
    cfg.set_value("player", "wins", wins)

    for i in range(upgrades.size()):
        cfg.set_value("upgrades", "level_%d" % i, upgrades[i])

    cfg.save(SAVE_PATH)


func horsepower() -> float:
    return (
        BASE_HP
        + float(upgrades[0]) * 5.0
        + float(upgrades[1]) * 10.0
        + float(upgrades[3]) * 2.0
    )


func weight_kg() -> float:
    return BASE_WEIGHT_KG - float(upgrades[5]) * 25.0


func shift_duration() -> float:
    return maxf(0.35, 0.60 - float(upgrades[2]) * 0.05)


func tire_grip_multiplier() -> float:
    return 1.0 + float(upgrades[4]) * 0.05


func rating() -> int:
    var hp_gain := horsepower() - BASE_HP
    var weight_gain := BASE_WEIGHT_KG - weight_kg()

    return int(round(
        250.0
        + hp_gain * 3.0
        + weight_gain * 0.40
        + float(upgrades[2]) * 18.0
        + float(upgrades[4]) * 14.0
    ))


func upgrade_cost(index: int) -> int:
    if index < 0 or index >= upgrades.size():
        return 0
    if upgrades[index] >= 5:
        return 0

    var level: int = int(upgrades[index])
    return UPGRADE_BASE_COST[index] * (level + 1) * (level + 1)


func buy_upgrade(index: int) -> bool:
    if index < 0 or index >= upgrades.size():
        return false
    if upgrades[index] >= 5:
        return false

    var cost := upgrade_cost(index)
    if money < cost:
        return false

    money -= cost
    upgrades[index] += 1
    save()
    return true


func reset_upgrades() -> void:
    upgrades = [0, 0, 0, 0, 0, 0]
    save()


func add_dev_cash() -> void:
    money += 500_000
    save()


func start_race(selected_mode: int) -> void:
    mode = selected_mode
    screen = Screen.COUNTDOWN

    gas_held = false
    countdown_started = false
    rpm = IDLE_RPM
    gear = 1
    pending_gear = 1
    speed_kmh = 0.0
    player_distance = 0.0
    opponent_distance = 0.0
    race_time = 0.0
    countdown = 3.2
    launch_quality = 0.0
    launch_penalty = 0.0
    launch_rpm_at_go = 4550.0
    timing_power_multiplier = 1.0

    shift_message = ""
    shift_message_time = 0.0
    shifting = false
    shift_timer = 0.0
    active_shift_duration = 0.0
    shift_start_rpm = IDLE_RPM

    player_finished = false
    opponent_finished = false
    player_finish_time = 0.0
    opponent_finish_time = 0.0
    post_finish_drive_time = 0.0
    zero_to_100_time = -1.0
    max_speed_seen = 0.0
    last_reward = 0

    opponent_speed_kmh = 0.0

    var player_perf := performance_index()

    if mode == Mode.CAREER:
        opponent_performance = 0.95 + float(maxi(0, career_stage - 1)) * 0.045
    else:
        opponent_performance = player_perf * randf_range(0.96, 1.04)

    opponent_max_speed = BASE_TOP_SPEED_KMH * pow(opponent_performance, 0.34)


func go_garage() -> void:
    gas_held = false
    screen = Screen.GARAGE


func set_gas(held: bool) -> void:
    gas_held = held

    if held and screen == Screen.COUNTDOWN and not countdown_started:
        countdown_started = true


func green_low() -> float:
    return SHIFT_GREEN_LOW


func green_high() -> float:
    return SHIFT_GREEN_HIGH


func red_start() -> float:
    return SHIFT_RED_START


func launch_green_low() -> float:
    return 4050.0 - float(upgrades[4]) * 35.0


func launch_green_high() -> float:
    return 5050.0 + float(upgrades[4]) * 55.0


func launch_red_start() -> float:
    return minf(REV_LIMIT_RPM, launch_green_high() + 600.0)


func shift() -> void:
    if screen != Screen.RACING:
        return
    if player_finished or shifting or gear >= MAX_GEARS:
        return

    if rpm >= SHIFT_GREEN_LOW and rpm <= SHIFT_GREEN_HIGH:
        timing_power_multiplier = GREEN_POWER_MULTIPLIER
        shift_message = "ZIELONY SHIFT  +1% MOCY"
    elif rpm >= SHIFT_RED_START:
        timing_power_multiplier = RED_POWER_MULTIPLIER
        shift_message = "CZERWONY SHIFT  -1% MOCY"
    else:
        timing_power_multiplier = 1.0
        shift_message = "ŻÓŁTY SHIFT"

    shift_message_time = 0.8
    shifting = true
    pending_gear = gear + 1
    active_shift_duration = shift_duration()
    shift_timer = active_shift_duration
    shift_start_rpm = rpm


func update(delta: float) -> void:
    var dt: float = minf(delta, 0.05)

    if shift_message_time > 0.0:
        shift_message_time -= dt

    if screen == Screen.COUNTDOWN:
        _update_countdown(dt)
        return

    # The result overlay is allowed to appear while both cars keep rolling
    # beyond the finish line. After a few seconds they are already outside
    # the frozen finish-line camera, so the simulation can stop safely.
    if screen == Screen.RESULT:
        _update_post_finish_drive(dt)
        return

    if screen != Screen.RACING:
        return

    race_time += dt

    # Both cars keep moving even after one of them has crossed the line.
    # This is especially important when the rival wins first: the player
    # still gets to complete the full 1/4 mile instead of ending instantly.
    _update_player_physics(dt)
    _update_opponent(dt)

    # The result is shown only when the PLAYER reaches the finish line.
    # If the rival arrived earlier this becomes a loss; if the rival has not
    # finished yet, the player has already secured the win.
    if player_finished:
        _finish_race()


func _update_post_finish_drive(dt: float) -> void:
    if post_finish_drive_time >= POST_FINISH_DRIVE_SECONDS:
        return

    post_finish_drive_time += dt
    race_time += dt

    _update_player_physics(dt)
    _update_opponent(dt)


func _update_countdown(dt: float) -> void:
    var rise_rate := 3600.0
    var fall_rate := 1080.0

    if gas_held:
        rpm += rise_rate * dt
    else:
        rpm -= fall_rate * dt

    rpm = clampf(rpm, IDLE_RPM, REV_LIMIT_RPM + 140.0)

    # The first GAS press starts the countdown permanently. Releasing GAS
    # can still lower RPM, but it never pauses or resets 3-2-1.
    if not countdown_started:
        return

    countdown -= dt

    if countdown > 0.0:
        return

    var lo: float = launch_green_low()
    var hi: float = launch_green_high()
    var red_from: float = launch_red_start()

    launch_rpm_at_go = rpm
    launch_penalty = 0.0

    if rpm >= lo and rpm <= hi:
        launch_quality = 1.0
        timing_power_multiplier = GREEN_POWER_MULTIPLIER
        shift_message = "ZIELONY START  +1% MOCY"
    elif rpm >= red_from:
        launch_quality = 0.0
        timing_power_multiplier = RED_POWER_MULTIPLIER
        shift_message = "CZERWONY START  -1% MOCY"
    else:
        launch_quality = 0.5
        timing_power_multiplier = 1.0
        shift_message = "ŻÓŁTY START"

    shift_message_time = 1.0
    screen = Screen.RACING


func _update_player_physics(dt: float) -> void:
    var mass := weight_kg()
    var speed_ms := speed_kmh / 3.6
    var drive_force := 0.0

    if shifting:
        shift_timer -= dt

        var progress := 1.0
        if active_shift_duration > 0.0:
            progress = clampf(1.0 - shift_timer / active_shift_duration, 0.0, 1.0)

        var target_rpm: float = maxf(IDLE_RPM, rpm_from_speed(speed_kmh, pending_gear))
        var smooth := progress * progress * (3.0 - 2.0 * progress)
        rpm = lerpf(shift_start_rpm, target_rpm, smooth)

        if shift_timer <= 0.0:
            gear = pending_gear
            shifting = false
            rpm = maxf(IDLE_RPM, rpm_from_speed(speed_kmh, gear))
    else:
        rpm = calculate_engine_rpm()

        var torque := engine_torque_nm(rpm)
        torque *= (horsepower() / BASE_HP) * timing_power_multiplier

        drive_force = (
            torque
            * GEAR_RATIOS[gear - 1]
            * FINAL_DRIVE
            * DRIVETRAIN_EFFICIENCY
            / WHEEL_RADIUS_M
        )

        var grip := tire_grip_multiplier()

        if gear == 1:
            var traction_limit := mass * GRAVITY * FIRST_GEAR_TRACTION * grip
            drive_force = minf(drive_force, traction_limit)
        elif gear == 2:
            var traction_limit := mass * GRAVITY * SECOND_GEAR_TRACTION * grip
            drive_force = minf(drive_force, traction_limit)

        var launch_fade: float = maxf(0.0, 1.0 - race_time / 2.2)
        drive_force *= maxf(0.70, 1.0 - launch_penalty * launch_fade)

        if rpm >= REV_LIMIT_RPM:
            drive_force *= 0.08
            rpm = REV_LIMIT_RPM - 70.0 + sin(race_time * 32.0) * 45.0

    var aero_force := 0.5 * AIR_DENSITY * CDA * speed_ms * speed_ms
    var rolling_force := ROLLING_RESISTANCE * mass * GRAVITY
    var net_force := drive_force - aero_force - rolling_force
    var accel_ms2 := net_force / mass

    speed_ms += accel_ms2 * dt
    speed_ms = maxf(0.0, speed_ms)
    speed_kmh = speed_ms * 3.6

    if not shifting:
        rpm = calculate_engine_rpm()

    player_distance += speed_ms * dt
    max_speed_seen = maxf(max_speed_seen, speed_kmh)

    if zero_to_100_time < 0.0 and speed_kmh >= 100.0:
        zero_to_100_time = race_time

    if not player_finished and player_distance >= RACE_DISTANCE_M:
        player_finished = true
        player_finish_time = race_time


func calculate_engine_rpm() -> float:
    var coupled_rpm: float = maxf(IDLE_RPM, rpm_from_speed(speed_kmh, gear))

    if gear == 1 and race_time < 0.90:
        var coupling: float = clampf(race_time / 0.90, 0.0, 1.0)
        var slipping_rpm := lerpf(launch_rpm_at_go, 1400.0, coupling)
        return maxf(coupled_rpm, slipping_rpm)

    return coupled_rpm


func rpm_from_speed(kmh: float, selected_gear: int) -> float:
    var index := clampi(selected_gear - 1, 0, MAX_GEARS - 1)
    var speed_ms := kmh / 3.6
    var wheel_rps := speed_ms / (2.0 * PI * WHEEL_RADIUS_M)

    return wheel_rps * 60.0 * GEAR_RATIOS[index] * FINAL_DRIVE


func engine_torque_nm(engine_rpm: float) -> float:
    var r: float = maxf(700.0, engine_rpm)

    if r < 800.0:
        return 70.0
    if r < 1400.0:
        return lerpf(90.0, 160.0, (r - 800.0) / 600.0)
    if r <= 3500.0:
        return 160.0
    if r <= 4300.0:
        return lerpf(160.0, 139.0, (r - 3500.0) / 800.0)
    if r <= 5300.0:
        return lerpf(139.0, 113.0, (r - 4300.0) / 1000.0)
    if r <= 6000.0:
        return lerpf(113.0, 80.0, (r - 5300.0) / 700.0)

    return 75.0


func performance_index() -> float:
    var power_part := horsepower() / BASE_HP
    var weight_part := pow(BASE_WEIGHT_KG / weight_kg(), 0.65)
    var gearbox_part := 1.0 + float(upgrades[2]) * 0.025
    var tires_part := 1.0 + float(upgrades[4]) * 0.015

    return power_part * weight_part * gearbox_part * tires_part


func _update_opponent(dt: float) -> void:
    var speed_ratio := 0.0
    if opponent_max_speed > 1.0:
        speed_ratio = opponent_speed_kmh / opponent_max_speed

    var aero_fade: float = maxf(0.18, 1.0 - speed_ratio * speed_ratio * 0.82)
    var accel_kmh_per_sec := 9.3 * opponent_performance * aero_fade

    if race_time < 0.25:
        accel_kmh_per_sec *= 0.75

    opponent_speed_kmh += accel_kmh_per_sec * dt
    opponent_speed_kmh = minf(opponent_speed_kmh, opponent_max_speed)
    opponent_distance += (opponent_speed_kmh / 3.6) * dt

    if not opponent_finished and opponent_distance >= RACE_DISTANCE_M:
        opponent_finished = true
        opponent_finish_time = race_time


func _finish_race() -> void:
    if screen == Screen.RESULT or not player_finished:
        return

    # If the opponent already crossed, compare the recorded finish times.
    # Otherwise the player is first across the line and has won immediately.
    if opponent_finished:
        last_win = player_finish_time <= opponent_finish_time
    else:
        last_win = true

    if last_win:
        wins += 1

        if mode == Mode.CAREER:
            last_reward = 150_000 + career_stage * 45_000
            career_stage += 1
        else:
            last_reward = 120_000 + rating() * 180
    else:
        last_reward = 20_000

    money += last_reward
    save()
    post_finish_drive_time = 0.0
    screen = Screen.RESULT


func money_text() -> String:
    return "%d $" % money


func mode_name() -> String:
    return "CAREER" if mode == Mode.CAREER else "CASH RUN"
