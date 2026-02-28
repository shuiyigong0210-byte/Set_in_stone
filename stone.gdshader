shader_type canvas_item;

uniform sampler2D trail_tex;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	float trail = texture(trail_tex, UV).r;
	COLOR = mix(COLOR, vec4(vec3(0.0), 1.0), trail);
	//COLOR = vec4(vec3(trail), 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
