/*
 * TODO:
 * Abstracct the code for the list object so it can be reused.
 */

$(document).ready(init);

// Global variables
var app_info = {};


function init()
{
	// Add callbacks
	add_callbacks();
	// Signal that we're ready
	window.location = 'skp:ready';
}


function add_callbacks()
{
	$('#cmdSave').click( function() { window.location = 'skp:save'; } );
	$('#cmdCancel').click( function() { window.location = 'skp:cancel'; } );
}

// Process all the data from Sketchup. Used to be sent separatly in Ruby, but
// due to syncing problems on Mac we do it all here.
function process_data(data)
{
	// Set General Info
	set_info(data['Info']);
	// Add UI Hosts
	add_ui_hosts(data['Hosts']);
	// UI Elements
	for (var key in data['UI'])
	{
		add_ui_element(key, data['UI'][key]);
	}
}

// Sets the General info
function set_info(data)
{
	app_info = data;
	$('#header .title').text(data['Title']);
	$('#header .info a').text(data['Info']);
	$('#header .info a').attr('href', data['URL']);
	$('#header .info a').attr('title', data['URL']);
}

// Adds the host UI groups
function add_ui_hosts(data)
{
	var list = $('#listUI');
	for (var key in data)
	{
		var value = data[key];
		var sublist = 'ui_' + key;
		var li = $('<li id="'+sublist+'"><h2>'+value+'</h2><ul></ul></li>');
		list.append(li);
		// Add fold/unfold events.
		li.find('h2').click(function () {
			$(this).parent().find('ul').slideToggle('fast');
		});
	}
}

// Adds UI elements to the list
function add_ui_element(id, data)
{
	//if (data == undefined) { return }
	
	var host = $('#ui_' + data['Host'] + ' > ul');
	// Build HTML
	var li = $('<li id="ui_' + id + '"></li>');
	// Checkbox to store data we can retreive from Ruby.
	li.append('<input type="hidden" id="ui_' + id + '_data"/>');
	// Toolbar icon
	if (data['SmallIcon'])
	{
		var file = app_info['ConfigPath'] + app_info['IconPath'] + data['SmallIcon'];
		li.append('<img src="' + file + '" width="16" height="16" />');
	}
	li.append(data['Label']);
	li.append('<div class="description">' + data['Description'] + '</div>');
	// Set INPUT data which SU can get the list data from
	li.find('input').val(data['Visible']);
	// Set classes to indicate the default selected state
	if (data['Visible']) { li.addClass('default selected'); }
	// Sub section
	if (data['sub_menu'])
	{
		li.append('<div class="listToggle collapse" title="Collapse Section">Collapse</div>');
		li.append('<ul></ul>');
		sub_list = li.children('.listToggle');
		sub_list.next('ul').hide();
	}
	// Add to document
	host.append(li);
	if (data['sub_menu'])
	{
		li.find('.listToggle').click(foldlist_listToggle);
	}
	// Attach events
	if (data['Locked'] != true)
	{
		li.click(foldlist_listitem_click);
		li.click(function () {
			// Restart Indicator
			if ( $('#listUI .add, #listUI .remove').length > 0 )
			{
				$('body').addClass('restart');
			}
			else
			{
				$('body').removeClass('restart');
			}
		});
	}
	else
	{
		li.addClass('locked');
	}
}