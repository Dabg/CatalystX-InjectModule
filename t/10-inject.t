#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 'no_plan';
use lib "t/lib";

#BEGIN { $ENV{CATALYST_CONFIG} = 't/myapp.yml' }

$ENV{CATALYST_CONFIG} = 't/myapp.yml';

use_ok( 'Catalyst::Test', 'MyApp' );

ok(my(undef, $c) = ctx_request('/'), 'The first request');

#          A
#         / \
#        v   v
#        D   B
#        ^  /\
#         \v  v
#          C->E

my $resolved = $c->im->resolv('Ax');
my $resolved_names = [ map  $_->name , @$resolved ];
use Data::Dumper;print Dumper($resolved_names);
is_deeply( $resolved_names, [ 'Dx', 'Ex', 'Cx', 'Bx', 'Ax' ], 'return the expected modules');

print $c->im->get_module('Ax');
