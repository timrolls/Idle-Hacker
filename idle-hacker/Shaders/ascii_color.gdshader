shader_type canvas_item;
render_mode unshaded;

const vec3 MONOCHROME_SCALE = vec3( 0.298912, 0.586611, 0.114478 );

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;
uniform sampler2D ascii_tex : source_color;
uniform sampler2D palette_tex : source_color;
uniform vec2 ascii_size = vec2( 8.0, 16.0 );
uniform int available_columns = 10;
uniform int max_columns = 16;
uniform float color_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float randomness : hint_range(0.0, 1.0) = 0.5;
uniform bool use_original_brightness = true;
uniform float black_threshold : hint_range(0.0, 0.2) = 0.05;

// Simple hash function for pseudo-random numbers
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 screen_uv = floor( SCREEN_UV / SCREEN_PIXEL_SIZE / ascii_size ) * SCREEN_PIXEL_SIZE * ascii_size;
	vec2 diff = ascii_size * SCREEN_PIXEL_SIZE;
	vec4 color = (
		textureLod( SCREEN_TEXTURE, screen_uv, 0.0 )
	+	textureLod( SCREEN_TEXTURE, screen_uv + vec2( 0.0, diff.y ), 0.0 )
	+	textureLod( SCREEN_TEXTURE, screen_uv + vec2( diff.x, 0.0 ), 0.0 )
	+	textureLod( SCREEN_TEXTURE, screen_uv + diff, 0.0 )
	) / 4.0;

	vec2 ascii_uv = fract( SCREEN_UV / SCREEN_PIXEL_SIZE / ascii_size );
	ascii_uv.x = ( 1.0 - ascii_uv.x ) / float( max_columns );
	float col = floor( dot( color.rgb, MONOCHROME_SCALE ) * float( available_columns ) ) / float( available_columns );
	
	// Get the ASCII character
	vec4 ascii_char = texture( ascii_tex, ascii_uv + vec2( col * ( float( available_columns ) / float( max_columns ) ), 0.0 ) );
	
	// Generate pseudo-random value based on screen position
	vec2 cell_pos = floor( SCREEN_UV / SCREEN_PIXEL_SIZE / ascii_size );
	float random_val = hash(cell_pos);
	
	// Calculate brightness for threshold check
	float brightness = dot(color.rgb, MONOCHROME_SCALE);
	
	// Only render characters if brightness is above threshold
	if (brightness < black_threshold) {
		// Keep negative space black
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Choose between original color and random palette color based on randomness
		vec3 final_color;
		
		if (random_val < randomness) {
			// Use random palette color
			vec2 palette_uv = vec2(hash(cell_pos + vec2(1.0, 0.0)), 0.5);
			vec4 palette_color = texture( palette_tex, palette_uv );
			
			if (use_original_brightness) {
				// Scale palette color by original brightness but keep it vibrant
				final_color = palette_color.rgb * max(brightness, 0.3); // Minimum brightness for visibility
			} else {
				// Use palette color at full intensity
				final_color = palette_color.rgb;
			}
		} else {
			// Use original color converted to grayscale
			final_color = vec3(brightness);
		}
		
		// Apply color intensity
		final_color *= color_intensity;
		
		// Apply to ASCII character
		COLOR = vec4(final_color * ascii_char.rgb, ascii_char.a);
	}
}