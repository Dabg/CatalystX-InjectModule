use utf8;

package CatalystX::Inject;

use Moose::Role;
use namespace::autoclean;
use CatalystX::Inject::MI;


after 'finalize_config' => sub {
	my $c = shift;

    my $conf = $c->config->{'CatalystX::Inject'};

    $c->mk_classdata('mi'); # we will use this name in Catalyst

    # module injector
	my $mi = $c->mi( CatalystX::Inject::MI->new(ctx => $c) );

    $mi->load($conf);

};

after 'setup_components' => sub {
	my $c = shift;

    my $conf = $c->config->{'CatalystX::Inject'};

    # inject configured modules
    $c->mi->inject($conf->{inject});
};


=head1 NAME

CatalystX::Inject - Inject components, plugins, template, lib ...

This module is at EXPERIMENTAL stage, so use with caution.

=head1 SYNOPSIS


    use Catalyst qw/
        ConfigLoader
        +CatalystX::Inject
    /;

    # myapp.yml
    CatalystX::Inject:
      path:
        - t/share/modulesX
        - t/share/modules
      modules:
        - Ax
        - A

    # Each module must have at least one file config.yml
    name: Bx
    version: 2
    deps:
      - Cx == 2
      - Ex
    catalyst_plugins:
      - Static::Simple
      - +CatalystX::SimpleLogin


=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-catalyst-plugin-inject at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CatalystX-Inject>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CatalystX::Inject


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-Inject>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CatalystX-Inject>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CatalystX-Inject>

=item * Search CPAN

L<http://search.cpan.org/dist/CatalystX-Inject/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Daniel Brosseau.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of CatalystX::Inject
