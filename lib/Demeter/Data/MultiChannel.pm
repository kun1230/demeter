package Demeter::Data::MultiChannel;

use Moose;
extends 'Demeter::Data';

has '+is_temp'   => (default => 1);
has '+is_col'    => (default => 1);
has '+name'      => (default => 'multichannel data',);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_MultiChannel($self);
};

## make this a null op
override 'put_data' => sub {
  my ($self) = @_;
#  my $string = $self->_read_data_command('raw');
#  $self->dispose($string);
  $self->update_data(0);
};

sub make_data {
  my ($self, @args) = @_;
  my %args = @args;

  $self->_update('data');

  ## get columns from ifeffit
  my @cols = split(" ", $self->columns);
  unshift @cols, q{};

  my $energy_string = $self->energy;
  my ($xmu_string, $i0_string, $signal_string) = (q{}, q{}, q{});
  if ($args{ln}) {
    $xmu_string    =   "ln(abs(  ("
	           . $args{numerator}
                   . ") / ("
		   . $args{denominator}
		   . ") ))";
    $i0_string     = $args{numerator};
    $signal_string = $args{denominator};
  } else {
    $xmu_string    = "(" . $args{numerator} . ") / (" . $args{denominator} . ")";
    $i0_string     = $args{denominator};
    $signal_string = $args{numerator};
  };

  delete $args{$_} foreach (qw(ln energy numerator denominator));
  my $this = Demeter::Data->new(%args, datatype=>'xmu', energy=>$energy_string);

  ## resolve column tokens
  my $group = $self->group;
  $i0_string     =~ s{\$(\d+)}{$group.$cols[$1]}g;
  $signal_string =~ s{\$(\d+)}{$group.$cols[$1]}g;
  $xmu_string    =~ s{\$(\d+)}{$group.$cols[$1]}g;
  $energy_string =~ s{\$(\d+)}{$group.$cols[$1]}g;

  $this->i0_string($i0_string);
  $this->signal_string($signal_string);
  $this->xmu_string($xmu_string);
  $this->energy_string($energy_string);

  my $command = $this->template("process", "columns");
  $command   .= $this->template("process", "deriv");
  $this->dispose($command);
  $this->i0_scale(Ifeffit::get_scalar('__i0_scale'));
  $this->signal_scale(Ifeffit::get_scalar('__signal_scale'));
  $this->update_columns(0);
  $this->update_data(0);
  $this->provenance(sprintf("Imported from multichannel data file %s", $self->file));
  $this->initialize_e0;

  return $this;
};


sub discard {
  my ($self) = @_;
  $self->dispose("erase \@group " . $self->group);
  $self->alldone;
  $self->DEMOLISH;
};

1;



=head1 NAME

Demeter::Data::MultiChannel - Efficiantly read multiple data channels from a single file

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 DESCRIPTION

This object provides a way to read multiple channels of data from a
single column data file that uses Ifeffit as efficiently as possible.

  my $mc = Demeter::Data::MultiChannel->new(file => $file,
                                            energy => '$1');
  my $data1 = $mc->make_data(numerator   => '$3',
                             denominator => '$2',
                             ln          => 0,
                             name        => 'MED Channel 1');
  my $data2 = $mc->make_data(numerator   => '$4',
                             denominator => '$2',
                             ln          => 0,
                             name        => 'MED Channel 2');
  $_->plot('E') foreach ($data1, $data2);

    ## later on...

  $mc -> discard;

The data file containing multiple channels of data is imported by the
Data::MultiChannel object.  Normal Data objects are created using the
C<make_data> method.  The advantage of this over simply re-importing
the data file for each Data object is that Ifeffit arrays for the raw
data columns are only created once, greatly reducing the amount of array
wrangling that Ifeffit must perform.

This method was written for the mutichannel ioniziation chambers
discussed in (give reference).  This class would also be useful for
generating fuorescence data groups from each individual channel of an
energy dispersive detector.

This object inherits from L<Demeter::Data> although most data
processing capabilities of the Data object are disabled in a simple
way.  Many of the array handling methods described in
L<Demeter::Data::Arrays> are useful when dealing with
Data::MultiChannel objects.

=head1 METHODS

=over 4

=item C<make_data>

This returns a Data object.  When a Data::MultiChannel object is
created, you B<must> specify the C<file> and C<energy> attributes,
both of which are inherited from the Data object.  The C<energy>
attribute is required so that the raw data arrays can be properly
sorted.  The energy array is then pushed onto all Data objects make
using C<make_data>.

The C<make_data> certainly requires that the C<numerator>,
C<denominator>, and C<ln> attributes are set so that mu(E) data can be
generated from the columns of the data file.  All other Data
attributes specified in the C<make_data> method call will be passed
along to the data object.

=item C<discard>

This method destroys the Data::MultiChannel object and also removes
all its associated arrays from Ifeffit.  It is hard to make all that
happen automatically B<and> at the proper time, so it is a good idea
to explicitly do this when you are finished with a Data::MultiChannel
object.

=back

=head1 CONFIGURATION

There are no configuration options for this class.

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Test and profile....

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut