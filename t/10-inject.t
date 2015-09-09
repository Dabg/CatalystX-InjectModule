#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 'no_plan';
use lib "t/lib";

# Dependencies between modules
# (see all config.yml in paths defined in myapp.yml)
#
#          A
#         / \
#        v   v
#        D   B
#        ^  /\
#         \v  v
#          C->E

$ENV{CATALYST_CONFIG} = 't/myapp.yml';

use_ok( 'Catalyst::Test', 'MyApp' );

ok(my(undef, $c) = ctx_request('/'), 'The first request');

# After first request 'A' and 'Ax' modules are loaded (and their dependencies).

# check if Dependency::Resolver working properly
my $resolved = $c->mi->resolv('Ax');
my $resolved_names = [ map  $_->{name} , @$resolved ];
is_deeply( $resolved_names, [ 'Dx', 'Ex', 'Cx', 'Bx', 'Ax' ], 'return the expected modules');

ok( my $ax = $c->mi->get_module('Ax'), 'get Ax module');
is($ax->{path}, 't/share/modulesX/Ax', 'return Ax module path');

ok( my $bx1 = $c->mi->get_module('Bx', "==", 1), 'get Bx1 module');
is($bx1->{path}, 't/share/modulesX/Bx', 'return Bx1 path');

ok( my $bx2 = $c->mi->get_module('Bx'), 'get Bx2 module');
is($bx2->{path}, 't/share/modules/Bx', 'return Bx2 path');



# check if INC contains Ax lib :
ok((grep { 't/share/modulesX/Ax/lib' eq $_ } @INC), 'check if INC contains Ax lib');

# check if Controller A is injected from modules/A/lib/MyApp/Controller/A.pm
ok( request('/a')->is_success, 'Request /a should succeed' );

# check if Controller Bx is injected from modules/Bx/lib/MyApp2/Controller/Bx.pm
ok( request('/bx')->is_success, 'Request /bx should succeed' );
