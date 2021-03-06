#!/usr/bin/env perl
use strict;
use warnings;
use Path::Class;

BEGIN {
    use Test::Most tests => 3;
    use VRPipeTest (
        required_env => [qw(VRPIPE_TEST_PIPELINES BISMARK_GENOME_FOLDER)],
        required_exe => [qw(bismark)]
    );
    use TestPipelines;
    use_ok('VRPipe::Steps::bismark');
}

my ($output_dir, $pipeline, $step) = create_single_step_pipeline('bismark', 'fastq_files');
is_deeply [$step->id, $step->description], [1, 'Step for bismark Bisulfite sequencing mapper'], 'Bismark step created and has correct description';

# run bismark on a fastq file.
my $setup = VRPipe::PipelineSetup->create(
    name       => 'bismark',
    datasource => VRPipe::DataSource->create(
        type    => 'delimited',
        method  => 'all_columns',
        options => { delimiter => "\t" },
        source  => file(qw(t data bismark_datasource.fofn))->absolute
    ),
    output_root => $output_dir,
    pipeline    => $pipeline,
    options     => { bismark_genome_folder => $ENV{BISMARK_GENOME_FOLDER}, paired_end => 0 }
);

my @output_subdirs = output_subdirs(1);
my $outputfile_1   = file(@output_subdirs, '1_bismark', "2822_6_1", "2822_6_1.fastq_Bismark_mapping_report.txt");
my $outputfile_2   = file(@output_subdirs, '1_bismark', "2822_6_1", "2822_6_1.fastq_bismark.sam");
my @outputfiles;
push(@outputfiles, $outputfile_1, $outputfile_2);
ok handle_pipeline(@outputfiles), 'bismark pipeline ran ok, generating the expected output file';
