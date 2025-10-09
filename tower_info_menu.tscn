[gd_scene load_steps=2 format=3 uid="uid://c8xk9plqw2m6b"]

[ext_resource type="Script" path="res://tower_info_menu.gd" id="1_tower_info"]

[node name="TowerInfoMenu" type="Control"]
custom_minimum_size = Vector2(300, 200)
layout_mode = 3
anchors_preset = 0
offset_right = 300.0
offset_bottom = 200.0
script = ExtResource("1_tower_info")

[node name="Panel" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="MarginContainer" type="MarginContainer" parent="Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 15
theme_override_constants/margin_top = 15
theme_override_constants/margin_right = 15
theme_override_constants/margin_bottom = 15

[node name="VBoxContainer" type="VBoxContainer" parent="Panel/MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="TowerNameLabel" type="Label" parent="Panel/MarginContainer/VBoxContainer"]
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Archer Tower"
horizontal_alignment = 1

[node name="StatsLabel" type="Label" parent="Panel/MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Damage: 15
Attack Speed: 1.2/s
Range: 300"

[node name="HSeparator" type="HSeparator" parent="Panel/MarginContainer/VBoxContainer"]
layout_mode = 2

[node name="HBoxContainer" type="HBoxContainer" parent="Panel/MarginContainer/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="UpgradeButton" type="Button" parent="Panel/MarginContainer/VBoxContainer/HBoxContainer"]
custom_minimum_size = Vector2(120, 50)
layout_mode = 2
size_flags_horizontal = 3
text = "Upgrade"

[node name="CostLabel" type="Label" parent="Panel/MarginContainer/VBoxContainer/HBoxContainer/UpgradeButton"]
layout_mode = 0
offset_left = 35.0
offset_top = 30.0
offset_right = 85.0
offset_bottom = 53.0
theme_override_colors/font_color = Color(1, 1, 0, 1)
text = "150g"
horizontal_alignment = 1

[node name="SellButton" type="Button" parent="Panel/MarginContainer/VBoxContainer/HBoxContainer"]
custom_minimum_size = Vector2(120, 50)
layout_mode = 2
size_flags_horizontal = 3
text = "Sell (70g)"