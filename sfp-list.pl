#!/usr/bin/perl
use warnings;
use strict;
use autodie;

@ARGV = glob 'out/*.sfp' unless @ARGV;

my $name;
my @v;

sub dump_v {
	warn "XXX $name $ARGV v=", join(',',@v);
}
sub print_line {
	dump_v;
	my $sw = $ARGV; $sw =~ s/out\///; $sw =~ s/\.sfp//;
	return if grep { /status: no-link/ } @v; # skip
	print join(" | ", $sw, $name, @v), $/;
}

while(<>) {
	chomp;
	s/\r$//;
	if ( /^$/ ) {
		print_line;
		@v = ();
		next;
	}
	warn "## $_\n";
	if ( m/(;;;|name|status|rate|wavelength)/ ) {
		s/^\s+//;
		if ( m/^name: (\S+)/ ) {
			$name = $1;
		} else {
			push @v, $_;
		}
	} else {
		#warn "# ignore [$_]";
	}
}
