package Demeter::Plugins::10BMMultiChannel;  # -*- cperl -*-

use File::Basename;
use File::Copy;
use File::Spec;
use Readonly;
Readonly my $INIFILE => '10bmmultichannel.ini';

use Moose;
extends 'Demeter::Plugins::FileType';

my $demeter = Demeter->new();
has 'inifile' => (is => 'rw', isa => 'Str', default => File::Spec->catfile($demeter->dot_folder, $INIFILE));

has '+is_binary'   => (default => 0);
has '+description' => (default => 'the APS 10BM multi-channel detector');
has '+version'     => (default => 0.1);
has '+output'      => (default => 'project');

if (not -e File::Spec->catfile($demeter->dot_folder, $INIFILE)) {
  copy(File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'ini', $INIFILE),
       File::Spec->catfile($demeter->dot_folder, $INIFILE));
};

sub is {
  my ($self) = @_;
  open (my $D, $self->file) or die "could not open " . $self->file . " as data (10BM multi-channel)\n";
  my $is_mx = (<$D> =~ m{\A\s*MRCAT_XAFS});
  while (<$D>) {
    last if (m{\A\s*-----});
  };
  my $is_mc = (<$D> =~ m{mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}});
  close $D;
  #print join("|",$is_xdac, $is_mc), $/;
  return ($is_mx and $is_mc);
};

sub fix {
  my ($self) = @_;

  my $ini = $self->inifile;
  confess "10BM multi-channel inifile $ini does not exist", return q{} if (not -e $ini);
  confess "could not read 10BM multi-channel inifile $ini", return q{} if (not -r $ini);
  my $cfg = new Config::IniFiles( -file => $ini );

  my $file = $self->file;
  my $prj  = File::Spec->catfile($self->stash_folder, basename($self->file));

  my $mc = Demeter::Data::MultiChannel->new(file => $file, energy => '$1',);

  $mc->_update('data');
  if ($cfg->val('flags', 'temperature_column')) {
    my @energy = $mc->get_array('nergy');
    my $iedge = $mc->iofx('nergy', $cfg->val('flags', 'edge'));
    my @temp = $mc->get_array($cfg->val('flags', 'temperature_column'));
    my $this_temp = sprintf("%d", 200*($temp[$iedge]/10000 - 1));
  };

  my @data = ($mc->make_data(numerator   => q{$}.$cfg->val('numerator',   '1'),
			     denominator => q{$}.$cfg->val('denominator', '1'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), $cfg->val('names', '1')),
			     bkg_eshift  => $cfg->val('eshift', '1'),
			    ),
	      $mc->make_data(numerator   => q{$}.$cfg->val('numerator',   '2'),
			     denominator => q{$}.$cfg->val('denominator', '2'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), $cfg->val('names', '2')),
			     bkg_eshift  => $cfg->val('eshift', '2'),
			    ),
	      $mc->make_data(numerator   => q{$}.$cfg->val('numerator',   '3'),
			     denominator => q{$}.$cfg->val('denominator', '3'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), $cfg->val('names', '3')),
			     bkg_eshift  => $cfg->val('eshift', '3'),
			    ),
	      $mc->make_data(numerator   => q{$}.$cfg->val('numerator',   '4'),
			     denominator => q{$}.$cfg->val('denominator', '4'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), $cfg->val('names', '4')),
			     bkg_eshift  => $cfg->val('eshift', '4'),
			    ),
	     );

  if ($cfg->val('flags',   'reference')) {
    $data[4] = $mc->make_data(numerator   => q{$}.$cfg->val('numerator',   'reference'),
			      denominator => q{$}.$cfg->val('denominator', 'reference'),
			      ln          => 1,
			      name        => join(" - ", basename($self->file), $cfg->val('names', 'reference')),
			     );
  };

  $mc->dispose("erase \@group ".$mc->group);
  $data[0]->write_athena($prj, @data);
  $_ -> DEMOLISH foreach (@data, $mc);

  $self->fixed($prj);
  return $prj;
};

sub suggest {
  ();
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugins::10BMMultiChannel - filetype plugin for 10BM multi-channel data files

=head1 SYNOPSIS

This plugin converts data from 10BM multi-channel ion chambers to an
Athena project file.  An inifile, F<$HOME/.horae/10bmmultichannel.ini>,
is used to set the column labels and to identify which columns belong
to which data channels.

=head1 METHODS

=over 4

=item C<is>

The multichannel file is recognized by  

=item C<fix>

The column data file is converted into an Athena project file using
the L<Demeter::Data::MultiChannel> object.

=back

=head1 INI FILE

Here is an example of F<$HOME/.horae/10bmmultichannel.ini>:

   ## name each sample in each channel
   [names]
   1=oxide
   2=sulfide
   3=hydroxide
   4=metal
   reference=reference

   ## column numbers for the I0 columns
   [numerator]
   1=2
   2=3
   3=4
   4=5
   reference=9

   ## column numbers for the It columns
   [denominator]
   1=6
   2=7
   3=8
   4=9
   reference=10

   ## energy offsets of channels 2,3,4 relative to channel 1
   [eshift]
   1=0
   2=0
   3=0
   4=0

   ## flags for changing the behavior of the plugin
   [flags]
   reference=1

The energy shifts are measured by placing a foil in front of all four
channels and measuring the edge shift across the horizontal extent of
the beam.

=head1 BUGS AND SHORTCOMINGS

=over 4

=item *

Tie all four channels to a single reference (this is a Demeter
shortcoming, not a bug of this plugin).

=item *

Use all 4 It channels in the numerator of the reference

=back

=head1 REVISIONS

=over 4

=item 0.1

Initial version

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

