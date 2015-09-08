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

my $resolved = $c->mi->resolv('Ax');
my $resolved_names = [ map  $_->{name} , @$resolved ];


is_deeply( $resolved_names, [ 'Dx', 'Ex', 'Cx', 'Bx', 'Ax' ], 'return the expected modules');

ok( my $ax = $c->mi->get_module('Ax'), 'get Ax module');

is($ax->{path}, 't/share/modulesX/Ax', 'return Ax module path');
