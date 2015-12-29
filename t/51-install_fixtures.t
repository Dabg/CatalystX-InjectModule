#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 'no_plan';
use lib "t/lib";

$ENV{CATALYST_CONFIG} = 't/conf/install_fixtures.yml';

use_ok( 'Catalyst::Test', 'MyApp' );

ok(my(undef, $c) = ctx_request('/'), 'get catalyst context');

my $module_Fixture = $c->mi->get_module('Fixture');

is( -e $c->mi->_persist_file_name($module_Fixture), 1, 'persistent file exist');

ok($c->mi->uninstall_module($module_Fixture), 'UnInstall module Fixture');

is( ! -e $c->mi->_persist_file_name($module_Fixture), 1, 'persistent file is deleted');

unlink 't/share/myapp-schema.db';
