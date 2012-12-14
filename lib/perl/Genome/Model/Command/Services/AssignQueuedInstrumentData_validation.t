#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use above 'Genome';

require Genome::InstrumentData::Solexa;
use Test::More tests => 34;
use Test::MockObject;

use_ok('Genome::Model::Command::Services::AssignQueuedInstrumentData');

my (@instrument_data);
no warnings;
*Genome::InstrumentDataAttribute::get = sub {
    my ($class, %params) = @_;
    my %attrs = map { $_->id => $_ } map { $_->attributes } @instrument_data;
    for my $param_key ( keys %params ) {
        my @param_values = ( ref $params{$param_key} ? @{$params{$param_key}} : $params{$param_key} );
        my @unmatched_attrs;
        for my $attr ( values %attrs ) {
            next if grep { $attr->$param_key eq $_ } @param_values;
            push @unmatched_attrs, $attr->id;
        }
        for ( @unmatched_attrs ) { delete $attrs{$_} }
    }
    return values %attrs;
};
sub GSC::PSE::get { return; }
use warnings;

my $taxon = Genome::Taxon->get( species_name => 'human' );
my $individual = Genome::Individual->create(
    id => '-10',
    name => 'AQID-test-individual',
    common_name => 'AQID10',
    taxon_id => $taxon->id,
);

my $sample = Genome::Sample->create(
    id => '-1',
    name => 'AQID-test-sample',
    common_name => 'normal',
    source_id => $individual->id,
);

my $library = Genome::Library->create(
    id => '-2',
    sample_id => $sample->id,
    name => $sample->name.'-testlibs',
);

isa_ok($library, 'Genome::Library');
isa_ok($sample, 'Genome::Sample');

my $instrument_data_1 = Genome::InstrumentData::Solexa->create(
    id => '-100',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'validation-test',
    index_sequence => 'GTTAC',
);
$instrument_data_1->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
ok($instrument_data_1, 'create instrument data 1');
push @instrument_data, $instrument_data_1;

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(name => 'NCBI-human-build36');
isa_ok($ref_seq_build, 'Genome::Model::Build::ImportedReferenceSequence') or die;


my $fl = Genome::FeatureList->__define__(
    id => 'ABCDEFG',
    name => 'validation-test',
    format => 'true-BED',
    content_type => 'validation',
    reference => $ref_seq_build,
    file_content_hash => 1,
);

my $processing_profile = Genome::ProcessingProfile::ReferenceAlignment->create(
    dna_type => 'genomic dna',
    name => 'AQID-test-pp',
    read_aligner_name => 'bwa',
    sequencing_platform => 'solexa',
    read_aligner_params => '#this is a test',
    transcript_variant_annotator_version => 1,
);
ok($processing_profile, 'Created a processing_profile');

my $sv_model = Genome::Model::SomaticValidation->__define__(
    name => 'test-validation-model',
    target_region_set => $fl,
    design_set => $fl,
    tumor_sample => $instrument_data_1->sample,
    subject => $instrument_data_1->sample->source,
    reference_sequence_build => $ref_seq_build,
    auto_assign_inst_data => 1,
    processing_profile_id => 1,
);

