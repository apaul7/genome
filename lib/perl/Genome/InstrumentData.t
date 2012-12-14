#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

my $base_class = 'Genome::InstrumentData';

use_ok('Genome::InstrumentData') or die;

my %seq_plats_and_ids = (
    454     => ['2853729194','2853729397'],
        # region_id  seq_id     index_sequence
        # 2853729293 2853729194
        # 2853729292 2853729397 AACAACTC
    sanger  => ['22sep09.863amcb1'],
    solexa  => ['2338813239'],
);

my @rcs = Genome::InstrumentData->get([ map { @$_ } values %seq_plats_and_ids ]);
is(scalar(@rcs), 4, "got 4 objects");

for my $platform (keys %seq_plats_and_ids) {
    note("Now test $platform");
    
    my $subclass = $base_class.'::'.ucfirst($platform);
    use_ok($subclass);
    
    for my $id (@{ $seq_plats_and_ids{$platform} }) {
        my $instrument_data =Genome::InstrumentData->get($id);
        isa_ok($instrument_data, $subclass);
        is($instrument_data->sequencing_platform, $platform, 'platform is correct');
        
        if ( $platform eq 'solexa' ) {
            is($instrument_data->sample_type,'rna','got expected sample type');
            is($instrument_data->resolve_quality_converter,'sol2sanger','got expected quality converter');
        }
    }
}

# Test is_attribute
class SuperSeq {
    is => 'Genome::InstrumentData',
    has => [
        file => { is_attribute => 1, },
    ],
};

my $library = Genome::Library->create(
    name => '__TEST_LIBRARY__',
    sample => Genome::Sample->create(name => '__TEST_SAMPLE__'),
);
ok($library, 'define library');
my $inst_data = SuperSeq->__define__(
    library => $library,
    file => 'some_file',
);
ok($inst_data, 'create super seq inst data');
my @attrs = $inst_data->attributes;
ok(@attrs, 'super seq has attributes');
my ($file_attr) = grep { $_->attribute_label eq 'file' } @attrs;
ok($file_attr, 'super seq file attr');
is($file_attr->attribute_value, $inst_data->file, 'super seq file attr matches accessor');

done_testing();
