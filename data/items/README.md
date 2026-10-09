# Item catalog

`data/items/` is the source of truth for runtime item definitions. The catalog uses Godot's built-in `FileAccess` and `JSON` APIs, so it does not require a plugin or an external database server.

## Adding an item

1. Choose an existing category file or create a new JSON file.
2. If the file is new, add its `res://` path to `index.json`.
3. Add an object with a unique lower-case `snake_case` ID.
4. Run `test/item_catalog_smoke_test.gd`.

Minimal item:

```json
{
	"id": "example_item",
	"display_name": "Example item",
	"description": "A description shown in the inventory.",
	"icon": "res://UI/assets/pick_up_icon.png",
	"max_stack": 4,
	"grid_width": 1,
	"grid_height": 1,
	"tags": ["pick", "world_item"],
	"mass": 0.2,
	"preview_color": [0.5, 0.5, 0.5]
}
```

## Core fields

- `id` — permanent unique identifier; do not change it after saves start using it.
- `display_name` — player-facing name.
- `description` — short or long player-facing description.
- `icon` — optional Godot resource path.
- `max_stack` — maximum amount in one inventory stack.
- `grid_width`, `grid_height` — backpack footprint before rotation.
- `tags` — groups applied to a spawned `WorldItem`.
- `mass` — mass used by the generic physical placeholder.
- `preview_color` — RGB values from `0.0` to `1.0` for the placeholder mesh.

## Optional gameplay fields

- `hunger_restore`
- `thirst_restore`
- `sanity_restore`
- `health_restore`
- `dropped_item` — custom world scene; omitted values use `generic_world_item.tscn`.
- `deployable` and `deployable_scene`

Unknown fields are preserved in `InvItemDef.properties`, allowing new systems to add data without changing the catalog loader first.

## Validation

The catalog reports malformed JSON, duplicate or invalid IDs, missing names, missing resource paths, and non-numeric stats. JSON files are explicitly included by the Windows export preset because runtime path strings are not discovered automatically by Godot's dependency scanner.
