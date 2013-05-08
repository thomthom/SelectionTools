#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'

#-----------------------------------------------------------------------------

module TT::Plugins::SelectionToys

	require File.join( PATH, 'core_lib.rb' )
	
	# Sortable Hash that preserves the insertion order.
	# Prints out JSON strings of the content.
	#
	# Based of Bill Kelly's InsertOrderPreservingHash
	#
	# @see http://www.ruby-forum.com/topic/166075#728764
	class JSON
		include Enumerable

		# @since 1.0.0
		def initialize(*args, &block)
			@h = Hash.new(*args, &block)
			@ordered_keys = []
		end

		# @since 1.0.0
		def []=(key, val)
			@ordered_keys << key unless @h.has_key? key
			@h[key] = val
		end

		# @since 1.0.0
		def each
			@ordered_keys.each {|k| yield(k, @h[k])}
		end
		alias :each_pair :each

		# @since 1.0.0
		def each_value
			@ordered_keys.each {|k| yield(@h[k])}
		end

		# @since 1.0.0
		def each_key
			@ordered_keys.each {|k| yield k}
		end
		
		# @since 1.0.0
		def key?(key)
			@h.key?(key)
		end
		alias :has_key? :key?
		alias :include? :key?
		alias :member? :key?
		
		# @since 1.0.0
		def keys
			@ordered_keys
		end
		
		# @since 1.0.0
		def values
			@ordered_keys.map {|k| @h[k]}
		end

		# @since 1.0.0
		def clear
			@ordered_keys.clear
			@h.clear
		end

		# @since 1.0.0
		def delete(k, &block)
			@ordered_keys.delete k
			@h.delete(k, &block)
		end

		# @since 1.0.0
		def reject!
			del = []
			each_pair {|k,v| del << k if yield k,v}
			del.each {|k| delete k}
			del.empty? ? nil : self
		end

		# @since 1.0.0
		def delete_if(&block)
			reject!(&block)
			self
		end

		# @since 1.0.0
		%w(merge!).each do |name|
			define_method(name) do |*args|
			raise NotImplementedError, "#{name} not implemented"
			end
		end

		# @since 1.0.0
		def method_missing(*args)
			@h.send(*args)
		end
		
		# Compile JSON Hash into a string.
		# @since 1.0.0
		def to_s(format=false)
			str = self.collect { |key, value|
				
				if value.is_a?(JSON)
					value = value.to_s(format)
				elsif [Numeric, TrueClass, FalseClass].include?(value.class)
					value = value.to_s
				else
					value = "'#{PLUGIN.escape_js(value.to_s)}'"
				end
				
				"'#{key}': #{value}"
			}
			str = (format) ? str.join(",\n\t") : str.join(", ")
			return (format) ? "{\n\t#{str}\n}\n" : "{#{str}}"
		end
		alias :inspect :to_s
	end

end # module