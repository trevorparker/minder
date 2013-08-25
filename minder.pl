#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use POSIX qw(setsid strftime);
use Storable;
use Time::HiRes qw(gettimeofday tv_interval usleep);

daemonize();

my $MINDER_ROOT = (($ENV{HOME}) && -e $ENV{HOME}) ? $ENV{HOME} : '';
my ($MIN_SLEEP, $MAX_SLEEP) = (250000, 750000);

my $procs;
my $sleep = $MIN_SLEEP;
my $time_previous = [gettimeofday];

$procs = retrieve("$MINDER_ROOT/.minder_data") if (-e "$MINDER_ROOT/.minder_data");
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
