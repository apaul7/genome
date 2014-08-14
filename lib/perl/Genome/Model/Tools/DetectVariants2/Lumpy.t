use strict;
use warnings;

BEGIN {
    $ENV{NO_LSF} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';
use Genome::SoftwareResult;

use Test::More;
use File::Compare qw(compare);
use Genome::Utility::Test qw(compare_ok); 

use_ok('Genome::Model::Tools::DetectVariants2::Lumpy');

    my $refbuild_id = 101947881;
    my $test_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Lumpy';
    my $output_dir = Genome::Sys-> create_temp_directory();
    my $tumor_bam = $test_dir .'/tumor.bam';

my $command = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id => $refbuild_id,
        aligned_reads_input => $tumor_bam,
        params  =>"-lp,-mw:4,-tt:0.0//-pe,min_non_overlap:150,discordant_z:4,back_distance:20,weight:1,id:20//-sr,back_distance:20,weight:1,id:2,min_mapping_threshold:20",
        output_directory => $output_dir,
        version => "0.2.6",
    );

my $expected_lumpy_directory = File::Spec->catdir(File::Spec->rootdir,qw/ usr lib lumpy0.2.6 /);
my $lumpy_directory = $command->lumpy_directory;
is($lumpy_directory, $expected_lumpy_directory, "lumpy directory");
my $lumpy_scripts_directory =  $command->lumpy_scripts_directory;
is($lumpy_scripts_directory, File::Spec->catfile($expected_lumpy_directory,"scripts"), "lumpy scripts directory");
is($command->lumpy_script_for_extract_split_reads_bwamem, File::Spec->catfile($lumpy_scripts_directory,"extractSplitReads_BwaMem"), "lumpy script for split reads");
is($command->lumpy_script_for_pairend_distro, File::Spec->catfile($lumpy_scripts_directory,"pairend_distro.py"), "lumpy script for paired end");
is($command->lumpy_command, File::Spec->catfile($expected_lumpy_directory,"bin","lumpy"), "lumpy command");

ok($command, 'Created `gmt detect-variants2 Lumpy` command');

subtest "Execute"=>sub {

    $command->dump_status_messages(1);
    ok($command->execute, 'Executed `gmt detect-variants2 Lumpy` command');

    my $output_file = "$output_dir/svs.hq";
    my $expected_file = "$test_dir/1_svs.hq";

    compare_ok($output_file,$expected_file)or `diff $output_file $expected_file`;

};

subtest "test file without split reads"=>sub{
    
    my $wo_sr_bam = $test_dir .'/medlarge2.bam';    
    my $output_dir2 = Genome::Sys->create_temp_directory();

my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id => $refbuild_id,
        aligned_reads_input => $wo_sr_bam,
        params  =>"-lp,-mw:4,-tt:0.0//-pe,min_non_overlap:150,discordant_z:4,back_distance:20,weight:1,id:2//-sr,back_distance:20,weight:1,id:2,min_mapping_threshold:20",
        output_directory => $output_dir2,
        version => "0.2.6",
    );

    ok($command2, 'Created `gmt detect-variants2 Lumpy` command');

    $command2->dump_status_messages(1);
    ok($command2->execute, 'Executed `gmt detect-variants2 Lumpy` command');

    my $output_file = "$output_dir2/svs.hq";
    my $expected_file = "$test_dir/wo_sr1_svs.hq";

    compare_ok($output_file,$expected_file);
};

subtest "test matched samples"=>sub{
    
    my $wo_sr_bam = $test_dir .'/medlarge2.bam';
    my $tumor_bam = $test_dir .'/tumor.bam';
    my $output_dir2 = Genome::Sys-> create_temp_directory();

    my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id => $refbuild_id,
        aligned_reads_input => $wo_sr_bam,
        control_aligned_reads_input => $tumor_bam,
        params  =>"-lp,-mw:4,-tt:0.0//-pe,min_non_overlap:150,discordant_z:4,back_distance:20,weight:1,id:2//-sr,back_distance:20,weight:1,id:2,min_mapping_threshold:20",
        output_directory => $output_dir2,
        version => "0.2.6",
    );

    ok($command2, 'Created `gmt detect-variants2 Lumpy` command');

    $command2->dump_status_messages(1);
    ok($command2->execute, 'Executed `gmt detect-variants2 Lumpy` command');

    
    my $output_file = "$output_dir2/svs.hq";
    my $expected_file = "$test_dir/match_svs.hq";

    compare_ok($output_file,$expected_file)or `diff $output_file $expected_file`;
};

subtest "has version test"=>sub{

    my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create();
    
    is(1, Genome::Model::Tools::DetectVariants2::Lumpy->has_version("0.2.6"));
    is(0, Genome::Model::Tools::DetectVariants2::Lumpy->has_version("0.2.10"));
};

subtest "pe_arrange"=>sub{

    my $t_pe = "Test_PE_location";
    my $t_histo = "histo_loc";
    my $pe_text =$command->pe_param;
    my $mean = 123;
    my $std = 456;
   
   Sub::Install::reinstall_sub({
    into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
    as => 'pe_alignment',
    code => sub {return $t_pe;},
});

   Sub::Install::reinstall_sub({
    into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
    as => 'mean_stdv_reader',
    code => sub {return (mean=>$mean,stdv=>$std,histo=>$t_histo);},
});

    my $pe_cmd = $command->pe_cmd_arrangement($t_pe);
    is ($pe_cmd, " -pe bam_file:$t_pe,histo_file:$t_histo,mean:$mean,stdev:$std,read_length:150,$pe_text");
};

subtest "sr_arrange"=>sub{
    my $t_sr = "Test SR location";
    my $sr_text =$command->sr_param;
    my $sr_cmd = $command->sr_arrange($t_sr); 

    is($sr_cmd, " -sr bam_file:$t_sr,$sr_text");
};

done_testing();

