# Sea They Are Angry - Blender Character Scene Setup
# Run inside Blender: Scripting workspace > Open > Run Script.
# Imports the supplied GLB keeper models, arranges them, creates studio lighting/camera,
# and saves sea_they_are_angry_keepers.blend beside this script.
import bpy, os
from mathutils import Vector
ASSET_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(ASSET_DIR, "sea_they_are_angry_keepers.blend")
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
files=[("Callum MacLeod","callum_keeper.glb",-4.5),("Hamish Fraser","hamish_keeper.glb",-1.5),("Mairi Campbell","mairi_keeper.glb",1.5),("Ewan Reid","ewan_keeper.glb",4.5)]
for name,filename,x in files:
    path=os.path.join(ASSET_DIR,filename)
    if not os.path.exists(path): print('Missing asset:',path); continue
    before=set(bpy.context.scene.objects); bpy.ops.import_scene.gltf(filepath=path)
    imported=[o for o in bpy.context.scene.objects if o not in before]
    coll=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(coll)
    for obj in imported:
        for old in list(obj.users_collection): old.objects.unlink(obj)
        coll.objects.link(obj); obj.location.x += x; obj['keeper_character']=name
    print('Imported',name,'with',len(imported),'objects')
bpy.ops.mesh.primitive_plane_add(size=30,location=(0,0,-0.08)); ground=bpy.context.object; ground.name='Studio Ground'
mat=bpy.data.materials.new('Storm Slate'); mat.diffuse_color=(0.025,0.055,0.085,1); ground.data.materials.append(mat)
def area_light(name,location,energy,color,size):
    bpy.ops.object.light_add(type='AREA',location=location); light=bpy.context.object; light.name=name
    light.data.energy=energy; light.data.color=color; light.data.shape='DISK'; light.data.size=size
    light.rotation_euler=(Vector((0,0,1.2))-light.location).to_track_quat('-Z','Y').to_euler(); return light
area_light('Cool Key',(0,-8,10),1700,(0.62,0.78,1.0),8)
area_light('Warm Rim',(3,5,7),1300,(1.0,0.58,0.28),6)
area_light('Soft Fill',(-8,0,5),800,(0.35,0.55,1.0),7)
bpy.ops.object.camera_add(location=(0,-18,6.2)); camera=bpy.context.object; camera.name='Keeper Lineup Camera'
target=Vector((0,0,1.7)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=13.8; bpy.context.scene.camera=camera
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=32
scene.render.resolution_x=1600; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.world.color=(0.015,0.025,0.05)
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:
    if obj.get('keeper_character'): obj.select_set(True)
if bpy.context.selected_objects: bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_FILE); print('Saved Blender project:',OUTPUT_FILE)
