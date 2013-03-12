#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
  $ENV{UR_DBI_NO_COMMIT} = 1;
  $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
  $ENV{NO_LSF} = 1;
};

use above "Genome";
use Test::More tests=>11; #One per 'ok', 'is', etc. statement below
use Genome::Model::ClinSeq::Command::Converge::AllEvents;
use Data::Dumper;

use_ok('Genome::Model::ClinSeq::Command::Converge::AllEvents') or die;

#Define the test where expected results are stored
my $expected_output_dir = $ENV{"GENOME_TEST_INPUTS"} . "Genome-Model-ClinSeq-Command-Converge-AllEvents/2013-03-11/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Get some clin-seq builds to converge
my $build_id1 = 135220643;
my $build1 = Genome::Model::Build->get($build_id1);
ok($build1, "obtained a clinseq build from the database for clinseq build id: $build_id1") or die;
my $build_id2 = 135220652;
my $build2 = Genome::Model::Build->get($build_id2);
ok($build2, "obtained a clinseq build from the database for clinseq build id: $build_id2") or die;
my $build_id3 = 135220657;
my $build3 = Genome::Model::Build->get($build_id3);
ok($build3, "obtained a clinseq build from the database for clinseq build id: $build_id3") or die;

#Find the input files
my $target_gene_list = $expected_output_dir . "target_genes.tsv";
ok(-e $target_gene_list, "Found target genes list file: $target_gene_list") or die;
my $ignore_gene_list = $expected_output_dir . "genes_to_ignore.tsv";
ok(-e $ignore_gene_list, "Found ignore genes list file: $ignore_gene_list") or die;

#Create converge all-events command and execute

#genome model clin-seq converge all-events --builds='id in [135220643,135220652,135220657]' --outdir=/tmp/converge_all_events/ --snv-label=S --indel-label=I --cnv-gain-label=A --cnv-loss-label=D --de-up-label=G --de-down-label=L --sv-fusion-label=T --tophat-outlier-label=J --cufflinks-outlier-label=C --target-gene-list=/tmp/target_genes.tsv --ignore-gene-list=/tmp/genes_to_ignore.tsv

my $converge_all_events_cmd = Genome::Model::ClinSeq::Command::Converge::AllEvents->create(outdir=>$temp_dir, builds=>[$build1,$build2,$build3], snv_label=>'S', indel_label=>'I', cnv_gain_label=>'A', cnv_loss_label=>'D', de_up_label=>'G', de_down_label=>'L', sv_fusion_label=>'T', tophat_outlier_label=>'J', cufflinks_outlier_label=>'C', target_gene_list=>$target_gene_list, ignore_gene_list=>$ignore_gene_list);
$converge_all_events_cmd->queue_status_messages(1);
my $r1 = $converge_all_events_cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$r1);

#Dump the output to a log file
my @output1 = $converge_all_events_cmd->status_messages();
my $log_file = $temp_dir . "/ConvergeAllEvents.log.txt";
my $log = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
ok(-e $log_file, "Wrote message file from converge all-events to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r -x '*.log.txt' -x '*.pdf' -x 'genes_to_ignore.tsv' -x 'target_genes.tsv' $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected results and test results")
or do {
  diag("expected: $expected_output_dir\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  print "\n\nFound $diff_line_count differing lines\n\n";
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-converge-all-events/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-converge-all-events");
};

