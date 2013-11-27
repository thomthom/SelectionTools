#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'
require 'tt_selection_toys.rb'

#-----------------------------------------------------------------------------

module TT::Plugins::SelectionToys

  # Shim for the Set class which was moved in SketchUp 2014.
  if defined?(Sketchup::Set)
    Set = Sketchup::Set
  end

  require File.join( PATH, 'core_lib.rb' )
  require File.join( PATH, 'ui_manager.rb' )
  
  unless file_loaded?(__FILE__)
  # --- Constants --- #
  # Select Instance Flags
  S_DEFAULT = 0b0000 # Select components
  S_ACTIVE  = 0b0001 # Select only from active context
  S_LAYER   = 0b0010 # Select instances only on the same layer as those already selected
  S_DC      = 0b0100 # Select Dynamic Components
  S_GROUP	  = 0b1000 # Select Groups
  
  MAX_SEL_LENGTH = 1000 # Max size of selection to evaluate

  # --- UI Manager --- #
  config_file = File.join(PATH, 'ui_config.dat')
  @uim = UI_Manager.new(config_file)
  
  # --- Commands --- #
  # Select Tools
  @uim.add_command('SelectFaceLoops')             { self.tool(Select_Face_Loops.new) }
  # Component
  @uim.add_command('SelectActiveInstances')       { self.select_instances(S_ACTIVE) }
  @uim.add_command('SelectInstances')             { self.select_instances() }
  @uim.add_command('SelectActiveInstancesLayer')  { self.select_instances(S_ACTIVE | S_LAYER) }
  @uim.add_command('SelectInstancesLayer')        { self.select_instances(S_LAYER) }
  # Dynamic Component
  @uim.add_command('SelectDCActiveInstances')     { self.select_instances(S_DC | S_ACTIVE) }
  @uim.add_command('SelectDCInstances')           { self.select_instances(S_DC) }
  @uim.add_command('SelectDCActiveInstancesLayer'){ self.select_instances(S_DC | S_ACTIVE | S_LAYER) }
  @uim.add_command('SelectDCInstancesLayer')      { self.select_instances(S_DC | S_LAYER) }
  #Group
  @uim.add_command('SelectActiveGroups')          { self.select_instances(S_GROUP | S_ACTIVE) }
  @uim.add_command('SelectGroups')                { self.select_instances(S_GROUP) }
  @uim.add_command('SelectActiveGroupsLayer')     { self.select_instances(S_GROUP | S_ACTIVE | S_LAYER) }
  @uim.add_command('SelectGroupsLayer')           { self.select_instances(S_GROUP | S_LAYER) }
  @uim.add_command('GroupsToComponents')          { self.convert_group_copies_to_components() }
  # Edge
  @uim.add_command('QuadFaceLoop')                { self.select_quadface_loops() }
  # Face
  @uim.add_command('ConnectedPerpendicularFaces') { self.select_connected_perpendicular_faces() }
  @uim.add_command('ConnectedParallelFaces')      { self.select_connected_parallel_faces() }
  @uim.add_command('ConnectedCoplanarFaces')      { self.select_connected_planar_faces() }
  @uim.add_command('ConnectedFacesAngle')         { self.tool(Select_Connected_Faces_By_Angle_Tool.new) }
  @uim.add_command('ConnectedFacesArea')          { self.select_connected_same_area() }
  @uim.add_command('PerpendicularFaces')          { self.select_perpendicular_faces() }
  @uim.add_command('FacesSameDirection')          { self.select_same_direction_faces() }
  @uim.add_command('ParallelFaces')               { self.select_parallel_faces() }
  @uim.add_command('OppositeFaces')               { self.select_opposite_faces() }
  @uim.add_command('FacesArea')                   { self.select_same_area() }
  # Edge / Face
  @uim.add_command('ConnectedMaterial')           { self.select_connected_by_material(false) }
  @uim.add_command('ConnectedBackMaterial')       { self.select_connected_by_material(true) }
  @uim.add_command('ConnectedLayer')              { self.select_connected_by_layer() }
  # Entities
  @uim.add_command('SelectActiveLayers')          { self.select_active_by_selected_layers() }
  @uim.add_command('SelectAllLayers')             { self.select_by_selected_layers() }
  @uim.add_command('SelectActiveMaterials')       { self.select_active_by_selected_materials() }
  # Filter Selection
  @uim.add_command('SelectOnlyEdges')             { self.select(Sketchup::Edge) }
  @uim.add_command('SelectOnlyFaces')             { self.select(Sketchup::Face) }
  @uim.add_command('SelectOnlyGroups')            { self.select(Sketchup::Group) }
  @uim.add_command('SelectOnlyComponents')        { self.select(Sketchup::ComponentInstance) }
  @uim.add_command('SelectOnlyGuides')            { self.select(Sketchup::ConstructionLine) }
  @uim.add_command('SelectOnlyCPoints')           { self.select(Sketchup::ConstructionPoint) }
  @uim.add_command('SelectOnlyText')              { self.select(Sketchup::Text) }
  @uim.add_command('SelectOnlyImages')            { self.select(Sketchup::Image) }
  @uim.add_command('SelectOnlySections')          { self.select(Sketchup::SectionPlane) }
  @uim.add_command('SelectOnlyCurves')            { self.select() { |e| self.is_curve?(e) } }
  @uim.add_command('SelectOnlyArcs')              { self.select() { |e| self.is_arc?(e) } }
  @uim.add_command('SelectOnlyCircles')           { self.select() { |e| self.is_circle?(e) } }
  @uim.add_command('SelectOnlyPolygons')          { self.select() { |e| self.is_polygon?(e) } }
  @uim.add_command('SelectOnlyNGons')             { self.select() { |e| self.is_ngon?(e) } }
  @uim.add_command('SelectOnly3DPolylines')       { self.select_drawingelement('Polyline3d') }
  @uim.add_command('SelectOnlyLinearDimensions')  { self.select_drawingelement('DimensionLinear') }
  @uim.add_command('SelectOnlyRadialDimensions')  { self.select_drawingelement('DimensionRadial') }
  @uim.add_command('SelectOnlyFrontDefaultMaterial')  { self.select_default_material(false) }
  @uim.add_command('SelectOnlyBackDefaultMaterial')   { self.select_default_material(true) }
  @uim.add_command('SelectOnlyHidden')            { self.select() { |e| e.hidden? } }
  @uim.add_command('SelectOnlySoftEdges')         { self.select(Sketchup::Edge) { |e| e.soft? } }
  @uim.add_command('SelectOnlySmoothEdges')       { self.select(Sketchup::Edge) { |e| e.smooth? } }
  @uim.add_command('SelectOnlyEdgeBorder')        { self.select() { |e| self.is_border_edge?(e) } }
  @uim.add_command('SelectOnlySelectionBorder')   { self.select() { |e| self.is_selection_border?(e) } }
  # Deselect Selection
  @uim.add_command('DeselectEdges')               { self.deselect(Sketchup::Edge) }
  @uim.add_command('DeselectFaces')               { self.deselect(Sketchup::Face) }
  @uim.add_command('DeselectGroups')              { self.deselect(Sketchup::Group) }
  @uim.add_command('DeselectComponents')          { self.deselect(Sketchup::ComponentInstance) }
  @uim.add_command('DeselectGuides')              { self.deselect(Sketchup::ConstructionLine) }
  @uim.add_command('DeselectCPoints')             { self.deselect(Sketchup::ConstructionPoint) }
  @uim.add_command('DeselectText')                { self.deselect(Sketchup::Text) }
  @uim.add_command('DeselectImages')              { self.deselect(Sketchup::Image) }
  @uim.add_command('DeselectSections')            { self.deselect(Sketchup::SectionPlane) }
  @uim.add_command('DeselectCurves')              { self.deselect() { |e| self.is_curve?(e) } }
  @uim.add_command('DeselectArcs')                { self.deselect() { |e| self.is_arc?(e) } }
  @uim.add_command('DeselectCircles')             { self.deselect() { |e| self.is_circle?(e) } }
  @uim.add_command('DeselectPolygons')            { self.deselect() { |e| self.is_polygon?(e) } }
  @uim.add_command('DeselectNGons')               { self.deselect() { |e| self.is_ngon?(e) } }
  @uim.add_command('Deselect3DPolylines')         { self.deselect_drawingelement('Polyline3d') }
  @uim.add_command('DeselectLinearDimensions')    { self.deselect_drawingelement('DimensionLinear') }
  @uim.add_command('DeselectRadialDimensions')    { self.deselect_drawingelement('DimensionRadial') }
  @uim.add_command('DeselectFrontDefaultMaterial')  { self.deselect_default_material(false) }
  @uim.add_command('DeselectBackDefaultMaterial')   { self.deselect_default_material(true) }
  @uim.add_command('DeselectHidden')              { self.deselect() { |e| e.hidden? } }
  @uim.add_command('DeselectSoftEdges')           { self.deselect(Sketchup::Edge) { |e| e.soft? } }
  @uim.add_command('DeselectSmoothEdges')         { self.deselect(Sketchup::Edge) { |e| e.smooth? } }
  @uim.add_command('DeselectEdgeBorder')          { self.deselect() { |e| self.is_border_edge?(e) } }
  @uim.add_command('DeselectSelectionBorder')     { self.deselect() { |e| self.is_selection_border?(e) } }
  # Settings
  @uim.add_command('UISettings')                  { @uim.show_window }
  @uim.add_command('UICheatSheet')                { @uim.show_cheat_sheet }
  
  # --- Validate Items --- #
  # Instances
  @uim.add_eval('M_Instances') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH
      self.selected_any?(Sketchup::ComponentInstance)
    else
      true
    end
  }
  @uim.add_eval('M_DCInstances') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH
      self.selected_any_dcs?
    else
      true
    end
  }
  @uim.add_eval('M_GroupCopies') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH
      self.selected_any_group_copies?
    else
      true
    end
  }
  # Select Edges and Faces
  @uim.add_eval('M_Select') { Sketchup.active_model.selection.length > 0 }
  @uim.add_eval('@Group:M_Select>SelectEdges') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH
      self.selected?(Sketchup::Edge)
    else
      true
    end
  }
  @uim.add_eval('@Group:M_Select>SelectConnectedFaces') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH
      self.selected?(Sketchup::Face)
    else
      true
    end
  }
  @uim.add_eval('@Group:M_Select>SelectSimilarFaces') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH
      self.selected?(Sketchup::Face)
    else
      true
    end
  }
  @uim.add_eval('@Group:M_Select>SelectRelatedFaces') {
    if Sketchup.active_model.selection.length < MAX_SEL_LENGTH &&
      self.selected?(Sketchup::Face)
    else
      true
    end
  }
  # Select Filters
  @uim.add_eval('M_SelectOnly') { Sketchup.active_model.selection.length > 0 }
  @uim.add_eval('@Group:M_SelectOnly>Polygons') { self.support_polygons? }
  # Deselect Filters
  @uim.add_eval('M_Deselect') { Sketchup.active_model.selection.length > 0 }
  @uim.add_eval('@Group:M_Deselect>Polygons') { self.support_polygons? }

  # Build the UI defined in the config file.
  @uim.build_ui
  
  end # end if file_loaded


  ### INSTANCES ### -------------------------------------------------------
  def self.select_instances(filter = S_DEFAULT)
    model = Sketchup.active_model
    sel = model.selection
    
    active    = filter & S_ACTIVE == S_ACTIVE
    by_layer  = filter & S_LAYER  == S_LAYER
    by_dc     = filter & S_DC     == S_DC
    group     = filter & S_GROUP  == S_GROUP
    hidden    = model.rendering_options['DrawHidden']
    
    protos = Set.new
    layers = Set.new
    dcs = []
    
    # Build list of definitions in selection and instance layers from the selection.
    sel.each { |e|
      if (group && e.is_a?(Sketchup::Group)) || (!group && e.is_a?(Sketchup::ComponentInstance))
        definition = self.get_definition(e)
        protos.insert(definition)
        #layers << e.layer unless by_layer == false
        layers.insert(e.layer) unless by_layer == false
        # Add DC definitions
        if by_dc && !definition.attribute_dictionary('dynamic_attributes').nil?
          dc_name = definition.get_attribute('dynamic_attributes', '_name')
          next if dcs.include?(dc_name)
          dcs << dc_name
          model.definitions.each { |d|
            next if protos.include?(d)
            protos.insert(d) if d.get_attribute('dynamic_attributes', '_name') == dc_name
          }
        end
      end
    }
    
    # Build list of entities to select
    selection = []
    if active
      # Select only visible entitites from the active space.
      model.active_entities.each { |e| 
        # Check if the entity is of the type we look for
        next unless [Sketchup::ComponentInstance, Sketchup::Group].include?(e.class)
        next unless	protos.include?(self.get_definition(e))
        # Check if it's visible
        next unless hidden || (e.layer.visible? && e.visible?)
        # Add to selection if it's on valid layer
        selection << e unless by_layer && !layers.include?(e.layer)
      }
    else
      # Select entities from the global space.
      if by_layer
        protos.each { |d|
          d.instances.each { |i|
            selection << i if layers.include?(i.layer)
          }
        }
      else
        selection = protos.to_a.collect { |d| d.instances }.flatten
      end
    end
    sel.add(selection)
  end
  
  ### GROUPS ### -----------------------------------------------------------
  def self.convert_group_copies_to_components
    model = Sketchup.active_model
    sel = model.selection
    
    self.start_operation('Convert Copies to Components')
    
    # Cache some properties to transfer
    group_name = sel[0].name
    group_lock = sel[0].locked?
    # Find all the copies and make a prototype
    groups = self.get_definition(sel[0]).instances
    proto = groups[0].to_component
    # Transfer some properties that where not converted
    proto.name = group_name
    proto.locked = group_lock
    
    # Iterate through the rest of the copies
    protodef = proto.definition
    groups.each { | group |
      next if group.deleted?
      # Add a new component
      new_comp          = group.parent.entities.add_instance(protodef, group.transformation)
      new_comp.name     = group.name
      new_comp.material = group.material
      new_comp.layer    = group.layer
      new_comp.hidden   = group.hidden?
      new_comp.casts_shadows    = group.casts_shadows?
      new_comp.receives_shadows = group.receives_shadows?
      new_comp.locked   = group.locked?
      # (!) Glued to, attributes?
      # Delete the old group
      group.locked = false
      group.parent.entities.erase_entities(group)
    }
    
    model.commit_operation
    Sketchup.set_status_text(protodef.instances.length.to_s + ' group copies converted into components', SB_PROMPT)
  end
  
  
  ### EDGES ### ------------------------------------------------------------
  
  # --- Select Quadface Loop from Edge ---
  def self.select_quadface_loops
    sel = Sketchup.active_model.selection
    entities = []
    sel.each { |e|
      next unless e.is_a?(Sketchup::Edge)
      entities << self.select_quadface_loop(e)
    }
    entities.flatten!.uniq!
    sel.add(entities)
  end
  
  def self.select_quadface_loop(start_edge)
    #sel = Sketchup.active_model.selection
    
    # Prepare first array to feed the loop
    select = Set.new
    #edges = [sel.first]
    edges = [start_edge]
    while edges.length > 0
      # Filter out the faces we've allready selected and faces
      # with more than four edges.
      edge = edges.shift
      faces = edge.faces.reject { | face |
        select.include?(face) || face.edges.length > 4
      }
      select.insert(faces)
      # Get the opposite edge and loop
      faces.each { |face|
        other_edge = (face.edges - (edge.start.edges + edge.end.edges)).first
        # Add opposite edges for next iteration
        next if other_edge.nil? || select.include?(other_edge)
        select.insert(other_edge)
        edges << other_edge
      }
    end
    #sel.add(select.to_a)
    return select.to_a
  end
  
  
  ### FACES ### -----------------------------------------------------------
  # --- Select Connected Planar Faces ---
  def self.select_connected_planar_faces
    face = Sketchup.active_model.selection[0]
    self.select_connected_faces(face) { |f|
      f.normal.samedirection?(face.normal)
    }
  end
  
  # --- Select Connected Parallel Faces ---
  def self.select_connected_parallel_faces
    face = Sketchup.active_model.selection[0]
    self.select_connected_faces(face) { |f|
      f.normal.parallel?(face.normal)
    }
  end
  
  # --- Select Connected Perpendicular Faces ---
  def self.select_connected_perpendicular_faces
    face = Sketchup.active_model.selection[0]
    self.select_connected_faces(face) { |f|
      f.normal.perpendicular?(face.normal)
    }
  end
  
  # --- Select Connected Faces by Area ---
  def self.select_connected_same_area
    face = Sketchup.active_model.selection[0]
    self.select_connected_faces(face) { |f|
      self.floats_equal?(face.area, f.area)
    }
  end
  
  # --- Select Opposite Faces ---
  def self.select_opposite_faces
    sel = Sketchup.active_model.selection
    face = sel[0]
    distance = nil
    op = [face]
    
    face.all_connected.each { |e|
      # Ignore the face we start out with and look for faces that are the reverse
      # direction of our face.
      next if e == face
      next unless e.is_a?(Sketchup::Face) && e.normal.samedirection?(face.normal.reverse)
      # Find distance to face, pick the closest (might be multiple)
      
      # Find out if it's truely opposite
      # (?) Not sure if I need to check from the other side as the check is now.
      next unless self.faces_opposite?(face, e) || self.faces_opposite?(e, face)
      
      # We take the distance of the first vertex of the select face and measure the
      # distance to the current face we are testing.
      ds = face.vertices.first.position.distance_to_plane(e.plane)
      
      # If the face is closer than the one we currently have; we choose it.
      if distance.nil?
        op << e
        distance = ds
      elsif ds < distance
        op = [e]
        distance = ds 
      elsif ds == distance
        op << e
      end
    }
    sel.add(op)
  end

  # --- Select Faces in same direction ---
  def self.select_same_direction_faces
    face = Sketchup.active_model.selection[0]
    self.select_active_entities { |e|
      e.is_a?(Sketchup::Face) && e.normal.samedirection?(face.normal)
    }
  end
  
  # --- Select Parallel Faces ---
  def self.select_parallel_faces
    face = Sketchup.active_model.selection[0]
    self.select_active_entities { |e|
      e.is_a?(Sketchup::Face) && e.normal.parallel?(face.normal)
    }
  end
  
  # --- Select Perpendicular Faces ---
  def self.select_perpendicular_faces		
    face = Sketchup.active_model.selection[0]
    self.select_active_entities { |e|
      e.is_a?(Sketchup::Face) && e.normal.perpendicular?(face.normal)
    }
  end
  
  # --- Select Faces by Area ---
  def self.select_same_area
    face = Sketchup.active_model.selection[0]
    self.select_active_entities { |e|
      e.is_a?(Sketchup::Face) && self.floats_equal?(face.area, e.area)
    }
  end

  
  ### ENTITIES ###---------------------------------------------------------
  # --- Select Connected Entities By Material ---
  def self.select_connected_by_material(backside = false)
    source = Sketchup.active_model.selection[0]
    
    if source.is_a?(Sketchup::Face)
      source_material = (backside) ? source.back_material : source.material
    else
      source_material = source.material
    end
    
    self.select_connected_entities([source]) { |entity|
      if entity.is_a?(Sketchup::Face)
        material = (backside) ? entity.back_material : entity.material
      else
        material = entity.material
      end
      material == source_material
    }
  end

  # --- Select Connected Entities By Layer ---
  def self.select_connected_by_layer
    source = Sketchup.active_model.selection[0]
    layer = source.layer
    
    self.select_connected_entities([source]) { |entity|
      entity.layer == layer
    }
  end
  
  # --- Select Active By Selected Layers ---
  def self.select_active_by_selected_layers
    sel = Sketchup.active_model.selection
    # Get list of layers to select.
    layers = Set.new
    sel.each { |e| layers.insert(e.layer) }
    # Select the entities.
    self.select_active_entities { |e|
      layers.include?(e.layer)
    }
  end
  
  # --- Select Everything By Selected Layers ---
  def self.select_by_selected_layers
    sel = Sketchup.active_model.selection
    # Get list of layers to select.
    layers = Set.new
    sel.each { |e| layers.insert(e.layer) }
    # Select the entities.
    sel.clear
    ents = []
    self.all_entities { |e| ents << e if layers.include?(e.layer) }
    sel.add(ents)
  end
  
  # --- Select Active By Selected Layers ---
  def self.select_active_by_selected_materials
    sel = Sketchup.active_model.selection
    # Get list of layers to select.
    materials = Set.new
    sel.each { |e| materials.insert(e.material) }
    # Select the entities.
    self.select_active_entities { |e|
      materials.include?(e.material)
    }
  end
  
  
  ### SELECTION ### -------------------------------------------------------
  # Work similar to .select() except that it removes the entities from the selection.
  def self.deselect(class_type = nil)
    entities = []
    sel = Sketchup.active_model.selection
    if block_given?
      if class_type.nil?
        sel.each { |e| entities << e if yield(e) }
      else
        sel.each { |e| entities << e if e.is_a?(class_type) && yield(e) }
      end
    else
      sel.each { |e| entities << e if e.is_a?(class_type) }
    end
    sel.remove(entities)
  end
  
  def self.deselect_drawingelement(typename)
    self.deselect { |ent| ent.class == Sketchup::Drawingelement && ent.typename == typename }
  end
  
  def self.deselect_default_material(backface)
    self.deselect { |ent|
      if backface && ent.is_a?(Sketchup::Face)
        ent.back_material.nil?
      else
        ent.material.nil?
      end
    }
  end
  
  # Iterates over the current selection and filters out the entities.
  #
  # Argument: type
  #   Quick filter for selecting a type of entity. This is to keep the code short.
  #
  # Block:
  # Optional to perform further filtering.
  # If the block returns false the entity is removed from the selection.
  #
  # We collect the entities in an array and modify the selection at the end for big speed gain.
  def self.select(class_type = nil)
    entities = []
    sel = Sketchup.active_model.selection
    if block_given?
      if class_type.nil?
        sel.each { |e| entities << e unless yield(e) }
      else
        sel.each { |e| entities << e unless e.is_a?(class_type) && yield(e) }
      end
    else
      sel.each { |e| entities << e unless e.is_a?(class_type) }
    end
    sel.remove(entities)
  end
  
  def self.select_drawingelement(typename)
    self.select { |ent| ent.class == Sketchup::Drawingelement && ent.typename == typename }
  end
  
  def self.select_default_material(backface = false)
    self.select { |ent|
      if backface && ent.is_a?(Sketchup::Face)
        ent.back_material.nil?
      else
        ent.material.nil?
      end
    }
  end
  
  
  ### SELECT CONNECTED ITERATOR ### -------------------------------------------------
  # Generic Connected Faces method. Selects the yielded faces that evalutes true.
  # Profile Results:
  # Array.reject is much faster than Array - Array
  # On a test of 3423 entities the difference was ~2.4s vs. ~0.1s
  # Using the Set class to ensure unique objects also seem to add similar improvements.
  def self.select_connected_faces(face)
    sel = Sketchup.active_model.selection
    selection = Set.new
    selection.insert(face)
    faces = self.connected_faces(face)
    while faces.length > 0
      face = faces.shift
      if yield(face)
        selection.insert(face)
        faces += self.connected_faces(face).reject{|f|selection.include?(f)||faces.include?(f)}
      end
    end
    sel.add(selection.to_a)
  end
  
  # Return the neighbouring faces for the given face
  def self.connected_faces(face)
    faces = []
    face.edges.each { |edge|
      faces |= edge.faces
      #faces += edge.faces
    }
    faces.delete(face)
    return faces
  end
  
  # Generic Connected Entities method. Selects the yielded faces that evalutes true.
  # (?) Only select hidden if hidden geometry is visible?
  def self.select_active_entities
    sel = Sketchup.active_model.selection
    selection = Set.new
    Sketchup.active_model.active_entities.each { |e|
      selection.insert(e) if yield(e)
    }
    sel.add(selection.to_a)
  end
  
  # Connected Entities
  def self.select_connected_entities(entities)
    sel = Sketchup.active_model.selection
    selection = Set.new
    entities.each{ |e| selection.insert(e) }
    while entities.length > 0
      entity = entities.shift
      if yield(entity)
        selection.insert(entity)
        
        if entity.is_a?(Sketchup::Edge)
          entities += entity.faces.reject{|e|selection.include?(e)||entities.include?(e)}
        elsif entity.is_a?(Sketchup::Face)
          entities += entity.edges.reject{|e|selection.include?(e)||entities.include?(e)}
        end
      end
    end
    sel.add(selection.to_a)
  end
  
  
  ### TOOLS ### ------------------------------------------------------------
  def self.tool(tool)
    Sketchup.active_model.select_tool(tool)
  end
  
  class Select_Connected_Faces_By_Angle_Tool
    @angle = 0.0
    @face = nil
    
    def activate
      Sketchup::set_status_text('Angle', SB_VCB_LABEL)
      Sketchup::set_status_text(0.0, SB_VCB_VALUE)
      
      @face = Sketchup.active_model.selection[0]
      @angle = 0.0
      self.select_by_angle()
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def draw(view)
      view.line_width = 5
      view.drawing_color = [255, 0, 0]
      @face.edges.each { |edge|
        view.draw_line(edge.start.position, edge.end.position)
      }
    end
    
    def draw_xxx(view)
      model = Sketchup.active_model
      sel = model.selection
      face = sel[0]
      
      ents = face.all_connected
      vector =  face.normal
      view.line_width = 5
      
      ents.each { |ent|
        if ent.is_a?(Sketchup::Face)
          angle = vector.angle_between(ent.normal)
          ratio = angle / (Math::PI/2)
          
          red   = Integer(255 * ratio)
          green = Integer(255 - red)
          blue  = Integer(0)
          
          view.drawing_color = [red, green, blue]
          
          ent.edges.each { |edge|
            view.draw_line(edge.start.position, edge.end.position)
          }
        end
      }
    end
    
    def onUserText(text, view)
      @angle = text.to_f
      self.select_by_angle()
      Sketchup::set_status_text(text, SB_VCB_VALUE)
    end
    
    def select_by_angle
      sel = Sketchup.active_model.selection.clear()
      Select_Toys::select_connected_faces(@face) { |face|
        angle = @face.normal.angle_between(face.normal).radians
        angle <= @angle
      }
    end
  end
  
  class Select_Face_Loops

    def initialize
      @cursor_point = nil
      @path = nil
      @best = nil
      @face = nil
      @edge = nil
      @loop = nil
      
      @ctrl = nil
      @shift = nil
      
      @cursor_select			= cursor('Select.png',        3, 8)
      @cursor_select_add		= cursor('Select_Add.png',    3, 8)
      @cursor_select_remove	= cursor('Select_Remove.png', 3, 8)
      @cursor_select_toggle	= cursor('Select_Toggle.png', 3, 8)
    end
    
    def activate
      @cursor_point	  = Sketchup::InputPoint.new
      @entity = nil
      @path = nil
      
      @ctrl = false
      @shift = false
      
      @drawn = false
      
      self.reset(nil)
    end
    
    def deactivate(view)
      view.invalidate if @drawn
    end
    
    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      
      @face = ph.picked_face if ph.picked_face != @face
      @edge = ph.picked_edge if ph.picked_edge != @edge
      @best = ph.best_picked if ph.best_picked != @best
      
      @cursor_point.pick(view, x, y)
      view.invalidate
    end
    
    def onLButtonUp(flags, x, y, view)
      # FLAGS
      #  4	Shift		Add/Remove	CONSTRAIN_MODIFIER_MASK
      #  8	Ctrl		Add			COPY_MODIFIER_MASK
      # 32	Alt
      #
      # 12	Ctrl+Shift	Remove
      #
      # CONSTRAIN_MODIFIER_KEY	= 16
      # CONSTRAIN_MODIFIER_MASK	=  4
      # COPY_MODIFIER_KEY			= 17
      # COPY_MODIFIER_MASK		=  8
      # ALT_MODIFIER_KEY			= 18
      # ALT_MODIFIER_MASK			= 32
      
      entities = Set.new
      
      if @face && @edge && (@best.is_a?(Sketchup::Face) || @best.is_a?(Sketchup::Edge))
        @face.loops.each { |loop|
          next unless loop.edges.include?(@edge)
          entities.insert(loop.edges)
          break
        }
      elsif @face
        @face.loops.each { |loop|
          entities.insert(loop.edges)
        }
      end
      
      unless entities.empty?
        if flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK && flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
          #puts 'Remove'
          Sketchup.active_model.selection.remove(entities.to_a)
        elsif flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
          #puts 'Toggle'
          Sketchup.active_model.selection.toggle(entities.to_a)
        elsif flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
          #puts 'Add'
          Sketchup.active_model.selection.add(entities.to_a)
        else
          #puts 'Clear'
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(entities.to_a)
        end
      end
    end
    
    def onKeyDown(key, repeat, flags, view)
      @ctrl  = true if key == VK_CONTROL
      @shift = true if key == VK_SHIFT
      onSetCursor
    end
    
    def onKeyUp(key, repeat, flags, view)
      @ctrl  = false if key == VK_CONTROL
      @shift = false if key == VK_SHIFT
      onSetCursor
    end
    
    def onSetCursor		
      if @ctrl && @shift
        UI.set_cursor(@cursor_select_remove)
      elsif @ctrl
        UI.set_cursor(@cursor_select_add)
      elsif @shift
        UI.set_cursor(@cursor_select_toggle)
      else
        UI.set_cursor(@cursor_select)
      end
    end
    
    def draw(view)
      if @face && @edge && (@best.is_a?(Sketchup::Face) || @best.is_a?(Sketchup::Edge))
        @face.loops.each { |loop|
          next unless loop.edges.include?(@edge)
          loop.edges.each { |e| draw_edge(view, e) }
          @drawn = true
          return
        }
      elsif @best.is_a?(Sketchup::Face)
        @face.loops.each { |loop|
          loop.edges.each { |e| draw_edge(view, e) }
        }
        @drawn = true
      end
    end
    
    def draw_edge(view, edge)
      p1 = (@shift) ? global_position(edge.start.position) : edge.start.position
      p2 = (@shift) ? global_position(edge.end.position) : edge.end.position
      
      view.line_width = 5.0
      view.drawing_color = 'orange'
      view.draw_line(p1, p2)
    end
    
    # Get the global position with the help of the path list from the PickHelper.
    def global_position(point)
      return point if @path.nil?
      @path.each { |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        point.transform!(e.transformation)
      }
      return point
    end
    
    # Reset the tool back to its initial state
    def reset(view)

      if view
        view.tooltip = nil
        view.invalidate if @drawn
      end

      @drawn = false
    end
    
    def cursor(file, x = 0, y = 0)
      cursor_path = File.join(PATH, 'Cursors')
      return (cursor_path) ? UI.create_cursor(cursor_path, x, y) : 0
    end
  end
  
end # module

#-----------------------------------------------------------------------------
file_loaded(__FILE__)
#-----------------------------------------------------------------------------