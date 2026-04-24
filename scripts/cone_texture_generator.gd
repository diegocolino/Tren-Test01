@tool
class_name ConeTextureGenerator
extends Node


static func generate(size: Vector2i = Vector2i(1024, 512), origin_width: float = 0.02, max_width: float = 0.95, falloff: float = 1.4) -> ImageTexture:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	var center_y: float = size.y / 2.0

	for x: int in range(size.x):
		for y: int in range(size.y):
			var dist_x: float = float(x) / float(size.x)

			# Ancho del cono: casi 0 en el origen, max_width al final
			var cone_width: float = lerpf(origin_width, max_width, dist_x)

			var dist_y: float = abs(float(y) - center_y) / center_y

			var alpha: float = 0.0

			if dist_y <= cone_width:
				var horizontal_falloff: float = pow(1.0 - dist_x, falloff)
				var edge_softness: float = 1.0 - pow(dist_y / cone_width, 2.0)
				alpha = horizontal_falloff * edge_softness

			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)
