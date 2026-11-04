// Post-processing (port of ScanlineShader.ts + DamageFlashShader.ts):
// alternating rows are darkened/brightened with a light blue tint (CRT look),
// then the screen is tinted red with a vignette when the player takes damage.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Strength of the scanline effect.
uniform float scanline_intensity = 0.03;
uniform vec3 scanline_color = vec3(0.608, 0.753, 0.922);
// 0..1, set every frame from Player.damage_flash_intensity.
uniform float damage_intensity = 0.0;
uniform vec3 flash_color = vec3(0.8, 0.063, 0.063);

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);

	// Mask centered around 1.0, so the average brightness stays the same
	float row = mod(floor(FRAGCOORD.y), 5.0);
	float mask = 1.0 + scanline_intensity * (0.5 - row);
	vec3 rgb = color.rgb * mask + scanline_color * 0.12;

	// The center always keeps 35% of the flash so it never looks like a hole
	float dist = length(SCREEN_UV - 0.5);
	float vignette = smoothstep(0.1, 0.75, dist);
	float strength = damage_intensity * mix(0.35, 1.0, vignette);

	COLOR = vec4(mix(rgb, flash_color, strength), 1.0);
}
