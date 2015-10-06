package Genome::Model::ReferenceVariation;

use strict;
use warnings;

use Genome;

class Genome::Model::ReferenceVariation {
    is => 'Genome::Model',
    has_param => [
        aligner_version => {
            is => 'Text',
            doc => 'The version of speedseq to run',
        },
        aligner_params => {
            is => 'Text',
            is_optional => 1,
            doc => 'Params to pass to speedseq',
        },
        aligner_api_version => {
            is => 'Text',
            doc => 'Aligner API version',
        },
        qc_config => {
            is => 'Text',
            doc => 'Name of the QC configuration to use',
        },
    ],
    has_input => [
        instrument_data => {
            is => 'Genome::InstrumentData',
            is_many => 1,
            doc => 'Instrument data to align',
        },
        target_region_set => {
            is => 'Genome::FeatureList',
            doc => 'the target region set for the instrument data',
            is_optional => 1,
        },
        region_of_interest_set => {
            is => 'Genome::FeatureList',
            doc => 'the region of interest set for the analysis',
            is_optional => 1,
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            doc => 'the reference to which to align',
        },
    ],
    has_optional_mutable => [ #convenience mutators for config
        region_of_interest_set_name => {
            is => 'Text',
            via => 'region_of_interest_set',
            to => 'name',
        },
        target_region_set_name => {
            is => 'Text',
            via => 'target_region_set',
            to => 'name',
        },
        reference_sequence_build_id => {
            via => 'reference_sequence_build',
            to => 'id'
        },
    ],
    has_classwide => [
        aligner_name => {
            is_mutable => 0,
            value => 'speedseq',
        },
    ],
};

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;

    my $dag = Genome::WorkflowBuilder::DAG->from_xml_filename(__FILE__ . '.xml');
    $dag->log_dir($build->log_directory);
    $dag->name($build->workflow_name);

    my ($alignment_op) = grep { $_->name eq 'Alignment' } @{$dag->operations};
    $alignment_op->lsf_resource(
        Genome::InstrumentData::Command::AlignAndMerge->lsf_resource_string_for_aligner_and_instrument_data(
            'speedseq',
            $build->instrument_data,
        )
    );

    return $dag;
}

sub map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    return (
        build => $build,
    );
}

1;

