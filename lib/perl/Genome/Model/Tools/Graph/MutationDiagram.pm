package Genome::Model::Tools::Graph::MutationDiagram;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Graph::MutationDiagram::MutationDiagram;
use Carp qw(confess);

class Genome::Model::Tools::Graph::MutationDiagram {
    is => 'Command',
    has => [
        annotation => {
            type => 'String',
            doc => "Annotator output.  Requires --reference-transcripts option",
        },
        annotation_format => {
            type => 'String',
            doc => "annotation file format",
            valid_values => ["tgi", "vep"],
            default_value => "tgi",
        },
        reference_transcripts => {
            type => 'String',
            doc => 'name/version number of the reference transcripts set ("NCBI-human.combined-annotation/0") Defaults to "NCBI-human.combined-annotation/54_36p_v2"',
            example_values => ['NCBI-human.combined-annotation/54_36p_v2'],
            is_optional => 1,
        },
        annotation_build_id => {
            type => 'Text',
            doc => 'The id of the annotation build to use',
            is_optional => 1,
        },
        genes  => {
            type => 'String',
            doc => "comma separated list of (hugo) gene names (uppercase)--default is ALL",
            is_optional => 1
        },
        custom_domains   => {
            type => 'String',
            doc => "comma separated list of protein domains to add. Expects triplets of name,start,end.",
            is_optional => 1
        },
        output_directory => {
            type => 'Text',
            doc => 'The output directory to write .svg files in',
            default => '.',
        },
        file_prefix => {
            type => 'Text',
            doc => 'A prefix to prepend to all filenames',
            default => '',
        },
        file_suffix => {
            type => 'Text',
            doc => 'A suffix to append to all filenames (before the extension)',
            default => '',
        },
        vep_frequency_field => {
            type => 'Text',
            doc => 'For VEP annotation, the name of a field in the EXTRA column that specifies the frequency of mutations',
            default_value => 'COUNT',
        },
    ],
    has_optional => [
        max_display_frequency => {
            type => 'Number',
            doc => "The maximum number of single lollis for any one mutations. Those sites exceeding this number will be truncated. Specifying this option automatically adds the number of mutations to the labels.",
        },
        lolli_shape => {
            type => 'Text',
            valid_values => ["circle", "diamond", "square"],
            default_value => "circle",
            doc => 'shape of the lolli part of each lollipop',
        },
        allow_floating_labels => {
            type => 'Boolean',
            doc => "If on, then each label's height is determined independently instead of all aligning to the same position",
            default => 0,
        },
        only_label_above_max_frequency => {
            type => 'Boolean',
            doc => "Only label those mutations that have a frequency greater than the max",
            default => 0,
        },
    ],
};

sub help_brief {
    "report mutations as a (svg) diagram"
}

sub help_synopsis {
    return <<"EOS"
gmr graph mutation-diagram  --annotation my.maf
EOS
}

sub help_detail {
    return <<"EOS"
Generates (gene) mutation diagrams from an annotation file.
EOS
}

sub execute {
    my $self = shift;
    my $anno_file = $self->annotation;
    if($anno_file) {
        my %params = (
            domain_provider => $self->resolve_domain_provider,
            mutation_provider => $self->resolve_mutation_provider,
            hugos => $self->genes,
            custom_domains => $self->custom_domains,
            output_directory => $self->output_directory,
            basename => $self->file_prefix,
            suffix => $self->file_suffix,
            max_display_freq => $self->max_display_frequency,
            lolli_shape => $self->lolli_shape,
            floating_labels => $self->allow_floating_labels,
            only_label_max => $self->only_label_above_max_frequency,
        );

        my $anno_obj = new Genome::Model::Tools::Graph::MutationDiagram::MutationDiagram(
            %params);
    }
    else {
        $self->error_message("Must provide annotation output format");
        return;
    }
    return 1;
}

sub resolve_mutation_provider {
    my $self = shift;

    if ($self->annotation_format eq 'vep') {
        return Genome::Model::Tools::Graph::MutationDiagram::VepMutationProvider->create(
           input_file => $self->annotation,
           vep_frequency_field => $self->vep_frequency_field,
        );
    }
    elsif ($self->annotation_format eq 'tgi') {
        return Genome::Model::Tools::Graph::MutationDiagram::TgiMutationProvider->create(
            input_file => $self->annotation,
        );
    }
    else {
        die $self->error_message("Unrecognized annotation format");
    }
}

sub resolve_domain_provider {
    my $self = shift;

    my $build;
    if ($self->annotation_build_id) {
        $build = Genome::Model::Build->get($self->annotation_build_id);
    }
    elsif ($self->reference_transcripts) {
        my ($model_name, $version) = split('/', $self->reference_transcripts);
        my $model = Genome::Model->get(name => $model_name);
        unless ($model){
            print STDERR "ERROR: couldn't get reference transcripts set for $model_name\n";
            return;
        }
        $build = $model->build_by_version($version);
    }
    else {
        confess "No value supplied for reference_transcripts or annotation_build_id, abort!";
    }

    unless ($build){
        $self->error_message("couldn't load reference trascripts set");
        return;
    }

    return Genome::Model::Tools::Graph::MutationDiagram::AnnotationBuild->create(build => $build);
}

1;
