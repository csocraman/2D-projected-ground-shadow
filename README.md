<img width="640" height="260" alt="title" src="https://github.com/user-attachments/assets/98b5e2e0-d0a1-4161-9ee1-a5d8c05e4e73" />

![Demostration](https://i.imgur.com/NW63TxJ.gif)

Generates a ground-projected shadow polygon based on collision points detected by several rays.

## Features

- ### Custom textures

Allows you to put custom textures on the shadow with `DropShadowCaster2D` node

> [!WARNING]
> If the shadows do not appear in the editor in TilemapLayers, just change any property of the TilemapLayer and then change it back.

![Demostration2](https://i.imgur.com/SW6X1EN.png)

![Demostration3](https://i.imgur.com/UH5yoa1.gif)

<!-- ### Customizable level of detail
![Demostration2](https://i.imgur.com/45sw6wJ.gif)-->

- ### Animated Shadows

Shadows can also be animated with the `AnimatedDropShadowCaster2D` node

![Demostration4](https://i.imgur.com/rn5fw9q.gif)
|`AnimatedDropShadowCaster2D` methods|
|---|
|float get_animation_duration(animationname: String)|
|AtlasTexture get_current_frame()
|void pause()
|void play(animationname: String)
|void stop()
