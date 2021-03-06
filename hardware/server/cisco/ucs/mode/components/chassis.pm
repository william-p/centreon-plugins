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

package hardware::server::cisco::ucs::mode::components::chassis;

use strict;
use warnings;
use hardware::server::cisco::ucs::mode::components::resources qw($thresholds);

sub check {
    my ($self) = @_;

    # In MIB 'CISCO-UNIFIED-COMPUTING-EQUIPMENT-MIB'
    $self->{output}->output_add(long_msg => "Checking chassis");
    $self->{components}->{chassis} = {name => 'chassis', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'chassis'));
    
    # Don't do the 'presence'. Is 'unknown' ??!!!
    my $oid_cucsEquipmentChassisOperState = '.1.3.6.1.4.1.9.9.719.1.15.7.1.27';
    my $oid_cucsEquipmentChassisDn = '.1.3.6.1.4.1.9.9.719.1.15.7.1.2';

    my $result = $self->{snmp}->get_multiple_table(oids => [ 
                                                            { oid => $oid_cucsEquipmentChassisOperState },
                                                            { oid => $oid_cucsEquipmentChassisDn },
                                                            ]
                                                   );
    foreach my $key ($self->{snmp}->oid_lex_sort(keys %{$result->{$oid_cucsEquipmentChassisOperState}})) {
        # index
        $key =~ /\.(\d+)$/;
        my $chassis_index = $1;        
        my $chassis_dn = $result->{$oid_cucsEquipmentChassisDn}->{$oid_cucsEquipmentChassisDn . '.' . $chassis_index};
        my $chassis_operstate = defined($result->{$oid_cucsEquipmentChassisOperState}->{$oid_cucsEquipmentChassisOperState . '.' . $chassis_index}) ?
                                $result->{$oid_cucsEquipmentChassisOperState}->{$oid_cucsEquipmentChassisOperState . '.' . $chassis_index} : 0; # unknown

        next if ($self->absent_problem(section => 'chassis', instance => $chassis_dn));
        next if ($self->check_exclude(section => 'chassis', instance => $chassis_dn));
        
        $self->{components}->{chassis}->{total}++;
        
        $self->{output}->output_add(long_msg => sprintf("chassis '%s' state is '%s'.",
                                                        $chassis_dn, ${$thresholds->{operability}->{$chassis_operstate}}[0]
                                    ));
        my $exit = $self->get_severity(section => 'chassis', threshold => 'operability', value => $chassis_operstate);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("chassis '%s' state is '%s'.",
                                                             $chassis_dn, ${$thresholds->{operability}->{$chassis_operstate}}[0]
                                                             )
                                        );
        }
    }
}

1;
