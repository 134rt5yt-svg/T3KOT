extends CanvasLayer
## Капли дождя на «экране»: два слоя маленьких капель, стекающих вниз,
## с тонким хвостом и лёгким преломлением картинки под каплей.
## Живёт под PS1-слоем, так что дизеринг ложится уже поверх капель.

const WET_SHADER := "
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float wetness : hint_range(0.0, 1.0) = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	// Весь эффект живёт в «жирных» PS1-пикселях 3x3.
	vec2 px = floor((SCREEN_UV / SCREEN_PIXEL_SIZE) / 3.0) * 3.0;
	vec2 uv = SCREEN_UV;
	float drop_all = 0.0;

	for (int layer = 0; layer < 2; layer++) {
		float lf = float(layer);
		vec2 grid = vec2(30.0, 55.0) * (1.0 + lf * 0.7);
		vec2 g = px / grid;
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float h = hash12(cell + lf * 31.7);
		float active = step(0.66, h);
		if (active < 0.5) { continue; }
		float speed = 0.3 + h * 0.7;
		// Движение ступенчатое — капля «прыгает» по 1/12 ячейки, без плавности.
		float stepped = floor((h * 13.0 + TIME * speed) * 12.0) / 12.0;
		float y = fract(stepped);
		float x = 0.2 + fract(h * 57.3) * 0.6;
		vec2 rel = f - vec2(x, y);
		// капля: маленький овал
		float head = smoothstep(0.06, 0.0, length(rel * vec2(1.0, 0.6)));
		// тонкий хвост над каплей
		float tail = (1.0 - smoothstep(0.008, 0.02, abs(rel.x)))
			* smoothstep(0.0, 0.06, -rel.y)
			* smoothstep(0.28, 0.02, -rel.y);
		float d = clamp(head + tail * 0.7, 0.0, 1.0);
		uv += rel * d * 0.0025 * wetness;
		drop_all = max(drop_all, d);
	}

	drop_all *= wetness;
	vec3 c = texture(screen_tex, uv).rgb;
	c += drop_all * 0.07;
	COLOR = vec4(c, 1.0);
}
"

func _ready() -> void:
	layer = 4
	var rect := ColorRect.new()
	var sh := Shader.new()
	sh.code = WET_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

func set_wetness(v: float) -> void:
	pass  # дождь постоянный; параметр оставлен на будущее
