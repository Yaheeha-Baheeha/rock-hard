shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White outline
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;
uniform bool is_active = false; // We will toggle this from the script!

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	if (is_active) {
		vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
		float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
		outline = min(outline, 1.0);
		
		vec4 final_color = mix(col, outline_color, outline - col.a);
		COLOR = vec4(final_color.rgb, max(col.a, outline));
	} else {
		COLOR = col;
	}
}