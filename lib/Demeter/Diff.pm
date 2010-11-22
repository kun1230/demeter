package Demeter::Diff;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

use Carp;
use List::MoreUtils qw{any};
use Math::Spline;

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

use MooseX::Aliases;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty );

has '+plottable'    => (default => 1);
has '+data'         => (isa => Empty.'|Demeter::Data');
has '+name'         => (default => 'Difference spectrum' );
has 'standard'      => (is => 'rw', isa => 'Any',     default => q{},
			trigger => sub{ my($self, $new) = @_; $self->datagroup($new->group) if $new});
has 'standardgroup' => (is => 'rw', isa => 'Str',     default => q{});

has 'space'         => (is => 'rw', isa => 'Str',     default => 'norm',
			trigger => sub{ my($self, $new) = @_;
					if (any {$new eq $_} (qw(xmu norm flat der nder sec nsec))) {
					  $self->xsuff('energy');
					} elsif ($new eq 'chi') {
					  $self->xsuff('k');
					};
				      });
has 'dataspace'     => (is => 'rw', isa => 'Str',     default => 'norm',);
has 'standardspace' => (is => 'rw', isa => 'Str',     default => 'norm',);

has 'invert'        => (is => 'rw', isa => 'Bool',    default => 0);
has 'xmin'          => (is => 'rw', isa => 'Num',     default => -20);
has 'xmax'          => (is => 'rw', isa => 'Num',     default =>  30);
has 'epsilon'       => (is => 'rw', isa => 'Num',     default =>  1e-5);
has 'steps'         => (is => 'rw', isa => 'Int',     default =>  6);
has 'area'          => (is => 'rw', isa => 'Num',     default =>  0);
has 'xsuff'         => (is => 'rw', isa => 'Str',     default => 'energy');

has 'plotspectra'   => (is => 'rw', isa => 'Bool',    default => 0);
has 'spline'        => (is => 'rw', isa => 'Any',     default => 0);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Diff($self);
  return $self;
};

sub diff {
  my ($self) = @_;
  $self->standard->_update('fft');
  $self->data->_update('fft');

  $self->standardspace($self->space);
  $self->standardspace('flat') if (($self->space eq 'norm') and $self->standard->bkg_flatten);
  $self->dataspace($self->space);
  $self->dataspace('flat') if (($self->space eq 'norm') and $self->data->bkg_flatten);

  $self->standard->standard;
  $self->dispose($self->template("analysis", "diff_diff"));
  $self->standard->unset_standard;

  my @x = $self->data->get_array('energy');
  my @y = $self->data->get_array('diff');
  $self->spline(Math::Spline->new(\@x,\@y));
  $self->_integrate;
  return $self;
};

sub plot {
  my ($self) = @_;
  $self->po->title(join(' - ', $self->data->name, $self->standard->name));
  if ($self->plotspectra) {
    my $save = $self->po->e_markers;
    $self->po->e_markers(0);
    $self->po->start_plot;
    $self->data->plot('E');
    $self->standard->plot('E');
    $self->dispose($self->template("plot", "overdiff"), 'plotting');
    $self->po->e_markers($save);
  } else {
    my $which = ($self->po->New) ? 'newdiff' : 'overdiff';
    $self->dispose($self->template("plot", $which), 'plotting');
    $self->po->increment;
  };
  if ($self->po->e_markers) {
    $self->data->plot_marker('diff', $self->data->bkg_e0+$self->xmin);
    $self->data->plot_marker('diff', $self->data->bkg_e0+$self->xmax);
  };
  $self->po->title(q{});
  return $self;
};



# adapted from Mastering Algorithms with Perl by Orwant, Hietaniemi,
# and Macdonald Chapter 16, p 632
#
# _integrate() uses the Romberg algorithm to estimate the definite integral
# of the function $func from $lo to $hi.
#
# The subroutine will compute roughly ($steps + 1) * ($steps + 2) / 2
# estimates for the integral, of which the last will be the most accurate.
#
# _integrate() returns early if intermediate estimates change by less
# than $epsilon.
#
sub _integrate {
  my ($self) = @_;
  my $hi = $self->data->bkg_e0+$self->xmax;
  my $lo = $self->data->bkg_e0+$self->xmin;
  my $h = $hi - $lo;
  my (@r, $sum);
  my @est;

  # Our initial estimate.
  $est[0][0] = ($h / 2) * ( $self->spline->evaluate($lo) + $self->spline->evaluate($hi) );

  # Compute each row of the Romberg array.
  foreach my $i (1 .. $self->steps) {

    $h /= 2;
    $sum = 0;

    # Compute the first column of the current row.
    my $j;
    for ($j = 1; $j < 2 ** $i; $j += 2) {
      $sum += $self->spline->evaluate($lo + $j * $h);
    }
    $est[$i][0] = $est[$i-1][0] / 2 + $sum * $h;

    # Compute the rest of the columns in this row.
    foreach my $j (1 .. $i) {
      $est[$i][$j] = ($est[$i][$j-1] - $est[$i-1][$j-1]) / (4**$j - 1) + $est[$i][$j-1];
    }

    # Are we close enough?
    return $est[$i][$i] if (abs($est[$i][$i] - $est[$i-1][$i-1]) <= $self->epsilon);
  }
  $self->area($est[$self->steps][$self->steps]);
  return $self->area;
};

1;

=head1 NAME

Demeter::Diff - Difference spectra

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

  my $prj = Demeter::Data::Prj->new(file=>'athena.prj');
  my $stan = $prj->record(1);
  my $data = $prj->record(2);
  my $diff = Demeter::Diff->new(data=>$data, standard=>$stan);
  $diff->diff;
  $diff->plot;
  $diff->pause;

=head1 DESCRIPTION

Compute the difference spectrum between two L<Demeter::Data> objects
and compute the integrated area of a region of the difference
spectrum.

=head1 ATTRIBUTES

=over 4

=item C<data>

The Data group from which this difference spectrum is made.

=item C<standard>

The Data group subtracted from the C<data>.

=item C<xmin>

The lower bound of the integration range.  For a difference in energy,
this number is relative to E0.

=item C<xmax>

The upper bound of the integration range.  For a difference in energy,
this number is relative to E0.

=item C<invert>

When true, swap the C<data> and C<standard> when calculating the
difference spectrum.

=item C<plotspectra>

When true, include the C<data> and C<standard> in the plot when
calling the C<plot> method.

=item C<area>

After the difference is made, the integrated area between C<xmin> and
C<xmax> will be stored in this attribute.

=back

=head1 METHODS

=over 4

=item C<diff>

Compute the difference spectrum and integrated area.

  $diff_object -> diff;

=item C<plot>

Make a plot of the difference spectrum.

  $diff_object -> plot;

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the lcf configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need better error checking

=item *

Difference spectra of things other than norm(E); C<space> attribute

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
