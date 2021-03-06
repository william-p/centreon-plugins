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

package hardware::server::hp::proliant::snmp::mode::components::pc;

use strict;
use warnings;

my %map_pc_condition = (
    1 => 'other', 
    2 => 'ok', 
    3 => 'degraded', 
    4 => 'failed',
);

my %map_present = (
    1 => 'other',
    2 => 'absent',
    3 => 'present',
);

my %map_redundant = (
    1 => 'other',
    2 => 'not redundant',
    3 => 'redundant',
);

# In MIB 'CPQHLTH-MIB.mib'
my $mapping = {
    cpqHePwrConvPresent => { oid => '.1.3.6.1.4.1.232.6.2.13.3.1.3', map => \%map_present },
    cpqHePwrConvRedundant => { oid => '.1.3.6.1.4.1.232.6.2.13.3.1.6', map => \%map_redundant },
    cpqHePwrConvRedundantGroupId => { oid => '.1.3.6.1.4.1.232.6.2.13.3.1.7' },
    cpqHePwrConvCondition => { oid => '.1.3.6.1.4.1.232.6.2.13.3.1.8', map => \%map_pc_condition },
};
my $oid_cpqHePowerConverterEntry = '.1.3.6.1.4.1.232.6.2.13.3.1';

sub load {
    my (%options) = @_;
    
    push @{$options{request}}, { oid => $oid_cpqHePowerConverterEntry, start => $mapping->{cpqHePwrConvPresent}->{oid}, end => $mapping->{cpqHePwrConvCondition}->{oid} };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking power converters");
    $self->{components}->{pc} = {name => 'power converters', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'pc'));
    
    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_cpqHePowerConverterEntry}})) {
        next if ($oid !~ /^$mapping->{cpqHePwrConvPresent}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_cpqHePowerConverterEntry}, instance => $instance);

        next if ($self->check_exclude(section => 'pc', instance => $instance));
        next if ($result->{cpqHePwrConvPresent} !~ /present/i && 
                 $self->absent_problem(section => 'pc', instance => $instance));
        
        $self->{components}->{pc}->{total}++;

        $self->{output}->output_add(long_msg => sprintf("powerconverter '%s' status is %s [redundance: %s, redundant group: %s].",
                                    $instance, $result->{cpqHePwrConvCondition},
                                    $result->{cpqHePwrConvRedundant}, $result->{cpqHePwrConvRedundantGroupId}
                                    ));
        my $exit = $self->get_severity(section => 'pc', value => $result->{cpqHePwrConvCondition});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("powerconverter '%s' status is %s",
                                           $instance, $result->{cpqHePwrConvCondition}));
        }
    }
}

1;