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

package hardware::sensors::sensorip::snmp::mode::components::switch;

use strict;
use warnings;

my %map_sw_status = (
    1 => 'noStatus',
    2 => 'normal',
    4 => 'highCritical',
    6 => 'lowCritical',
    7 => 'sensorError',
    8 => 'relayOn',
    9 => 'relayOff',
);
my %map_sw_online = (
    1 => 'online',
    2 => 'offline',
);

my $mapping = {
    sensorProbeSwitchDescription => { oid => '.1.3.6.1.4.1.3854.1.2.2.1.18.1.1' },
    sensorProbeSwitchStatus => { oid => '.1.3.6.1.4.1.3854.1.2.2.1.18.1.3', map => \%map_sw_status },
    sensorProbeSwitchOnline => { oid => '.1.3.6.1.4.1.3854.1.2.2.1.18.1.4', map => \%map_sw_online },
};
my $oid_sensorProbeSwitchEntry = '.1.3.6.1.4.1.3854.1.2.2.1.18.1';

sub load {
    my (%options) = @_;
    
    push @{$options{request}}, { oid => $oid_sensorProbeSwitchEntry, end => $mapping->{sensorProbeSwitchOnline}->{oid} };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking switch");
    $self->{components}->{switch} = {name => 'switch', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'switch'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_sensorProbeSwitchEntry}})) {
        next if ($oid !~ /^$mapping->{sensorProbeSwitchStatus}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_sensorProbeSwitchEntry}, instance => $instance);
        
        next if ($self->check_exclude(section => 'switch', instance => $instance));
        if ($result->{sensorProbeSwitchOnline} =~ /Offline/i) {  
            $self->absent_problem(section => 'switch', instance => $instance);
            next;
        }
        
        $self->{components}->{switch}->{total}++;
        $self->{output}->output_add(long_msg => sprintf("Switch sensor '%s' status is '%s' [instance : %s]", 
                                            $result->{sensorProbeSwitchDescription}, $result->{sensorProbeSwitchStatus}, $instance));
        my $exit = $self->get_severity(section => 'switch', value => $result->{sensorProbeSwitchStatus});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Switch sensor '%s' status is '%s'", $result->{sensorProbeSwitchDescription}, $result->{sensorProbeSwitchStatus}));
        }
    }
}

1;