#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Net::OpenSSH;
use Data::Dump qw(dump);
use Time::HiRes qw(sleep);

our $debug = $ENV{DEBUG} || 0;

my $ip = shift @ARGV || die "usage: $0 IP command[ command ...]\n";
$ip = $1 if `host $ip` =~ m/has address (\S+)/;
my @commands = @ARGV;
if ( ! @commands && ! -t STDIN && -p STDIN ) { # we are being piped into
	while(<>) {
		push @commands, $_;
	}
} else {
	@commands = <DATA> unless @commands;
}

# https://wiki.mikrotik.com/wiki/Manual:Console_login_process
# example: admin+c80w - will disable console colors and set terminal width to 80.
# Param 	Default 	Implicit 	Description
# "w" 	auto 	auto 	Set terminal width
# "h" 	auto 	auto 	Set terminal height
# "c" 	on 	off 	disable/enable console colors
# "t" 	on 	off 	Do auto detection of terminal capabilities
# "e" 	on 	off 	Enables "dumb" terminal mode
my $login = 'admin+dc200w';
#my $login = 'admin+dc200w';
my $login = 'admin+cte';
my $identity = '/home/dpavlin/mikrotik-switch/ssh/mikrotik';

warn "\n## ssh -i $identity $login\@$ip\n";
my $ssh = Net::OpenSSH->new($ip, user => $login,
    master_opts => [
	-i => $identity,
	],
    default_ssh_opts => [
	-i => $identity,
	],
);
my ($pty ,$pid) = $ssh->open2pty();
if ( ! $pty ) {
	warn "ERROR: can't connect to $ip, skipping";
	exit 0;
}

my $buff;

sub send_pty {
	my $string = shift;

	print STDERR "\n>>> ",dump($string), "\n";
	syswrite $pty, $string;
	$pty->flush;
	return; # XXX

	my $read_len = length($string);
	sysread $pty, my $echo, length($string); 
	print STDERR "\n<<< ",dump($echo), "\n";

	# slurp character by character echo
	foreach my $read_len ( 1 .. length($string) ) {
		sysread $pty, $echo, $read_len;
		print STDERR "\n<<< ",dump($echo), "\n";
	}

	print STDERR $echo;
	$buff .= $echo;

=for char-by-char
	sleep 0.05; # we really need to wait for slow PowerConnect 5324
	foreach (split //, $string) {
		print STDERR "[$_]" if $debug;
		syswrite $pty, $_;
		#$pty->flush;
		sleep 0.01;
		sysread $pty, my $echo, 1;
		print STDERR $echo;
		$buff .= $echo;
	}
=cut
}

mkdir 'log' unless -d 'log';

chdir 'log';

sub save_log {
	my ($ip, $hostname, $command, $buff) = @_;

	return unless $command;
	return if $ENV{NO_LOG};

	$command =~ s{/}{}; # remote / in front of command

	my $file = "${hostname}.${command}";
	open my $log, '>', $file;
	#$buff =~ s/\r//gs; # strip CR, leave LF only
	print $log $buff;
	close $log;
	if ( -e '.git' ) {
		system 'git', 'add', $file;
		#system 'git', 'commit', '-m', "$ip $hostname", $file;
	}
}

my $command;
my @commands_while = ( @commands );

while() {
	my $data;
	my $read = sysread($pty, $data, 1); # XXX must be more than 1 to handle echo
	print STDERR $data;
	$buff .= $data;

	# check for prompt
	# [admin@sw-ganeti] >
        #                          [admin@sw-ganeti] >

	$buff =~ s{\r\[[^\]]+\] > /.*?\s+\r}{\r}g && warn "\nXXX remove echo prompt\n";

	if ( $buff =~ s/\s*\e\[K/ /s ) {
		print STDERR "\nXXX ", Time::HiRes::time, " remove prompt echo buff=", dump( $buff ), "\n";
		

	} elsif ( $buff =~ s/\s*\r\[\w+\@([\w\-]+)\]\s>\s// ) { # find prompt and remove it

		my $hostname = $1;
		print STDERR "\nXXX ", Time::HiRes::time, " prompt [$command] buff=", dump( $buff ), "\n";

		if ( $command && substr($command,0,length($buff)) eq $buff ) {
			print STDERR "<";
			$buff = '';
			next; # read more
		}


		if ( length $buff ) {
			save_log $ip, $hostname, $command, $buff;
			$buff = '';
			undef $command;
		} else {

		}

		if ( $command ) {
			print STDERR "<";
			next; # read more
		}

		if ( $command = shift @commands_while ) {
			$command =~ s/[\n\r]+$//;
			send_pty "$command\r\n\r\n";
			$buff = '';
		} else  {
			send_pty "exit\n";
			close($pty);
			last;
		}
	} elsif ( $buff =~ s{(\e\[\d+[a-zA-Z])}{} || $buff =~ s{(\eZ)}{} ) {
		my $ansi = $1;
		print STDERR "\nXXX ", Time::HiRes::time, " ANSI terminal detect?", dump( $ansi, $buff ), "\n";
	} elsif ( $buff =~ s{^.+Use command at the base level\r\n\r}{}s ) {
		warn "\nSTRIP banner", dump( $buff );
	} elsif ( $buff =~ s{\Q--More-- or (q)uit\E}{} ) { # FIXME pager
		send_pty " ";
	}
}

=for later

/interface ethernet print detail without-paging
/interface bridge print
/ip address print
/ip route print
/ip neighbor print detail terse
/system health print
/system package print
/system package update check-for-updates
/system routerboard print

=cut

__DATA__
/interface ethernet print
/interface bridge print
