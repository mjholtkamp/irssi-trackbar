# trackbar.pl
#
# Track what you read last when switching to a window.
#
#    Copyright (C) 2003  Peter Leurs
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# 
# This little script will do just one thing: it will draw a line each time you
# switch away from a window. This way, you always know just upto where you've
# been reading that window :) It also removes the previous drawn line, so you
# don't see double lines.
#
# Usage: 
#
#     The script works right out of the box, but if you want you can change
#     the working by /set'ing the following variables:
#
#     trackbar_string       The characters to repeat to draw the bar
#     trackbar_style        The style for the bar, %r is red for example
#                           See formats.txt that came with irssi
#
#     /mark is a command that will redraw the line at the bottom.  However!  This
#     requires irssi version after 20021228.  otherwise you'll get the error
#     redraw: unknown command, and your screen is all goofed up :)
#
#     /upgrade & buf.pl notice: This version tries to remove the trackbars before 
#     the upgrade is done, so buf.pl does not restore them, as they are not removeable
#     afterwards by trackbar.  Unfortiounatly, to make this work, trackbar and buf.pl
#     need to be loaded in a specific order.  Please experiment to see which order works
#     for you (strangely, it differs from configuration to configuration, something I will
#     try to fix in a next version) 
#
# Authors:
#   - Main maintainer & author: Peter 'kinlo' Leurs
#   - Many thanks to Timo 'cras' Sirainen for placing me on my way
#   - on-upgrade-remove-line patch by Uwe Dudenhoeffer
#   - trackbar resizing by Michiel Holtkamp (02 Jul 2012)
#
# Version history:
#  1.6: - Work around Irssi resize bug (see below)
#  1.5: - Resize trackbars in all windows when terminal is resized
#  1.4: - Changed our's by my's so the irssi script header is valid
#       - Removed utf-8 support.  In theory, the script should work w/o any
#         problems for utf-8, just set trackbar_string to a valid utf-8 character
#         and everything *should* work.  However, this script is being plagued by
#         irssi internal bugs.  The function Irssi::settings_get_str does NOT handle
#         unicode strings properly, hence you will notice problems when setting the bar
#         to a unicode char.  For changing your bar to utf-8 symbols, read the line sub.
#  1.3: - Upgrade now removes the trackbars. 
#       - Some code cleanups, other defaults
#       - /mark sets the line to the bottom
#  1.2: - Support for utf-8
#       - How the bar looks can now be configured with trackbar_string 
#         and trackbar_style
#  1.1: - Fixed bug when closing window
#  1.0: - Initial release
#
#
# Known bugs:
#  - if you /clear a window, it will be uncleared when returning to the window
#  - UTF-8 characters in the trackbar_string doesnt work.  This is an irssi bug.
#  - changing the trackbar style is only visible after returning to a window
#  however, changing style/resize takes in effect after you left the window.
#
# Whishlist/todo:
#  - instead of drawing a line, just invert timestamp or something, 
#    to save a line (but I don't think this is possible with current irssi)
#  - some pageup keybinding possibility, to scroll up upto the trackbar
#  - <@coekie> kinlo: if i switch to another window, in another split window, i 
#              want the trackbar to go down in the previouswindow in  that splitwindow :)
#  - < bob_2> anyway to clear the line once the window is read?
#  - < elho> kinlo: wishlist item: a string that gets prepended to the repeating pattern
#  - < elho> an option to still have the timestamp in front of the bar
#  - < elho> oh and an option to not draw it in the status window :P
#
# BTW: when you have feature requests, mailing a patch that works is the fastest way
# to get it added :p

# IRSSI RESIZE BUG:
# when resizing from a larger window to a smaller one, the width of the
# trackbar causes some lines at the bottom not to be shown. This only happens
# if the trackbar was not the last line. This glitch can be 'fixed' by
# resetting the trackbar to the last line (e.g. by switching to another window
# and back) and then resize twice (e.g. to a bigger size and back). Of course,
# this is not convenient for the user.
# This script works around this problem by printing not one, but two lines and
# then removing the second line. My guess is that irssi does something to the
# previous line (or the line cache) whenever a line is 'completed' (i.e. the
# EOL is sent). When only one line is printed, it is not 'completed', but when
# printing the second line, the first line is 'completed'. The second line is
# still not completed, but since we delete it straight away, it doesn't matter.

use strict;
use 5.6.1;
use Irssi;
use Irssi::TextUI;

my $VERSION = "1.6";

my %IRSSI = (
    authors     => "Peter 'kinlo' Leurs, Uwe Dudenhoeffer, Michiel Holtkamp",
    contact     => "irssi-trackbar\@supermind.nl",
    name        => "trackbar",
    description => "Shows a bar where you've last read a window",
    license     => "GPLv2",
    url         => "http://github.com/mjholtkamp/irssi-trackbar/",
    changed     => "Tue, 04 Sep 2012 05:38:04 +0000",
);

