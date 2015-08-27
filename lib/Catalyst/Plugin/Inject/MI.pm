use utf8;
package Catalyst::Plugin::Inject::MI;

use Moose;
use namespace::autoclean;
use Dependency::Resolver;
use Catalyst::Plugin::Inject::Module;

has modules => (is      => 'rw',
                isa     => 'ArrayRef',
                default => sub { [] },
               );

has deps => ( is       => 'rw',
              isa      => "ArrayRef|Catalyst::Plugin::Inject::Module",
              default  => sub {[]},
            );

has resolver => (
              is       => 'rw',
              isa      => 'Dependency::Resolver',
              default  => sub { Dependency::Resolver->new }
          );

has name_to_ids => (is      => 'rw',
                   isa     => 'HashRef',
                   default => sub { {} },
               );


sub get_module {
    my $self      = shift;
    my $module    = shift;
    my $operation = shift;
    my $version   = shift;

    if ( ! $operation || ! $version ) {
        $operation = '>=';
        $version   = 0;
    }

    my $ids_module = $self->name_to_ids->{$module};

    # operation / version
    # if operation : '>=' => uses the high version after or egal to 'version'
    #                '>'  => uses the high version after to 'version'
    #                '<'  => uses the high version under or egal to 'version'
    #                '<=' => uses the high version under to 'version'

    foreach my $id ( @$ids_module ) {
        my $mod = ${$self->modules}[$id];
        return $mod;
        print "get_module: module=$module id=$id version:" . $mod->version . "\n";
    }
}

sub resolv {
    my $self      = shift;
    my $module    = shift;
    my $operation = shift;
    my $version   = shift;

    my $moduleref = $self->get_module($module, $operation, $version );
    $self->resolver->dep_resolv($moduleref);
}

sub load {
    my $self           = shift;
    my $conf           = shift;
    my $conf_filename  = shift;

    $conf_filename ||= 'config.yml';
    print "load_modules ...\n";

    # search modules in 'path' directories  and in @INC
    for my $dir ( @{ $conf->{'path'} }, @INC ) {
        $self->load_modules_path($dir, $conf_filename);
    }
    $self->convert_deps;
}

sub convert_deps{
    my $self = shift;

    foreach my $m ( @{$self->modules} ) {
        my $i=0;
        print "module:" . $m->name ."\n";
        foreach my $name_op_version ( @{$m->deps} ) {

            my ( $name, $operation, $version ) = split ( /\s+/, $name_op_version) ;
            print "   dependence: $name\n";
            print "   search module with good version ...\n";
            # Converts the dependency name into a module object
            # use the first module finded (without operation and version)
            ${$m->deps}[$i] = $self->get_module($name);
            $i++;
        }
    }
}




sub load_modules_path{
    my $self           = shift;
    my $dir            = shift;
    my $conf_filename  = shift;

    print "  - search modules on $dir ...\n";

    my $id=0;
    for my $mod_path ( glob("$dir/*") ) {
        next if ! -d $mod_path;

        my $mod_name = $mod_path;
        $mod_name =~ s/\/$//gmx;
        $mod_name =~ s/^.*\///gmx;

        my $mod_conf_filename = "$mod_path/$conf_filename";

        # OK config exist
        if ( -e $mod_conf_filename ) {
            print "    - find module $mod_name : OK\n";
            my $mod_config;
            my $filename;
            my $cfg = Config::Any->load_files({files => [$mod_conf_filename], use_ext => 1 })
                or die "Error (conf: $mod_conf_filename) : $!\n";
            ($filename, $mod_config) = %{$cfg->[0]};

            my $args = { name => $mod_name };
            $args->{path} = $mod_path;

            $args->{version} = $mod_config->{version}
                if ( defined $mod_config->{version} );

            $args->{deps} = $mod_config->{dependencies}
                if ( defined $mod_config->{dependencies} );

            # adds the new module found in modules
            push( @{ $self->modules },Catalyst::Plugin::Inject::Module->new( $args ));

            push(@{$self->name_to_ids->{$mod_name}}, $id);
            $id++;
        }
        #else {  print "No config -> NEXT"; }
    }
}

=head1 NAME

Catalyst::Plugin::Inject::MI Module injector

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=cut

1;
