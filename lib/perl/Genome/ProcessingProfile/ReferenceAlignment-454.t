#!/usr/bin/env genome-perl

use strict;
use warnings;
use Carp;
use File::Temp;
use File::Basename;
require Test::MockObject;
use Test::More;
use Cwd;

plan skip_all => 'broken with new API';

use above 'Genome';
use Genome::Model::Event::Build::ReferenceAlignment::Test;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

#plan skip_all => 'this test is hanging presumambly from a workflow related issue';
plan tests => 44;

my $message_flag = 0;


my $tmp_dir = File::Temp::tempdir('TestAlignmentResultXXXXX', DIR => "$ENV{GENOME_TEST_TEMP}", CLEANUP => 1);
my $model_name = "test_454_" . Genome::Sys->username;
my $subject_name = 'TCAM-090304_gDNA_tube1';
my $subject_type = 'sample_name';
my $pp_name = '454_ReferenceAlignment_test';
my %pp_params = (
                 name => $pp_name,
                 dna_type => 'genomic dna',
                 indel_detection_strategy => 'varScan',
                 read_aligner_name => 'blat',
                 reference_sequence_name => 'refseq-for-test',
                 sequencing_platform => '454',
             );

my @instrument_data = setup_test_data($subject_name);
my $build_test = Genome::Model::Event::Build::ReferenceAlignment::Test->new(
                                                                                  model_name => $model_name,
                                                                                  subject_name => $subject_name,
                                                                                  subject_type => $subject_type,
                                                                                  processing_profile_name => $pp_name,
                                                                                  instrument_data => \@instrument_data,
                                                                                  tmp_dir => $tmp_dir,
                                                                                  messages => $message_flag,
                                                                              );
isa_ok($build_test,'Genome::Model::Event::Build::ReferenceAlignment::Test');
$build_test->create_test_pp(%pp_params);
$build_test->runtests;



sub setup_test_data {
    my $subject_name = shift;
    my @instrument_data;
    
    my $cwd = getcwd;

    chdir $tmp_dir || die("Failed to change directory to '$tmp_dir'");

    my $zip_file = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Command-AddReads/addreads-454-varScan.tgz';
    `tar -xzf $zip_file`;

    my @run_dirs = grep { -d $_ } glob("$tmp_dir/R_2008_07_29_*");
    for my $run_dir (@run_dirs) {
        my $run_name = basename($run_dir);
        my $analysis_name = $run_name . Genome::Sys->username . $$;
        $analysis_name =~ s/^R/D/;
        my @files = grep { -e $_ } glob("$run_dir/*.sff");
        for my $file (@files) {
            $file =~ /(\d+)\.sff/;
            my $region_number = $1;
            # FIXME removed run region gsc class. probably won't work right off the bat. Test has been skipped since Mar 2010
            my $instrument_data = Genome::InstrumentData::454->create_mock(
                                                                           id => -1111,
                                                                           sequencing_platform => '454',
                                                                           sample_name => $subject_name,
                                                                           analysis_name => $analysis_name,
                                                                           run_name => $run_name,
                                                                           subset_name => $region_number,
                                                                       );
            $instrument_data->set_always('class', 'Genome::InstrumentData::454');
            $instrument_data->mock('__meta__', \&Genome::InstrumentData::454::__meta__);
            unless ($instrument_data) {
                die ('Failed to create instrument data object for '. $run_name);
            }
my $allocation_path = sprintf('alignment_data/%s/%s/%s/%s_%s',
                              'blat',
                              'refseq-for-test',
                              $instrument_data->run_name,
                              $instrument_data->subset_name,
                              $instrument_data->id,    );
            my $id = UR::DataSource->next_dummy_autogenerated_id;
            my $alignment_allocation = Genome::Disk::Allocation->create_mock(
                                                                             disk_group_name => 'info_apipe',
                                                                             allocation_path => $allocation_path,
                                                                             mount_path => $tmp_dir,
                                                                             group_subdirectory => '',
                                                                             kilobytes_requested => 10000,
                                                                             kilobytes_used => 0,
                                                                             id => $id,
                                                                             owner_class_name => 'Genome::InstrumentData::454',
                                                                             owner_id => $instrument_data->id,
                                                                         );
            $alignment_allocation->mock('reallocate',sub { return 1; });
            $alignment_allocation->mock('deallocate',sub { return 1; });
            $alignment_allocation->set_always('absolute_path',$tmp_dir.'/'.$allocation_path);
            $instrument_data->set_list('allocations',$alignment_allocation);
            $instrument_data->set_always('sample_type','dna');

            $instrument_data->mock('full_path',sub {
                                       my $self = shift;
                                       if (@_) {
                                           $self->{_full_path} = shift;
                                       }
                                       return $self->{_full_path};
                                   }
                               );
            # TODO:switch these paths to something like $ENV{GENOME_TEST_INPUTS}BLAH
            #$instrument_data->mock('_data_base_path',\&Genome::InstrumentData::_data_base_path);
            #$instrument_data->mock('_default_full_path',\&Genome::InstrumentData::_default_full_path);
            #$instrument_data->set_always('resolve_full_path',$run_dir);
            #$instrument_data->mock('resolve_sff_path',\&Genome::InstrumentData::454::resolve_sff_path);
            $instrument_data->set_always('is_external',undef);
            $instrument_data->set_always('sff_file',$run_dir .'/'.$region_number .'.sff');
            $instrument_data->set_always('fasta_file',$run_dir .'/'.$region_number .'.fa');
            $instrument_data->set_always('qual_file',$run_dir .'/'.$region_number .'.qual');
            $instrument_data->set_always('dump_to_file_system',1);
            push @instrument_data, $instrument_data;
        }
    }
    chdir $cwd || die("Failed to change directory to '$cwd'");
    return @instrument_data;
}
