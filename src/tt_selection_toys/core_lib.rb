#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'

#-----------------------------------------------------------------------------

module Select_Toys
  
  ##### STRING #####
  
  # @param [String] string
  # @return [String]
  # @since 1.0.0
  def self.escape_js(string)
    return string.gsub("'", "\\\\'")
  end
  
  
  ##### FLOATS #####
  
  # Compare two floats with some tolerance. (Thanks jeff99)
  #
  # @param [Float] float1
  # @param [Float] float2
  # @param [Float] epsilon
  #
  # @since 1.0.0
  def self.floats_equal?(float1, float2, epsilon = 0.00000001)
    return (float1 - float2).abs < epsilon
  end
  
  
  ##### SYSTEM #####
  
  # @since 1.0.0
  def self.is_mac?
    return (Object::RUBY_PLATFORM =~ /darwin/i) ? true : false
  end
  
  
  ##### SKETCHUP #####

  # Being able to tell the difference between a curve and polygon was first
  # introduced in SU7.1. This method return true when run under a Sketchup
  # version that supports this.
  #
  # @since 1.2.0
  def self.support_polygons?
    return Sketchup::Curve.method_defined?(:is_polygon?)
  end
  
  
  ##### MODEL #####
  
  # Make use of the SU7 speed boost with +start_operation+ while
  # making sure it works in SU6.
  #
  # @param [String] name
  # @param [Boolean] disable_ui
  #
  # @return [Boolean]
  # @since 1.0.0
  def self.start_operation(name, disable_ui = true)
    if Sketchup.version.split('.')[0].to_i >= 7
      Sketchup.active_model.start_operation(name, disable_ui)
    else
      Sketchup.active_model.start_operation(name)
    end
  end
  
  # Returns the definition for a +Group+ or +ComponentInstance+
  #
  # @param [Sketchup::ComponentInstance, Sketchup::Group] instance
  #
  # @return [Sketchup::ComponentDefinition]
  # @since 1.0.0
  def self.get_definition(instance)
    # ComponentInstance
    return instance.definition if instance.is_a?(Sketchup::ComponentInstance)
    # Group
    #
    # (i) group.entities.parent should return the definition of a group.
    # But because of a SketchUp bug we must verify that group.entities.parent returns
    # the correct definition. If the returned definition doesn't include our group instance
    # then we must search through all the definitions to locate it.
    if instance.entities.parent.instances.include?(instance)
      return instance.entities.parent
    else
      Sketchup.active_model.definitions.each { |definition|
        return definition if definition.instances.include?(instance)
      }
    end
    return nil # Error. We should never exit here.
  end
  
  # Block method that will iterate all entities in the model.
  # Setting in_model_only to false will make it iterate the entities of definitions that
  # has no instanced placed in the model.
  #
  # @param [Boolean] in_model_only
  #
  # @yield [entity]
  # @yieldparam [Sketchup::Entity] entity
  #
  # @return [Sketchup::Model, nil] +nil+ if no block is given, +Sketchup::Model+ otherwise.
  #
  # @since 1.0.0
  def self.all_entities(in_model_only = true)
    return false unless block_given?
    Sketchup.active_model.entities.each { |entity| yield(entity) }
    Sketchup.active_model.definitions.each { |definition|
      next if definition.image?
      next if in_model_only && definition.count_instances == 0
      definition.entities.each { |entity|
        yield(entity)
      }
    }
    return Sketchup.active_model
  end
  
  
  ##### ENTITIES #####
  
  # @param [Sketchup::Entity] entity
  # @param [String] typename
  #
  # @since 1.2.0
  def self.is_drawingelement?(entity, typename)
    return entity.class == Sketchup::Drawingelement && entity.typename == typename
  end
  
  # @param [Sketchup::Entity] entity
  # @since 1.2.0
  def self.is_border_edge?(entity)
    return entity.is_a?(Sketchup::Edge) && entity.faces.length == 1
  end
  
  # @param [Sketchup::Entity] entity
  # @since 1.2.0
  def self.is_selection_border?(entity)
    return false unless entity.is_a?(Sketchup::Edge)
    selection = Sketchup.active_model.selection
    faces = entity.faces & selection.to_a
    return faces.length == 1
  end
  
  # @param [Sketchup::Entity] entity
  # @since 1.0.0
  def self.is_curve?(entity)
    return false unless entity.is_a?(Sketchup::Edge) && entity.curve
    return false if entity.curve.respond_to?(:is_polygon? ) && entity.curve.is_polygon?
    return true
  end
  
  # @param [Sketchup::Entity] entity
  # @since 1.0.0
  def self.is_arc?(entity)
    return self.is_curve?(entity) && entity.curve.is_a?(Sketchup::ArcCurve)
  end
  
  # @param [Sketchup::Entity] ent
  # @since 1.0.0
  def self.is_circle?(ent)
    # (i) A bug in SU makes extruded circles into Arcs with .end_angle of 720 degrees when reopening the file.
    # Instead of checking for 360 degrees exactly, we check for anything larger as well. A 2D arc
    # can't have more than 360 degrees.
    #
    # This doesn't work. Maybe due to rounding errors?
    # return (arc_curve.end_angle - arc_curve.start_angle >= 360.degrees) ? true : false
    return false unless self.is_arc?(ent)
    return ((ent.curve.end_angle - ent.curve.start_angle).radians >= 360) ? true : false
  end
  
  # @param [Sketchup::Entity] ent
  # @since 1.0.0
  def self.is_polygon?(ent)
    return ent.is_a?(Sketchup::Edge) && ent.curve && ent.curve.respond_to?(:is_polygon? ) && ent.curve.is_polygon?
  end
  
  # @param [Sketchup::Entity] ent
  # @since 1.0.0
  def self.is_ngon?(ent)
    return false unless self.is_polygon?(ent) && ent.curve.is_a?(Sketchup::ArcCurve)
    return ((ent.curve.end_angle - ent.curve.start_angle).radians >= 360) ? true : false
  end
  
  # Returns +true+ if the two faces given are opposite each other.
  #
  # @param [Sketchup::Face] source
  # @param [Sketchup::Face] target
  #
  # @since 1.0.0
  def self.faces_opposite?(source, target)
    # Make a flag to check of any of the return projections are outside the source face.
    # If a point projection doesn't return to be inside the face, then all the projections
    # we do must at least hit on the Edge or Vertex.
    outside = false
    source.edges.each { |e|
      # Project a point from the source to the target, if it's on the target face we
      # return true. If not we must do further checking.
      projected_point = e.vertices.first.position.project_to_plane(target.plane)
      return true if target.classify_point(projected_point) == POINT_INSIDE
      # Now we try to intersect a line with the edges of the target face.
      # The line is the current source edge's line projected onto the target plane.
      projected_line = [projected_point, e.line[1]]
      target.edges.each { |edge|
        intersect_point = Geom.intersect_line_line(edge.line, projected_line)
        # Ensure the intersecing point is on target
        next if intersect_point.nil?
        point_type = target.classify_point(intersect_point)
        # If it projects outside the target face we discard it.
        if point_type > POINT_ON_VERTEX
          outside = true
          next 
        end
        # Project from the intersecting point back to source
        # and ensure we're still opposite it.
        return_point = intersect_point.project_to_plane(source.plane)
        # If it's outside we set the outside flag. This will ensure we don't select this
        # face unless we later find a point that projects to inside our source face.
        point_type = source.classify_point(return_point)
        outside = true if point_type > POINT_ON_VERTEX
        # If it returns back to us inside or on one of our edges then we don't need to check
        # any further because then we know the face is opposite.
        return true if point_type <= POINT_ON_EDGE
      }
    }
    # If we come to this point we've not point any points that projects from the source to the
    # inside of the target. Then all projections we've did back from the target had to hit the
    # source in some manner. If that projection ended up outside for any of the points then
    # the outside flag will have been set. We will only return true here if 'outside' evaluates
    # to false.
    return false if outside
    return true
  end
  
  
  ##### VERTICES #####
  
  # @param [Sketchup::Edge] edge1
  # @param [Sketchup::Edge] edge2
  #
  # @return [Sketchup::Vertex]
  # @since 1.1.0
  def self.common_vertex(edge1, edge2)
    edge1.vertices.each { |v|
      return v if v.used_by?(edge1) && v.used_by?(edge2)
    }
  end

  # Finds the corners in a face, ignoring vertices between colinear edges.
  #
  # @param [Sketchup::Face] face
  #
  # @return [Array<Sketchup::Vertex>] array of vertices.
  # @since 1.2.0
  def self.corner_vertices(face)
    raise ArgumentError, 'Must be a Sketchup::Face' unless face.is_a?(Sketchup::Face)
    corners = []
    # We only check the outer loop, ignoring interior lines.
    face.outer_loop.edgeuses.each { |eu|
      # Ignore vertices that's between co-linear edges.
      unless eu.edge.line[1].parallel?(eu.next.edge.line[1])
        corners << self.common_vertex(eu.edge, eu.next.edge)
      end
    }
    return corners
  end
  
  
  ##### SELECTION #####
  
  # @since 1.1.0
  def self.selected_any_dcs?
    return Sketchup.active_model.selection.any? { |e|
      e.is_a?(Sketchup::ComponentInstance) &&
      !e.definition.attribute_dictionary('dynamic_attributes').nil?
    }
  end
  
  # @since 1.1.0
  def self.selected_any_group_copies?
    return Sketchup.active_model.selection.any? { |e|
      e.is_a?(Sketchup::Group) && self.get_definition(e).count_instances > 0
    }
  end
  
  # @since 1.2.0
  def self.selected?(entity_class)
    sel = Sketchup.active_model.selection
    return sel.single_object? && sel[0].is_a?(entity_class)
  end
  
  # @since 1.2.0
  def self.selected_any?(entity_class)
    return Sketchup.active_model.selection.any? { |e| e.is_a?(entity_class) }
  end
  
  # @since 1.2.0
  def self.selected_all?(entity_class)
    return Sketchup.active_model.selection.all? { |e| e.is_a?(entity_class) }
  end

end # module Select_Toys