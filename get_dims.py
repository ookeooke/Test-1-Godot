import struct
import os

files = [
    r"c:\Users\ollil\Test-1-Godot\assets\sprites\heroes\warrior\warrior_idle.png",
    r"c:\Users\ollil\Test-1-Godot\assets\sprites\heroes\warrior\warrior_walking.png",
    r"c:\Users\ollil\Test-1-Godot\assets\sprites\heroes\warrior\warrior_attack.png"
]

for f in files:
    with open(f, 'rb') as img:
        img.seek(16)
        w_bytes = img.read(4)
        h_bytes = img.read(4)
        width = struct.unpack('>I', w_bytes)[0]
        height = struct.unpack('>I', h_bytes)[0]
        print(f"{os.path.basename(f)}: {width}x{height}")
