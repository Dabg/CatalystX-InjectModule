use utf8;
package CatalystX::Inject::MI;

# This plugin is inspired by :
# - CatalystX::InjectComponent
# - Catalyst::Plugin::AutoCRUD
# - Catalyst::Plugin::PluginLoader
# - Catalyst::Plugin::Thruk::ConfigLoader

use Class::Load ':all';
use File::Find;
use Dependency::Resolver;
use Devel::InnerPackage qw/list_packages/;
use Moose;
use Moose::Util qw/find_meta apply_all_roles/;
use File::Basename;
use Clone 'clone';

has resolver => (
              is       => 'rw',
              isa      => 'Dependency::Resolver',
          );

has ctx => (
              is       => 'rw',
          );

has catalyst_plugins => (
              is       => 'rw',
              isa      => 'HashRef',
              default  => sub { {} },
          );

my $debug = 0;

sub log {
    my($self, $msg) = @_;
	$self->ctx->log->debug( "MI: $msg" ) if $debug;
}

sub get_module {
    my($self, $mod, $op , $ver) = @_;

    my $modules = $self->resolver->get_modules($mod, $op, $ver);
    return $modules->[-1];
}

sub resolv {
    my $self      = shift;
    my $module    = shift;
    my $operation = shift;
    my $version   = shift;

    my $Module   = $self->get_module($module, $operation, $version );
    die "Module $module not found !" if ! defined $Module->{name};

    my $resolved = $self->resolver->dep_resolv($Module);
    return $resolved;
}

sub load {
    my $self           = shift;
    my $conf           = shift;
    my $conf_filename  = shift;

    $debug = 1 if $conf->{debug};
    $conf_filename ||= 'config.yml';
    $self->log("load_modules ...");

    $self->resolver(Dependency::Resolver->new(debug => $debug ));

    # search modules in 'path' directories
    for my $dir ( @{ $conf->{path} } ) {
        if ( $dir eq '__INC__' ) {
            push(@{$conf->{path}}, @INC);
            next;
        }
        $self->_load_modules_path($dir, $conf_filename);
    }
    # Merge config resolved modules ----------------
    $self->_merge_resolved_configs;

}


sub _load_modules_path{
    my $self           = shift;
    my $dir            = shift;
    my $conf_filename  = shift;

    $self->log("  - search modules on $dir ...");

    my $all_configs = $self->_search_in_path( $dir, $conf_filename );

    for my $config ( @$all_configs ) {

        my $cfg = Config::Any->load_files({files => [$config], use_ext => 1 })
            or die "Error (conf: $config) : $!\n";

        my($filename, $mod_config) = %{$cfg->[0]};

        my $msg = "    - find module ". $mod_config->{name};
        $msg .= " v". $mod_config->{version} if defined $mod_config->{version};
        $self->log($msg);

        my $path = dirname($config);
        $path =~ s|^\./||;

        $mod_config->{path} = $path;
        $self->resolver->add($mod_config);
    }
}

sub modules_to_inject {
    my $self    = shift;
    my $modules_name = shift;

    my $modules = [];
    foreach my $m ( @$modules_name ) {
        $self->log(" Requested module: $m");
        my $resolved = $self->resolv($m);

        if ( $resolved->[-1]->{_loaded}){
                $self->log("  Already loaded");
                next;
        }

        foreach my $M ( @$resolved ) {
            $self->log("  inject " . $M->{name} . '...');
            if ( $M->{_injected} ){
                $self->log("Already loaded");
                next;
            }
            push(@$modules,$M);
            $M->{_loaded} = 1;
        }
    }
    return $modules;
}

