class_name Game extends Node

onready var debug_ui = get_node("%DebugUI")
onready var camera_rig : Spatial = get_node("%Camera Rig")
onready var gridmap : GridMap = get_node("%GridMap")
onready var cursor : Spatial = get_node("%Cursor")
onready var highlight : Spatial = get_node("%Highlight")
onready var highlight_mesh_instance : MeshInstance = highlight.get_node("MeshInstance")

const MOVE_SPEED : float = 10.0
const MOVE_RANGE : float = 80.0
const CROSSHAIR_SIZE : int = 16
const SHOOT_CHARGE_SPEED : float = 1.0
const SHOOT_CHARGE_MIN : float = 0.1
const SHOOT_CHARGE_MAX : float = 1.0
const SLOPE : Vector3 = Vector3(0.370, 0.771, 0.517)
const ORTHOGONAL_ANGLES = [
    Vector3(0, 0, 0),
    Vector3(0, 0, PI/2),
    Vector3(0, 0, PI),
    Vector3(0, 0, -PI/2),
    Vector3(PI/2, 0, 0),
    Vector3(PI, -PI/2, -PI/2),
    Vector3(-PI/2, PI, 0),
    Vector3(0, -PI/2, -PI/2),
    Vector3(-PI, 0, 0),
    Vector3(PI, 0, -PI/2),
    Vector3(0, PI, 0),
    Vector3(0, PI, -PI/2),
    Vector3(-PI/2, 0, 0),
    Vector3(0, -PI/2, PI/2),
    Vector3(PI/2, 0, PI),
    Vector3(0, PI/2, -PI/2),
    Vector3(0, PI/2, 0),
    Vector3(-PI/2, PI/2, 0),
    Vector3(PI, PI/2, 0),
    Vector3(PI/2, PI/2, 0),
    Vector3(PI, -PI/2, 0),
    Vector3(-PI/2, -PI/2, 0),
    Vector3(0, -PI/2, 0),
    Vector3(PI/2, -PI/2, 0)
]

func _ready() -> void:
    State.debug_ui_active = true
    load_level(0)
    move_cursor(State.cursor_position)

func _process(_delta: float) -> void:
    var new_cursor_position = State.cursor_position

    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

    if Input.is_action_just_released("move_left"):
        new_cursor_position.x -= 1
    if Input.is_action_just_released("move_right"):
        new_cursor_position.x += 1
    if Input.is_action_just_released("move_up"):
        new_cursor_position.y -= 1
    if Input.is_action_just_released("move_down"):
        new_cursor_position.y += 1

    if Input.is_action_just_released("ui_up"):
        create_tween().tween_property(camera_rig, "rotation_degrees:z", camera_rig.rotation_degrees.z + 90, 0.3)
    if Input.is_action_just_released("ui_down"):
        create_tween().tween_property(camera_rig, "rotation_degrees:z", camera_rig.rotation_degrees.z - 90, 0.3)

    if Input.is_action_just_released("camera_left"):
        create_tween().tween_property(camera_rig, "rotation_degrees:y", camera_rig.rotation_degrees.y - 90, 0.3)
    if Input.is_action_just_released("camera_right"):
        create_tween().tween_property(camera_rig, "rotation_degrees:y", camera_rig.rotation_degrees.y + 90, 0.3)

    if Input.is_action_just_released("debug_1"):
        State.debug_ui_active = !State.debug_ui_active
        print("Debug menu: %s" % ("ENABLED" if State.debug_ui_active else "DISABLED"))

    if Input.is_action_just_released("debug_2"):
        gridmap.visible = !gridmap.visible
        print("Map: %s" % ("ENABLED" if gridmap.visible else "DISABLED"))

    if Input.is_action_just_released("debug_3"):
        load_level(0)
        move_cursor(State.cursor_position)

    if Input.is_action_just_released("debug_4"):
        load_level(1)
        move_cursor(State.cursor_position)

    if State.cursor_position != new_cursor_position:
        move_cursor(new_cursor_position)

