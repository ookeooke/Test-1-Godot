
# Define constants
UID_IDLE = "uid://dlvyirprm2omg"
PATH_IDLE = "res://assets/sprites/heroes/warrior/warrior_idle.png"
UID_WALK = "uid://c5grr5pgf8gal"
PATH_WALK = "res://assets/sprites/heroes/warrior/warrior_walking.png"
UID_ATTACK = "uid://rto24tpi4dgo"
PATH_ATTACK = "res://assets/sprites/heroes/warrior/warrior_attack.png"

FRAME_WIDTH = 1024
FRAME_HEIGHT = 256
FRAME_COUNT = 6

# Helper to generate AtlasTexture definitions
def generate_atlas_textures(anim_name, resource_id):
    output = ""
    for i in range(FRAME_COUNT):
        y_pos = i * FRAME_HEIGHT
        output += f"""[sub_resource type="AtlasTexture" id="AtlasTexture_{anim_name}_{i}"]
atlas = ExtResource("{resource_id}")
region = Rect2(0, {y_pos}, {FRAME_WIDTH}, {FRAME_HEIGHT})

"""
    return output

# Helper to generate animation frame list
def generate_anim_frames(anim_name):
    frames = ""
    for i in range(FRAME_COUNT):
        frames += f"""{{
"duration": 1.0,
"texture": SubResource("AtlasTexture_{anim_name}_{i}")
}}"""
        if i < FRAME_COUNT - 1:
            frames += ", "
    return frames

# Generate full content
content = f"""[gd_resource type="SpriteFrames" load_steps=22 format=3 uid="uid://warrior_frames_generated"]

[ext_resource type="Texture2D" uid="{UID_IDLE}" path="{PATH_IDLE}" id="1_idle"]
[ext_resource type="Texture2D" uid="{UID_WALK}" path="{PATH_WALK}" id="2_walk"]
[ext_resource type="Texture2D" uid="{UID_ATTACK}" path="{PATH_ATTACK}" id="3_attack"]

"""

content += generate_atlas_textures("idle", "1_idle")
content += generate_atlas_textures("run", "2_walk")
content += generate_atlas_textures("attack", "3_attack")

content += f"""[resource]
animations = [{{
"frames": [{generate_anim_frames("attack")}],
"loop": false,
"name": &"attack",
"speed": 10.0
}}, {{
"frames": [{generate_anim_frames("idle")}],
"loop": true,
"name": &"idle",
"speed": 10.0
}}, {{
"frames": [{generate_anim_frames("run")}],
"loop": true,
"name": &"run",
"speed": 10.0
}}]
"""

with open(r"c:\Users\ollil\Test-1-Godot\scenes\heroes\warrior_animations.tres", "w") as f:
    f.write(content)
