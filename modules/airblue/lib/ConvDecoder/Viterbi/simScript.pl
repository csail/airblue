#!/usr/local/bin/perl
use POSIX; # for ceil

for($ber = 0.01; $ber <= 0.1; $ber += 0.01)
{
    for($rate = 0; $rate < 2; $rate++) # just the first two rate is useful for now, one with puncturing another without
    {
        for ($pushzeros = 0; $pushzeros < 2; $pushzeros++)
        {
            system "bsc -Xc -DBER=$ber -Xc -DRATE=$rate -Xc -DPUSHZEROS=$pushzeros -v -e mkViterbiTest -sim -bdir ../../../build/mkViterbiTest/bo -simdir ../../../build/mkViterbiTest/bo -p ../../../build/mkViterbiTest/bo:../../../build/bo:+ -o bsim_mkViterbiTest ../../../build/mkViterbiTest/bo/addError.ba ../../../build/mkViterbiTest/bo/finishTime.ba ../../../build/mkViterbiTest/bo/getConvOutBER.ba ../../../build/mkViterbiTest/bo/mkACS.ba ../../../build/mkViterbiTest/bo/mkConvEncoderInstance.ba ../../../build/mkViterbiTest/bo/mkDemapperInstance.ba ../../../build/mkViterbiTest/bo/mkDepuncturerInstance.ba ../../../build/mkViterbiTest/bo/mkIViterbiTBPath.ba ../../../build/mkViterbiTest/bo/mkMapperInstance.ba ../../../build/mkViterbiTest/bo/mkPathMetricUnit.ba ../../../build/mkViterbiTest/bo/mkPuncturerInstance.ba ../../../build/mkViterbiTest/bo/mkTraceback.ba ../../../build/mkViterbiTest/bo/mkViterbiInstance.ba ../../../build/mkViterbiTest/bo/mkViterbiTest.ba ../../../build/mkViterbiTest/bo/module_acsButterfly.ba ../../../build/mkViterbiTest/bo/module_getACSOut.ba ../../../build/mkViterbiTest/bo/module_permute.ba ../../../build/mkViterbiTest/bo/nextRate.ba ../../../build/mkViterbiTest/bo/viterbiMapCtrl.ba ../../../build/mkViterbiTest/bo/addError.c";   
            system "./bsim_mkViterbiTest > result_RATE_$rate\_BER_$ber\_PUSHZEROS_$pushzeros\_reset_favor_state_0_path_sum_9b";
        }
    }
}



