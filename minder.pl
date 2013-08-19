#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use POSIX qw(setsid strftime);
use Storable;
use Time::HiRes qw(gettimeofday tv_interval usleep);

daemonize();

my $MINDER_ROOT = (($ENV{HOME}) && -e $ENV{HOME}) ? $ENV{HOME} : '';
my $procs;
my $sleep = 250000;
my $time_previous = [gettimeofday];

$procs = retrieve("$MINDER_ROOT/.minder_data") if (-e "$MINDER_ROOT/.minder_data");
while (usleep $sleep) {
    my $time_now = [gettimeofday];
    my $idle_seconds = get_idle();
    if (tv_interval($time_previous, $time_now) - ($idle_seconds) > 0) {
        my $frontmost = get_frontmost();
        my $datestamp = strftime "%Y%m%d", localtime($time_now->[0]);
        my $timestamp = strftime "%H:%M", localtime($time_now->[0]);
        my $time_spent = tv_interval($time_previous, $time_now) - ($idle_seconds);
        $procs->{$datestamp}->{$frontmost}->{total} += $time_spent;
        $procs->{$datestamp}->{$frontmost}->{$timestamp} += $time_spent;
        $sleep -= 10000 if ($sleep > 250000);
        store \%$procs, "$MINDER_ROOT/.minder_data" if ((($sleep / 10000) % 6) == 0);
    }
    elsif ($sleep < 1500000) {
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
