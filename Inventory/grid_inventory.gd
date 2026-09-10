class_name InvGrid
extends Node

signal contents_changed
signal updated_stack(stack_index: int)

@export var size: Vector2i = Vector2i(8, 6)
@export var database: InvDatabase

## Lista zajętych stosów (pozycje w siatce tetris).
var stacks: Array[InvItemStack] = []


func _ready() -> void:
	if database:
		database._rebuild_cache()


func get_item_count(item_id: String) -> int:
	var total := 0
	for stack in stacks:
		if stack != null and stack.item_id == item_id:
			total += stack.amount
	return total


## Dodaje przedmioty. Zwraca ile NIE udało się dodać.
func add(item_id: String, amount: int = 1) -> int:
	if amount <= 0 or database == null:
		return amount
	var definition := database.get_item(item_id)
	if definition == null:
		push_error("InvGrid: unknown item_id '%s'." % item_id)
		return amount

	var remaining := amount
	var max_stack: int = maxi(definition.max_stack, 1)

	# Najpierw dopełnij istniejące stosy.
	for i in stacks.size():
		var stack := stacks[i]
		if stack == null or stack.item_id != item_id:
			continue
		if stack.amount >= max_stack:
			continue
		var can_add: int = mini(remaining, max_stack - stack.amount)
		stack.amount += can_add
		remaining -= can_add
		updated_stack.emit(i)
		if remaining <= 0:
			contents_changed.emit()
			return 0

	# Potem nowe komórki.
	while remaining > 0:
		var place := _find_free_position(definition, false)
		var use_rotated := false
		if place.x < 0:
			place = _find_free_position(definition, true)
			use_rotated = place.x >= 0
		if place.x < 0:
			break
		var put: int = mini(remaining, max_stack)
		stacks.append(InvItemStack.new(item_id, put, place, use_rotated))
		remaining -= put
		updated_stack.emit(stacks.size() - 1)

	contents_changed.emit()
	return remaining


## Usuwa przedmioty. Zwraca ile NIE udało się usunąć.
func remove(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	for i in range(stacks.size() - 1, -1, -1):
		var stack := stacks[i]
		if stack == null or stack.item_id != item_id:
			continue
		var take: int = mini(remaining, stack.amount)
		stack.amount -= take
		remaining -= take
		if stack.amount <= 0:
			stacks.remove_at(i)
		updated_stack.emit(i)
		if remaining <= 0:
			break
	contents_changed.emit()
	return remaining


func can_place_stack(stack: InvItemStack, at: Vector2i, rotated: bool) -> bool:
	if stack == null or database == null:
		return false
	var definition := database.get_item(stack.item_id)
	if definition == null:
		return false
	return _can_fit(definition, at, rotated, stack)


func move_stack(stack_index: int, at: Vector2i, rotated: bool) -> bool:
	if stack_index < 0 or stack_index >= stacks.size():
		return false
	var stack := stacks[stack_index]
	if not can_place_stack(stack, at, rotated):
		return false
	stack.grid_position = at
	stack.rotated = rotated
	updated_stack.emit(stack_index)
	contents_changed.emit()
	return true


func get_stack_at_cell(cell: Vector2i) -> InvItemStack:
	for stack in stacks:
		if stack == null:
			continue
		if _stack_covers_cell(stack, cell):
			return stack
	return null


func get_stack_index(stack: InvItemStack) -> int:
	return stacks.find(stack)


func _find_free_position(definition: InvItemDef, rotated: bool) -> Vector2i:
	var dims := definition.get_grid_size(rotated)
	for y in size.y:
		for x in size.x:
			var pos := Vector2i(x, y)
			if _can_fit(definition, pos, rotated, null):
				return pos
	return Vector2i(-1, -1)


func _can_fit(
	definition: InvItemDef,
	at: Vector2i,
	rotated: bool,
	ignore_stack: InvItemStack
) -> bool:
	var dims := definition.get_grid_size(rotated)
	if at.x < 0 or at.y < 0:
		return false
	if at.x + dims.x > size.x or at.y + dims.y > size.y:
		return false
	for yy in dims.y:
		for xx in dims.x:
			var cell := Vector2i(at.x + xx, at.y + yy)
			var occupant := get_stack_at_cell(cell)
			if occupant != null and occupant != ignore_stack:
				return false
	return true


func _stack_covers_cell(stack: InvItemStack, cell: Vector2i) -> bool:
	if database == null:
		return false
	var definition := database.get_item(stack.item_id)
	if definition == null:
		return false
	var dims := definition.get_grid_size(stack.rotated)
	var origin := stack.grid_position
	return (
		cell.x >= origin.x
		and cell.y >= origin.y
		and cell.x < origin.x + dims.x
		and cell.y < origin.y + dims.y
	)
