#!/usr/bin/perl

## File import tests

=for Copyright
 .
 Copyright (c) 2008-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Test::More tests => 4;

use Demeter;

my $demeter = Demeter->new;

ok( (not $demeter->is_atoms('t/fe.060')),     'recognize data as not atoms');
ok( $demeter->is_atoms('t/PbFe12O19.inp'),    'identify atoms input file');

ok( (not $demeter->is_feff('t/fe.060')),      'recognize data as not feff');
ok( $demeter->is_feff('t/withHg.inp'),        'identify feff input file');