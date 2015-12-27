package MyLib;

use Moose;
use Exporter qw(import);

our @EXPORT_OK = qw(ping);

sub ping { return 'pong' }

sub install {
    my ($self, $module, $mi ) = @_;
    $module->{installed} = 1;
}

1;
