extends CharacterBody3D

var hunger: float = 100.0
var thirst: float = 100.0
var sanity: float = 100.0
var tired : float = 10.0
var health: float = 100.0
const MAX_STAT = 100.0
var is_sleeping: bool = false

const HUNGER_DRAIN_RATE: float = 0.1
const THIRST_DRAIN_RATE: float = 0.15
const SANITY_DRAIN_MULTIPLIER: float = 1.5
const HEALTH_DRAIN_RATE: float = 2.0
const TIRED_DRAIN_RATE: float = 0.04

const THIRST_SLEEP_DRAIN_RATE: float = 9.0
const HUNGER_SLEEP_DRAIN_RATE: float = 6.0
const TIREDNESS_RECOVERY_RATE = 30.0
const SANITY_RECOVERY_RATE = 15.0
const SLEEP_TIME_MULTIPLIER = 500.0

@export_group("Movement")
@export var moveSpeed = 5.0
@export var sprint_speed_multiplier: float = 1.65
@export var acceleration = 7.5
@export var crouch_speed_multiplier: float = 0.45
@export var standing_capsule_height: float = 2.0
@export var crouch_capsule_height: float = 0.78
@export var standing_capsule_radius: float = 0.5
@export var crouch_capsule_radius: float = 0.36
@export var standing_head_height: float = 0.75
@export var crouch_head_height: float = -0.35
@export var crouch_transition_speed: float = 12.0
var moveDir: Vector3

@export var jumpForce = 4.5
@export var gravity = 9.8

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 22.0
@export var stamina_regen_idle: float = 28.0
@export var stamina_regen_walk: float = 10.0
@export var min_stamina_to_sprint: float = 5.0

@export_group("Camera")
@export var mouseSens = Vector2(0.2, 0.2)
@export var camera_collision_radius: float = 0.18
@export var camera_collision_margin: float = 0.05
@export var headbob_walk_amount: float = 0.035
@export var headbob_sprint_amount: float = 0.038
@export var headbob_crouch_amount: float = 0.018
@export var headbob_walk_frequency: float = 8.0
@export var headbob_sprint_frequency: float = 9.0
@export var footstep_walk_interval: float = 0.48
@export var footstep_sprint_interval: float = 0.38
@export var footstep_crouch_interval: float = 0.62
@onready var camera = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var body_collision: CollisionShape3D = $CollisionShape3D

@export_group("Holding Objects")
@export var throwForce = 7.5
@export var followSpeed = 5.0
@export var followDistance = 2.5
@export var minHoldDistance = 0.25
@export var maxDistanceFromCamera = 5.0
@export var maxHoldSpeed = 12.0
@export var holdSpringStrength = 45.0
@export var holdDamping = 8.0
@export var holdCollisionMargin = 0.05
@export var dropBelowPlayer = false
@export var groundRay: RayCast3D

@export_group("Mass Interaction")
@export var max_lift_mass: float = 40.0
@export var max_manipulate_mass: float = 250.0
@export var grab_follow_distance: float = 2.0
@export var grab_push_spring: float = 22.0
@export var grab_push_damping: float = 14.0
@export var grab_max_horizontal_speed: float = 1.6
@export var grab_force_reference_mass: float = 70.0
@export var grab_min_speed_factor: float = 0.35
@export var mass_move_drag_reference: float = 140.0
@export var rotate_reference_mass: float = 8.0
@export var held_rotate_sensitivity: float = 0.012
@export var ground_yaw_sensitivity: float = 0.006

@onready var interactRay = $Head/Camera3D/RayCast3D
@onready var inventory: GridInventory = $Inventory

