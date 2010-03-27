//These parameters configure the viterbi architecture

typedef 36                   TBLength;  // the minimum TB length for each output
typedef 3                    NoOfDecodes;    // no of traceback per stage, TBLength dividible by this value
//typedef 3                    MetricSz;  // input metric
typedef 1                    FwdSteps;  // forward step per cycle
typedef 4                    FwdRadii;  // 2^(FwdRadii+FwdSteps*ConvInSz) <= 2^(KSz-1)
