shader_type canvas_item;

uniform sampler2D trail_tex;
uniform float depth_scale;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 texel = TEXTURE_PIXEL_SIZE;
	//float trail = texture(trail_tex, UV).r;
	//COLOR = mix(COLOR, vec4(vec3(0.0), 1.0), trail);
	float hL = texture(trail_tex, UV - vec2(texel.x, 0.0)).r;
	float hR = texture(trail_tex, UV + vec2(texel.x, 0.0)).r;
	float hD = texture(trail_tex, UV - vec2(0.0, texel.y)).r;
	float hU = texture(trail_tex, UV + vec2(0.0, texel.y)).r;
	
	float dx = (hR - hL) * depth_scale;
	float dy = (hU - hD) * depth_scale;
	
	vec3 normal = normalize(vec3(-dx, -dy, 1.0));
	vec3 light = vec3(-0.6, -0.3, 1.0);
	float brightness = dot(normal, light);
	COLOR = vec4(COLOR.xyz * brightness, 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
