#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Getopt::Long qw(:config bundling);
use JSON;
use Pod::Usage;
use POSIX qw(setsid strftime);
use Storable;
use Time::HiRes qw(gettimeofday tv_interval usleep);

my $VERSION = v0.10.0;
my $MINDER_ROOT = (($ENV{HOME}) && -e $ENV{HOME}) ? $ENV{HOME} : '';
my ($MIN_SLEEP, $MAX_SLEEP) = (250000, 750000);

my $opt_date = strftime("%Y%m%d", localtime);
my ($opt_daemon, $opt_help, $opt_human, $opt_man, $opt_minified, $opt_output) = 0;

GetOptions (
    'daemon'        => \$opt_daemon,
    'd|date=s'      => \$opt_date,
    'help'          => \$opt_help,
    'h|human'       => \$opt_human,
    'm|minified'    => \$opt_minified,
    'man'           => \$opt_man,
    'o|output'      => \$opt_output,
    'v|version'     => sub{ version_message() },
) || pod2usage(2);
pod2usage(1) if ($opt_help);
pod2usage(-exitval => 0, -verbose => 2) if ($opt_man);

my $procs;
$procs = retrieve("$MINDER_ROOT/.minder_data") if (-e "$MINDER_ROOT/.minder_data");

if ($opt_output) {
    print_data({
        date        => $opt_date,
        human       => $opt_human,
        minified    => $opt_minified,
    });
}
elsif ($opt_daemon) {
    daemonize();
    collect();
}
else {
    pod2usage(1);
}

sub collect {
    my $sleep = $MIN_SLEEP;
    my $time_previous = [gettimeofday];

    while (usleep $sleep) {
        my $time_now = [gettimeofday];
        my $seconds_slept = tv_interval($time_previous, $time_now);
        my $seconds_idle = get_idle();
        my $seconds_used = $seconds_slept - $seconds_idle;

        if ($seconds_used > 0 && $seconds_used <= ($MAX_SLEEP / 1000000)) {
            my $frontmost = get_frontmost();
            my $datestamp = strftime "%Y%m%d", localtime($time_now->[0]);
            my $timestamp = strftime "%H:%M", localtime($time_now->[0]);

            $procs->{$datestamp}->{$frontmost}->{total} += $seconds_used;
            $procs->{$datestamp}->{$frontmost}->{$timestamp} += $seconds_used;
            $sleep -= 10000 if ($sleep > $MIN_SLEEP);
            store \%$procs, "$MINDER_ROOT/.minder_data" if ((($sleep / 10000) % 6) == 0);
        }
        elsif ($sleep < $MAX_SLEEP) {
            $sleep += 10000;
        }

        $time_previous = $time_now;
    }
}

sub print_data {
    my $args = shift;
    my $data = $procs->{$args->{date}};

    if ($args->{human}) {
        for my $app ( sort { lc $a cmp lc $b } keys %$data ) {
            printf("%-64s%11.2fs\n", "$app", "$data->{$app}->{total}");
        }
    }
    else {
        if ($args->{minified}) {
            say JSON->new->utf8->encode($data);
        }
        else {
            say JSON->new->utf8->pretty->encode($data);
        }
    }

    exit;
}

sub get_idle {
    open(my $fh, '-|', 'ioreg', '-c', 'IOHIDSystem');
    for my $line (<$fh>) {
        chomp($line);
        my @parts = split(' ', $line);
        if ($line =~ /Idle/) {
            close $fh;
            return (pop @parts)/1000000000;
        }
    }
    close $fh;
}

sub get_frontmost {
    open(my $fh, '-|', 'osascript', '-e', 'tell application "System Events" to get name of (processes whose frontmost = true)');
    chomp(my $line = <$fh>);
    close $fh;
    return $line;
}

sub daemonize {
    chdir('/')                      || die "can't chdir to /: $!";
    open(STDIN, '<', '/dev/null')   || die "can't read /dev/null: $!";
    open(STDOUT, '>', '/dev/null')  || die "can't write to /dev/null: $!";
    defined(my $pid = fork())       || die "can't fork: $!";
    exit if $pid;
    (setsid() != -1)                || die "Can't start a new session: $!";
    open(STDERR, '>&', STDOUT)      || die "can't dup stdout: $!";
}

sub version_message {
    printf("minder %vd\n", $VERSION);
    say "Copyright (C) 2013 Trevor Parker";
    exit;
}

__END__

=head1 NAME

minder -- App usage data collection and display for OS X

=head1 SYNOPSIS

B<minder> [-B<dhmov>]

=head1 OPTIONS

=over 8

=item B<--daemon>

Run in daemon mode and collect application usage data.

=item B<-d>, B<--date>

Select a specific date in B<YYYYMMDD> format for printing application
usage data. This option is ignored unless run with B<--output> option.

=item B<--help>

Print a brief help message and then exit.

=item B<-h>, B<--human>

Print application usage data in human-readable format: application name
left-aligned, and number of seconds in this app right-aligned. This
option is ignored unless run with B<--output> option.

=item B<--man>

Print full documentation and then exit.

=item B<-m>, B<--minified>

Print application usage data in minified JSON format. This option is
ignored unless run with B<--output> option.

=item B<-o>, B<--output>

Print one day's application usage data and exit. By default, the format
is indented JSON and today's data is output.

=item B<-v>, B<--version>

Print current version information and exit.

=back

=head1 DESCRIPTION

Collects and displays information about application usage on Mac OS X.

=cut
