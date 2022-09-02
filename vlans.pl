#!/usr/bin/perl
use warnings;
use strict;

chdir '/home/dpavlin/mikrotik-switch';

foreach my $sw ( glob('backup/*.rsc'), glob('../tilera/backup/backup.rsc') ) {
	open(my $fh, '<', $sw);
	$sw =~ s{^.*backup/}{};
	$sw =~ s{\.\w+}{};
	$sw = 'sw-core' if $sw eq 'backup'; # rewrite tilera name
	while(<$fh>) {
		chomp;
		if ( m/vlan-ids?=(\d+)/ ) {
			next if m/disabled=yes/;
			my $vlan = $1;
			my $ports;
			if ( m/tagged-ports=(\S+)/ ) {
				$ports = $1;
			} elsif ( m/tagged=(\S+)/ ) {
				$ports = $1;
			} elsif ( m/ports=(\S+)/ ) {
				$ports = $1;
			} elsif (  m/name=(\S+)/ ) {
				$ports = $1;
			} else {
				warn "IGNORED: $_\n";
			}

			# can be "quoted" and have spaces
			#if ( m/interface=(\S+)/ ) {
			#	$ports = "i:$1 $ports";
			#}

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
