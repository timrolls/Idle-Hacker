# Color Palette Generator Script
# Add this as a tool script to generate your palette texture
@tool
extends EditorScript

func _run():
	# Colors extracted from your image
	var colors = [
		Color(0.0, 0.0, 0.0),      # Black
		Color(0.2, 0.2, 0.2),      # Dark Gray
		Color(0.5, 0.5, 0.5),      # Medium Gray
		Color(0.8, 0.8, 0.8),      # Light Gray
		Color(1.0, 0.0, 0.0),      # Bright Red
		Color(0.8, 0.0, 0.0),      # Dark Red
		Color(0.0, 0.0, 1.0),      # Bright Blue
		Color(0.0, 0.0, 0.8),      # Dark Blue
		Color(0.0, 0.8, 1.0),      # Bright Cyan
		Color(0.0, 0.6, 0.8),      # Medium Cyan
		Color(0.0, 1.0, 1.0),      # Pure Cyan
		Color(1.0, 1.0, 1.0),      # White
	]
	
	# Create the palette texture
	var width = colors.size()
	var height = 1
	var image = Image.create(width, height, false, Image.FORMAT_RGB8)
	
	# Fill with colors
	for i in range(colors.size()):
		image.set_pixel(i, 0, colors[i])
	
	# Save as ImageTexture resource
	var texture = ImageTexture.create_from_image(image)
	ResourceSaver.save(texture, "res://palette_texture.tres")
	
	print("Palette texture created and saved as 'palette_texture.tres'")
	print("Colors included: ", colors.size())
