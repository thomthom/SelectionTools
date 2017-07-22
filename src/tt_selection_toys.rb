#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module SelectionToys
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = 'TT_Selection_Toys'.freeze
  PLUGIN_NAME     = 'Selection Toys'.freeze
  PLUGIN_VERSION  = '2.4.0'.freeze

  # Resource paths
  file = File.expand_path( __FILE__ )
  file.force_encoding( "UTF-8" ) if file.respond_to?( :force_encoding )
  FILENAMESPACE = File.basename( file, '.*' )
  PATH_ROOT     = File.dirname( file ).freeze
  PATH          = File.join( PATH_ROOT, FILENAMESPACE ).freeze
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    file = File.join( PATH, 'core.rb' )
    ex = SketchupExtension.new( PLUGIN_NAME, file )
    ex.description = "Suite of tools to create, manipulate and filter selections."
    ex.version = PLUGIN_VERSION
    ex.copyright = 'Thomas Thomassen © 2008–2017'
    ex.creator = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension( ex, true )
  end 

  end # module SelectionToys
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
