shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : source_color, hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : source_color, hint_normal_roughness_texture, filter_nearest;

uniform float depth_threshold : hint_range(0, 1) = 0.05;
uniform float normal_threshold : hint_range(0, 1) = 0.6;

uniform float darken_amount : hint_range(0, 1, 0.01) = 0.3;
uniform float lighten_amount : hint_range(0, 10, 0.01) = 1.5;

uniform vec3 light_direction = vec3(-0.96, -0.18, 0.2);

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth = get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal = texture(normal_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	vec2 texel_size = 1.0 / VIEWPORT_SIZE.xy;
	
	vec2 uvs[4];
	uvs[0] = vec2(SCREEN_UV.x, SCREEN_UV.y + texel_size.y);
	uvs[1] = vec2(SCREEN_UV.x, SCREEN_UV.y - texel_size.y);
	uvs[2] = vec2(SCREEN_UV.x + texel_size.x, SCREEN_UV.y);
	uvs[3] = vec2(SCREEN_UV.x - texel_size.x, SCREEN_UV.y);
	
	float depth_diff = 0.0;
	float nearest_depth = depth;
	vec2 nearest_uv = SCREEN_UV;
	
	float normal_sum = 0.0;
	for (int i = 0; i < 4; i++) {
		float d = get_depth(uvs[i], INV_PROJECTION_MATRIX);
		depth_diff += depth - d;
		
		if (d < nearest_depth) {
			nearest_depth = d;
			nearest_uv = uvs[i];
		}
		
		vec3 n = texture(normal_texture, uvs[i]).xyz * 2.0 - 1.0;
		vec3 normal_diff = normal - n;
		
		// Edge pixels should yield to the normal closest to the bias direction
		vec3 normal_edge_bias = vec3(1, 1, 1);
		float normal_bias_diff = dot(normal_diff, normal_edge_bias);
		float normal_indicator = smoothstep(-0.01, 0.01, normal_bias_diff);
		
		normal_sum += dot(normal_diff, normal_diff) * normal_indicator;
	}
	float depth_edge = step(depth_threshold, depth_diff);
	
	float indicator = sqrt(normal_sum);
	float normal_edge = step(normal_threshold, indicator);
	
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	vec3 nearest = texture(screen_texture, nearest_uv).rgb;
	
	mat3 view_to_world_normal_mat = mat3(
            INV_VIEW_MATRIX[0].xyz, 
            INV_VIEW_MATRIX[1].xyz,
            INV_VIEW_MATRIX[2].xyz
	);
	float ld = dot((view_to_world_normal_mat * normal), normalize(light_direction));
	
	vec3 edge_mix;
	if (depth_edge > 0.0) {
		edge_mix = mix(original, nearest * darken_amount, depth_edge);
	} else {
		edge_mix = mix(original, original * (ld > 0.0 ? darken_amount : lighten_amount), normal_edge);
	}
	
	ALBEDO = edge_mix;
}