
=head1 NAME

VRPipe::PipelineSetup - set up a pipeline

=head1 SYNOPSIS

*** more documentation to come

=head1 DESCRIPTION

The main thing that users want to do is "run a pipeline" on a given set of
data. Pipelines are modelled by L<VRPipe::Pipline> objects, and the set of data
is modelled by a L<VRPipe::DataSource>. A PipelineSetup relates the two and
also stores the user configuration of both, resulting in a named object
defining what the user wants to happen.

So users "set up" pipelines and get back a PipelineSetup. They, and the
B<VRPipe> system itself, look to these PipelineSetups to see what is supposed
to be run and how, on what data.

Multiple PipelineSetups can run at once, even working on the same Pipelines and
DataSources (presumably with different configuration options), and the system
ensures that there are no problems with similar work being done by different
PipelineSetups overwriting each other's files.

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

use VRPipe::Base;

class VRPipe::PipelineSetup extends VRPipe::Persistent {
    has 'name' => (
        is     => 'rw',
        isa    => Varchar [64],
        traits => ['VRPipe::Persistent::Attributes'],
        is_key => 1
    );
    
    has 'datasource' => (
        is         => 'rw',
        isa        => Persistent,
        coerce     => 1,
        traits     => ['VRPipe::Persistent::Attributes'],
        is_key     => 1,
        belongs_to => 'VRPipe::DataSource'
    );
    
    has 'pipeline' => (
        is         => 'rw',
        isa        => Persistent,
        coerce     => 1,
        traits     => ['VRPipe::Persistent::Attributes'],
        is_key     => 1,
        belongs_to => 'VRPipe::Pipeline'
    );
    
    has 'output_root' => (
        is     => 'rw',
        isa    => Dir,
        coerce => 1,
        traits => ['VRPipe::Persistent::Attributes'],
        is_key => 1
    );
    
    has 'options' => (
        is                   => 'rw',
        isa                  => 'HashRef',
        traits               => ['VRPipe::Persistent::Attributes'],
        default              => sub { {} },
        allow_key_to_default => 1,
        is_key               => 1
    );
    
    has 'description' => (
        is          => 'rw',
        isa         => Text,
        traits      => ['VRPipe::Persistent::Attributes'],
        is_nullable => 1
    );
    
    has 'active' => (
        is      => 'rw',
        isa     => 'Bool',
        traits  => ['VRPipe::Persistent::Attributes'],
        default => 1
    );
    
    has 'user' => (
        is      => 'rw',
        isa     => Varchar [64],
        traits  => ['VRPipe::Persistent::Attributes'],
        default => 'vrpipe'
    );
    
    has 'desired_farm' => (
        is          => 'rw',
        isa         => Text,
        traits      => ['VRPipe::Persistent::Attributes'],
        is_nullable => 1
    );
    
    has 'controlling_farm' => (
        is          => 'rw',
        isa         => Text,
        traits      => ['VRPipe::Persistent::Attributes'],
        is_nullable => 1
    );
    
    __PACKAGE__->make_persistent(has_many => [states => 'VRPipe::StepState']);
    
    # because lots of frontends get the dataelementstates for a particular
    # pipelinesetup
    sub _des_search_args {
        my $self              = shift;
        my $include_withdrawn = shift;
        return ({ pipelinesetup => $self->id, $include_withdrawn ? () : ('dataelement.withdrawn' => 0) }, { prefetch => 'dataelement' });
    }
    
    method dataelementstates_pager (Bool :$include_withdrawn = 0) {
        return VRPipe::DataElementState->search_paged($self->_des_search_args($include_withdrawn));
    }
    
    method dataelementstates (Bool :$include_withdrawn = 0) {
        return VRPipe::DataElementState->search($self->_des_search_args($include_withdrawn));
    }
    
    around desired_farm (Maybe[Str] $farm) {
        my $current_farm = $self->$orig();
        if ($farm && $farm ne $current_farm) {
            $self->controlling_farm(undef);
            return $self->$orig($farm);
        }
        return $current_farm;
    }
    
