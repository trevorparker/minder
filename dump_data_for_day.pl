#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Storable;
use POSIX 'strftime';
use Data::Dumper;

my $day = shift || strftime( "%Y%m%d", localtime );

my $MINDER_ROOT = ( ( $ENV{HOME} ) && -e $ENV{HOME} ) ? $ENV{HOME} : '';
my $procs = retrieve("$MINDER_ROOT/.minder_data")
    or die "Couldn't find and load .minder_data\n";

my $data = $procs->{$day};

for my $app ( keys %$data ) {
    say $app;
    for my $time ( sort keys %{ $data->{$app} } ) {
        say "\t", join( "\t", $time, sprintf( '%.1f', $data->{$app}{$time} ) );
    }
}
