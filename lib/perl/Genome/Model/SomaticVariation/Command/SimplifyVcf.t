#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';
use Test::More tests => 4;
use Genome::Utility::Test qw(diff_ok);

my $test_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-SomaticVariation-Command-SimplifyVcf';
my $test_input_dir = "$test_dir/input.v1";
my $build_variants_dir = "$test_input_dir/variants";
Genome::Sys->create_directory($build_variants_dir);
my $output_dir = File::Temp::tempdir('Genome-Model-SomaticVariation-Command-SimplifyVcf-XXXXX', DIR => "$ENV{GENOME_TEST_TEMP}", CLEANUP => 1);

my $indel_vcf = "$build_variants_dir/indels.vcf.gz";
my $snv_vcf = "$build_variants_dir/snvs.vcf.gz";

my $expected_dir = "$test_dir/expected.v1";
my $expected_vcf = "$expected_dir/expected.snvs.vcf";

# Create the result for the indel variant list

my $class = "Genome::Model::SomaticVariation::Command::SimplifyVcf";
use_ok($class);

# Make the minimum amount of fake stuff to make this work
my $pp = Genome::ProcessingProfile::ReferenceAlignment->__define__(sequencing_platform => "solexa", type_name => "reference alignment");
my $pp_somvar = Genome::ProcessingProfile::SomaticVariation->__define__(type_name => "somatic variation");
my $subject = Genome::Subject->__define__( name => "test_subject_for_simplify_vcf", common_name => "common_name", subclass_name => "Genome::Sample");

my $tumor_subject = Genome::Subject->__define__( name => "H_KU-16454-D925307", subclass_name => "Genome::Sample"); # This name must match the input vcf test data
my $tumor_model = Genome::Model::ReferenceAlignment->__define__(subject => $tumor_subject, processing_profile => $pp, processing_profile_id => $pp->id);
my $tumor_build = Genome::Model::Build->create( model_id => $tumor_model->id, data_directory => $test_input_dir,);

my $normal_subject = Genome::Subject->__define__( name => "H_KU-16454-gl926886", subclass_name => "Genome::Sample"); # This name must match the input vcf test data
my $normal_model = Genome::Model::ReferenceAlignment->__define__(subject => $normal_subject, processing_profile => $pp, processing_profile_id => $pp->id);
my $normal_build = Genome::Model::Build->create( model_id => $normal_model->id, data_directory => $test_input_dir,);

my $model = Genome::Model::SomaticVariation->__define__( processing_profile=> $pp_somvar,processing_profile_id => $pp_somvar->id, subject => $subject, tumor_model => $tumor_model, normal_model => $normal_model);
my $build = Genome::Model::Build::SomaticVariation->__define__( data_directory => $test_input_dir, model => $model, normal_build =>$normal_build, tumor_build => $tumor_build);

my $command = $class->create(
    builds => [$build],
    outdir => $output_dir,
);
isa_ok($command, $class);

ok($command->execute, "Executed the $class command");
my $output_vcf = "$output_dir/" . $command->resolve_vcf_filename($build, "snv");

# Diff files vs expected
diff_ok($expected_vcf, $output_vcf, filter => [qr(^##fileDate=.*)]);
