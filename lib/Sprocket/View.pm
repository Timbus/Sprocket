#!/usr/bin/perl
package Sprocket::View;
use strict;
use warnings;
use 5.10.0;

use Gtk2;
use Moose;
use MooseX::NonMoose;
extends 'Gtk2::SourceView2::View';

has 'start_iter' => (
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->get_buffer->get_start_iter;
	},
);

has 'end_iter' => (
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->start_iter->copy;
	},
);

sub init {
	my $self = shift;

	my $select_tag = Gtk2::TextTag->new('select_tag');
	$select_tag->set_property('background' => '#cccc00');
	$select_tag->set_property('underline'  => 'single'); 

	my $follow_tag = Gtk2::TextTag->new('follow_tag');
	$follow_tag->set_property('background' => 'green'); 
	$follow_tag->set_property('underline'  => 'single'); 
	
	my $run_tag = Gtk2::TextTag->new('run_tag');
	$run_tag->set_property('background'    => 'red'); 
	$run_tag->set_property('underline'     => 'single');
	

	my $tt = $self->get_buffer->get_tag_table;
	$tt->add($select_tag);
	$tt->add($follow_tag);
	$tt->add($run_tag);

	$self->signal_connect('button-press-event'   => \&on_click);
	$self->signal_connect('motion-notify-event'  => \&continue_drag);
	$self->signal_connect('button-release-event' => \&end_drag);

	$self->signal_connect('map-event' => \&get_colours);

	$self;
}

sub get_colours {

}

has 'is_dragging' => (
	is => 'rw',
	default => 0,
);

has 'last_direction' => (
	is => 'rw',
	default => 0,
);

has 'active_tag' => (
	is => 'rw',
	default => undef,
);

my $tagmap = {
	1 => 'select_tag',
	2 => 'run_tag',
	3 => 'follow_tag',
};

sub on_click {
	my ($self, $e) = @_;
	my $button = $e->button;
	return undef if ($button != 1 && $button != 2 && $button != 3);
	
	#Deligate these cases.
	return $self->on_doubleclick($e) if $e->type eq '2button-press';
	return $self->on_tripleclick($e) if $e->type eq '3button-press';

	if ($button == 1) {
		my $buf = $self->get_buffer;
		$buf->remove_tag_by_name(
			'select_tag', 
			$buf->get_start_iter, 
			$buf->get_end_iter
		);
	}

	my $tag = $tagmap->{$button};
	$self->active_tag( $tag );
		
	my $start = $self->get_iter_at_window_coords($e->x, $e->y);
	$self->start_iter($start);
	$self->end_iter($start->copy);
	$self->is_dragging(1);
	
	return ($button != 1);
}

sub on_doubleclick {
	my ($self, $e) = @_;
	#Can't (yet) justify an action for doubleclicking mid/right mouse btn.
	return undef if $e->button != 1;

	my $point = $self->get_iter_at_window_coords($e->x, $e->y);
	my ($start, $end) = ($point->copy, $point->copy);

	$start->backward_word_start() unless $point->starts_word;
	$end->forward_word_end()      unless $point->ends_word;
	
	$self->get_buffer->apply_tag_by_name($tagmap->{$e->button}, $start, $end);
	return 1;
}

sub on_tripleclick {
	my ($self, $e) = @_;
	return undef if $e->button != 1;
	
	my $point = $self->get_iter_at_window_coords($e->x, $e->y);
	my ($start, $end) = ($point->copy, $point->copy);
	
	$start->set_line($point->get_line) unless $point->starts_line;
	$end->forward_line() unless $point->ends_line;

	$self->get_buffer->apply_tag_by_name($tagmap->{$e->button}, $start, $end);
	
	return 1;
}

sub continue_drag {
	my ($self, $e) = @_;
	return 0 if (!$self->is_dragging());

	my $current = $self->get_iter_at_window_coords($e->x, $e->y);
	my $start = $self->start_iter;
	my $end = $self->end_iter;
	my $buf = $self->get_buffer;
	
	if (!$current->equal($end)) {
		my $direction = $current->compare($start);
		my $active_tag = $self->active_tag;
		if ($direction){
			if ($direction != $self->last_direction){
				$buf->remove_tag_by_name($active_tag, $start, $end);
				$buf->apply_tag_by_name($active_tag, $start, $current);
			}
			elsif ($direction != $current->compare($end)) {
				$buf->remove_tag_by_name($active_tag, $current, $end);
			}
			else {
				$buf->apply_tag_by_name($active_tag, $current, $end);
			}
			$self->last_direction($direction);
		}
		else {
			$buf->remove_tag_by_name($active_tag, $start, $end);
		}
		$self->end_iter($current);

		$buf->place_cursor($current);
	}
	return 1;
}

sub end_drag {
	my ($self, $e) = @_;
	my ($start, $end) = ($self->start_iter, $self->end_iter);
	
	if (!$start->equal($end) && $e->button != 1) {
		$self->get_buffer->remove_tag_by_name($self->active_tag, $start, $end);
		$self->start_iter($end);
	}

	$self->is_dragging(0);
	return 0;
}


#Seriously why is this not a core function
sub get_iter_at_window_coords {
	my ($self, $x, $y) = @_;
	my ($buf_x, $buf_y) =
	$self->window_to_buffer_coords (
		'widget', int($x), int($y)
	);

	$self->get_iter_at_location($buf_x, $buf_y);
}

__PACKAGE__->meta->make_immutable;
