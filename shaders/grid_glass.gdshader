shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled;

uniform vec4 tint : source_color = vec4(0.17, 0.22, 0.29, 0.30);
uniform vec4 edge_tint : source_color = vec4(0.62, 0.78, 0.95, 0.72);
uniform float metallic = 0.28;
uniform float roughness = 0.20;

void fragment() {
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.4);
	ALBEDO = mix(tint.rgb, edge_tint.rgb, edge * 0.55);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	ALPHA = tint.a + edge * 0.22;
}