my $command_1 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
isa_ok($command_1, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_1->dump_status_messages(1);

ok($command_1->execute(), 'assign-queued-instrument-data executed successfully.');

my $new_models = $command_1->_newly_created_models;
is(scalar(keys %$new_models), 0, 'the cron created no models for validation');
is($sv_model->instrument_data, $instrument_data_1, 'the cron added the instrument data to the validation model');
my $models_changed_1 = $command_1->_existing_models_assigned_to;
is(scalar(keys %$models_changed_1), 1, 'data was reported assigned to an existing model');
is((values(%$models_changed_1))[0]->build_requested, 1, 'requested build');



my $sample1a = Genome::Sample->create(
    id => '-11',
    name => 'Pooled_Library_test-sample',
    common_name => 'normal',
    source_id => $individual->id,
);

my $library1a = Genome::Library->create(
    id => '-22',
    sample_id => $sample1a->id,
    name => $sample1a->name.'-testlibs',
);


my $instrument_data_1a = Genome::InstrumentData::Solexa->create(
    id => '-1033',
    library_id => $library1a->id,
    flow_cell_id => 'TM-021',
    lane => '1',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'validation-test',
    index_sequence => 'unknown',
);
$instrument_data_1a->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
ok($instrument_data_1a, 'creat instrument data 1a');
push @instrument_data, $instrument_data_1a;

my $command_1a = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
isa_ok($command_1a, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_1a->dump_status_messages(1);
ok($command_1a->execute(), 'assign-queued-instrument-data executed successfully.');
is($instrument_data_1a->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'skipped', 'inst data 1a is skipped');

my $fl2 = Genome::FeatureList->__define__(
    id => 'ABCDEFGH',
    name => 'validation-test-roi',
    format => 'true-BED',
    content_type => 'roi',
    reference => $ref_seq_build,
    file_content_hash => 1,
);

my $instrument_data_2 = Genome::InstrumentData::Solexa->create(
    id => '-101',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '2',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'validation-test-roi',
    index_sequence => 'GGGGG',
);
$instrument_data_2->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
ok($instrument_data_2, 'create instrument data 2');
push @instrument_data, $instrument_data_2;


my $ref_seq_build_2a = Genome::Model::Build::ImportedReferenceSequence->__define__(
    id => '-10000',
    model_id => $ref_seq_build->model_id,
    version => '36-alternative_for_validation_test',
);

my $fl2a = Genome::FeatureList->__define__(
    id => 'ABCDEFGH_alt',
    name => 'validation-test-roi-alternate_reference',
    format => 'true-BED',
    content_type => 'validation',
    reference => $ref_seq_build_2a,
    file_content_hash => 1,
);

my $sv_model_2a = Genome::Model::SomaticValidation->__define__(
    name => 'test-validation-model',
    target_region_set => $fl2a,
    design_set => $fl2a,
    tumor_sample => $instrument_data_1->sample,
    subject => $instrument_data_1->sample->source,
    reference_sequence_build => $ref_seq_build,
    auto_assign_inst_data => 1,
    processing_profile_id => 1,
);
my $ref_converter = Genome::Model::Build::ReferenceSequence::Converter->create(
    source_reference_build_id => $ref_seq_build_2a->id,
    destination_reference_build_id => $ref_seq_build->id,
    algorithm => 'chop_chr',
);

my $instrument_data_2a = Genome::InstrumentData::Solexa->create(
    id => '-103',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '3',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'validation-test-roi-alternate_reference',
    index_sequence => 'GGGGG',
);
$instrument_data_2a->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
ok($instrument_data_2a, 'create instrument data 2a');
push @instrument_data, $instrument_data_2a;

my $command_2 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
isa_ok($command_2, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_2->dump_status_messages(1);
ok($command_2->execute(), 'assign-queued-instrument-data executed successfully.');

my $err = $command_2->error_message;
like($err, qr/validation-test-roi/, 'reported error about feature-list');

is($instrument_data_2->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'failed', 'inst data 2 is failed');
is($instrument_data_2->attributes(attribute_label => 'tgi_lims_fail_message')->attribute_value, 'Unexpected "roi"-typed feature-list set as target region set name: validation-test-roi', 'inst data 2 tgi_lims_fail_message is correct');
is($instrument_data_2->attributes(attribute_label => 'tgi_lims_fail_count')->attribute_value, 1, 'inst data 2 tgi_lims_fail_count is 1');
is($instrument_data_2a->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'processed', 'inst data 2a is processed');

$fl2->content_type(undef);
my $command_3 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
isa_ok($command_3, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_3->dump_status_messages(1);
ok($command_3->execute(), 'assign-queued-instrument-data executed successfully.');

$err = $command_3->error_message;
ok($err =~ 'validation-test-roi', 'reported error about feature-list');

$sv_model_2a->auto_assign_inst_data(0);

my $instrument_data_2b = Genome::InstrumentData::Solexa->create(
    id => '-113',
    library_id => $library->id,
    flow_cell_id => 'TM-021',
    lane => '3',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 65535,
    rev_clusters => 65536,
    target_region_set_name => 'validation-test-roi-alternate_reference',
    index_sequence => 'GGGGG',
);
$instrument_data_2b->add_attribute(
    attribute_label => 'tgi_lims_status',
    attribute_value => 'new',
);
ok($instrument_data_2b, 'create instrument data 2b');
push @instrument_data, $instrument_data_2b;

my $command_4 = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
isa_ok($command_4, 'Genome::Model::Command::Services::AssignQueuedInstrumentData');
$command_4->dump_status_messages(1);
ok($command_4->execute(), 'assign-queued-instrument-data executed successfully.');
is($instrument_data_2b->attributes(attribute_label => 'tgi_lims_status')->attribute_value, 'failed', 'inst data 2b is failed');
is($instrument_data_2b->attributes(attribute_label => 'tgi_lims_fail_message')->attribute_value, 'Did not assign validation instrument data to any models.', 'inst data 2b is failed');
is($instrument_data_2b->attributes(attribute_label => 'tgi_lims_fail_count')->attribute_value, 1, 'inst data 2b is failed');

done_testing();
