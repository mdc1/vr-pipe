
=head1 NAME

VRPipe::SchedulerMethodsFactory - a job scheduler factory

=head1 SYNOPSIS

*** more documentation to come

=head1 DESCRIPTION

Internal use only. B<VRPipe> looks at the site-wide configuration to see what
job scheduler should be used, then loads the appropriate scheduler class using
this factory, for use by L<VRPipe::Scheduler>.

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Genome Research Limited.

This file is part of VRPipe.

VRPipe is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

package VRPipe::SchedulerMethodsFactory;
use VRPipe::Base::AbstractFactory;

implementation_does qw/VRPipe::SchedulerMethodsRole/;
implementation_class_via sub { 'VRPipe::Schedulers::' . shift };

1;
