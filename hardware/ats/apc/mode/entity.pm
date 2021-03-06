################################################################################
# Copyright 2005-2013 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Authors : Quentin Garnier <qgarnier@merethis.com>
#
####################################################################################

package hardware::ats::apc::mode::entity;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my %switch_states = (
    1 => ['fail', 'CRITICAL'],
    2 => ['ok', 'OK'],
);

my %hardware_states = (
    1 => ['fail', 'CRITICAL'],
    2 => ['ok', 'OK'],
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};

    my $oid_atsStatusSwitchStatus = '.1.3.6.1.4.1.318.1.1.8.5.1.10.0';
    my $oid_atsStatusHardwareStatus = '.1.3.6.1.4.1.318.1.1.8.5.1.16.0';

    $self->{results} = $self->{snmp}->get_leef(oids => [$oid_atsStatusSwitchStatus, $oid_atsStatusHardwareStatus], nothing_quit => 1);

    my $exit1 = ${$switch_states{$self->{results}->{$oid_atsStatusSwitchStatus}}}[1];
    my $exit2 = ${$hardware_states{$self->{results}->{$oid_atsStatusHardwareStatus}}}[1];
    my $exit = $self->{output}->get_most_critical(status => [ $exit1, $exit2 ]);
    
    $self->{output}->output_add(severity => $exit,
                                short_msg => sprintf("Hardware state is '%s' , Switch state is '%s'", 
                                                ${$hardware_states{$self->{results}->{$oid_atsStatusHardwareStatus}}}[0], ${$switch_states{$self->{results}->{$oid_atsStatusSwitchStatus}}}[0]));
       
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check APC ATS entity (hardware and switch state).

=over 8

=back

=cut
    
