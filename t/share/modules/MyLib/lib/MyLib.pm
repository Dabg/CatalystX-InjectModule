package MyLib;

use Moose;
use Exporter qw(import);

our @EXPORT_OK = qw(ping);

sub ping { return 'pong' }

sub setup {
    my ($self, $module, $c ) = @_;

    $module->{setup} = 1;
}

1;
