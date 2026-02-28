shader_type canvas_item;

uniform sampler2D u_trail_tex;
uniform float u_depth_scale;
uniform vec2 u_viewport_topleft;
uniform vec2 u_viewport_size;
uniform vec2 u_resolution;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 texel = 1.0 / u_resolution;
	//float trail = texture(trail_tex, UV).r;
	//COLOR = mix(COLOR, vec4(vec3(0.0), 1.0), trail);
	vec2 uv = (UV - u_viewport_topleft) / u_viewport_size;
	float hL = texture(u_trail_tex, uv - vec2(texel.x, 0.0)).r;
	float hR = texture(u_trail_tex, uv + vec2(texel.x, 0.0)).r;
	float hD = texture(u_trail_tex, uv - vec2(0.0, texel.y)).r;
	float hU = texture(u_trail_tex, uv + vec2(0.0, texel.y)).r;
	
	float dx = (hR - hL) * u_depth_scale;
	float dy = (hU - hD) * u_depth_scale;
	
	vec3 normal = normalize(vec3(-dx, -dy, 1.0));
	vec3 light = vec3(0.6, 0.3, 1.0);
	float brightness = dot(normal, light);
	COLOR = vec4(COLOR.xyz * brightness, 1.0);
	//COLOR = vec4(uv, 0.0, 1.0);
	//COLOR = vec4(texture(u_trail_tex, uv).r, 0.0, 0.0, 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
