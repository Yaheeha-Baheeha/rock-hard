shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.2, 1.0);   // Bright Yellow (Extreme Density)
uniform vec4 body_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);   // Orange (Medium Density)
uniform vec4 crust_color : source_color = vec4(0.4, 0.05, 0.0, 1.0); // Dark Red (Outer Crust)

uniform float outer_edge = 0.4;  // The very edge of the fluid (everything below is invisible)
uniform float crust_edge = 0.45; // How thick the hard crust line is
uniform float core_start = 0.85; // How dense it needs to be to turn pure yellow

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 current_color = texture(screen_texture, SCREEN_UV);
    float alpha = current_color.a;
    
    // 1. Delete everything outside the fluid
    if (alpha < outer_edge) {
        COLOR = vec4(0.0);
    } 
    // 2. Draw the hard outer crust
    else if (alpha < crust_edge) {
        COLOR = crust_color;
    } 
    // 3. The interior Heatmap (Density Gradient)
    else {
        // Map the density from the inside of the crust (0.45) to the pure core (0.85)
        // This gives us a smooth number from 0.0 to 1.0 based on how deep inside the lava we are
        float heat = smoothstep(crust_edge, core_start, alpha);
        
        // Blend from Dark Red -> Orange -> Bright Yellow
        vec3 final_color;
        if (heat < 0.5) {
            // The outer half of the interior blends Crust to Orange
            float blend = smoothstep(0.0, 0.5, heat);
            final_color = mix(crust_color.rgb, body_color.rgb, blend);
        } else {
            // The inner half of the interior blends Orange to Yellow
            float blend = smoothstep(0.5, 1.0, heat);
            final_color = mix(body_color.rgb, core_color.rgb, blend);
        }
        
        COLOR = vec4(final_color, 1.0);
    }
}