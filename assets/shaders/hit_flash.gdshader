shader_type canvas_item;

uniform bool active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	if (active) {
		vec3 flashed_rgb = mix(texture_color.rgb, flash_color.rgb, flash_intensity);
		COLOR = vec4(flashed_rgb, texture_color.a);
	} else {
		COLOR = texture_color;
	}
}
