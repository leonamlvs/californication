"""Blender VSE fallback for Windows FFmpeg builds with a broken Theora encoder.

blender --background --factory-startup --python tools/encode_island_preview_blender.py -- SOURCE OUTPUT
"""
import sys
import bpy

source, destination = sys.argv[sys.argv.index("--") + 1:]
scene = bpy.context.scene
scene.sequence_editor_create().sequences.new_movie("Island intro", source, channel=1, frame_start=1)
scene.frame_start = 1
scene.frame_end = 104
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.fps = 30
scene.render.fps_base = 1.001
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.sequencer_colorspace_settings.name = "sRGB"
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "OGG"
scene.render.ffmpeg.codec = "THEORA"
scene.render.ffmpeg.audio_codec = "NONE"
scene.render.ffmpeg.video_bitrate = 8000
scene.render.use_file_extension = False
scene.render.filepath = destination
bpy.ops.render.render(animation=True)
