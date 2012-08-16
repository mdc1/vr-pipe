
=head1 NAME

VRPipe::Pipelines::convex_l2r_bp_generation - a pipeline

=head1 DESCRIPTION

This is second of of three pipeline required to run in sequence in order to
generate CNV Calls using the Convex Exome CNV detection package. This pipeline
generates L2R files, and a single Breakpoints file, from the Read Depth files
generated by the previous pipeline convex_read_depth_generation. The Convex L2R
program runs once only for a set of Read Depth files, so its datasource will be
a vrpipe group_by_metadata set of Read Depth files from the previous pipeline.

=head1 AUTHOR

Chris Joyce <cj5@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 Genome Research Limited.

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

use VRPipe::Base;

class VRPipe::Pipelines::convex_l2r_bp_generation with VRPipe::PipelineRole {
    method name {
        return 'convex_l2r_bp_generation';
    }
    
    method _num_steps {
        return 2;
    }
    
    method description {
        return 'Run CoNVex pipeline to Generate L2R files from Read Depth files, and Breakpoint file, for subsequent CNV Calling pipeline';
    }
    
    method steps {
        $self->throw("steps cannot be called on this non-persistent object");
    }
    
    method _step_list {
        return ([
                VRPipe::Step->get(name => 'convex_breakpoints'), #
                VRPipe::Step->get(name => 'convex_L2R'),         #
            ],
            [VRPipe::StepAdaptorDefiner->new(from_step => 0, to_step => 1, to_key => 'rd_files'), VRPipe::StepAdaptorDefiner->new(from_step => 0, to_step => 2, to_key => 'rd_files'),],
            [],
        );
    }
}

1;
