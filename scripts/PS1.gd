extends CanvasLayer
## PS1-постобработка: рендер уже идёт в половинном разрешении
## (scaling_3d/scale=0.5), здесь поверх — дизеринг Байера 4x4 и
## квантование цвета до 5 бит на канал.

const DITHER_SHADER := "
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	c = floor(c * 31.0 + bayer2(0.5 * px) * 0.25 + bayer2(px)) / 31.0;
	COLOR = vec4(c, 1.0);
}
"

func _ready() -> void:
	layer = 5
	var rect := ColorRect.new()
	var sh := Shader.new()
	sh.code = DITHER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
