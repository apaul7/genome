#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use above 'Genome';

use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 8;
}

use_ok('Genome::Model::Tools::Varscan::PullOneTwoBpIndels');

# Inputs
my $varscan_version = "2.3.2";
my $test_data_dir = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-Varscan-PullOneTwoBpIndels';
my $input_indels = "$test_data_dir/indel_files_to_validate";
my $tumor_bam = "$test_data_dir/tumor.bam";
my $normal_bam = "$test_data_dir/normal.bam";
my $reference_fasta = "/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa";

# Outputs
my $output_dir = File::Temp::tempdir('VarscanValidationXXXXX', CLEANUP => 1, TMPDIR => 1);
my $small_indel_output_bed = "$output_dir/small_indel_output.bed";
my $large_indel_output_bed = "$output_dir/large_indel_output.bed";
my $varscan_snp_output = "$output_dir/varscan_snp_output";
my $varscan_indel_output = "$output_dir/varscan_indel_output";
my $realigned_bam_file_directory = "$output_dir/realigned_bams";
my $final_output_file = "$output_dir/final_output";
my @output_files = ("$output_dir/small_indel_output.padded1bp.bed", $large_indel_output_bed, $varscan_snp_output, $varscan_indel_output, $final_output_file);

# Expected
my $expected_dir = "$test_data_dir/1";
my $expected_small_indel_output_bed = "$expected_dir/small_indels.padded1bp.bed";
my $expected_large_indel_output_bed = "$expected_dir/large_indels.bed";
my $expected_varscan_snp_output = "$expected_dir/varscan_snps";
my $expected_varscan_indel_output = "$expected_dir/varscan_indels";
my $expected_realigned_bam_file_directory = "$expected_dir/realigned_bams";
my $expected_final_output_file = "$expected_dir/final_output";
my @expected_files = ($expected_small_indel_output_bed, $expected_large_indel_output_bed, $expected_varscan_snp_output, $expected_varscan_indel_output, $expected_final_output_file);


my $cmd = Genome::Model::Tools::Varscan::PullOneTwoBpIndels->create(
    varscan_version => $varscan_version,
    list_of_indel_files_to_validate => $input_indels,
    small_indel_output_bed => $small_indel_output_bed,
    large_indel_output_bed => $large_indel_output_bed,
    varscan_snp_output => $varscan_snp_output,
    varscan_indel_output => $varscan_indel_output,
    realigned_bam_file_directory => $realigned_bam_file_directory,
    final_output_file => $final_output_file,
    tumor_bam => $tumor_bam,
    normal_bam => $normal_bam,
    reference_fasta => $reference_fasta,
);

isa_ok($cmd, 'Genome::Model::Tools::Varscan::PullOneTwoBpIndels', "Made the command");
ok($cmd->execute, "Executed the command");

while (@output_files) {
    my $output_file = shift @output_files;
    my $expected_file = shift @expected_files;

    my $diff = Genome::Sys->diff_file_vs_file($output_file, $expected_file);
    ok(!$diff, "output matches expected result for $output_file and $expected_file")
        or diag("Diff:\n" . $diff);
}
