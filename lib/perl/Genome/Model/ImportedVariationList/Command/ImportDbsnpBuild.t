#!/usr/bin/env genome-perl
use strict;
use warnings;
use above "Genome";
use Test::More;

Genome::Report::Email->silent();

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok("Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild");

my $reference_sequence_build = Genome::Model::Build::ReferenceSequence->get_by_name('g1k-human-build37');

my $version = 137;
my $import_dbsnp_build = Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild->create(
    vcf_file_url => Genome::Config::get('test_url').'/Genome-Model-Tools-Dbsnp-Import-Vcf/v2/VCF/00-All.vcf.gz',
    version => $version,
    reference_sequence_build => $reference_sequence_build ,
);

# The kB requested is hard-coded at 20GB but the test does not need
# to make a 20GB allocation.
*Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild::kilobytes_requested
    = sub { return 5_000 };

ok($import_dbsnp_build->execute(), "Dbsnp build import completed");

my $build = $import_dbsnp_build->build;
isa_ok($build, "Genome::Model::Build::ImportedVariationList");

ok($build->snv_result, "The build has a snv result attached to it");
is($build->version, $version);
is($build->source_name, "dbsnp", "Source name is set properly");
ok($build->snvs_bed, "The build has a snv bed");
ok($build->snvs_vcf, "The build has a vcf");
ok(-s $build->snvs_bed, "The snvs bed has content");
ok(-s $build->snvs_vcf, "The snvs vcf has size");

done_testing();
