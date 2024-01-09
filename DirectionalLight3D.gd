@tool
extends DirectionalLight3D

func _process(_delta):
	(%PostProcessing as MeshInstance3D).mesh.surface_get_material(0).set_shader_parameter('light_direction', -global_basis.z)
