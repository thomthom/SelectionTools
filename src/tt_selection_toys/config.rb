#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'

#-----------------------------------------------------------------------------

module Select_Toys

  require File.join( PATH, 'core_lib.rb' )
  require File.join( PATH, 'json.rb' )

 module Config
  D_TAB	  = 1 # @private
  D_ID	  = 2 # @private
  D_DATA  = 4 # @private
  

  # @param [String] config_file a string with the filename and path of the 
  #   configuration file to open.
  #
  # @return [JSON, nil] a +JSON+ on success, +nil+ on failure
  #
  # @since 1.0.0
  def self.read(config_file)
    return nil unless File.readable?(config_file)
    
    # Read the file into an array of lines
    file = File.new(config_file, 'r')
    lines = file.readlines
    file.close
    
    # Root JSON object
    json = JSON.new
    # Track the path in the JSON tree
    path = []
    path << json
    # Parse the data into a JSON object
    lines.each { |line|
      line.rstrip! # Remove Right hand whitespace. (Mac compatibility)
      data = line.match(/^(\t*)(\w+)(\s*=\s*(.*))*/)
      # data Content:
      # 1. Tab Characters
      # 2. ID String
      # 4. Data - Unless it has child elements
      
      # Less tab characters - step back in the tree. Determine which
      # level we step back to from the number of tab characters.
      if data[D_TAB].length < path.length - 1
        back = path.length - 1 - data[D_TAB].length
        back.times { path.pop }
      end
      
      if data[D_DATA].nil?
        # Add new JSON
        path.last[ data[D_ID] ] = JSON.new
        # Set new tree node to the newly added
        path << path.last[ data[D_ID] ]
      else
        # Insert data
        path.last[ data[D_ID] ] = self.string_to_data( data[D_DATA] )
      end
    }
    
    return json
  end
  
  # @todo Add support for nested +JSON+ objects.
  #
  # @param [String] config_file the filepath to write to.
  # @param [JSON] json the +JSON+ object to write to file.
  #
  # @return [Boolean] +true+ on success, +false+ on failure
  #
  # @since 1.0.0
  def self.write(config_file, json)
    # (!) Deal with nested JSONs.
    file = File.new(config_file, 'w')
    json.each { |key, value|
      file.puts "#{key} = #{value}"
    }
    file.close
  end
  
  # Format a string into appropriate data type.
  #
  # @param [String] string
  #
  # @return [String, Float, Integer, Boolean]
  #
  # @since 1.0.0
  def self.string_to_data(string)
    # On mac we end up with trailing whitespace - remove it.
    #string.strip!
    
    # Quoted String
    string_test = string.match(/^"(.*)"|'(.*)'$/)
    return string_test[1] unless string_test.nil?
    
    # Float
    return string.to_f unless string.match(/^(\d+(\.\d*))$/).nil?
    
    # Integer
    return string.to_i unless string.match(/^(\d+)$/).nil?
    
    # Boolean
    return true  if %w(true yes on).include?(string)
    return false if %w(false no off).include?(string)
    
    # Default
    return string
  end
    
 end # module Config
end # module Select_Toys