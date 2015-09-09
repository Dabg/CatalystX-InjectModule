use utf8;
package Catalyst::Plugin::Inject::MI;

use Moose;
use Dependency::Resolver;

has resolver => (
              is       => 'rw',
              isa      => 'Dependency::Resolver',
          );


sub get_module {
    my($self, $mod, $op , $ver) = @_;

    my $modules = $self->resolver->get_modules($mod, $op, $ver);
    return $modules->[-1];
}

sub resolv {
    my $self      = shift;
    my $module    = shift;
    my $operation = shift || '>=';
    my $version   = shift || 0;

    my $Module   = $self->get_module($module, $operation, $version );
    my $resolved = $self->resolver->dep_resolv($Module);
    return $resolved;
}

sub load {
    my $self           = shift;
    my $conf           = shift;
    my $conf_filename  = shift;

    $conf_filename ||= 'config.yml';
    print "load_modules ...\n";

    $self->resolver(Dependency::Resolver->new(debug => $conf->{debug}));

    # search modules in 'path' directories  and in @INC
    for my $dir ( @{ $conf->{path} }, @INC ) {
        $self->load_modules_path($dir, $conf_filename, $conf->{debug});
    }
}


sub load_modules_path{
    my $self           = shift;
    my $dir            = shift;
    my $conf_filename  = shift;
    my $debug          = shift;

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

            my $module = { name    => $mod_config->{name},
                           version => $mod_config->{version},
                           deps    => $mod_config->{deps},
                           path    => $mod_path,
                       };

            $self->resolver->add($module);
        }
        #else {  print "No config -> NEXT\n"; }
    }
}

sub inject {
    my $self    = shift;
    my $modules = shift;

    foreach my $m ( @$modules ) {
        print " Requested module: $m\n";
        my $resolved = $self->resolv($m);

        if ( $resolved->[-1]->{_injected}){
                print "  Already injected\n";
                next;
        }

        foreach my $M ( @$resolved ) {
            print "  inject " . $M->{name} . ": ";
            if ( $M->{_injected} ){
                print "Already injected\n";
                next;
            }

            # inject module
            $self->_inject($M);

            $M->{_injected} = 1;
            print "OK\n";
        }
    }

}


sub _inject {
    my $self   = shift;
    my $module = shift;


    # Inject lib and components ----------
    $self->_load_lib($module);

    # Inject catalyse plugin dependencies
    $self->_load_catalyst_plugins($module);

    # Inject templates -------------------
    $self->_load_template($module);

    # Inject static ----------------------
    $self->_load_static($module);

}

sub _load_lib {
	my ( $c, $module ) = @_;

}

sub _load_catalyst_plugins {
	my ( $c, $module ) = @_;

}

sub _load_template {
	my ( $c, $module ) = @_;

}

sub _load_static {
	my ( $c, $module ) = @_;

}

=head1 NAME

Catalyst::Plugin::Inject::MI Module injector

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=cut

1;
