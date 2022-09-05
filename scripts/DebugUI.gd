class_name DebugUI extends Control

onready var dump_label : Label = get_node("%Dump")

var font : DynamicFont

func _ready() -> void:
    font = ResourceLoader.load("res://fonts/Silver.tres").duplicate()
    update()

func _process(_delta: float) -> void:
    dump_label.visible = State.debug_ui_active

    update()

func _draw() -> void:
    if State.debug_ui_active == false:
        return

    dump_label.set_text(JSON.print({
        "FPS": Performance.get_monitor(Performance.TIME_FPS),
        "Cursor position": State.cursor_position,
        "Shortcuts": {
            "F1": "Toggle debug menu",
            "F2": "Toggle world",
            "F/F4": "Change level",
            "WASD": "Move cursor",
            "Q/E": "Rotate camera",
        },
    }, "  "))

    pass
