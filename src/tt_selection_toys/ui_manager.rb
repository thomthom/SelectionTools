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
	require File.join( PATH, 'json.rb' )
	require File.join( PATH, 'config.rb' )
 
 # @todo Complete documentation and examples.
 #
 # @since 1.0.0
 class UI_Manager < UI::WebDialog

	VERSION = '1.1.0'	
	
	# Create new object with path to config file.
	#
	# @param [String] config_file Path to config file.
	#
	# @since 1.0.0
	def initialize(config_file)
		
		# Load configuration
		@config = Config.read(config_file)
		@config['General']['ConfigFile'] = config_file
		@config['General']['ConfigPath'] = File.dirname(config_file) + File::SEPARATOR

		# Load Settings
		@config['General']['Settings'] = @config['General']['ConfigPath'] + @config['General']['Settings']
		settings = Config.read(@config['General']['Settings'])
		
		# Links the Command ID's with the actual Procs which is defined by .add_command.
		@procs = {}
		# Index of procs that must return true for the UI element to be added.
		@val = {}
		# List of all UI Hosts (Root elements such as Toolbars, Menus).
		@hosts = JSON.new
		# Index of all the UI elements and it's properties.
		@ui = JSON.new
		# Index of the hosts and their current Group
		@groups = {}
		# Flag indicating if our menu UI has been built
		@menus_added = false
		@toolbars_added = false
		
		# Index of hosts for the UI elements. Be it Toolbars, Menus, Context Menus.
		# Build host list
		# {
		#   HostID => Label,
		#   HostID => Label,
		#   HostID => Label,
		# }
		# The Hosts acts as root elements for the various sections.
		elements = []
		@config['UI'].each { |host_id, host|
			# Add the new host
			@hosts[host_id] = host['Label'] if host.is_a?(JSON)
			# Add it's child UI elements to the parse list
			host.each { |item_id, item|
				if item.is_a?(JSON)
					# Merge Host ID so we know where it should belong.
					item['Host'] = host_id
					elements << [item_id, item]
				end
			}
			#@ui[host_id] = host
		}

		# Iterate over the nested JSON objects and create a flat JSON list
		# for easy access to each element. 
		# For each UI element we fetch the Label and Description based on
		# the command associated.
		# We also read in the @settings data is availible.
		# As we traverse and flatten the hash we add a Host key which references
		# the parent UI element - (toolbar, menu or sub-menu).
		while element = elements.shift
			id, item = element
			
			# Add to UI list
			@ui[id] = item
			
			# Merge in data for the item based on it's command.
			cmd = @config['Commands'][ item['Command'] ]
			if cmd.nil?
				puts "Error! UI_Manager.initialize: UI '#{id}' can not link to missing command '#{item['Command']}'."
				next
			end
			@ui[id]['Label']		= cmd['Label']
			@ui[id]['Description']	= cmd['Description']
			@ui[id]['SmallIcon']	= cmd['SmallIcon'] if cmd.key?('SmallIcon')
			@ui[id]['LargeIcon']	= cmd['LargeIcon'] if cmd.key?('LargeIcon')
			
			# Merge @settings
			unless settings.nil? || settings[id].nil?
				@ui[id]['Visible'] = settings[id] unless @ui[id]['Locked']
			end
			
			# Look for child elements
			item.each { |child_id, child_item|
				if child_item.is_a?(JSON)
					item['sub_menu'] = true
					# Merge Host ID so we know where it should be inserted.
					child_item['Host'] = id
					elements << [child_id, child_item]
					#item.delete(child_id)
				end
			}
			#item.reject! { |key, value| value.is_a?(JSON) }
		end
		# Cleanup a bit - get rid of the child JSON elements.
		#@ui.reject! { |key, value| value.is_a?(JSON) }
		#@ui.each {|k,v| v.reject! { |key, value| value.is_a?(JSON) } }
		
		# Prepare webdialog object
		super @config['General']['Title'], false, 'pm_uim', 500, 325, 100, 100, true
		self.navigation_buttons_enabled = false if self.respond_to?(:navigation_buttons_enabled)
		self.min_width = 330	 if self.respond_to?(:min_width)
		self.min_height = 200	 if self.respond_to?(:min_height)
		# Callbacks
		self.add_action_callback('ready') { |dialog, params|
			puts '>> Dialog Ready'
			
			# Previously we sent each of these sections one by one, but due to Mac's async
			# nature that didn't work as the dialog had not created the hosts before it tried
			# to add the UI elements. So now we compile one big JSON and let JS sort it out.
			data = JSON.new
			# Set General Info
			data['Info'] = @config['General']
			# Add UI Hosts
			data['Hosts'] = @hosts
			# UI Elements
			data['UI'] = JSON.new
			@ui.each { |key, value|
				next unless value.is_a?(JSON)
				# Push data to the webdialog
				data['UI'][key] = value
			}
			#puts data['UI'].to_s(true) # DEBUG
			dialog.execute_script("process_data(#{data});")
		}
		self.add_action_callback('save') { |dialog, params|
			puts '>> Save'
			# Build Settings JSON
			settings = JSON.new
			@ui.each { |id, value|
				setting = dialog.get_element_value("ui_#{id}_data")
				settings[id] = setting
				@ui[id]['Visible'] = Config::string_to_data(setting) unless @ui[id]['Locked']
			}
			# Write file
			Config.write(@config['General']['Settings'], settings)
			dialog.close
		}
		self.add_action_callback('cancel') { |dialog, params|
			puts '>> Cancel'
			dialog.close
		}
		
	end
	
	# Open or bring to front the window.
	#
	# @return [nil]
	# @since 1.0.0
	def show_window
		if self.visible?
			self.bring_to_front
		else
			# We use set_file here to prevent Macs loading the whole dialog when the
			# plugin loads. No need to populate the dialog and use extra resources
			# if it will never be used.
			filepath = File.join(PATH, 'webdialog/ui_manager.html')
			self.set_file(filepath)
			if PLUGIN.is_mac?
				self.show_modal
			else
				self.show
			end
		end
	end
	
	# @since 1.0.0
	def enable_toolbars
		Sketchup.write_default(@config['General']['AppID'], 'EnableToolbars', true)
		build_ui()
	end
	
	# @since 1.0.0
	def toolbars_enabled?
		return Sketchup.read_default(@config['General']['AppID'], 'EnableToolbars', false)
	end
	
	# Returns the UI::Command object on success - which the you can perform additional
	# actions to, such as adding validating procs.
	# Returns nil on failure.
	# @since 1.0.0
	def add_command(id, &command)
		if @config['Commands'].nil? || @config['Commands'][id].nil?
			puts "Plugin Manager: No command '#{id}' defined for #{@config['General']['Title']}"
			return nil
		end
		cmd = @config['Commands'][id]
		@procs[id] = UI::Command.new(cmd['Label'], &command)
		# Tooltips
		@procs[id].tooltip = cmd['Label']
		@procs[id].status_bar_text = cmd['Description'] if cmd.key?('Description')
		# Add Icons
		icon_path = @config['General']['ConfigPath'] + @config['General']['IconPath']
		@procs[id].small_icon = icon_path + cmd['SmallIcon'] if cmd.key?('SmallIcon')
		@procs[id].large_icon = icon_path + cmd['LargeIcon'] if cmd.key?('LargeIcon')
		#puts "> Command '#{id}' registered!"
		return @procs[id]
	end
	
	# The ID should match the UI element ID. When a new item is added, it checks the
	# hash of validating procs for it's ID and evaluates the proc.
	#
	# @param [String] id
	#
	# @since 1.0.0
	def add_eval(id, &command)
		@val[id] = command
	end
	
	# Build the UI. Add all toolbars and menus.
	# @since 1.0.0
	def build_ui
		return if @toolbars_enabled
		@config['UI'].each { |host_id, item|
			type, name = item['Host'].split(':')
			if type == 'Toolbar'
				# Create Toolbar
				toolbar = UI::Toolbar.new(name)
				# Add buttons
				item.each { |id, button|
					next unless button.is_a?(JSON)
					add_item(toolbar, id)
				}
				# Show only if the toolbar was shown last time
				# Seems to be a bug related. When a toolbar is created for the first time
				# Sketchup will list it under View->Toolbars ticked of, like it's been shown.
				# So if we don't show it when it has never been shown, then the user must
				# untick then tick it again. Confusing for the user.
				#toolbar.restore if toolbar.get_last_state == TB_VISIBLE
				if toolbar.get_last_state == TB_VISIBLE
					toolbar.restore
					UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
				end
			elsif type == 'Menu'
				next if @menus_added
				if name == 'Context'
					UI.add_context_menu_handler { |menu|
						build_menus(menu, item)
					}
				else
					menu = UI.menu(name)
					next if menu.nil? # (?) Error?
					build_menus(menu, item)
				end
			end
		}
		# We set this flag true as we might run this method again when toolbars are enabled.
		@menus_added = true
		@toolbars_added = toolbars_enabled?
	end
	
	# Build menus from JSON structure
	# @private
	# @since 1.0.0
	def build_menus(menu, items)
		items.each { |id, item|
			# For each JSON, add the item and then run build_menus in that item
			# in case it has sub menus. Hopefully such a recursive method won't
			# cause any problems.
			if item.is_a?(JSON)
				sub_menu = add_item(menu, id)
				build_menus(sub_menu, item)
			end
		}
	end
	private :build_menus
	
	# host: Toolbar or Menu where the item is inserted to
	# ui_is: string ID of the UI element
	# @private
	# @since 1.0.0
	def add_item(host, ui_id)
		begin
			# Abort if the host is nil.
			return nil if host.nil?
			# Only add items which is visible
			return nil unless !@ui[ui_id].nil? && @ui[ui_id]['Visible']
			
			# Fetch the Item data
			item = @ui[ui_id]
			
			# Validate the item
			# ID rules
			return nil if @val.key?(ui_id) && @val[ui_id].call == false
			# Check for Group rules
			# @Group:GroupName
			if @ui[ui_id].key?('Group')
				group = "@Group:#{@ui[ui_id]['Host']}>#{@ui[ui_id]['Group']}"
				return nil if @val.key?(group) && @val[group].call == false
			end
			
			# Groups - Separators
			# We cache the last used group name for each host.
			# If the item spesifies a group and it's different from what we have caches,
			# or we haven't cached anything yet, we add the group to the hash and adds
			# and separator to the host.
			groupId = host.to_s
			if item.key?('Group') && (!@groups.key?(groupId) || @groups[groupId] != item['Group'])
				# If there wasn't previously a group id this this host,
				# don't add the separator. We do want to add a separator if we're adding a
				# root host menu and the group is not nil.
				root_menu = (@hosts.key?(item['Host']) && @config['UI'][item['Host']]['Host'][0,5] == 'Menu:') ? true : false
				host.add_separator if @groups.key?(groupId) || root_menu
			end
			# Keep track of the last group for the current host. When the group changes
			# we add an separator.
			# If item has a group defined the ID will be a string, otherwise it's be nil.
			# We do this to prevent a separator being added to the top of each menu.
			@groups[groupId] = item['Group']
			
			# Insert the item
			if item['sub_menu']
				cmd = item['Command']
				return host.add_submenu( @config['Commands'][cmd]['Label'] )
			else
				puts "No such command '#{item['Command']}' registered!" unless @procs.key?( item['Command'] )
				return host.add_item( @procs[ item['Command'] ] )
			end
		rescue => details
			puts "Error! Can't add UI item '#{ui_id}'\n>#{details}\n#{details.backtrace.join("\n")}"
			return nil
		end
	end
	private :add_item

	# @private
	# @since 1.1.0
	def get_host_path(item)
		host = item['Host']
		#puts host
		path = []
		until host.nil?
			path << host
			host = (@ui.key?(host)) ? @ui[host]['Host'] : nil
			#puts "> #{host}"
		end
		#puts path.inspect
		return path.reverse.collect { |i|
			if @ui.key?(i)
				@ui[i]['Label']
			elsif @config['UI'].key?(i)
				@config['UI'][i]['Label']
			else
				i
			end
		}
	end
	private :get_host_path
	
	# @private
	# @since 1.1.0
	def get_shortcut(item)
		path = get_host_path(item)
		#puts path
		path[0] = 'Edit/Item' if path[0] == 'Context Menu'
		path[0] = 'Tools' if path[0] == 'Tools Menu'
		path << item['Label']
		path = path.join('/')
		#puts path
		
		Sketchup.get_shortcuts.each { |s|
			hotkey, p = s.split("\t")
			return hotkey if p == path
		}
		return nil
	end
	private :get_shortcut
	
	# @since 1.1.0
	def show_cheat_sheet
		html = ''
    webdialog_path = File.join(PATH, 'webdialog')
    filename = File.join(webdialog_path, 'cheat_sheet.html')
		path = webdialog_path + '/'
		File.open(filename, 'r') { |f|
			f.read(nil, html)
		}
		content = ''
		@ui.each { |id,item|
			# Ignore Submenus
			#next if item.key?('sub_menu') && item['sub_menu']
			
			# Get Shortcut
			hotkey = get_shortcut(item)
			hotkey = "<code>(#{hotkey})</code>" unless hotkey.nil?
			# Title with shortcut
			str = "\t<dt>#{item['Label']} #{hotkey}</dt>\n"
			# Get Icon
			if item.key?('LargeIcon')
				icon_path = @config['General']['ConfigPath'] + @config['General']['IconPath']
				icon = icon_path + item['LargeIcon']
				str += "\t<dd class='icon'><img src='#{icon}' width='24' height='24' /></dd>\n"
			end
			# Get Host Path
			host = get_host_path(item).join(" » ")
			str += "\t<dd class='host'>#{host}</dd>\n"
			# Description
			str += "\t<dd>#{item['Description']}</dd>\n"
			content += str
		}
		html.gsub!('%PATH%', path)
		html.gsub!('%TITLE%', @config['General']['Title'])
		html.gsub!('%CONTENT%', content)
	
		w = UI::WebDialog.new("#{@config['General']['Title']} Cheat Sheet")
		w.set_html(html)
		w.show
	end
		
 end # class UI_Manager
end # module