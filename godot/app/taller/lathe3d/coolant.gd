## Refrigerante (taladrina: emulsión de aceite soluble al 5 %, blanca lechosa), solo visual: un chorro de gotas
## desde la tobera hasta la punta y unas salpicaduras en la zona de corte (GPUParticles3D, que también funcionan en
## Compatibility). No moja ni enfría nada: el efecto físico del refrigerante es cosa del modelo de corte.
extends Node3D

var _stream: GPUParticles3D
var _splash: GPUParticles3D
var _on := false


## nozzle: nodo de la tobera (su −Z apunta a la punta). Las partículas viven en coordenadas globales, así que
## las ya emitidas no siguen al carro.
func setup(nozzle: Node3D) -> void:
	name = "Coolant"
	var drop := SphereMesh.new()
	drop.radius = 0.0006
	drop.height = 0.0012
	drop.radial_segments = 6
	drop.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.95, 0.97, 0.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.0
	drop.material = mat

	_stream = GPUParticles3D.new()
	_stream.name = "Stream"
	_stream.amount = 140
	_stream.lifetime = 0.075
	_stream.local_coords = false
	_stream.draw_pass_1 = drop
	_stream.emitting = false
	_stream.visibility_aabb = AABB(Vector3(-0.3, -0.3, -0.3), Vector3(0.6, 0.6, 0.6))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.0, -1.0)
	pm.spread = 3.5
	pm.initial_velocity_min = 1.35
	pm.initial_velocity_max = 1.55
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	_stream.process_material = pm
	nozzle.add_child(_stream)
	_stream.position = Vector3(0.0, 0.0, -0.022)

	_splash = GPUParticles3D.new()
	_splash.name = "Splash"
	_splash.amount = 40
	_splash.lifetime = 0.18
	_splash.local_coords = false
	_splash.draw_pass_1 = drop
	_splash.emitting = false
	_splash.visibility_aabb = AABB(Vector3(-0.3, -0.3, -0.3), Vector3(0.6, 0.6, 0.6))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.003
	sm.direction = Vector3(0.0, 1.0, 0.4)
	sm.spread = 70.0
	sm.initial_velocity_min = 0.25
	sm.initial_velocity_max = 0.6
	sm.gravity = Vector3(0.0, -9.8, 0.0)
	sm.scale_min = 0.5
	sm.scale_max = 1.0
	_splash.process_material = sm
	add_child(_splash)


## Enciende o apaga el refrigerante y coloca las salpicaduras en la punta (coordenadas globales).
func update(on: bool, tip_global: Vector3) -> void:
	if _stream == null:
		return
	_splash.global_position = tip_global
	if on != _on:
		_on = on
		_stream.emitting = on
		_splash.emitting = on