func load_level(index: int) -> void:
    gridmap.clear()
    print("GridMap cleared!")

    var levels := [
        gridmap_to_json("res://scenes/level_0.tscn"),
        gridmap_to_json("res://scenes/level_1.tscn")
    ]
    var cells_dictionary := get_cells_dictionary_from_json(levels[index])

    for cell_position in cells_dictionary.keys():
        var cell_id : int = cells_dictionary[cell_position][0]
        var cell_orientation : int = cells_dictionary[cell_position][1]
        gridmap.set_cell_item(int(cell_position.x), int(cell_position.y), int(cell_position.z), cell_id, cell_orientation)

    print("Level %s loaded." % index)

func move_cursor(new_cursor_position: Vector2) -> void:
    # Update cursor
    var cursor_height := 0
    var max_height := 10
    var cell_id := gridmap.get_cell_item(int(new_cursor_position.x), cursor_height, int(new_cursor_position.y))
    var cell_orientation := gridmap.get_cell_item_orientation(int(new_cursor_position.x), cursor_height, int(new_cursor_position.y))

    for height in range(cursor_height + 1, cursor_height + max_height):
        var new_cell_id := gridmap.get_cell_item(int(new_cursor_position.x), height, int(new_cursor_position.y))
        if new_cell_id > -1:
            cell_id = new_cell_id
            cell_orientation = gridmap.get_cell_item_orientation(int(new_cursor_position.x), height, int(new_cursor_position.y))
            cursor_height += 1

    var cursor_world_position := Vector3(new_cursor_position.x, cursor_height, new_cursor_position.y)

    # No cell_id == not cell to highlight / move cursor to. In a real game we probably want to avoid this before moving the cursor
    if cell_id > -1:
        cursor.transform.origin = cursor_world_position

        # Notes: After writing all this by hand (not this one), i found MeshDataTool which could probably simplify this code a lot...
        # Edit: Fuck me, this is way simpler indeed :o
        # https://docs.godotengine.org/en/stable/classes/class_meshdatatool.html

        # Update cell highlight
        var cell_mesh := gridmap.mesh_library.get_item_mesh(cell_id)

        var highlight_material := SpatialMaterial.new()
        highlight_material.albedo_color = Color.yellow

        var mdt = MeshDataTool.new()
        var highlight_mesh := Mesh.new()
        for surface_index in range(0, cell_mesh.get_surface_count()):
            mdt.create_from_surface(cell_mesh, surface_index)

            for i in range(mdt.get_vertex_count()):
                var normal : Vector3 = mdt.get_vertex_normal(i)
                if vector_is_equal_approx(normal, Vector3.UP) || vector_is_equal_approx(normal, SLOPE):
                    var vertex = mdt.get_vertex(i) + normal * 0.01
                    mdt.set_vertex(i, vertex)
                else:
                    mdt.set_vertex(i, Vector3.ZERO)

        mdt.set_material(highlight_material)
        mdt.commit_to_surface(highlight_mesh)

        highlight.transform.origin = cursor_world_position + Vector3(0.5, 0.5, 0.5)
        highlight_mesh_instance.mesh = highlight_mesh
        highlight_mesh_instance.rotation = ORTHOGONAL_ANGLES[cell_orientation]

        State.cursor_position = new_cursor_position

func quit_game() -> void:
    print("Quitting game...")
    get_tree().quit()

static func get_cells_dictionary_from_json(json: String) -> Dictionary:
    var raw_dict : Dictionary = JSON.parse(json).result
    var cells : Dictionary = {}

    for key in raw_dict.keys():
        cells[str2var(key)] = raw_dict[key]

    return cells

static func gridmap_to_json(path: String) -> String:
    var cells := {}
    var gridmap_instance : GridMap = (ResourceLoader.load(path) as PackedScene).instance()
    var cell_positions := gridmap_instance.get_used_cells()

    for cell_position in cell_positions:
        var cell_id := gridmap_instance.get_cell_item(cell_position.x, cell_position.y, cell_position.z)
        var cell_orientation := gridmap_instance.get_cell_item_orientation(cell_position.x, cell_position.y, cell_position.z)
        cells[var2str(cell_position)] = [cell_id, cell_orientation]

    gridmap_instance.free()

    return JSON.print(cells)

static func vector_is_equal_approx(v1: Vector3, v2: Vector3, epsilon: float = 0.05) -> bool:
    var difference := v1 - v2
    return difference.x < epsilon && difference.y < epsilon && difference.z < epsilon
