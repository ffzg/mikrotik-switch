#!/usr/bin/perl
use warnings;
use strict;

foreach my $sw ( glob 'backup/*' ) {
	open(my $fh, '<', $sw);
	$sw =~ s{\w+/}{};
	$sw =~ s{\.\w+}{};
	while(<$fh>) {
		chomp;
		if ( m/vlan-ids?=(\d+)/ ) {
			my $vlan = $1;
			my $ports;
			if ( m/tagged-ports=(\S+)/ ) {
				$ports = $1;
			} elsif ( m/tagged=(\S+)/ ) {
				$ports = $1;
			} elsif ( m/ports=(\S+)/ ) {
				$ports = $1;
			} else {
				warn "IGNORED: $_\n";
			}
			if ( $ports =~ m/,/ ) {
				foreach my $port ( split(/,/, $ports) ) {
					print "$sw $port $vlan\n";
				}
			} elsif ( $ports ) {
				print "$sw $ports $vlan\n";
			}
		}
	}
}