sub inject {
    my $self         = shift;
    my $modules_name = shift;

    my $modules = $self->modules_to_inject($modules_name);

    for my $m ( @$modules) {
        $self->_inject($m);
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

sub _merge_resolved_configs {
	my ( $self, $module ) = @_;

    $self->log("  - Merge all resolved modules config.yml");

    my $conf = $self->ctx->config->{'CatalystX::Inject'};
    my $modules = $self->modules_to_inject($conf->{inject});

    for my $module (@$modules) {

        my $mod_conf = clone($module);

        # Merge all keys except these
        map { delete $mod_conf->{$_} } qw /name path version deps catalyst_plugins _loaded/;

        # If there is at least one pattern key
        for my $k ( keys %$mod_conf) {
            $self->ctx->config->{$k} = $mod_conf->{$k};
        }
    }
}

sub _load_lib {
	my ( $self, $module ) = @_;

    my $libpath = $module->{path} . '/lib';
    return if ( ! -d $libpath);

    $self->log("  - Add lib $libpath");
    unshift( @INC, $libpath );

	# Search and load components
	my $all_libs = $self->_search_in_path( $module->{path}, '.pm$' );

	foreach my $file (@$all_libs) {
		$self->_load_component( $module, $file )
			if ( grep {/Model|View|Controller/} $file );
	}
}

sub _load_catalyst_plugins {
	my ( $self, $module ) = @_;

	my $plugins = $module->{catalyst_plugins};
	foreach my $p (@$plugins) {

		# If plugin is not already loaded
		if ( !$self->catalyst_plugins->{$p} ) {
			$self->_load_catalyst_plugin($p);
			$self->catalyst_plugins->{$p} = 1;
		} else {
			$self->log(" - Catalyst plugin $p already loaded !");
		}
	}
}

sub _load_catalyst_plugin {
	my ( $self, $plugin ) = @_;

	$self->log("  - Add Catalyst plugin $plugin\n");

	my $isa = do { no strict 'refs'; \@{ $self->ctx . '::ISA' } };
	my $isa_idx = 0;
	$isa_idx++ while $isa->[$isa_idx] ne 'Catalyst'; #__PACKAGE__;


	if ( $plugin !~ s/^\+(.*)/$1/ ) { $plugin = 'Catalyst::Plugin::' . $plugin }

	Catalyst::Utils::ensure_class_loaded($plugin);
	$self->ctx->_plugins->{$plugin} = 1;

	my $meta = find_meta($plugin);

	if ( $meta && blessed $meta && $meta->isa('Moose::Meta::Role') ) {
		apply_all_roles( $self->ctx => $plugin );
	} else {
		splice @$isa, ++$isa_idx, 0, $plugin;
	}

	unshift @$isa, shift @$isa; # necessary to tell perl that @ISA changed
	mro::invalidate_all_method_caches();

	{

		# ->next::method won't work anymore, we have to do it ourselves
		my @precedence_list = $self->ctx->meta->class_precedence_list;

		1 while shift @precedence_list ne 'Catalyst'; #__PACKAGE__;

		my $old_next_method = \&maybe::next::method;

		my $next_method = sub {
			if ( ( caller(1) )[3] !~ /::setup\z/ ) {
				goto &$old_next_method;
			}

			my $code;
			while ( my $next_class = shift @precedence_list ) {
				$code = $next_class->can('setup');
				last if $code;
			}
			return unless $code;

			goto &$code;
		};

		no warnings 'redefine';
		local *next::method        = $next_method;
		local *maybe::next::method = $next_method;

		return $self->ctx->next::method(@_);
	}
}


sub _load_template {
	my ( $c, $module ) = @_;

    # TODO
}

sub _load_static {
	my ( $c, $module ) = @_;

    # TODO
}


sub _load_component {
	my ( $self, $module, $file ) = @_;

	my $libpath = $module->{path} . '/lib';
	my $comp    = $file;
	$comp =~ s|$libpath/||;
	$comp =~ s|\.pm$||;
	$comp =~ s|/|::|g;

	$self->log("  - Add Component $comp");

	if ( !is_class_loaded($comp) ) {
		load_class($comp) or die "Can't load $comp !";

		# inject entry to %INC so Perl knows this component is loaded
		# this is just for politeness and does not aid Catalyst
		( my $file = "$comp.pm" ) =~ s{::}{/}g;
		$INC{$file} = 'loaded';

		#  add newly created components to catalyst
		#  must set up component and -then- call list_packages on it
		$self->ctx->components->{$comp} = $self->ctx->setup_component($comp);

		for my $m ( list_packages($comp) ) {
			$self->ctx->components->{$m} = $self->ctx->setup_component($m);
		}
	} else {
        # XXX : die ???
		$self->log( $module->{name} . " $comp id already loaded" );
	}
}


sub _search_in_path {
	my $self  = shift;
    my $path  = shift;
	my $regex = shift;

	my @files;
	my $tf_finder = sub {
		return if !-f;
		return if !/$regex/;

		my $file = $File::Find::name;
		push @files, $file;
	};

    find( $tf_finder, $path  );
	return \@files;
}


=head1 NAME

CatalystX::Inject::MI Catalyst Module injector

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=cut

1;
