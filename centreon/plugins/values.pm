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

package centreon::plugins::values;

use strict;
use warnings;

# le label de perfdata: on peut le surcharger (au lieu du label)
# le warning/critical: on peut surcharger 

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;

    $self->{statefile} = $options{statefile};
    $self->{output} = $options{output};
    $self->{perfdata} = $options{perfdata};
    $self->{label} = $options{label};

    $self->{perfdatas} = [];
    
    $self->{output_template} = $self->{label} . ' : %s';
    $self->{output_use} = undef;
    $self->{output_change_bytes} = 0;
    $self->{output_absolute_unit} = '';
    $self->{output_per_second_unit} = '';
    
    $self->{output_error_template} = $self->{label} . ' : %s';
    
    $self->{threshold_use} = undef;
    $self->{threshold_warn} = undef;
    $self->{threshold_crit} = undef;

    $self->{per_second} = 0;
    $self->{last_timestamp} = undef;

    $self->{result_values} = {};
    
    return $self;
}

sub init {
    my ($self, %options) = @_;
    my $warn = defined($self->{threshold_warn}) ? $self->{threshold_warn} : 'warning-' . $self->{label};
    my $crit = defined($self->{threshold_crit}) ? $self->{threshold_crit} : 'critical-' . $self->{label}; 
    
    if (($self->{perfdata}->threshold_validate(label => $warn, value => $options{option_results}->{$warn})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong $warn threshold '" . $options{option_results}->{$warn} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => $crit, value => $options{option_results}->{$crit})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong $crit threshold '" . $options{option_results}->{$crit} . "'.");
        $self->{output}->option_exit();
    }
}

sub set {
    my ($self, %options) = @_;

    foreach (keys %options) {
        $self->{$_} = $options{$_};
    }
}

sub calc {
    my ($self, %options) = @_;

    # manage only one value ;)
    foreach my $value (@{$self->{key_values}}) {
        if (defined($value->{diff}) && $value->{diff} == 1) { 
            if ($self->{per_second} == 1) {
                $self->{result_values}->{$value->{name} . '_per_second'} = ($options{new_datas}->{$self->{instance} . '_' . $value->{name}} - $options{old_datas}->{$self->{instance} . '_' . $value->{name}}) / $options{delta_time};
            }
            $self->{result_values}->{$value->{name} . '_absolute'} = $options{new_datas}->{$self->{instance} . '_' . $value->{name}} - $options{old_datas}->{$self->{instance} . '_' . $value->{name}};
        } else {
            # absolute one. nothing to do. Can be used for values.
            $self->{result_values}->{$value->{name} . '_absolute'} = $options{new_datas}->{$self->{instance} . '_' . $value->{name}};
        }
    }

    return 0;
}

sub threshold_check {
    my ($self, %options) = @_;
    
    if (defined($self->{closure_custom_threshold_check})) {
        return &{$self->{closure_custom_threshold_check}}($self, %options);
    }
    
    my $warn = defined($self->{threshold_warn}) ? $self->{threshold_warn} : 'warning-' . $self->{label};
    my $crit = defined($self->{threshold_crit}) ? $self->{threshold_crit} : 'critical-' . $self->{label};
    
    my $first = ${${$self->{key_values}}[0]}{name};
    my $value;

    if (!defined($self->{threshold_use})) {
        $value = $self->{result_values}->{$first . '_absolute'};
        if ($self->{per_second} == 1) {
            $value = $self->{result_values}->{$first . '_per_second'};
        }
    } else {
        $value = $self->{result_values}->{$self->{threshold_use}};
    }

    return $self->{perfdata}->threshold_check(value => $value, threshold => [ { label => $crit, 'exit_litteral' => 'critical' },
                                                                              { label => $warn, 'exit_litteral' => 'warning' }]);
}

sub output_error {
    my ($self, %options) = @_;
    
    return sprintf($self->{output_error_template}, $self->{error_msg});
}

sub output {
    my ($self, %options) = @_;
     
    if (defined($self->{closure_custom_output})) {
        return $self->{closure_custom_output}->($self);
    }
    my $first = ${${$self->{key_values}}[0]}{name};
    my ($value, $unit) = ($self->{result_values}->{$first . '_absolute'}, $self->{result_values}->{output_absolute_unit});
    
    if (!defined($self->{output_use})) {
        if ($self->{per_second} == 1) {
            $value = $self->{result_values}->{$first . '_per_second'};
            $unit = $self->{output_per_second_unit};
        }
    } else {
        $value = $self->{result_values}->{$self->{output_use}};
    }

    if ($self->{output_change_bytes} == 1) {
        ($value, $unit) = $self->{perfdata}->change_bytes(value => $value);
    } elsif ($self->{output_change_bytes} == 2) {
        ($value, $unit) = $self->{perfdata}->change_bytes(value => $value, network => 1);
    }
    
    return sprintf($self->{output_template}, $value, $unit);
}

sub perfdata {
    my ($self, %options) = @_;
    
    if (defined($self->{closure_custom_perfdata})) {
        return &{$self->{closure_custom_perfdata}}($self, %options);
    }
    
    my $warn = defined($self->{threshold_warn}) ? $self->{threshold_warn} : 'warning-' . $self->{label};
    my $crit = defined($self->{threshold_crit}) ? $self->{threshold_crit} : 'critical-' . $self->{label}; 
    
    foreach my $perf (@{$self->{perfdatas}}) {
        my ($label, $extra_label, $min, $max, $th_total) = ($self->{label}, '');
        my $cast_int = (defined($perf->{cast_int}) && $perf->{cast_int} == 1) ? 1 : 0;
        my $template = '%s';
        
        $template = $perf->{template} if (defined($perf->{template}));
        $label = $perf->{label} if (defined($perf->{label}));
        if (defined($perf->{min})) {
            $min = ($perf->{min} =~ /[^0-9]/) ? $self->{result_values}->{$perf->{min}} : $perf->{min};
        }
        if (defined($perf->{max})) {
            $max = ($perf->{max} =~ /[^0-9]/) ? $self->{result_values}->{$perf->{max}} : $perf->{max};
        }
        if (defined($perf->{threshold_total})) {
            $th_total = ($perf->{threshold_total} =~ /[^0-9]/) ? $self->{result_values}->{$perf->{threshold_total}} : $perf->{threshold_total};
        }
        
        if (defined($perf->{label_extra_instance}) && $perf->{label_extra_instance} == 1 && 
           (!defined($options{extra_instance}) || $options{extra_instance} != 0)) {
          
            if (defined($perf->{instance_use})) {
                $extra_label .= '_' . $self->{result_values}->{$perf->{instance_use}};
            } else {
                $extra_label .= '_' . $self->{instance};
            }
        }

        $self->{output}->perfdata_add(label => $label . $extra_label, unit => $perf->{unit},
                                      value => $cast_int == 1 ? int($self->{result_values}->{$perf->{value}}) : sprintf($template, $self->{result_values}->{$perf->{value}}),
                                      warning => $self->{perfdata}->get_perfdata_for_output(label => $warn, total => $th_total, cast_int => $cast_int),
                                      critical => $self->{perfdata}->get_perfdata_for_output(label => $crit, total => $th_total, cast_int => $cast_int),
                                      min => $min, max => $max);
    }
}

sub execute {
    my ($self, %options) = @_;
    my $old_datas = {};

    $self->{result_values} = {},
    $self->{error_msg} = undef;
    my $quit = 0;
    my $per_second = 0;
    
    $options{new_datas} = {} if (!defined($options{new_datas}));
    foreach my $value (@{$self->{key_values}}) {
        if (!defined($options{values}->{$value->{name}}) || 
            defined($value->{no_value}) && $options{values}->{$value->{name}} eq $value->{no_value}) {
            $quit = 2;
            last;
        }
    
        if (defined($value->{diff}) && $value->{diff} == 1) {            
            $options{new_datas}->{$self->{instance} . '_' . $value->{name}} = $options{values}->{$value->{name}};
            $old_datas->{$self->{instance} . '_' . $value->{name}} = $self->{statefile}->get(name => $self->{instance} . '_' . $value->{name});
            if (!defined($old_datas->{$self->{instance} . '_' . $value->{name}})) {
                $quit = 1;
                next;
            }
            if ($old_datas->{$self->{instance} . '_' . $value->{name}} > $options{new_datas}->{$self->{instance} . '_' . $value->{name}}) {
                $old_datas->{$self->{instance} . '_' . $value->{name}} = 0;
            }
        } else {
            $options{new_datas}->{$self->{instance} . '_' . $value->{name}} = $options{values}->{$value->{name}};
            if (defined($self->{statefile})) {
                $old_datas->{$self->{instance} . '_' . $value->{name}} = $self->{statefile}->get(name => $self->{instance} . '_' . $value->{name});
            }
        }
    }

    if ($quit == 2) {
        $self->{error_msg} = "skipped (no value(s))";
        return -10;
    }
    
    if ($quit == 1) {
        $self->{error_msg} = "Buffer creation";
        return -1;
    }
    
    if ($self->{per_second} == 1) {
        if (!defined($self->{last_timestamp})) {
            $self->{last_timestamp} = $self->{statefile}->get(name => 'last_timestamp');
        }
        if (!defined($self->{last_timestamp})) {
            $self->{error_msg} = "Buffer creation";
            return -1;
        }
    }
   
    my $delta_time;
    if ($self->{per_second} == 1) {
        $delta_time = $options{new_datas}->{last_timestamp} - $self->{last_timestamp};
        if ($delta_time <= 0) {
            $delta_time = 1;
        }
    }

    if (defined($self->{closure_custom_calc})) {
        return $self->{closure_custom_calc}->($self, old_datas => $old_datas, new_datas => $options{new_datas}, delta_time => $delta_time, extra_options => $self->{closure_custom_calc_extra_options});
    }
    return $self->calc(old_datas => $old_datas, new_datas => $options{new_datas}, delta_time => $delta_time);
}

1;

__END__

