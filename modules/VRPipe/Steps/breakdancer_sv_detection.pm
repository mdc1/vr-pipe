use VRPipe::Base;

class VRPipe::Steps::breakdancer_sv_detection with VRPipe::StepRole {
    method options_definition {
        return { 
            'breakdancer_max_options' => VRPipe::StepOption->get(description => 'breakdancer_max options excluding bam config file name'),
            'breakdancer_max_exe' => VRPipe::StepOption->get(description => 'full path to breakdancer_max executable', optional => 1, default_value => 'breakdancer_max'),
        };
    }
    method inputs_definition {
        return { bam_cfg => VRPipe::StepIODefinition->get(type => 'txt',
                                                            description => 'breakdancer bam config files',
                                                            max_files => -1) };
    }
    method body_sub {
        return sub {
            my $self = shift;
            
            my $options = $self->options;
            my $breakdancer_max_exe = $options->{breakdancer_max_exe};
            my $breakdancer_max_options = $options->{'breakdancer_max_options'};
            my $req = $self->new_requirements(memory => 500, time => 1);
            
            foreach my $bam_cfg (@{$self->inputs->{bam_cfg}}) {
                my $basename = $bam_cfg->basename;
                $basename =~ s/\.cfg$/.max/;
                my $breakdancer_max = $self->output_file(output_key => 'breakdancer_max', basename => $basename, type => 'txt');
                
                my $input_path = $bam_cfg->path;
                my $output_path = $breakdancer_max->path;
                
                my $cmd = "$breakdancer_max_exe $breakdancer_max_options $input_path > $output_path";
		
                $self->dispatch_wrapped_cmd('VRPipe::Steps::breakdancer_sv_detection', 'run_breakdancer_max', [$cmd, $req, {output_files => [$breakdancer_max]}]);
            }
        };
    }
    method outputs_definition {
        return { breakdancer_max => VRPipe::StepIODefinition->get(type => 'txt',
                                                               description => 'breakdancer max sv detection results',
                                                               max_files => -1) };
    }
    method post_process_sub {
        return sub { return 1; };
    }
    method description {
        return "Generates breakdancer sv detection results from input bam config file";
    }
    method max_simultaneous {
        return 0; # meaning unlimited
    }
    
    method run_breakdancer_max (ClassName|Object $self: Str $cmd_line) {

        system($cmd_line) && $self->throw("failed to run [$cmd_line]");
        
        my ($output_path) = $cmd_line =~ /.* > (\S+)$/;
        my $output_file = VRPipe::File->get(path => $output_path);
        $output_file->update_stats_from_disc;
        
        if ($output_file->num_records == 0) {
            $output_file->unlink;
			$self->throw("Output $output_path is empty)");
        }
        else {
            return 1;
        }
    }
    
}

1;
