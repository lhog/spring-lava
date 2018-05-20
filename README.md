# spring-lava
Fancy lava shader for SpringRTS maps

1. Cleaned up the existing version.
2. Added an option for fancy lava. Lava details are drawn with respect of viewing distance (something like mipmaping, but for procedurally generated textures)
3. Removed ugly black (void) water texture
4. Heightmap now is bilinearly interpolated and correctly applied as a texture effect
5. Texture becomes roughly same color as shores (configurable color)
6. Soft edges. Alpha is becoming 0.0 closer to the shore

https://drive.google.com/open?id=1RxHREt9jBmxOu-sIu6Pe78TsFHr7mmP8
