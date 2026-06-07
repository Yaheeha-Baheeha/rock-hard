shader_type canvas_item;

// Lava Color Palette
uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.2, 1.0);   // Bright Yellow
uniform vec4 body_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);   // Orange
uniform vec4 crust_color : source_color = vec4(0.4, 0.05, 0.0, 1.0); // Dark Red/Brown 

// Thresholds to control the thickness of each layer
uniform float core_threshold = 0.65;
uniform float threshold = 0.45;
uniform float crust_thickness = 0.06; 

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Intercept the blurred background buffer created by the CanvasGroup
    vec4 current_color = texture(screen_texture, SCREEN_UV);
    float alpha = current_color.a;
    
    // Strict step thresholds eliminate pixel blur entirely, creating a sharp vector look
    float is_core = step(core_threshold, alpha);
    float is_body = step(threshold, alpha) - is_core;
    float is_crust = step(threshold - crust_thickness, alpha) - step(threshold, alpha);
    
    if (is_core > 0.0) {
        COLOR = core_color;
    } else if (is_body > 0.0) {
        COLOR = body_color;
    } else if (is_crust > 0.0) {
        COLOR = crust_color;
    } else {
        COLOR = vec4(0.0);
    }
}