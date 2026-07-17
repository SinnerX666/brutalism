shader_type canvas_item;

uniform sampler2D noise_tex;


void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	float noise_value = texture(noise_tex, UV).r;
	COLOR = vec4(base_color.rgb * (0.8 + noise_value * 0.2), base_color.a);
}
