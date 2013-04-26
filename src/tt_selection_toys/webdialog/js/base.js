/*
 * Common methods for webdialogs.
 *
 * Requires jQuery
 */

$(document).ready(init_UI);

// Assigns events to common UI elements.
function init_UI()
{
	// Focus property
	add_focus_property()
	
	// Buttons
	$('.button').live('mousedown', function() { $(this).addClass('pressed'); return false; });
	$('.button').live('mouseup', function() { $(this).removeClass('pressed'); return false; });
	$('.button').live('selectstart', function() { return false; });
}

// Loops over all input elements and ensure that they get an .focus class added upon focus and
// remove it when it loses focus. This is a workaround for IE7's lack of :hover support.
function add_focus_property()
{
	$('input').each( function(i)
	{
		$(this).focus(function ()
		{
			$(this).addClass('focus');
		});
		$(this).blur(function ()
		{
			$(this).removeClass('focus');
		});
	});
}

// Fold List
function foldlist_listToggle()
{
	$(this).toggleClass('collapse');
	$(this).next('ul').slideToggle('fast');

	if ( $(this).hasClass('collapse') )
	{
		$(this).attr('title', 'Expand Section');
	}
	else
	{
		$(this).attr('title', 'Collapse Section');
	}

	return false;
}

function foldlist_listitem_click() {
	var li = $(this);
	li.toggleClass('selected');
	// Set INPUT data
	if ( li.hasClass('selected') )
	{
		li.find('input').val('true');
	}
	else
	{
		li.find('input').val('false');
	}
	// Illustrate added and removed elements.
	li.removeClass('add remove');
	if ( li.hasClass('selected') && !li.hasClass('default') )
	{
		li.addClass('add');
	}
	if ( !li.hasClass('selected') && li.hasClass('default') )
	{
		li.addClass('remove');
	}
	return false;
}