var heldObject: RigidBody3D
var grabbedObject: RigidBody3D
var heldObjectGravityScale: float = 1.0
var heldObjectDistance: float = followDistance
var holdShapeCast: ShapeCast3D
var holdMotionParameters := PhysicsTestMotionParameters3D.new()
var holdMotionResult := PhysicsTestMotionResult3D.new()
var holdSlideMotionResult := PhysicsTestMotionResult3D.new()
var ui_open: bool = false
var deployment_mode: bool = false
var is_crouching: bool = false
var wants_crouch: bool = false
var crouch_blend: float = 0.0
var is_rotating_object: bool = false
var is_sprinting: bool = false
var stamina: float = 100.0
var headbob_time: float = 0.0
var footstep_timer: float = 0.0
var camera_rest_position: Vector3 = Vector3.ZERO
var hud
var timeManager
var _capsule_shape: CapsuleShape3D
var _camera_collision_query := PhysicsShapeQueryParameters3D.new()
var _camera_collision_shape := SphereShape3D.new()
var _footstep_player: AudioStreamPlayer


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = get_tree().get_first_node_in_group("game_hud")
	timeManager = get_tree().get_first_node_in_group("time_manager")
	stamina = max_stamina
	_capsule_shape = body_collision.shape as CapsuleShape3D
	if _capsule_shape == null:
		_capsule_shape = CapsuleShape3D.new()
		_capsule_shape.height = standing_capsule_height
		_capsule_shape.radius = standing_capsule_radius
		body_collision.shape = _capsule_shape
	else:
		standing_capsule_height = _capsule_shape.height
		standing_capsule_radius = _capsule_shape.radius
	# Godot wymaga height >= 2 * radius — pilnujemy poprawnego kucania.
	crouch_capsule_height = maxf(crouch_capsule_height, crouch_capsule_radius * 2.0 + 0.01)
	standing_head_height = head.position.y
	if is_equal_approx(standing_head_height, 0.0):
		standing_head_height = 0.75
		head.position.y = standing_head_height
	camera_rest_position = camera.position
	_camera_collision_shape.radius = camera_collision_radius
	_camera_collision_query.shape = _camera_collision_shape
	_camera_collision_query.collide_with_areas = false
	_camera_collision_query.collide_with_bodies = true
	_setup_footstep_audio()
	_apply_crouch_visuals(0.0)

	holdShapeCast = ShapeCast3D.new()
	holdShapeCast.name = "HoldShapeCast"
	var initial_shape := SphereShape3D.new()
	initial_shape.radius = 0.5
	holdShapeCast.shape = initial_shape
	holdShapeCast.margin = holdCollisionMargin
	holdShapeCast.enabled = true
	holdShapeCast.collide_with_areas = false
	holdShapeCast.collision_mask = 0xFFFFFFFF
	camera.add_child(holdShapeCast)
	holdShapeCast.add_exception(self)

func _process(delta):
	if not is_sleeping:
		if ui_open:
			moveDir = Vector3.ZERO
		else:
			# Poruszanie się (Input)
			var inputDir = Input.get_vector("left", "right", "up", "down")
			moveDir = (transform.basis * Vector3(inputDir.x, 0, inputDir.y)).normalized()

		# Ubytek potrzeb gdy gracz nie śpi
		tired -= TIRED_DRAIN_RATE * delta
		hunger -= HUNGER_DRAIN_RATE * delta
		thirst -= THIRST_DRAIN_RATE * delta

		# Interakcje
		if not ui_open and not deployment_mode and Input.is_action_just_pressed("use"):
			if interactRay.is_colliding():
				var collider = interactRay.get_collider()

				# Łóżko
				if collider and collider.is_in_group("beds"):
					start_sleeping()
					return # Przerwij dalsze sprawdzanie w tej klatce

				# Używanie przedmiotów
				if (
					collider is RigidBody3D
					and collider.has_method("use_item")
					and collider.has_method("can_use")
					and collider.can_use()
				):
					var item = collider
					hunger = min(MAX_STAT, hunger + item.hunger_restore)
					thirst = min(MAX_STAT, thirst + item.thirst_restore)
					sanity = min(MAX_STAT, sanity + item.sanity_restore)
					health = min(MAX_STAT, health + item.health_restore)
					item.use_item()

		if not ui_open and not deployment_mode and Input.is_action_just_pressed("stash"):
			stash_world_item()
	else:
		# Gracz śpi - wygaszamy wektor ruchu, żeby nie wstał z łóżka
		moveDir = Vector3.ZERO

		# Statystyki snu
		tired = move_toward(tired, MAX_STAT, TIREDNESS_RECOVERY_RATE * delta)
		sanity = move_toward(sanity, MAX_STAT, SANITY_RECOVERY_RATE * delta)
		hunger -= HUNGER_SLEEP_DRAIN_RATE * delta
		thirst -= THIRST_SLEEP_DRAIN_RATE * delta

		if tired >= MAX_STAT:
			stop_sleeping()

	# Ograniczenia wartości, aby nie spadały poniżej 0 i nie rosły powyżej 100
	hunger = clamp(hunger, 0, MAX_STAT)
	thirst = clamp(thirst, 0, MAX_STAT)
	sanity = clamp(sanity, 0, MAX_STAT)
	tired = clamp(tired, 0, MAX_STAT)

	# Aktualizacja pasków postępu w UI
	if hud:
		hud.update_needs(hunger, thirst, tired)
		if hud.has_method("update_stamina"):
			hud.update_stamina(stamina, max_stamina, is_sprinting)

	# Utrata zdrowia przy skrajnym głodzie/pragnieniu
	if hunger <= 10 or thirst <= 10 or sanity <= 10:
		health -= HEALTH_DRAIN_RATE * delta

	health = max(0, health)

