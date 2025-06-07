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
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform int noise_octaves : hint_range(1, 4) = 3;
uniform float color_blend_smoothness : hint_range(0.0, 1.0) = 0.3;
uniform bool animate_colors = true;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 animation_direction = vec2(1.0, 0.5);
uniform float time_scale : hint_range(0.1, 10.0) = 1.0;

// Simple hash function for pseudo-random numbers
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 2D Simplex-like noise function
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	
	// Four corners
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	// Smooth interpolation
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Multi-octave noise for more natural patterns
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (int i = 0; i < octaves; i++) {
		value += amplitude * noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	
	return value;
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
	
	// Calculate brightness for threshold check
	float brightness = dot(color.rgb, MONOCHROME_SCALE);
	
	// Only render characters if brightness is above threshold
	if (brightness < 0.05) {
		// Keep negative space black
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Generate noise-based color selection
		vec2 cell_pos = floor( SCREEN_UV / SCREEN_PIXEL_SIZE / ascii_size );
		vec2 noise_coord = cell_pos * noise_scale * 0.01;
		
		// Add time-based animation if enabled
		if (animate_colors) {
			vec2 time_offset = TIME * animation_speed * animation_direction * time_scale;
			noise_coord += time_offset;
		}
		
		// Get noise value for smooth color transitions
		float noise_val = fbm(noise_coord, noise_octaves);
		
		// Generate random value for randomness control
		float random_val = hash(cell_pos);
		
		// Choose between original color and random palette color based on randomness
		vec3 final_color;
		
		if (random_val < randomness) {
			// Use noise-based palette color selection
			float normalized_noise = (noise_val + 1.0) * 0.5; // Convert from [-1,1] to [0,1]
			vec2 palette_uv = vec2(normalized_noise, 0.5);
			vec4 palette_color = texture( palette_tex, palette_uv );
			
			if (use_original_brightness) {
				// Scale palette color by original brightness but keep it vibrant
				final_color = palette_color.rgb * max(brightness, 0.3); // Minimum brightness for visibility
			} else {
				// Use palette color at full intensity
				final_color = palette_color.rgb;
			}
			
			// Optional: Blend with neighboring colors for even smoother transitions
			if (color_blend_smoothness > 0.0) {
				// Sample slightly offset noise for blending (also animated)
				vec2 blend_coord = noise_coord + vec2(0.1);
				float noise_offset = fbm(blend_coord, noise_octaves);
				float normalized_offset = (noise_offset + 1.0) * 0.5;
				vec4 blend_color = texture( palette_tex, vec2(normalized_offset, 0.5) );
				
				// Smooth blend factor based on noise gradients
				float blend_factor = smoothstep(0.0, 1.0, abs(noise_val - noise_offset)) * color_blend_smoothness;
				
				if (use_original_brightness) {
					blend_color.rgb *= max(brightness, 0.3);
				}
				
				final_color = mix(final_color, blend_color.rgb, blend_factor);
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