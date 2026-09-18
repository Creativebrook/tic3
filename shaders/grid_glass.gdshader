shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.17, 0.22, 0.29, 0.72);
uniform vec4 edge_tint : source_color = vec4(0.62, 0.78, 0.95, 0.90);
uniform float metallic = 0.28;
uniform float roughness = 0.20;
uniform float layer_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float layer_dim : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.4);
	vec3 surface_color = mix(tint.rgb, edge_tint.rgb, edge * 0.55);
	vec3 disabled_color = vec3(0.025, 0.032, 0.045);
	ALBEDO = mix(disabled_color, surface_color, layer_dim);
	METALLIC = metallic * layer_dim;
	ROUGHNESS = mix(0.72, roughness, layer_dim);
	ALPHA = clamp((tint.a + edge * 0.22) * layer_opacity, 0.0, 1.0);
}
