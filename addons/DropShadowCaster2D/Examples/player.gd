extends CharacterBody2D

@onready var animatedsprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var dir = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	if dir != 0:
		velocity.x = lerp(velocity.x,200.0*dir,delta*5)
		animatedsprite.scale.x = dir * 2
		$AnimatedDropShadowCaster2D.scale.x = -dir
		if animatedsprite.animation != "walk" and animatedsprite.animation != "jump" or !animatedsprite.is_playing():
			animatedsprite.play("walk")
			$AnimatedDropShadowCaster2D.play("walk")
	else:
		if animatedsprite.animation != "idle" and animatedsprite.animation != "jump" or !animatedsprite.is_playing():
			animatedsprite.play("idle")
			$AnimatedDropShadowCaster2D.play("idle")
		velocity.x = lerp(velocity.x,0.0,delta*5)
	
	velocity.y += delta * 600
	
	if is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		animatedsprite.play("jump")
		$AnimatedDropShadowCaster2D.play("jump")
		velocity.y = -290
	move_and_slide()
