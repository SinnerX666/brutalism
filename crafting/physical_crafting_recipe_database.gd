class_name PhysicalCraftingRecipeDatabase
extends Resource

@export var recipes: Array[PhysicalCraftingRecipe] = []


func find_matching_recipe(item_ids: Array[String]) -> PhysicalCraftingRecipe:
	for recipe in recipes:
		if recipe != null and recipe.matches(item_ids):
			return recipe
	return null
