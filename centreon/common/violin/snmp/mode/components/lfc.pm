################################################################################
# Copyright 2005-2014 MERETHIS
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

package centreon::common::violin::snmp::mode::components::lfc;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my $oid_localTargetFcEntry = '.1.3.6.1.4.1.35897.1.2.1.6.1';
my $oid_wwn = '.1.3.6.1.4.1.35897.1.2.1.6.1.2';
my $oid_enable = '.1.3.6.1.4.1.35897.1.2.1.6.1.3';
my $oid_portState = '.1.3.6.1.4.1.35897.1.2.1.6.1.7';

sub load {
    my (%options) = @_;
    
    push @{$options{request}}, { oid => $oid_localTargetFcEntry };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking local fc");
    $self->{components}->{lfc} = {name => 'local fc', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'lfc'));

    foreach my $oid (keys %{$self->{results}->{$oid_localTargetFcEntry}}) {
        next if ($oid !~ /^$oid_wwn\.(.*)$/);
        my $wwn = $self->{results}->{$oid_localTargetFcEntry}->{$oid};
        my $enable = $self->{results}->{$oid_localTargetFcEntry}->{$oid_enable . '.' .$1};
        my $state = $self->{results}->{$oid_localTargetFcEntry}->{$oid_portState . '.' .$1};

        if ($enable == 2) {
            $self->{output}->output_add(long_msg => sprintf("Skipping instance '$wwn' (not enable)"));
            next;
        }
        next if ($self->check_exclude(section => 'lfc', instance => $wwn));
        
        $self->{components}->{lfc}->{total}++;
        $self->{output}->output_add(long_msg => sprintf("Local FC '%s' is %s.",
                                    $wwn, $state));
        my $exit = $self->get_severity(section => 'lfc', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Local FC '%s' is %s", $wwn, $state));
        }
    }
}

1;