func _physics_process(delta):
	handle_holding_objects()
	_update_crouch(delta)
	_update_stamina(delta)

	# Jeśli gracz śpi, uziemniamy go i przerywamy proces fizyki
	if is_sleeping:
		velocity = Vector3.ZERO
		is_sprinting = false
		_update_camera_effects(delta)
		move_and_slide()
		return

	# Grawitacja
	if not is_on_floor():
		velocity.y -= gravity * delta

	if ui_open:
		velocity.x = 0.0
		velocity.z = 0.0
		is_sprinting = false
		_update_camera_effects(delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jumpForce

	is_sprinting = _can_sprint()
	var current_speed: float = moveSpeed
	if is_crouching:
		current_speed *= crouch_speed_multiplier
	elif is_sprinting:
		current_speed *= sprint_speed_multiplier
	current_speed *= _get_mass_move_multiplier()

	# Płynny ruch
	velocity.x = lerp(velocity.x, moveDir.x * current_speed, acceleration * delta)
	velocity.z = lerp(velocity.z, moveDir.z * current_speed, acceleration * delta)

	move_and_slide()
	_update_camera_effects(delta)

func _input(event):
	if is_sleeping or ui_open:
		return

	if event is InputEventMouseMotion:
		if is_rotating_object and _has_active_manipulation():
			_rotate_active_object(event.relative)
			return
		rotate_y(-event.relative.x * mouseSens.x * 0.01)
		camera.rotate_x(-event.relative.y * mouseSens.y * 0.01)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _update_crouch(delta: float) -> void:
	if is_sleeping or ui_open or deployment_mode:
		wants_crouch = false
	else:
		wants_crouch = Input.is_action_pressed("crouch")

	var can_stand := _can_stand_up()
	var target_crouch := wants_crouch or (is_crouching and not can_stand)
	var target_blend := 1.0 if target_crouch else 0.0
	crouch_blend = move_toward(crouch_blend, target_blend, crouch_transition_speed * delta)
	is_crouching = crouch_blend > 0.5
	_apply_crouch_visuals(crouch_blend)


func _apply_crouch_visuals(blend: float) -> void:
	if _capsule_shape == null or body_collision == null:
		return
	var height: float = lerpf(standing_capsule_height, crouch_capsule_height, blend)
	var radius: float = lerpf(standing_capsule_radius, crouch_capsule_radius, blend)
	height = maxf(height, radius * 2.0 + 0.01)
	_capsule_shape.radius = radius
	_capsule_shape.height = height
	# Trzymamy stopy w tym samym miejscu przy zmniejszaniu kapsuły wycentrowanej w origin.
	body_collision.position.y = -(standing_capsule_height - height) * 0.5
	head.position.y = lerpf(standing_head_height, crouch_head_height, blend)


func _can_stand_up() -> bool:
	if _capsule_shape == null:
		return true
	var rise: float = (standing_capsule_height - crouch_capsule_height) * 0.5 + 0.05
	return not test_move(global_transform, Vector3.UP * rise)


func notify_held_object_captured(item: RigidBody3D) -> void:
	if not is_instance_valid(item) or heldObject != item:
		return
	item.remove_collision_exception_with(self)
	heldObject = null
	heldObjectDistance = followDistance
	_reset_hold_shape_cast_exceptions()
	is_rotating_object = false


func set_held_object(body: Object) -> void:
	if not (is_instance_valid(body) and body is RigidBody3D):
		return

	var rigid_body := body as RigidBody3D
	if rigid_body is WorldItem and not (rigid_body as WorldItem).can_hold():
		return
	if rigid_body.mass > max_lift_mass:
		return

	release_grabbed_object()
	if is_instance_valid(heldObject) and heldObject != body:
		drop_held_object()

	if rigid_body is WorldItem:
		var world_item := rigid_body as WorldItem
		if world_item.has_meta(PhysicalCraftingSlot.CRAFTING_SLOT_META):
			var slot = world_item.get_meta(PhysicalCraftingSlot.CRAFTING_SLOT_META)
			if is_instance_valid(slot) and slot.has_method("notify_item_taken"):
				slot.notify_item_taken(world_item)

	_prepare_held_physics(rigid_body)
	heldObject = rigid_body
	heldObjectDistance = clampf(
		camera.global_position.distance_to(heldObject.global_position),
		minHoldDistance,
		maxDistanceFromCamera
	)
	heldObjectGravityScale = heldObject.gravity_scale
	heldObject.add_collision_exception_with(self)
	_configure_hold_shape_cast(heldObject)


func set_grabbed_object(body: Object) -> void:
	if not (is_instance_valid(body) and body is RigidBody3D):
		return
	var rigid_body := body as RigidBody3D
	if rigid_body.mass <= max_lift_mass or rigid_body.mass > max_manipulate_mass:
		return
	if rigid_body is WorldItem and not (rigid_body as WorldItem).can_hold():
		# Plandeka i inne obiekty z can_hold=false nie są do pchania.
		return

	drop_held_object()
	if is_instance_valid(grabbedObject) and grabbedObject != rigid_body:
		release_grabbed_object()

	grabbedObject = rigid_body
	grabbedObject.freeze = false
	grabbedObject.linear_velocity = Vector3.ZERO
	grabbedObject.angular_velocity = Vector3.ZERO
	grabbedObject.axis_lock_angular_x = true
	grabbedObject.axis_lock_angular_z = true


func _prepare_held_physics(body: RigidBody3D) -> void:
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = false


func drop_held_object() -> void:
	if is_instance_valid(heldObject):
		heldObject.gravity_scale = heldObjectGravityScale
		heldObject.remove_collision_exception_with(self)
	heldObject = null
	heldObjectDistance = followDistance
	_reset_hold_shape_cast_exceptions()
	is_rotating_object = false


func release_grabbed_object() -> void:
	grabbedObject = null
	is_rotating_object = false


func throw_held_object():
	if is_instance_valid(heldObject):
		var obj = heldObject
		drop_held_object()
		# Siła rzutu spada wraz z masą, żeby ciężkie (ale nadal podnoszone) przedmioty leciały krócej.
		var mass_factor: float = clampf(1.0 / maxf(obj.mass, 0.05), 0.05, 4.0)
		obj.apply_central_impulse(-camera.global_basis.z * throwForce * mass_factor)
	else:
		drop_held_object()


func try_interact_with_body(body: Object) -> void:
	if not (is_instance_valid(body) and body is RigidBody3D):
		return
	var rigid_body := body as RigidBody3D
	if rigid_body.mass <= max_lift_mass:
		set_held_object(rigid_body)
	elif rigid_body.mass <= max_manipulate_mass:
		set_grabbed_object(rigid_body)


func handle_holding_objects():
	# Zablokowanie manipulacji przedmiotami w trakcie snu
	if is_sleeping or ui_open or deployment_mode:
		is_rotating_object = false
		return

	if heldObject != null and not is_instance_valid(heldObject):
		drop_held_object()
	if grabbedObject != null and not is_instance_valid(grabbedObject):
		release_grabbed_object()

	is_rotating_object = (
		Input.is_action_pressed("rotate_item")
		and _has_active_manipulation()
	)

	# Rzucanie przedmiotów (tylko podniesione)
	if Input.is_action_just_pressed("throw"):
		if heldObject != null:
			throw_held_object()
		elif grabbedObject != null:
			release_grabbed_object()

	# Upuszczanie / podnoszenie / chwyt ciężkich
	if Input.is_action_just_pressed("interact"):
		if heldObject != null:
			drop_held_object()
		elif grabbedObject != null:
			release_grabbed_object()
		elif interactRay.is_colliding():
			try_interact_with_body(interactRay.get_collider())

	# System przenoszenia obiektu za celownikiem
	if heldObject != null:
		var targetPos: Vector3 = get_safe_hold_target(heldObject, heldObjectDistance)
		targetPos = _clamp_target_by_body_motion(heldObject, targetPos)
		var objectPos: Vector3 = heldObject.global_transform.origin
		var displacement: Vector3 = targetPos - objectPos
		var springForce: Vector3 = displacement * holdSpringStrength
		var dampingForce: Vector3 = -heldObject.linear_velocity * holdDamping
		heldObject.apply_central_force((springForce + dampingForce) * heldObject.mass)
		if heldObject.linear_velocity.length() > maxHoldSpeed:
			heldObject.linear_velocity = heldObject.linear_velocity.limit_length(maxHoldSpeed)

		# Upuść obiekt, jeśli odleciał zbyt daleko od kamery
		if heldObject.global_position.distance_to(camera.global_position) > maxDistanceFromCamera:
			drop_held_object()

		if dropBelowPlayer and groundRay and groundRay.is_colliding():
			if groundRay.get_collider() == heldObject:
				drop_held_object()

	elif grabbedObject != null:
		_update_grabbed_object()


func _update_grabbed_object() -> void:
	# Cel w poziomie przed graczem — stabilniejsze ciągnięcie niż punkt z kamery.
	var look_flat: Vector3 = -camera.global_basis.z
	look_flat.y = 0.0
	if look_flat.length_squared() < 0.0001:
		look_flat = -global_basis.z
		look_flat.y = 0.0
	look_flat = look_flat.normalized()
	var target: Vector3 = global_position + look_flat * grab_follow_distance
	target.y = grabbedObject.global_position.y

	var displacement: Vector3 = target - grabbedObject.global_position
	displacement.y = 0.0
	var damping: Vector3 = -grabbedObject.linear_velocity
	damping.y = 0.0

	var force_scale: float = maxf(grab_force_reference_mass, grabbedObject.mass * 0.4)
	grabbedObject.apply_central_force(
		(displacement * grab_push_spring + damping * grab_push_damping) * force_scale
	)

	# Blokada wywrotek: tylko yaw.
	grabbedObject.angular_velocity = Vector3(0.0, grabbedObject.angular_velocity.y, 0.0)
	grabbedObject.global_basis = Basis.from_euler(Vector3(0.0, grabbedObject.global_rotation.y, 0.0))

	var mass_speed_factor: float = clampf(
		grab_force_reference_mass / maxf(grabbedObject.mass, 0.01),
		grab_min_speed_factor,
		1.0
	)
	var max_speed: float = grab_max_horizontal_speed * mass_speed_factor
	var horizontal_velocity := Vector3(
		grabbedObject.linear_velocity.x,
		0.0,
		grabbedObject.linear_velocity.z
	)
	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.limit_length(max_speed)
		grabbedObject.linear_velocity.x = horizontal_velocity.x
		grabbedObject.linear_velocity.z = horizontal_velocity.z
	# Lekkie tłumienie pionu, żeby nie podskakiwała przy tarciu.
	grabbedObject.linear_velocity.y = minf(grabbedObject.linear_velocity.y, 0.0)

	if grabbedObject.global_position.distance_to(global_position) > maxDistanceFromCamera:
		release_grabbed_object()


func _has_active_manipulation() -> bool:
	return is_instance_valid(heldObject) or is_instance_valid(grabbedObject)


func _rotate_active_object(mouse_relative: Vector2) -> void:
	if is_instance_valid(heldObject):
		var mass_factor: float = _get_rotate_mass_factor(heldObject.mass, 0.2, 1.5)
		var yaw: float = -mouse_relative.x * held_rotate_sensitivity * mass_factor
		var pitch: float = -mouse_relative.y * held_rotate_sensitivity * mass_factor
		heldObject.rotate(camera.global_basis.y.normalized(), yaw)
		heldObject.rotate(camera.global_basis.x.normalized(), pitch)
		heldObject.angular_velocity = Vector3.ZERO
	elif is_instance_valid(grabbedObject):
		# Ciężkie obiekty: tylko yaw, mocno tłumiony masą (200 kg ≈ ledwo drgnie).
		var mass_factor: float = _get_rotate_mass_factor(grabbedObject.mass, 0.004, 0.35)
		var yaw_delta: float = -mouse_relative.x * ground_yaw_sensitivity * mass_factor
		grabbedObject.rotate_y(yaw_delta)
		grabbedObject.angular_velocity = Vector3.ZERO


func _get_rotate_mass_factor(mass: float, min_factor: float, max_factor: float) -> float:
	return clampf(rotate_reference_mass / maxf(mass, 0.01), min_factor, max_factor)


func _get_mass_move_multiplier() -> float:
	if not is_instance_valid(grabbedObject):
		return 1.0
	return 1.0 / (1.0 + grabbedObject.mass / maxf(mass_move_drag_reference, 1.0))


func _can_sprint() -> bool:
	if is_sleeping or ui_open or deployment_mode or is_crouching:
		return false
	if is_instance_valid(grabbedObject):
		# Sprint przy pchaniu ciężkich obiektów jest wyłączony.
		return false
	if not is_on_floor():
		return false
	if moveDir.length_squared() < 0.01:
		return false
	if not Input.is_action_pressed("sprint"):
		return false
	return stamina > min_stamina_to_sprint


func _update_stamina(delta: float) -> void:
	if is_sleeping:
		stamina = move_toward(stamina, max_stamina, stamina_regen_idle * delta)
		return

	var is_moving: bool = moveDir.length_squared() > 0.01 and not ui_open
	if is_sprinting:
		stamina = maxf(stamina - stamina_drain_rate * delta, 0.0)
	elif not is_moving:
		stamina = move_toward(stamina, max_stamina, stamina_regen_idle * delta)
	else:
		stamina = move_toward(stamina, max_stamina, stamina_regen_walk * delta)


func _setup_footstep_audio() -> void:
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.name = "FootstepPlayer"
	_footstep_player.volume_db = -18.0
	_footstep_player.bus = "Master"
	add_child(_footstep_player)
	_footstep_player.stream = _create_footstep_stream()


func _create_footstep_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := 900
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / float(sample_count)
		var envelope: float = (1.0 - t) * (1.0 - t)
		var noise: float = randf_range(-1.0, 1.0) * envelope * 0.35
		var sample: int = clampi(int(noise * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample)
	stream.data = data
	return stream


func _update_camera_effects(delta: float) -> void:
	var horizontal_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var moving_on_foot: bool = (
		is_on_floor()
		and not is_sleeping
		and not ui_open
		and horizontal_speed > 0.4
	)

	var bob_amount: float = headbob_walk_amount
	var bob_frequency: float = headbob_walk_frequency
	var step_interval: float = footstep_walk_interval
	if is_crouching:
		bob_amount = headbob_crouch_amount
		bob_frequency = headbob_walk_frequency * 0.75
		step_interval = footstep_crouch_interval
	elif is_sprinting:
		bob_amount = headbob_sprint_amount
		bob_frequency = headbob_sprint_frequency
		step_interval = footstep_sprint_interval

	var bob_offset := Vector3.ZERO
	if moving_on_foot:
		var speed_ref: float = moveSpeed
		if is_sprinting:
			speed_ref = moveSpeed * sprint_speed_multiplier
		elif is_crouching:
			speed_ref = moveSpeed * crouch_speed_multiplier
		# Bob idzie z tempem chodu, bez „turbo” przy wyższej prędkości.
		var pace: float = clampf(horizontal_speed / maxf(speed_ref, 0.1), 0.7, 1.05)
		headbob_time += delta * bob_frequency * pace
		bob_offset = Vector3(
			sin(headbob_time) * bob_amount * 0.35,
			sin(headbob_time * 2.0) * bob_amount,
			0.0
		)
		footstep_timer += delta
		if footstep_timer >= step_interval / pace:
			footstep_timer = 0.0
			if _footstep_player and not _footstep_player.playing:
				_footstep_player.pitch_scale = randf_range(0.92, 1.05)
				_footstep_player.play()
	else:
		headbob_time = move_toward(headbob_time, 0.0, delta * 8.0)
		footstep_timer = 0.0

	var desired_local: Vector3 = camera_rest_position + bob_offset
	camera.position = _resolve_camera_collision(desired_local)


func _resolve_camera_collision(desired_local: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return desired_local

	# Start z wnętrza aktualnej kapsuły — NIE z global_position postaci
	# (przy kucaniu origin postaci może być nad blatem stołu).
	var origin: Vector3 = body_collision.global_position
	var desired_global: Vector3 = head.to_global(desired_local)
	var cast_vector: Vector3 = desired_global - origin
	if cast_vector.length_squared() < 0.0001:
		return desired_local

	_camera_collision_shape.radius = camera_collision_radius
	_camera_collision_query.shape = _camera_collision_shape
	_camera_collision_query.transform = Transform3D(Basis.IDENTITY, origin)
	_camera_collision_query.motion = cast_vector
	_camera_collision_query.collision_mask = 0xFFFFFFFF
	_camera_collision_query.exclude = [get_rid()]
	if is_instance_valid(heldObject):
		_camera_collision_query.exclude.append(heldObject.get_rid())
	if is_instance_valid(grabbedObject):
		_camera_collision_query.exclude.append(grabbedObject.get_rid())

	var hit: PackedFloat32Array = space.cast_motion(_camera_collision_query)
	var safe_global: Vector3 = desired_global
	if hit.size() >= 1:
		var safe_fraction: float = hit[0]
		if safe_fraction < 1.0:
			safe_global = origin + cast_vector * maxf(safe_fraction - camera_collision_margin, 0.0)

	# Dodatkowy overlap w docelowym punkcie (gdy kamera już utknęła w geometrii).
	_camera_collision_query.transform = Transform3D(Basis.IDENTITY, safe_global)
	_camera_collision_query.motion = Vector3.ZERO
	var overlaps: Array = space.intersect_shape(_camera_collision_query, 1)
	if not overlaps.is_empty():
		# Cofnij kamerę w stronę bezpiecznego środka kapsuły.
		safe_global = origin.lerp(safe_global, 0.15)

	return head.to_local(safe_global)


func get_safe_hold_target(_item: RigidBody3D, distance: float) -> Vector3:
	return camera.global_position - camera.global_basis.z * distance


func get_safe_item_spawn_position(item: RigidBody3D, distance: float = 2.0) -> Variant:
	if not is_instance_valid(item) or holdShapeCast == null:
		return null

	if item != heldObject or holdShapeCast.shape == null:
		_configure_hold_shape_cast(item)
	holdShapeCast.target_position = Vector3(0.0, 0.0, -distance)
	holdShapeCast.force_shapecast_update()

	var safe_fraction := 1.0
	if holdShapeCast.is_colliding():
		safe_fraction = holdShapeCast.get_closest_collision_safe_fraction()
		if safe_fraction <= 0.001:
			return null

	var local_target := holdShapeCast.target_position * safe_fraction
	return camera.to_global(local_target)


func _configure_hold_shape_cast(item: RigidBody3D) -> void:
	var radius := 0.5
	if item.has_method("get_collision_radius"):
		radius = maxf(float(item.get_collision_radius()), 0.1)

	var sphere := holdShapeCast.shape as SphereShape3D
	if sphere == null:
		sphere = SphereShape3D.new()
		holdShapeCast.shape = sphere
	sphere.radius = radius
	holdShapeCast.margin = holdCollisionMargin

	_reset_hold_shape_cast_exceptions()
	if item.is_inside_tree():
		holdShapeCast.add_exception(item)


func _reset_hold_shape_cast_exceptions() -> void:
	if holdShapeCast == null:
		return
	holdShapeCast.clear_exceptions()
	holdShapeCast.add_exception(self)


func _clamp_target_by_body_motion(item: RigidBody3D, target: Vector3) -> Vector3:
	var requested_motion := target - item.global_position
	if requested_motion.is_zero_approx():
		return item.global_position

	holdMotionParameters.from = item.global_transform
	holdMotionParameters.motion = requested_motion
	holdMotionParameters.margin = holdCollisionMargin

	if PhysicsServer3D.body_test_motion(item.get_rid(), holdMotionParameters, holdMotionResult):
		var collider: Object = holdMotionResult.get_collider()
		if not _is_immovable_collider(collider):
			return target

		var travel := holdMotionResult.get_travel()
		var remainder := requested_motion - travel
		var slideMotion := remainder.slide(holdMotionResult.get_collision_normal())
		if slideMotion.is_zero_approx():
			return item.global_position + travel

		holdMotionParameters.from = item.global_transform.translated(travel)
		holdMotionParameters.motion = slideMotion
		if PhysicsServer3D.body_test_motion(
			item.get_rid(),
			holdMotionParameters,
			holdSlideMotionResult
		):
			slideMotion = holdSlideMotionResult.get_travel()
		return item.global_position + travel + slideMotion
	return target


func _is_immovable_collider(collider: Object) -> bool:
	if collider is StaticBody3D:
		return true
	if collider is RigidBody3D:
		return collider.freeze
	return false


func stash_world_item() -> void:
	var target: WorldItem
	if is_instance_valid(heldObject):
		target = heldObject as WorldItem
	elif heldObject != null:
		drop_held_object()

	if target == null and interactRay.is_colliding():
		var collider: Object = interactRay.get_collider()
		if is_instance_valid(collider):
			target = collider as WorldItem
	if target == null or target.item_id.is_empty():
		return
	if target.has_method("can_stash") and not target.can_stash():
		return

	var not_added: int = inventory.add(target.item_id, 1)
	if not_added != 0:
		return

	if target == heldObject:
		drop_held_object()
	target.queue_free()


func set_inventory_ui_open(is_open: bool) -> void:
	if is_open:
		var placement_controller := get_node_or_null("DeployablePlacement")
		if placement_controller and placement_controller.is_placing():
			placement_controller.cancel_placement()
	ui_open = is_open
	moveDir = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED


func set_deployment_mode(is_active: bool) -> void:
	deployment_mode = is_active
	if is_active and is_instance_valid(heldObject):
		drop_held_object()
	if is_active and is_instance_valid(grabbedObject):
		release_grabbed_object()

func start_sleeping():
	print("Gracz idzie spać.")
	if heldObject != null:
		drop_held_object() # Upuszczamy przedmiot przed pójściem spać
	if grabbedObject != null:
		release_grabbed_object()
	is_sleeping = true
	ScreenFader.fade_to_black()
	if timeManager:
		timeManager.set_time_scale(SLEEP_TIME_MULTIPLIER)

func stop_sleeping():
	print("Gracz się budzi.")
	is_sleeping = false
	if timeManager:
		timeManager.set_time_scale(1.0)
	ScreenFader.fade_from_black()
	tired = MAX_STAT
	print("Zmęczenie: ", tired, " | Poczytalność: ", sanity)
