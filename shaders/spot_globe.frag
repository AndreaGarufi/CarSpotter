#include <flutter/runtime_effect.glsl>

uniform vec4 uCanvas;
uniform vec4 uRotation;
uniform sampler2D uAtlas;
out vec4 fragColor;

void main() {
  vec2 p = (FlutterFragCoord().xy - uCanvas.xy) / uCanvas.z;
  float depth = sqrt(max(0.0, 1.0 - dot(p, p)));
  float rotatedZ = depth * uRotation.z + p.y * uRotation.w;
  vec3 world = vec3(
    p.x * uRotation.x + rotatedZ * uRotation.y,
    depth * uRotation.w - p.y * uRotation.z,
    rotatedZ * uRotation.x - p.x * uRotation.y
  );

  // Face order and orientation match the atlas generator and Dart hit test.
  vec3 magnitude = abs(world);
  vec2 tile;
  vec2 plane;
  if (magnitude.x >= magnitude.y && magnitude.x >= magnitude.z) {
    tile = vec2(world.x > 0.0 ? 0.0 : 1.0, 0.0);
    plane = vec2(world.x > 0.0 ? -world.z : world.z, -world.y) / magnitude.x;
  } else if (magnitude.y >= magnitude.z) {
    tile = world.y > 0.0 ? vec2(2.0, 0.0) : vec2(0.0, 1.0);
    plane = vec2(world.x, world.y > 0.0 ? world.z : -world.z) / magnitude.y;
  } else {
    tile = vec2(world.z > 0.0 ? 1.0 : 2.0, 1.0);
    plane = vec2(world.z > 0.0 ? world.x : -world.x, -world.y) / magnitude.z;
  }
  float tileSize = uCanvas.w;
  vec2 pixel = tile * tileSize + 1.0 + (plane * 0.5 + 0.5) * (tileSize - 2.0);
  vec3 surface = texture(uAtlas, pixel / (vec2(3.0, 2.0) * tileSize)).rgb;

  float light = clamp(dot(vec3(p, depth), vec3(-0.38, -0.47, 0.79)), 0.0, 1.0);
  fragColor = vec4(surface * mix(vec3(0.70, 0.74, 0.72), vec3(1.04), light), 1.0);
}
