#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

my $pkg = 'Genome::Qc::Tool::Picard::CollectWgsMetrics';
use_ok($pkg);

my $data_dir = __FILE__.".d";

my $output_file = File::Spec->join($data_dir, 'output_file.txt');
my $temp_file = Genome::Sys->create_temp_file_path;

my $tool = $pkg->create(
    gmt_params => {
        reference_sequence => $temp_file,
        input_file => $temp_file,
        output_file => $output_file,
        temp_directory => $temp_file,
        use_version => 1.123,
    }
);
ok($tool->isa($pkg), 'Tool created successfully');

my @expected_cmd_line =(
    'java',
    '-Xmx4096m',
    '-XX:MaxPermSize=64m',
    '-cp',
    '/usr/share/java/ant.jar:/gscmnt/sata132/techd/solexa/jwalker/lib/picard-tools-1.123/CollectWgsMetrics.jar',
    'picard.analysis.CollectWgsMetrics',
    sprintf('INPUT=%s', $temp_file),
    'MAX_RECORDS_IN_RAM=500000',
    sprintf('OUTPUT=%s', $output_file),
    sprintf('REFERENCE_SEQUENCE=%s', $temp_file),
    sprintf('TMP_DIR=%s', $temp_file),
    'VALIDATION_STRINGENCY=SILENT',
);
is_deeply([$tool->cmd_line], [@expected_cmd_line], 'Command line list as expected');

my %expected_metrics = (
    'haploid_coverage' => 0.000115,
);
is_deeply({$tool->get_metrics}, {%expected_metrics}, 'Parsed metrics as expected');

done_testing;