    method trigger ($supplied_data_element?) {
        my $setup_id     = $self->id;
        my $pipeline     = $self->pipeline;
        my @step_members = $pipeline->step_members;
        my $num_steps    = scalar(@step_members);
        
        my $datasource  = $self->datasource;
        my $output_root = $self->output_root;
        $self->make_path($output_root);
        
        # we either loop through all incomplete elementstates, or the
        # (single) elementstate for the supplied dataelement
        my $pager;
        if ($supplied_data_element) {
            $pager = VRPipe::DataElementState->search_paged({ pipelinesetup => $setup_id, dataelement => $supplied_data_element->id, completed_steps => { '<', $num_steps }, 'dataelement.withdrawn' => 0 }, { prefetch => 'dataelement' });
        }
        else {
            $pager = $datasource->incomplete_element_states($self, prepare => 1);
        }
        
        my $all_done = 1;
        while (my $estates = $pager->next) {
            foreach my $estate (@$estates) {
                my $element         = $estate->dataelement;
                my $completed_steps = $estate->completed_steps;
                next if $completed_steps == $num_steps;
                
                my %previous_step_outputs;
                my $already_completed_steps = 0;
                foreach my $member (@step_members) {
                    my $step_number = $member->step_number;
                    my $state       = VRPipe::StepState->create(
                        stepmember    => $member,
                        dataelement   => $element,
                        pipelinesetup => $setup
                    );
                    
                    my $step = $member->step(previous_step_outputs => \%previous_step_outputs, step_state => $state);
                    if ($state->complete) {
                        $self->_complete_state($step, $state, $step_number, $pipeline, \%previous_step_outputs);
                        $already_completed_steps++;
                        
                        if ($already_completed_steps > $completed_steps) {
                            $estate->completed_steps($already_completed_steps);
                            $completed_steps = $already_completed_steps;
                            $estate->update;
                        }
                        
                        next;
                    }
                    
                    # have we previously done the dispatch dance and are
                    # currently waiting on submissions to complete?
                    my @submissions = $state->submissions;
                    if (@submissions) {
                        my $unfinished = VRPipe::Submission->search({ '_done' => 0, stepstate => $state->id });
                        unless ($unfinished) {
                            my $ok = $step->post_process();
                            if ($ok) {
                                # we just completed all the submissions from a previous parse
                                $self->_complete_state($step, $state, $step_number, $pipeline, \%previous_step_outputs);
                                next;
                            }
                            else {
                                # we warn instead of throw, because the step may
                                # have discovered its output files are missing
                                # and restarted itself
                                $self->warn("submissions completed, but post_process failed");
                            }
                        }
                        # else we have $unfinished unfinished submissions from a
                        # previous parse and are still running
                    }
                    else {
                        # this is the first time we're looking at this step for
                        # this data member for this pipelinesetup
                        my $completed;
                        try {
                            $completed = $step->parse();
                        }
                        catch ($err) {
                            warn $err;
                            $all_done = 0;
                            last;
                        }
                        
                        if ($completed) {
                            # on instant complete, parse calls post_process
                            # itself and only returns true if that was
                            # successfull
                            $self->_complete_state($step, $state, $step_number, $pipeline, \%previous_step_outputs);
                            next;
                        }
                        else {
                            my $dispatched = $step->dispatched();
                            if (@$dispatched) {
                                # create submissions
                                foreach my $arrayref (@$dispatched) {
                                    my ($cmd, $reqs, $job_args) = @$arrayref;
                                    my $sub = VRPipe::Submission->create(job => VRPipe::Job->create(dir => $output_root, $job_args ? (%{$job_args}) : (), cmd => $cmd), stepstate => $state, requirements => $reqs);
                                }
                                $step_counts{$step_name}++ if $inc_step_count;
                            }
                            else {
                                # it is possible for a parse to result in a
                                # different step being started over because
                                # input files were missing
                                $self->debug("step " . $step->id . " for data element " . $element->id . " for pipeline setup " . $setup->id . " neither completed nor dispatched anything!");
                            }
                        }
                    }
                    
                    $all_done = 0;
                    last;
                }
            }
        }
        
        return $all_done;
    }
    
    method _complete_state (VRPipe::Step $step, VRPipe::StepState $state, Int $step_number, VRPipe::Pipeline $pipeline, PreviousStepOutput $previous_step_outputs) {
        while (my ($key, $val) = each %{ $step->outputs() }) {
            $previous_step_outputs->{$key}->{$step_number} = $val;
        }
        unless ($state->complete) {
            # are there a behaviours to trigger?
            foreach my $behaviour (VRPipe::StepBehaviour->search({ pipeline => $pipeline->id, after_step => $step_number })) {
                $behaviour->behave(data_element => $state->dataelement, pipeline_setup => $state->pipelinesetup);
            }
            
            # add to the StepStats
            foreach my $submission ($state->submissions) {
                my $sched_stdout = $submission->scheduler_stdout || next;
                my $memory = ceil($sched_stdout->memory || $submission->memory);
                my $time   = ceil($sched_stdout->time   || $submission->time);
                VRPipe::StepStats->create(step => $step, pipelinesetup => $state->pipelinesetup, submission => $submission, memory => $memory, time => $time);
            }
            
            $state->complete(1);
            $state->update;
        }
    }
}

1;