my %config;

my $screen_resizing = 0;   # terminal is being resized

Irssi::settings_add_str('trackbar', 'trackbar_string' => '-');
$config{'trackbar_string'} = Irssi::settings_get_str('trackbar_string');

Irssi::settings_add_str('trackbar', 'trackbar_style' => '%K');
$config{'trackbar_style'} = Irssi::settings_get_str('trackbar_style');

Irssi::signal_add(
    'setup changed' => sub {
        $config{'trackbar_string'} = Irssi::settings_get_str('trackbar_string');
        $config{'trackbar_style'}  = Irssi::settings_get_str('trackbar_style');
        if ($config{'trackbar_style'} =~ /(?<!%)[^%]|%%|%$/) {
            Irssi::print(
                "trackbar: %RWarning!%n 'trackbar_style' seems to contain "
                . "printable characters. Only use format codes (read "
                . "formats.txt).", MSGLEVEL_CLIENTERROR);
        }
    }
);

Irssi::signal_add(
    'window changed' => sub {
        my (undef, $oldwindow) = @_;

        if ($oldwindow) {
            my $line = $oldwindow->view()->get_bookmark('trackbar');
            $oldwindow->view()->remove_line($line) if defined $line;
            $oldwindow->print(line($oldwindow->{'width'}), MSGLEVEL_NEVER);
            $oldwindow->view()->set_bookmark_bottom('trackbar');
        }
    }
);

# terminal resize code inspired on nicklist.pl
sub sig_terminal_resized {
	if ($screen_resizing) {
		# prevent multiple resize_trackbars from running
		return;
	}
	$screen_resizing = 1;
	Irssi::timeout_add_once(10,\&resize_trackbars,[]);
}

sub resize_trackbars {
	my $active_win = Irssi::active_win();
	for my $window (Irssi::windows) {
		next unless defined $window;
		my $line = $window->view()->get_bookmark('trackbar');
		next unless defined $line;

		# first add new trackbar line, then remove the old one. For some reason
		# this works better than removing the old one, then adding a new one
		$window->print_after($line, MSGLEVEL_NEVER, line($window->{'width'}));
		my $next = $line->next();
		$window->view()->set_bookmark('trackbar', $next);
		$window->view()->remove_line($line);

		# This hack exists to work around a bug: see IRSSI RESIZE BUG above.
		# Add a line after the trackbar and delete it immediately
		$window->print_after($next, MSGLEVEL_NEVER, line(1));
		$window->view()->remove_line($next->next);
	}
	$active_win->view()->redraw();
	$screen_resizing = 0;
}

Irssi::signal_add('terminal resized' => \&sig_terminal_resized);

sub line {
    my $width  = shift;
    my $string = $config{'trackbar_string'};
    $string = '-' unless defined $string;

    # There is a bug in irssi's utf-8 handling on config file settings, as you 
    # can reproduce/see yourself by the following code sniplet:
    #
    #   my $quake = pack 'U*', 8364;    # EUR symbol
    #   Irssi::settings_add_str 'temp', 'temp_foo' => $quake;
    #   Irssi::print length $quake;
    #       # prints 1
    #   Irssi::print length Irssi::settings_get_str 'temp_foo';
    #       # prints 3
    #
    #
    # Trackbar used to have a workaround, but on recent versions of perl/irssi
    # it does no longer work.  Therefore, if you want your trackbar to contain
    # unicode characters, uncomment the line below for a nice full line, or set
    # the string to whatever char you want.

    # $string = pack('U*', 0x2500);


    my $length = length $string;

    if ($length == 0) {
        $string = '-';
        $length = 1;
    }

    my $times = $width / $length;
    $times = int(1 + $times) if $times != int($times);
    $string =~ s/%/%%/g;
    return $config{'trackbar_style'} . substr($string x $times, 0, $width);
}

# Remove trackbars on upgrade - but this doesn't really work if the scripts are not loaded in the correct order... watch out!

Irssi::signal_add_first( 'session save' => sub {
	    for my $window (Irssi::windows) {	
		next unless defined $window;
		my $line = $window->view()->get_bookmark('trackbar');
		$window->view()->remove_line($line) if defined $line;
	    }
	}
);

sub cmd_mark {
    my $window = Irssi::active_win();
#    return unless defined $window;
    my $line = $window->view()->get_bookmark('trackbar');
    $window->view()->remove_line($line) if defined $line;
    $window->print(line($window->{'width'}), MSGLEVEL_NEVER);
    $window->view()->set_bookmark_bottom('trackbar');
    Irssi::command("redraw");    
}

Irssi::command_bind('mark',   'cmd_mark');
