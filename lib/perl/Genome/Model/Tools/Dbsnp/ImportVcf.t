#!/usr/bin/env genome-perl 
use strict; 
use warnings; 
use above "Genome"; 
use Test::More tests => 4; 

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok("Genome::Model::Tools::Dbsnp::ImportVcf");

my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Dbsnp-Import-Vcf-XXXX', DIR => "$ENV{GENOME_TEST_TEMP}", CLEANUP => 1);

my $base_url = $ENV{GENOME_TEST_URL}.'/Genome-Model-Tools-Dbsnp-Import-Vcf';
my $importer = Genome::Model::Tools::Dbsnp::ImportVcf->create(
   vcf_file_url => $base_url.'/VCF/4.0/00-All.vcf.gz',
   output_file_path => $tmp_dir . '/testfile.vcf',
   flat_url => $base_url.'/ASN1_flat/',
);

ok($importer->execute(), "ImportVcf command successfully ran");

ok(-e ($tmp_dir . '/testfile.vcf'), "Ensure new VCF file was written to to the given output path");

my $vcf_fh  = Genome::Sys->open_file_for_reading($tmp_dir . '/testfile.vcf'); 

my $found_submitter_header = 0;
my $found_submitter_data = 0;

while (!$vcf_fh->eof() && (!$found_submitter_data || !$found_submitter_header)) {
    my $line = $vcf_fh->getline();
    if( $line =~ /^##INFO=<ID=SUB,/){
        $found_submitter_header = 1;
    }elsif ($line =~ /;SUB=.+/){
        $found_submitter_data = 1;
    }
}

ok($found_submitter_header && $found_submitter_data, "Submitter data was written to the VCF header and file entries");
