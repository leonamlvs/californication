"""Generate V3 packed shore data and periodic ripple noise using Blender's NumPy/OpenCV.

blender --background --factory-startup --python-exit-code 1 --python tools/generate_island_ocean.py
No editable island geometry, atlas, or historical V2 evidence is rewritten.
"""
from pathlib import Path
import sys, json, math, hashlib
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/island-authoring-deps'))
import cv2
import numpy as np
import bpy


def periodic_noise(size, seed):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[:size, :size].astype(np.float64) / size
    noise = np.zeros((size, size), np.float64)
    # Integer frequencies guarantee periodicity in both axes, including derivatives.
    for frequency, count, amplitude in [(2, 12, 1.0), (5, 18, .45), (13, 24, .15)]:
        for _ in range(count):
            kx, ky = rng.integers(-frequency, frequency + 1, 2)
            if kx == ky == 0:
                kx = 1
            noise += amplitude / math.sqrt(count) * np.sin(2 * math.pi * (kx*x + ky*y) + rng.uniform(0, 2*math.pi))
    return np.clip(.5 + noise / (6 * noise.std()), 0, 1).astype(np.float32)


def main():
    config_path = ROOT / 'art/source/island_intro/ocean-authoring.json'
    config = json.loads(config_path.read_text())
    output = ROOT / 'dev/island_scene/assets'
    evidence = ROOT / 'docs/evidence/island_intro/v3'
    evidence.mkdir(parents=True, exist_ok=True)
    ref = cv2.imread(str(ROOT / config['reference']))[:, :, ::-1].astype(np.float32) / 255
    land = cv2.imread(str(ROOT / config['land_mask']), cv2.IMREAD_GRAYSCALE)
    # Find nearest water pixel for safe color extension underneath the closed island.
    _, labels = cv2.distanceTransformWithLabels(land, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    water_colors = ref[land == 0]
    extended = water_colors[labels - 1]
    smooth = cv2.GaussianBlur(extended, (0, 0), config['color_smoothing_pixels'])
    colors = {name: np.array([int(config[name][i:i+2], 16)/255 for i in (0,2,4)], np.float32)
              for name in ['deep_color', 'shelf_color', 'shallow_color']}
    basis = np.stack([colors['shallow_color']-colors['deep_color'], colors['shelf_color']-colors['deep_color']], axis=1)
    coefficients = (smooth-colors['deep_color']) @ np.linalg.pinv(basis).T
    # Nonnegative constrained fit, total <= 1. Remove distant source wave rings.
    coefficients = np.maximum(coefficients, 0)
    coefficients /= np.maximum(coefficients.sum(axis=2, keepdims=True), 1)
    height = round(720 / math.sin(math.radians(config['elevation_degrees'])))
    water_world = cv2.resize(255-land, (960, height), interpolation=cv2.INTER_NEAREST)
    distance = cv2.distanceTransform(water_world, cv2.DIST_L2, cv2.DIST_MASK_PRECISE) / config['pixels_per_unit']
    distance = cv2.resize(distance, (960,720), interpolation=cv2.INTER_LINEAR)
    envelope = np.clip((2.2-distance)/.8, 0, 1)
    envelope = envelope*envelope*(3-2*envelope)
    coefficients *= envelope[:, :, None]
    foam = cv2.resize(periodic_noise(256, config['seed']+1), (960,720), interpolation=cv2.INTER_LINEAR)
    packed = np.stack([np.minimum(distance/config['distance_range_units'], 1), coefficients[:,:,0], foam, coefficients[:,:,1]], axis=2)
    packed = cv2.resize(packed, (config['shore_resolution'],)*2, interpolation=cv2.INTER_LINEAR)
    # Guard band gives a constant deep-water value at every texture boundary.
    yy, xx = np.mgrid[:config['shore_resolution'], :config['shore_resolution']]
    edge = np.minimum.reduce([xx, yy, config['shore_resolution']-1-xx, config['shore_resolution']-1-yy])
    fade = np.clip(edge/24, 0, 1).astype(np.float32)
    fade = fade*fade*(3-2*fade)
    packed[:,:,0] = 1-(1-packed[:,:,0])*fade
    packed[:,:,1] *= fade
    packed[:,:,3] *= fade
    packed[:,:,2] = .5+(packed[:,:,2]-.5)*fade
    packed8 = np.rint(packed*255).astype(np.uint8)
    cv2.imwrite(str(output/'ocean-shore.png'), packed8[:,:,[2,1,0,3]])
    noise = np.rint(periodic_noise(config['ripple_resolution'],config['seed'])*255).astype(np.uint8)
    cv2.imwrite(str(output/'ocean-ripple.png'), noise)
    profile_path=ROOT/'dev/island_scene/ocean.tres'
    profile='[gd_resource type="Resource" script_class="IslandOceanProfile" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://dev/island_scene/IslandOceanProfile.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n'
    for name,color in colors.items():
        profile+=name+' = Color('+', '.join(f'{v:.9f}' for v in color)+', 1)\n'
    profile+=f'map_size = Vector2({960/config["pixels_per_unit"]:.9f}, {720/config["pixels_per_unit"]/math.sin(math.radians(config["elevation_degrees"])):.9f})\n'
    profile+=f'distance_range = {config["distance_range_units"]}\n'
    profile_path.write_text(profile,encoding='utf-8')
    diagnostics = evidence/'maps'; diagnostics.mkdir(exist_ok=True)
    for index, name in enumerate(['distance','cyan','foam','shelf']):
        cv2.imwrite(str(diagnostics/(name+'.png')),packed8[:,:,index])
    reconstructed = colors['deep_color'] + coefficients @ basis.T
    reconstructed[land>0] = ref[land>0]
    cv2.imwrite(str(diagnostics/'color-fit.png'),np.rint(np.clip(reconstructed[:,:,::-1],0,1)*255).astype(np.uint8))
    near = (land == 0) & (distance < 1.5)
    files = [config_path, ROOT/config['reference'], ROOT/config['land_mask'], output/'ocean-shore.png', output/'ocean-ripple.png', profile_path]
    manifest = dict(schema=1,seed=config['seed'],blender=bpy.app.version_string,numpy=np.__version__,opencv=cv2.__version__,
        channels={'R':'shore distance / 4 world units','G':'cyan color coefficient','B':'local foam variation','A':'blue shelf coefficient'},
        near_water_rgb_mae_255=float(np.abs(reconstructed-ref)[near].mean()*255),
        note='Wave timings and texture patterns are authored approximations; reference-shaped cyan region is measured. No recovered original water shader is claimed.',
        files=[dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files])
    (evidence/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('ISLAND_OCEAN_GENERATED',json.dumps(manifest))


if __name__ == '__main__':
    main()
