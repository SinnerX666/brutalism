extends WorldItem

@onready var _mesh: MeshInstance3D = $Visuals/Mesh


func _ready() -> void:
	super._ready()
	_apply_preview_visuals()


func _apply_preview_visuals() -> void:
	if _mesh == null:
		return
	var definition: InvItemDef = ItemCatalog.get_item(item_id) if ItemCatalog else null
	if definition == null:
		return

	var catalog_mass: Variant = definition.get_property("mass", null)
	if catalog_mass != null:
		mass = maxf(float(catalog_mass), 0.05)

	var color_value: Variant = definition.get_property("preview_color", [0.55, 0.55, 0.55])
	var albedo := Color(0.55, 0.55, 0.55)
	if color_value is Array and color_value.size() >= 3:
		albedo = Color(float(color_value[0]), float(color_value[1]), float(color_value[2]))

	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.85
	_mesh.material_override = material
