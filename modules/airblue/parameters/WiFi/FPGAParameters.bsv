// Avalon bus params
typedef 16 AvalonAddressWidth;
typedef 32 AvalonDataWidth;

//Precision for A/D - D/A
typedef 1 ADCIPart;
typedef 9 ADCFPart;
typedef 1 DACIPart;
typedef 9 DACFPart;

// GCT params
// rx/tx switch == 20 20MHz cycles 
// need this long after the delay cycles count

// May be able to cut this down some.
typedef 32 TXtoRXDelayCycles; // wait 32 cycles to send data out, shut off TX
typedef 40 TXtoRXGainRouteDelayCycles; // at 48 cycles we switch to driving gain out DAC, need to wait at least 20
typedef 56 TXtoRXGHoldDelayCycles; // wait 64 cycles to release GHold on a RX TX switch.  
                               // At this point, we should be correctly driving 

// going RX -> TX we drop ghold immediately

typedef 8  RXtoTXGainRouteDelayCycles; // minimum of 20 cycles 
typedef 20 RXtoTXDelayCycles; // Need some time to assert GHold before turning not driving BB Gain

// Memory map for packet gen mac - some of these conflict with the bare phy assignments.  this is okay since
// both are not used simultaneously.
typedef 1024 TargetMACAddrOffset;

// Memory map for mac - some of these conflict with the bare phy assignments.  this is okay since
// both are not used simultaneously.
typedef 0    MACAddrOffset;
typedef 1024 MACTxFrameOffset; //0x400
typedef 2048 MACTxDataOffset; //0x800
typedef 3072 MACRxDataOffset; //0xc00
typedef 4096 MACRxFrameOffset;//0x1000
typedef 5120 MACTxStatusOffset;//0x1400

// Memory map for bare PHY - to calculate software addr, multiply by 4
// At somepoint, we should reduce these sizes slightly.
typedef 0    ReceiverOutRXVectorOffset;
typedef 1024 ReceiverOutDataOffset;
typedef 2048 ReceiverInOffset;
typedef 3072 TransmitterOutOffset;
typedef 4096 TransmitterTXStartOffset;
typedef 5120 TransmitterTXDataOffset;
typedef 6144 TransmitterTXEndOffset;
typedef 7168 TxCtrlStateOffset;
typedef 7184 AddrTX_PE;
typedef 7185 AddrTXVectorsReceived;
typedef 7186 AddrTXVectorsProcessed;
typedef 7200 AddrRX_PE;
typedef 7216 AddrDCCCalibration;
typedef 7232 AddrRXRFG1;
typedef 7233 AddrGCTPipelineState;
typedef 7248 AddrRXRFG2;
typedef 7264 AddrPA_EN;
typedef 7280 AddrADCDCS;
typedef 7296 AddrADCDFS;
typedef 7312 AddrADCMuxSel;
typedef 7328 AddrADCRefSel;
typedef 7330 AddrADCDropCounter;
typedef 7344 AddrDACGain;
typedef 7360 AddrDACMode;
typedef 7376 AddrDACModeSelect;
typedef 7392 AddrADCSampleCountLow;
typedef 7408 AddrADCSampleCountHigh;
typedef 7409 AddrADCIPartAvg;
typedef 7410 AddrADCRPartAvg;
typedef 7411 AddrADCIPartAvgPower;
typedef 7412 AddrADCRPartAvgPower;
typedef 7413 AddrADCSampleMin;
typedef 7414 AddrADCSampleAvg; 
typedef 7415 AddrRXGain;
typedef 7416 AddrRXGainPowerThresholdLow;
typedef 7417 AddrRXGainPowerThresholdHigh;
typedef 7418 AddrRXScaleFactor;
typedef 7419 AddrRXGainMin;
typedef 7420 AddrRXGainMax;
typedef 7421 AddrDirectGainControl;
typedef 7422 AddrDirectGain;
typedef 7423 AddrAGCState;
typedef 7424 AddrRXState;
typedef 7425 AddrSynchronizerState;
typedef 7426 AddrSynchronizerPower;
typedef 7427 AddrSynchronizerTimeOut;
typedef 7428 AddrSynchronizerGainStart;
typedef 7429 AddrSynchronizerGainHoldStart;
typedef 7430 AddrSynchronizerLongSync;
typedef 7431 AddrSuppressedLongSyncs;
typedef 7432 AddrAcceptedLongSyncs;
typedef 7433 AddrRXControlAbort;
typedef 7434 AddrAGCSweepEntries;
typedef 7435 AddrTXScaleFactor;
typedef 7436 AddrSweepTimeoutStart;
typedef 7440 AddrPowerPA;
typedef 7500 AddrCyclesCSMAIdle; // 64 bits (takes 2 addr);
typedef 7502 AddrCyclesCSMABusy; // 64 bits (takes 2 addr);
typedef 7504 AddrTXtoRXGainRouteDelayCycles;
typedef 7505 AddrRXtoTXGainRouteDelayCycles;
typedef 7506 AddrTXtoRXDelayCycles;
typedef 7507 AddrRXtoTXDelayCycles;
typedef 7508 AddrTXtoRXGHoldDelayCycles;
typedef 7600 AddrEnablePacketCheck;
typedef 7601 AddrPacketsRX;
typedef 7602 AddrPacketsRXCorrect;
typedef 7603 AddrGetBytesRXCorrect;
typedef 7604 AddrBER;
typedef 7605 AddrGetBytesRX;
typedef 7606 AddrMACSHIMAbort0;
typedef 7607 AddrMACSHIMAbort1;
typedef 7608 AddrMACSHIMCycle;
typedef 7700 AddrEnablePacketGen;
typedef 7701 AddrPacketsTX;
typedef 7702 AddrMinPacketLength;
typedef 7703 AddrMaxPacketLength;
typedef 7704 AddrCycleCountTX;
typedef 7705 AddrPacketDelay;
typedef 7706 AddrRate;
typedef 7707 AddrPacketLengthMask;
typedef 7708 AddrPacketsAcked;
typedef 7709 AddrPhyPacketsRX;
typedef 7800 AddrMACAckTmr;
typedef 7801 AddrMACIfsTmr;
typedef 7802 AddrMACBkfTmr;
typedef 7803 AddrMACBkfSlots;
typedef 7804 AddrMACAbort;
typedef 7805 AddrMACSIFS;
typedef 7806 AddrMACOnlyTXSecondary;
typedef 8192 RxCtrlStateOffset;
typedef 9216 GCTOffset;
typedef 9232 AddrADCStreamFifoOffset;
typedef 9248 AddrAGCStreamFifoOffset;
typedef 9264 AddrADCTriggeredStreamFifoOffset;
typedef 9280 AddrCoarCorrPowStreamFifoOffset;
typedef 9296 AddrCoarPowSqStreamFifoOffset;
