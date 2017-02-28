#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above "Genome";
use Test::More skip_all => 'Test data must be regenerated.';
#use Test::More tests => 24;  #One per 'ok', 'is', etc. statement below
use Genome::Model::ClinSeq::Command::CufflinksDifferentialExpression;
use Data::Dumper;

use_ok('Genome::Model::ClinSeq::Command::CufflinksDifferentialExpression') or die;

#Define the test where expected results are stored
my $expected_output_dir =
    Genome::Config::get('test_inputs') . "Genome-Model-ClinSeq-Command-CufflinksDifferentialExpression/2013-02-01/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Get a pair of rna-seq builds
my $case_build_id = 129767889;
my $case_build    = Genome::Model::Build->get($case_build_id);
ok($case_build, "got rna-seq build from the database using build id: $case_build_id") or die;
my $control_build_id = 129767952;
my $control_build    = Genome::Model::Build->get($control_build_id);
ok($control_build, "got rna-seq build from the database using build id: $control_build_id") or die;

#Create cufflinks-differential-expression command and execute
#genome model clin-seq cufflinks-differential-expression --outdir=/tmp/ --case-build=129767889 --control-build=129767952

my $cancer_annotation_db = Genome::Db->get("tgi/cancer-annotation/human/build37-20130401.1");

my $cufflinks_differential_expression_cmd = Genome::Model::ClinSeq::Command::CufflinksDifferentialExpression->create(
    outdir               => $temp_dir,
    case_build           => $case_build,
    control_build        => $control_build,
    cancer_annotation_db => $cancer_annotation_db,
);
$cufflinks_differential_expression_cmd->queue_status_messages(1);
my $r1 = $cufflinks_differential_expression_cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: ' . $r1);

#Dump the output to a log file
my @output1  = $cufflinks_differential_expression_cmd->status_messages();
my $log_file = $temp_dir . "/CufflinksDifferentialExpression.log.txt";
my $log      = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
ok(-e $log_file, "Wrote message file from cufflinks-differential-expression to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");

#Check for non-zero presence of expected PDFs
my @images = qw (
    case_vs_control_de_filtered_hist.pdf
    case_vs_control_de_hist.pdf
    case_vs_control_fpkm_density_postnorm.pdf
    case_vs_control_fpkm_density_prenorm.pdf
    case_vs_control_fpkm_scatter_postnorm.png
    case_vs_control_fpkm_scatter_postnorm_coding_de.png
    case_vs_control_fpkm_scatter_postnorm_de.png
    case_vs_control_fpkm_scatter_prenorm.png
);

foreach my $image (@images) {
    my $path1 = $temp_dir . "/genes/$image";
    ok(-s $path1, "Found non-zero image file genes/$image");
    my $path2 = $temp_dir . "/transcripts/$image";
    ok(-s $path2, "Found non-zero image file transcripts/$image");
}

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r -x '*.log.txt' -x '*.pdf' -x '*.stderr' -x '*.stdout' -x '*.png' $expected_output_dir $temp_dir`;
my $ok = ok(@diff == 0, "Found only expected number of differences between expected results and test results");
unless ($ok) {
    diag("expected: $expected_output_dir\nactual: $temp_dir\n");
    diag("differences are:");
    diag(@diff);
    my $diff_line_count = scalar(@diff);
    print "\n\nFound $diff_line_count differing lines\n\n";
    Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-cufflinks-differential-expression/");
    Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-cufflinks-differential-expression");
}
