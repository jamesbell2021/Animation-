# Stylised two-tone character material for Blender (supplied by the project owner, 2026-10-18).
# Run inside Blender: Scripting workspace > Open > Run Script.
# Builds a hard-stepped "painted" shader: Diffuse -> Shader to RGB -> constant ColorRamp -> Emission.
import bpy

def create_stylized_material(mat_name="Stylized_Character_Mat"):
    # Create a new material
    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear default nodes
    nodes.clear()

    # Add nodes
    output_node = nodes.new(type='ShaderNodeOutputMaterial')
    emission_node = nodes.new(type='ShaderNodeEmission')
    mix_node = nodes.new(type='ShaderNodeMixShader')
    diffuse_node = nodes.new(type='ShaderNodeBsdfDiffuse')
    shader_to_rgb = nodes.new(type='ShaderNodeValToRGB') # Shader to RGB
    color_ramp = shader_to_rgb.color_ramp
    
    # Configure Color Ramp for a stylized comic/painted look (hard steps)
    color_ramp.interpolation = 'CONSTANT'
    color_ramp.elements[0].position = 0.35
    color_ramp.elements[0].color = (0.2, 0.2, 0.25, 1.0) # Shadow color tint
    
    # Add a second stop for highlights
    element2 = color_ramp.elements.new(0.65)
    element2.color = (0.9, 0.9, 0.95, 1.0) # Light color tint

    # Link nodes together
    links.new(diffuse_node.outputs['BSDF'], shader_to_rgb.inputs['Shader'])
    links.new(shader_to_rgb.outputs['Color'], emission_node.inputs['Color'])
    
    # Connect to material output
    links.new(emission_node.outputs['Emission'], output_node.inputs['Surface'])

    print(f"Stylized material '{mat_name}' created successfully!")

# Run the function
create_stylized_material()
