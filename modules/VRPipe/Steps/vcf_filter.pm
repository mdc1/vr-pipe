use VRPipe::Base;

class VRPipe::Steps::vcf_filter with VRPipe::StepRole {
    method options_definition {
        return { 'tabix_exe' => VRPipe::StepOption->get(description => 'path to your tabix executable',
                                                        optional => 1,
                                                        default_value => 'tabix') };
    }
    method inputs_definition {
        return { vcf_files => VRPipe::StepIODefinition->get(type => 'vcf',
                                                            description => 'vcf files',
                                                            max_files => -1) };
    }
    method body_sub {
        return sub {
            my $self = shift;
            
            my $options = $self->options;
	    my $tabix_exe = $options->{tabix_exe};
            
            my $req = $self->new_requirements(memory => 500, time => 1);
            foreach my $vcf_file (@{$self->inputs->{vcf_files}}) {
                my $basename = $vcf_file->basename;
                if ($basename =~ /\.gz$/) {
                    $basename =~ s/\.gz$/.filtered.gz/;
                }
                else {
                    $basename =~ s/\.vcf$/.filtered.vcf/;
                }
                my $filtered_vcf = $self->output_file(output_key => 'filtered_vcf', basename => $basename, type => 'vcf');
                my $tbi = $self->output_file(output_key => 'tbi_file', basename => $basename.'.tbi', type => 'bin');
                
                my $input_path = $vcf_file->path;
                my $output_path = $filtered_vcf->path;

				## Replace copy with soft filter step when available
                my $this_cmd = "cp $input_path $output_path; $tabix_exe -f -p vcf $output_path";
                
                $self->dispatch_wrapped_cmd('VRPipe::Steps::vcf_filter', 'filter_vcf', [$this_cmd, $req, {output_files => [$filtered_vcf, $tbi]}]);
            }
        };
    }
    method outputs_definition {
        return { filtered_vcf => VRPipe::StepIODefinition->get(type => 'vcf',
                                                               description => 'a filtered vcf file',
                                                               max_files => -1),
                 tbi_file => VRPipe::StepIODefinition->get(type => 'bin',
                                                           description => 'a tbi file',
                                                           max_files => -1) };
    }
    method post_process_sub {
        return sub { return 1; };
    }
    method description {
        return "Soft-filter input VCFs, creating an output VCF for every input";
    }
    method max_simultaneous {
        return 0; # meaning unlimited
    }
    
    method filter_vcf (ClassName|Object $self: Str $cmd_line) {
        my ($input_path, $output_path) = $cmd_line =~ /^cp (\S+) (\S[^;]+)/;
        my $input_file = VRPipe::File->get(path => $input_path);
        
        my $expected_lines = $input_file->lines;
        
        $input_file->disconnect;
        system($cmd_line) && $self->throw("failed to run [$cmd_line]");
        
        my $output_file = VRPipe::File->get(path => $output_path);
        $output_file->update_stats_from_disc;
        my $output_lines = $output_file->lines;
        
        unless ($output_lines == $expected_lines) {
            $output_file->unlink;
            $self->throw("Output VCF has the wrong number of lines (expected $expected_lines vs $output_lines)");
        }
        else {
            return 1;
        }
    }
}

1;
