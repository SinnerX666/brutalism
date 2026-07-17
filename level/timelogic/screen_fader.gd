extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var animation_player = $AnimationPlayer

func _ready():
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_animations()

func create_animations():
	var fade_in_anim = Animation.new()
	fade_in_anim.add_track(Animation.TYPE_VALUE)
	fade_in_anim.track_set_path(0, "ColorRect:color")
	fade_in_anim.length = 1.0
	fade_in_anim.track_insert_key(0, 0.0, Color(0, 0, 0, 0))
	fade_in_anim.track_insert_key(0, 1.0, Color(0, 0, 0, 1))

	var fade_out_anim = Animation.new()
	fade_out_anim.add_track(Animation.TYPE_VALUE)
	fade_out_anim.track_set_path(0, "ColorRect:color")
	fade_out_anim.length = 1.5
	fade_out_anim.track_insert_key(0, 0.0, Color(0, 0, 0, 1))
	fade_out_anim.track_insert_key(0, 1.5, Color(0, 0, 0, 0))
	
	var anim_library = AnimationLibrary.new()
	anim_library.add_animation("fade_to_black", fade_in_anim)
	anim_library.add_animation("fade_from_black", fade_out_anim)
	animation_player.add_animation_library("", anim_library)

func fade_to_black():
	animation_player.play("fade_to_black")

func fade_from_black():
	animation_player.play("fade_from_black")
