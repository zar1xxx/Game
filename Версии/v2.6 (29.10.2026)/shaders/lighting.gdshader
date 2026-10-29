// Освещение мира: время суток (день / закат / ночь) и источники света.
// Карта света считается в маленьком буфере (в 3–5 раз меньше экрана — свет мягкий,
// разница не видна, а телефону в десятки раз легче), затем растягивается на экран
// и умножается на картинку: белый = без изменений, тёмный = ночь.
shader_type canvas_item;

uniform vec3 grade = vec3(1.0);                       // цветокоррекция (оранжевый закат и т.п.)
uniform vec3 night_color = vec3(0.16, 0.19, 0.34);    // цвет ночной темноты
uniform float darkness = 0.0;                         // 0 — день, 1 — полная ночь
uniform vec2 rect_size = vec2(1152.0, 648.0);
uniform vec4 lights[40];                              // xy — позиция на экране, z — радиус, w — яркость
uniform int light_count = 0;
uniform vec4 cone = vec4(0.0);                        // фары игрока: xy — начало, zw — направление × длина

void fragment() {
	vec2 p = UV * rect_size;
	float lit = 0.0;
	for (int i = 0; i < 40; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 l = lights[i];
		float d = length(p - l.xy);
		lit += l.w * (1.0 - smoothstep(l.z * 0.2, l.z, d));
	}
	float len = length(cone.zw);
	if (len > 1.0) {
		vec2 nd = cone.zw / len;
		vec2 rel = p - cone.xy;
		float along = dot(rel, nd);
		float perp = abs(rel.x * nd.y - rel.y * nd.x);
		if (along > -10.0 && along < len) {
			float w = max(along, 0.0) * 0.42 + 26.0;
			lit += (1.0 - smoothstep(w * 0.55, w, perp)) * (1.0 - clamp(along / len, 0.0, 1.0)) * 1.4;
		}
	}
	lit = clamp(lit, 0.0, 1.0);
	vec3 dark = mix(vec3(1.0), night_color, darkness);
	vec3 lit_color = mix(vec3(1.0), vec3(1.0, 0.95, 0.82), darkness);
	COLOR = vec4(grade * mix(dark, lit_color, lit), 1.0);
}
