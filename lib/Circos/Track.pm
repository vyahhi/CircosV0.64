package Circos::Track;

=pod

=head1 NAME

Circos::Track - track routines in Circos

=head1 SYNOPSIS

This module is not meant to be used directly.

=head1 DESCRIPTION

Circos is an application for the generation of publication-quality,
circularly composited renditions of genomic data and related
annotations.

Circos is particularly suited for visualizing alignments, conservation
and intra and inter-chromosomal relationships. However, Circos can be
used to plot any kind of 2D data in a circular layout - its use is not
limited to genomics. Circos' use of lines to relate position pairs
(ribbons add a thickness parameter to each end) is effective to
display relationships between objects or positions on one or more
scales.

All documentation is in the form of tutorials at L<http://www.circos.ca>.

=cut

# -------------------------------------------------------------------

use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(
track_type_ok
get_track_types
);

use Carp qw( carp confess croak );
use Data::Dumper;
use FindBin;
use GD::Image;
use Params::Validate qw(:all);
use List::MoreUtils qw(uniq);

use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/../lib";
use lib "$FindBin::RealBin/lib";

use Circos::Configuration; # qw(%CONF $DIMS);
use Circos::Constants;
use Circos::Debug;
use Circos::Error;
use Circos::Utils;

use Memoize;

for my $f ( qw ( ) ) {
memoize($f);
}

our @type_ok = qw(scatter line histogram heatmap highlight tile text connector);

sub make_tracks {
	my ($conf_leaf,$track_default,$type) = @_;
	my @tracks;
	# If the tracks are stored as named blocks, associate the
	# name with the __id parameter for each track. Otherwise, generate __id
	# automatically using an index
	if (ref $conf_leaf eq "HASH") {
		# Could be one or more named blocks, or a single unnamed block.
		# If each value is a hash, then assume that we have named blocks
		my @values      = values %$conf_leaf;
		my $values_hash = grep(ref $_ eq "HASH", @values);
		if ($values_hash == @values) {
	    # likely one or more named blocks
	    printdebug_group("conf","found multiple named tracks");
	    for my $track_name (keys %$conf_leaf) {
				printdebug_group("conf","adding named track [$track_name]");
				my $track      = $conf_leaf->{$track_name};
				if ( ref $track eq "ARRAY" ) {
					fatal_error("track","duplicate_names",$track_name);
				}
				if (defined $track->{id}) {
					$track->{__id} = $track->{id};
				} else {
					$track->{id}   = $track->{__id} = $track_name;
				}
				push @tracks, $track;
	    }
		} else {
			# likely a single unnamed block
			printdebug_group("conf","found single unnamed track block");
			push @tracks, $conf_leaf;
		}
	} elsif (ref $conf_leaf eq "ARRAY") {
		# Multiple unnamed/named blocks. A named block will be a
		# hash with a single key whose value is a hash
		printdebug_group("conf","found multiple unnamed/named track blocks");
		for my $track (@$conf_leaf) {
			if (ref $track eq "HASH" && keys %$track == 1) {
		    # this could be a named track, or an unnamed track with
		    # a single entry
		    my ($track_name) = keys %$track;
		    if (ref $track->{$track_name} eq "HASH") {
					$track = $track->{$track_name};
					# it's named, because its entry is a hash
			    if (defined $track->{id}) {
						$track->{__id} = $track->{id};
					} else {
						$track->{id}   = $track->{__id} = $track_name;
					}
					printdebug_group("conf","adding named track block [$track_name]");
					push @tracks, $track;
				} else {
					# it's unnamed
					printdebug_group("conf","adding unnamed track block");
					push @tracks, $track;
		    }
			} else {
		    # unnamed
		    printdebug_group("conf","adding unnamed track block");
		    push @tracks, $track;
			}
		}
	}
	assign_auto_id(@tracks);

	# assign auto type
	for my $t (@tracks) {
		if (! defined $t->{type}) {
			$t->{type} ||= seek_parameter("type",$track_default);
			$t->{type} ||= $type;
			if (! defined $t->{type}) {
				fatal_error("track","no_type",join(",",get_track_types()),$t->{id},Dumper($t));
			}
		}
		$t->{file} ||= seek_parameter("file",$track_default);
		if (! defined $t->{file}) {
			fatal_error("track","no_file",$t->{type},$t->{id},Dumper($t));
		}
	}
	assign_defaults(\@tracks,$track_default);
	#clear_undef(\@tracks);
	return @tracks;

}

sub clear_undef {
	my $tracks = shift;
	for my $t (@$tracks) {
		for my $param (keys %$t) {
	    delete $t->{$param} if $t->{$param} eq "undef";
		}
	}
}

sub assign_defaults {
	my ($tracks,$track_default) = @_;
	my $dir = fetch_conf("track_defaults");
	return unless defined $dir;
	my @types = uniq map {$_->{type}} @$tracks;
	for my $type (sort @types) {
		my $conf_file = "$dir/$type.conf";
		my $conf      = Circos::Configuration::loadconfiguration($conf_file,1);
		for my $track (@$tracks) {
			next unless $track->{type} eq $type;
			for my $default (keys %$conf) {
				if(! defined seek_parameter($default, $track, $track_default) ) {
					printdebug_group("conf","default",$type,$default,$conf->{$default});
					$track->{$default} = $conf->{$default};
				}
			}
		}
	}
}

sub assign_auto_id {
	my @tracks = @_;
	for my $i (0..@tracks-1) {
		my $track = $tracks[$i];
		my $id = first_defined($track->{id}, $track->{__id});
		if(! defined $id) {
			$id = sprintf("track_%d",$i);
			printdebug_group("conf","adding automatic track id [$id]");
		}
		$tracks[$i]{id} = $tracks[$i]{__id} = $id;
	}	
}

sub track_type_ok {
	my $type = shift;
	return grep($type eq $_, @type_ok);
}

sub get_track_types {
	return @type_ok;
}

1;
