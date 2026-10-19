"""Reference pixel extraction, using Blender's NumPy and local OpenCV.

blender --background --factory-startup --python-exit-code 1 --python tools/build_ocean_color_texture.py
This rebuilds generated art. Do not rerun over manual painting without a backup.
"""
from pathlib import Path
import hashlib, json, sys, zipfile, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/island-authoring-deps'))
import cv2
import numpy as np

SOURCE = ROOT / 'docs/evidence/island_intro/v0/reference/original_0199.png'
LAND = ROOT / 'docs/evidence/island_intro/v2/reference/land-mask.png'
EDIT = ROOT / 'art/source/island_intro/ocean-color'
RUNTIME = ROOT / 'frontend/island/live/assets'
EVIDENCE = ROOT / 'docs/evidence/island_intro/ocean-color'


def png(path, pixels):
    path.parent.mkdir(parents=True, exist_ok=True)
    assert cv2.imwrite(str(path), pixels)


def main():
    EDIT.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    ref = cv2.imread(str(SOURCE))
    land = cv2.imread(str(LAND), 0)
    assert ref.shape == (720, 960, 3) and land.shape == (720, 960)
    distance = cv2.distanceTransform(255-land, cv2.DIST_L2, 5)
    # Keep the bright cyan coast. Separate the outer bright bands; the mask is
    # supplied as editable art because a single frame cannot uniquely unmix waves.
    highpass = cv2.morphologyEx(ref[:,:,1], cv2.MORPH_TOPHAT,
                              cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(45,45)))
    wave = ((distance > 36) & (highpass > 9) & (ref[:,:,0] > 90)).astype(np.uint8)*255
    wave = cv2.morphologyEx(wave, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8))
    wave = cv2.dilate(wave, np.ones((7,7), np.uint8))
    wave[distance < 30] = 0
    cleaned = cv2.inpaint(ref, wave, 9, cv2.INPAINT_TELEA)
    # Nearest water extension underneath the entire 3D island, never green land.
    excluded = cv2.dilate(land,np.ones((7,7),np.uint8))
    _, labels = cv2.distanceTransformWithLabels(excluded, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    clean = cleaned.copy()
    clean[land > 0] = cleaned[excluded == 0][labels[land > 0]-1]
    # Source patch far from the coast: mirrored quadrants form a periodic tile
    # without changing its colors or synthesizing water.
    patch = ref[260:388, 24:152]
    tile = np.concatenate([np.concatenate([patch, patch[:,::-1]],1),
                           np.concatenate([patch[::-1], patch[::-1,::-1]],1)],0)
    y,x = np.mgrid[:720,:960]
    edge = np.minimum.reduce([x,959-x,y,719-y]).astype(np.float32)
    alpha = np.clip(edge/48.0,0,1)
    alpha = alpha*alpha*(3-2*alpha)
    # Protect the coast inside the feather, while keeping the image boundary zero.
    coast = np.clip((distance-24)/16,0,1)
    alpha = np.maximum(alpha, (1-coast)*np.clip(edge/24,0,1))
    alpha[land > 0] = 1
    mask = np.rint(alpha*255).astype(np.uint8)
    # Frame edges are always deep ocean in this reference.
    assert mask[0].max()==0 and mask[-1].max()==0 and mask[:,0].max()==0 and mask[:,-1].max()==0
    guide = np.zeros((720,960,4), np.uint8)
    contours,_=cv2.findContours(land,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(guide,contours,-1,(40,40,255,255),1)
    wave_rgba = np.dstack([ref, wave])
    outputs = {'reference.png':ref, 'coastline-guide.png':guide, 'base-water.png':clean,
               'wave-appearance.png':wave_rgba, 'wave-mask.png':wave,
               'coastal-blend-mask.png':mask, 'deep-water-tile.png':tile}
    for name, data in outputs.items(): png(EDIT/name,data)
    for name,data in [('ocean-color.png',clean),('ocean-color-mask.png',mask),('ocean-deep-color.png',tile)]:
        png(RUNTIME/name,data)
    # OpenRaster stack is top-to-bottom. Reference/guide/waves start hidden;
    # the default merged image is the clean water ready for manual painting.
    layers=[('Untouched reference','reference.png',False),('Coastline guide','coastline-guide.png',False),
            ('Extracted waves','wave-appearance.png',False),('Wave mask','wave-mask.png',False),
            ('Coastal blend mask','coastal-blend-mask.png',False),('Base water - EDIT THIS','base-water.png',True),
            ('Deep-water tile - 256x256','deep-water-tile.png',False)]
    root=ET.Element('image',{'w':'960','h':'720','name':'Reference ocean - static colors','version':'0.0.3'})
    stack=ET.SubElement(root,'stack')
    with zipfile.ZipFile(EDIT/'ocean-color.ora','w',zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('mimetype','image/openraster',compress_type=zipfile.ZIP_STORED)
        for i,(name,file,visible) in enumerate(layers):
            src=f'data/layer{i}.png'
            ET.SubElement(stack,'layer',{'name':name,'src':src,'x':'0','y':'0','opacity':'1.0',
                        'visibility':'visible' if visible else 'hidden','composite-op':'svg:src-over'})
            archive.write(EDIT/file,src)
        archive.writestr('stack.xml',ET.tostring(root,encoding='utf-8',xml_declaration=True))
        archive.write(EDIT/'base-water.png','mergedimage.png')
        ok,thumb=cv2.imencode('.png',cv2.resize(clean,(256,192))); assert ok
        archive.writestr('Thumbnails/thumbnail.png',thumb.tobytes())
    files=[SOURCE,LAND,Path(__file__).resolve(),*sorted(EDIT.glob('*.png')),EDIT/'ocean-color.ora',
           *[RUNTIME/n for n in ['ocean-color.png','ocean-color-mask.png','ocean-deep-color.png']]]
    manifest=dict(source_native_frame=199,canvas=[960,720],map_size=[32,24.536174277],
                  deep_patch=[24,260,152,388],wave_mask_pixels=int((wave>0).sum()),
                  algorithm='outer-band mask + Telea neighboring-pixel inpaint; nearest-water land extension; mirrored source deep tile',
                  limitations='Wave/base separation is an editable approximation from one frame. No unseen detail or AI generation.',
                  files=[dict(path=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files])
    (EVIDENCE/'assets.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('OCEAN_COLOR_ASSETS_PASS', manifest['wave_mask_pixels'], 'wave-mask pixels')


if __name__=='__main__': main()
