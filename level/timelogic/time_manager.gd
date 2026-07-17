# TimeManager.gd
# Dodaj ten skrypt jako Autoload w ustawieniach projektu.
extends Node3D

# Sygnały informujące inne części gry o zmianie czasu.
signal time_updated(hours, minutes)
signal day_changed(day)

# Zmienne czasowe
var current_seconds: float = 0.0
var minutes: int = 0
var hours: int = 6 # Gra zaczyna się o 8:00
var day: int = 1

# Ustawia długość dnia w grze w minutach czasu rzeczywistego.
@export var day_length_in_minutes: float = 60.0

# Mnożnik prędkości upływu czasu. 1.0 to normalna prędkość.
var time_scale: float = 1.0

var seconds_in_a_day: float = 24.0 * 60.0 * 60.0
var time_multiplier: float

func _ready():
	# Obliczamy, ile razy szybciej musi płynąć czas w grze
	var real_seconds_for_a_day = day_length_in_minutes * 60.0
	if real_seconds_for_a_day > 0:
		time_multiplier = seconds_in_a_day / real_seconds_for_a_day
	else:
		time_multiplier = 0 # Zatrzymuje czas, jeśli długość dnia to 0

	# Ustawiamy początkowy czas w sekundach
	current_seconds = hours * 3600 + minutes * 60

func _process(delta: float):
	if time_multiplier > 0:
		# Przyspieszamy upływ czasu zgodnie z mnożnikiem i time_scale
		update_time(delta * time_multiplier * time_scale)

func update_time(elapsed_seconds: float):
	current_seconds += elapsed_seconds
	
	# Sprawdzamy, czy minął dzień
	if current_seconds >= seconds_in_a_day:
		current_seconds = fmod(current_seconds, seconds_in_a_day)
		day += 1
		emit_signal("day_changed", day)
		
	# Obliczamy aktualne godziny i minuty
	var new_hours = floori(current_seconds / 3600)
	var new_minutes = floori(fmod(current_seconds, 3600) / 60)
	
	# Jeśli czas się zmienił, emitujemy sygnał
	if new_hours != hours or new_minutes != minutes:
		hours = new_hours
		minutes = new_minutes
		emit_signal("time_updated", hours, minutes)

# Funkcja do zmiany prędkości czasu (np. podczas snu)
func set_time_scale(new_time_scale: float):
	time_scale = new_time_scale

# Funkcja zwracająca czas w ładnym formacie
func get_time_string() -> String:
	return "%02d:%02d" % [hours, minutes]
func get_day_string() -> String:
	return "Day %d" % [day]
