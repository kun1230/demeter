#!/usr/bin/perl
BEGIN {
  # turn off Unity feature of the Mac-like global menu bar, which
  # interacts really poorly with Wx.  See
  # http://www.webupd8.org/2011/03/disable-appmenu-global-menu-in-ubuntu.html
  $ENV{UBUNTU_MENUPROXY} = 0;
  use Demeter::Here;
  use Wx::Perl::SplashFast Demeter::Here->here.'UI/Athena/share/logo.jpg', 4000;
};
use Wx;
Wx::InitAllImageHandlers();
use Demeter::UI::Athena;
use vars qw($app);
$app  = Demeter::UI::Athena->new;
$app -> process_argv(@ARGV);
$app -> MainLoop;

=head1 NAME

athena - XAS data processing

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 DESCRIPTION

Athena is a graphical interface to Ifeffit for XAS data processing.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
