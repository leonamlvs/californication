"""Blender 4.2 authoring: traced coast, editable terrain relief, reference color atlas.

blender --background --factory-startup --python-exit-code 1 --python tools/generate_island_asset.py
Requires the measured V2 reference bundle and local OpenCV tool dependency.
"""
from pathlib import Path
import sys, json, math, hashlib
import bpy
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt, tessellate_polygon
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/island-authoring-deps'))
import cv2
import numpy as np

SOURCE=ROOT/'art/source/island_intro'
ASSETS=ROOT/'dev/island_scene/assets'
EVIDENCE=ROOT/'docs/evidence/island_intro/v2'


def main():
    config=json.loads((SOURCE/'authoring.json').read_text())
    measured=json.loads((EVIDENCE/'reference-measurements.json').read_text())
    ASSETS.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    ref=cv2.imread(str(ROOT/measured['reference_image']))
    mask=cv2.imread(str(EVIDENCE/'reference/land-mask.png'),cv2.IMREAD_GRAYSCALE)
    distance=cv2.distanceTransform(mask,cv2.DIST_L2,5)
    coast=np.array(measured['coastline'],np.float64)
    if cv2.contourArea(coast.astype(np.float32),oriented=True)<0: coast=coast[::-1]
    points=coast.tolist()
    spacing=config['mesh_grid_pixels']
    dl,dt,dr,db=config['detail_rect']
    for y in np.arange(45,640,spacing):
        for x in np.arange(300,700,spacing):
            if distance[int(y),int(x)]>2.0:
                points.append([float(x),float(y)])
    for y in np.arange(dt,db,config['detail_grid_pixels']):
        for x in np.arange(dl,dr,config['detail_grid_pixels']):
            if distance[int(y),int(x)]>1.0:points.append([float(x),float(y)])
    corner=len(points);points.extend([[dl,dt],[dr,dt],[dr,db],[dl,db]])
    detail_edges=[(corner+i,corner+(i+1)%4) for i in range(4)]
    coords,edges,faces,*_=delaunay_2d_cdt([Vector(p) for p in points],detail_edges,[list(range(len(coast)))],1,0.01,True)
    faces=[face for face in faces if cv2.pointPolygonTest(coast.astype(np.float32),tuple(np.mean([coords[i] for i in face],axis=0)),False)>=0]
    pixels=np.array(coords,dtype=float)
    heights=np.zeros(len(pixels))
    for ridge in config['ridges']:
        chain=np.array(ridge['points'],float)
        influence=np.zeros(len(pixels))
        for a,b in zip(chain[:-1],chain[1:]):
            vector=b[:2]-a[:2]
            t=np.clip(((pixels-a[:2])*vector).sum(axis=1)/(vector@vector),0,1)
            d=np.linalg.norm(pixels-(a[:2]+t[:,None]*vector),axis=1)
            strength=a[2]+t*(b[2]-a[2])
            influence=np.maximum(influence,strength*np.exp(-(d/ridge['width_pixels'])**1.55))
        heights=np.maximum(heights,influence)
    px=np.clip(np.rint(pixels[:,0]).astype(int),0,959); py=np.clip(np.rint(pixels[:,1]).astype(int),0,719)
    shore=np.clip(distance[py,px]/config['shore_fade_pixels'],0,1)
    shore=shore*shore*(3-2*shore)
    rng=np.random.default_rng(2302)
    noise_image=cv2.resize(rng.normal(0,0.55,(36,48)).astype(np.float32),(960,720),interpolation=cv2.INTER_CUBIC)
    noise_image+=cv2.resize(rng.normal(0,0.18,(90,120)).astype(np.float32),(960,720),interpolation=cv2.INTER_CUBIC)
    noise=noise_image[py,px]
    heights=(config['terrain_base_height']+heights+noise*config['relief_noise_height'])*shore
    # Boundary goes below the opaque water plane. Interior and boundary share vertices.
    boundary=[]
    edge_counts={}
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            key=tuple(sorted((a,b))); edge_counts[key]=edge_counts.get(key,0)+1
    for a,b in [edge for edge,n in edge_counts.items() if n==1]:
        boundary.extend([a,b])
    boundary=set(boundary)
    for i in boundary: heights[i]=config['submerged_edge']
    ppu=config['pixels_per_unit']; elevation=math.radians(config['camera_elevation_degrees'])
    vertices=[((x-480)/ppu,-((y-360)/ppu/math.sin(elevation)+h/math.tan(elevation)),float(h)) for (x,y),h in zip(pixels,heights)]
    # Pixel y is downward, so reverse projected triangles for upward Blender normals.
    triangles=[tuple(reversed(face)) for face in faces]
    side_vertices={}
    for i in sorted(boundary):
        side_vertices[i]=len(vertices)
        x,y,_=vertices[i]
        vertices.append((x,y,config['underside_height']))
    for (a,b),n in edge_counts.items():
        if n==1:
            # Recalculate face normals below, ensuring the skirt faces outward.
            triangles.extend([(a,b,side_vertices[b]),(a,side_vertices[b],side_vertices[a])])
    # Tessellate only the boundary for the unseen underside, retaining the concave coast.
    neighbors={i:[] for i in boundary}
    for (a,b),n in edge_counts.items():
        if n==1: neighbors[a].append(b);neighbors[b].append(a)
    ring=[min(boundary)]
    while True:
        options=[i for i in neighbors[ring[-1]] if len(ring)<2 or i!=ring[-2]]
        nxt=options[0]
        if nxt==ring[0]:break
        ring.append(nxt)
    bottom_vectors=[Vector(vertices[side_vertices[i]]) for i in ring]
    triangles += [tuple(side_vertices[ring[i]] for i in tri) for tri in tessellate_polygon([bottom_vectors])]
    if len(triangles)>15000: raise RuntimeError(f'Triangle budget exceeded: {len(triangles)}')
    mesh=bpy.data.meshes.new('IslandTerrainMesh');mesh.from_pydata(vertices,[],triangles);mesh.update()
    island=bpy.data.objects.new('IslandTerrain',mesh);bpy.context.collection.objects.link(island)
    bpy.context.view_layer.objects.active=island;island.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    for face in mesh.polygons: face.use_smooth=True
    uv=mesh.uv_layers.new(name='ReferenceAtlas')
    left,top,right,bottom=config['atlas_rect']
    atlas=np.zeros((2048,2048,3),np.uint8)
    atlas[:,:1536]=cv2.resize(ref[top:bottom,left:right],(1536,2048),interpolation=cv2.INTER_CUBIC)
    # Reserve a separate detail tile within the same atlas for the tiny road
    # intersection. Registered earlier source frames supply actual markings;
    # each frame feathers into the next coarser image at its captured boundary.
    yy,xx=np.mgrid[0:496,0:496].astype(np.float32)
    rx=dl+xx/495*(dr-dl);ry=dt+yy/495*(db-dt)
    patch=cv2.remap(ref,rx,ry,cv2.INTER_CUBIC).astype(np.float32)
    for m in reversed(measured['measurements'][:-1]):
        source=cv2.imread(str(EVIDENCE/f'reference/original_{m["native_frame"]:04d}.png'))
        matrix=np.array(m['matrix'])
        sx=(matrix[0,0]*rx+matrix[0,1]*ry+matrix[0,2]).astype(np.float32)
        sy=(matrix[1,0]*rx+matrix[1,1]*ry+matrix[1,2]).astype(np.float32)
        sample=cv2.remap(source,sx,sy,cv2.INTER_LINEAR).astype(np.float32)
        edge=np.minimum.reduce([sx,sy,959-sx,719-sy])
        weight=np.clip(edge/90,0,1)
        weight*=np.clip(np.minimum.reduce([rx-dl,dr-rx,ry-dt,db-ry])/4,0,1)
        patch=patch*(1-weight[:,:,None])+sample*weight[:,:,None]
    atlas[8:504,1544:2040]=np.clip(patch,0,255).astype(np.uint8)
    # Replicate tile edge into an eight-pixel gutter for mip filtering.
    atlas[:512,1536:]=cv2.copyMakeBorder(atlas[8:504,1544:2040],8,8,8,8,cv2.BORDER_REPLICATE)
    cv2.imwrite(str(ASSETS/'island-color.png'),atlas)
    # All vertices map through the reference camera; underside uses the corresponding top UV.
    source_pixel=list(pixels)+[pixels[i] for i in sorted(boundary)]
    for face in mesh.polygons:
        center=np.mean([source_pixel[i] for i in face.vertices],axis=0)
        detail=dl+0.001<center[0]<dr-0.001 and dt+0.001<center[1]<db-0.001
        for loop_index in face.loop_indices:
            x,y=source_pixel[mesh.loops[loop_index].vertex_index]
            if detail:
                uv.data[loop_index].uv=((1544+(x-dl)/(dr-dl)*496)/2048,1-(8+(y-dt)/(db-dt)*496)/2048)
            else:
                uv.data[loop_index].uv=((x-left)/(right-left)*.75,1-(y-top)/(bottom-top))
    texture=bpy.data.images.load(str(ASSETS/'island-color.png'));texture.pack()
    mat=bpy.data.materials.new('BakedReferenceColor');mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial');emission=nodes.new('ShaderNodeEmission');image=nodes.new('ShaderNodeTexImage');image.image=texture
    mat.node_tree.links.new(image.outputs['Color'],emission.inputs['Color']);mat.node_tree.links.new(emission.outputs[0],out.inputs['Surface'])
    island.data.materials.append(mat)
    island['source_frame']=199;island['relief_is_inferred']=True;island['triangle_count']=len(triangles)
    # A color-only water plate for V2. Interior is occluded, and all water remains on one plane.
    ocean=ref.copy();ocean[cv2.erode(mask,np.ones((17,17),np.uint8))>0]=(202,222,112)
    cv2.imwrite(str(ASSETS/'ocean-static.png'),cv2.resize(ocean,(1024,1024),interpolation=cv2.INTER_AREA))
    camera_data=bpy.data.cameras.new('ReferenceCamera');camera=bpy.data.objects.new('ReferenceCamera',camera_data);bpy.context.collection.objects.link(camera)
    camera_data.type='ORTHO';camera_data.ortho_scale=32
    d=config['camera_distance'];camera.location=(0,-d*math.cos(elevation),d*math.sin(elevation));camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.scene.camera=camera
    scene=bpy.context.scene;scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'island.blend'))
    bpy.ops.object.select_all(action='DESELECT');island.select_set(True);bpy.context.view_layer.objects.active=island
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/'island.glb'),export_format='GLB',use_selection=True,export_materials='NONE',export_yup=True,export_cameras=False,export_lights=False)
    files=[ASSETS/'island.glb',ASSETS/'island-color.png',ASSETS/'ocean-static.png',SOURCE/'island.blend',SOURCE/'authoring.json']
    manifest=dict(triangles=len(triangles),surface_triangles=len(faces),vertices=len(vertices),materials=1,atlas=[2048,2048],
        bounds_min=np.min(vertices,axis=0).tolist(),bounds_max=np.max(vertices,axis=0).tolist(),
        blender=bpy.app.version_string,geometry='Closed inferred terrain relief; mountains through submerged beach edge; no water geometry',
        files=[dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files])
    (EVIDENCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('ISLAND_ASSET_GENERATED',len(triangles),'triangles',len(vertices),'vertices')


if __name__=='__main__':main()
