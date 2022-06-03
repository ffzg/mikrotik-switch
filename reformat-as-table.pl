#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

my @names;
my $name;
my $name_offset;
my $data;

while(<>) {
	chomp;
	s/\r$//g;
	if ( m/^$/ ) {
		if ( $data ) {
			warn "# data = ",dump($data), $/;
			print join(' ', map { $data->{$_} } grep { ! /eeprom/ } @names), "\n";
		}
		$data = undef;
	} elsif ( substr($_,27,1) eq ' ') {
		if ( my $new_name = substr($_,0,26) ) {
			$new_name =~ s/^\s+//;
			$name = $new_name if $new_name;
			if ( ! exists($name_offset->{$name}) ) {
				push @names, $name;
				$name_offset->{$name} = $#names;
			}
		}
		my $v = substr($_,28);
		warn "# [$name] = [$v]\n";
		if ( exists $data->{$name} ) {
			$data->{$name} .= "\n$v";
		} else {
			$data->{$name} = $v;
		}
	} else {
		die "ERROR: [$_] [",substr($_,26,1),"] not space!";
	}
}
