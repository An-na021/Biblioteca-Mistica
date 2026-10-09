class_name DialoguePanel
extends Control

@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var text_label: Label = $Panel/TextLabel


func show_message(speaker: String, message: String) -> void:
	speaker_label.text = speaker
	text_label.text = message
