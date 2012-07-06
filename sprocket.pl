#!/usr/bin/perl
use 5.10.0;
use strict;
use warnings;

use Gtk2 '-init';
use Gtk2::SourceView2;

use File::Basename;
use File::Spec;
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Sprocket::View;

my $lm = Gtk2::SourceView2::LanguageManager->get_default;
my $lang = $lm->get_language('perl');

my $sb = Gtk2::SourceView2::Buffer->new(undef);
if ($lang) {
	$sb->set_language($lang);
}

# loading a file should be atomically undoable.
$sb->begin_not_undoable_action();
open INFILE, "sprocket.pl" or die "Unable to open sprocket.pl: $!";
while (<INFILE>) {
	$sb->insert($sb->get_end_iter(), $_);
}
$sb->end_not_undoable_action();
$sb->set_modified(0);
$sb->place_cursor($sb->get_start_iter());


my $sw = Gtk2::ScrolledWindow->new;
my $win = Gtk2::Window->new('toplevel');
my $view = Sprocket::View->new();

$sw->set_policy('automatic', 'automatic');
$view->set_buffer($sb);
$view->init();

$sw->add($view);
$win->add($sw);
$win->set_size_request(600, 450);
$win->show_all;

Gtk2->main;
