class_name GrassReadabilityProfile
extends Resource
@export_range(1.25,3.0,0.05) var reaction_time:=1.5
@export_range(0.5,4.0,0.1) var corridor_half_width:=2.4
@export_range(0.0,100.0,0.5) var dense_grass_start_distance:=26.0
func allows_dense_dressing(distance:float,speed:float)->bool:
	return distance >= maxf(dense_grass_start_distance,speed*reaction_time)
