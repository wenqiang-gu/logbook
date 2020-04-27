### Hierarchy of the Data Prep configuration

#### protoDUNE-SP fhicl chain (1 includes 2, 2 includes 3, ...)
1) Top level: `protoDUNE_reco_data_Dec2018.fcl`
```json
caldata: @local::producer_adcprep_byapa
```

2) `services_dune.fcl`
```json
protodune_data_reco_services.RawDigitPrepService.AdcChannelToolNames: @local::protodune_dataprep_tools_wirecell
```

3.1) `dataprep_dune.fcl`
```json
producer_adcprep_byapa: {
  module_type: "DataPrepByApaModule"
  LogLevel:                     1
  DecoderTool:     "pdsp_decoder"       # Tool that reads digits.
  OutputTimeStampName: "dataprep"       # Non-blank writes digit RDTimeStamps
  OutputDigitName:             ""       # Non-blank writes digits
  OutputWireName:      "dataprep"       # Non-blank writes wires (processed digits)
  ChannelGroups:         ["apas"]
  BeamEventLabel:              ""
  KeepChannels:                []       # Channels to keep (all if empty).
  SkipChannels:                []       # Channels to skip.
  SkipEmptyChannels:         true       # If true, empty channels are not processed and do not produce wires
  DeltaTickCount:           0.005       # If true, empty channels are not processed and do not produce wires
  ApaChannelCounts:        [2560]       # # of channels in each APA. Last value used for later values.
  OnlineChannelMapTool: pd_onlineChannelMapByFemb
}
```

3.2) `protodune_dataprep_services.fcl`

```json
# Charge calibration, noise removal.
protodune_dataprep_tools_calib_noiserem: [
  "digitReader",                # Read RawDigit
  "pdsp_sticky_codes_ped",      # Flag sticky codes
  "pd_adcPedestalFit",          # Find pedestal
  "adcSampleCalibration",       # Subtract pedestal and apply charge calibration
  "pdsp_adcMitigate",           # Mitigate sticky codes
  "pdsp_timingMitigate",        # Mitigate FEMB302 timing
  "adcCorrectUndershootKe",     # correct undershoot
  "pdsp_noiseRemovalKe"         # Remove high frequency noise and coherent noise
]

# Drop ROIs, scale back to ADC and zero bad/noisy channels for wirecell processing.
protodune_dataprep_tools_wirecell: [
  @sequence::protodune_dataprep_tools_calib_noiserem,
  "adcKeepAllSignalFinder",     # Keep all signal (no ROIs)
  "adcScaleKeToAdc",            # Scale samples to nominal ADC counts
  "pdsp_RemoveBadChannels"      # Set bad channels to 0 ADC
]
```


#### ICEBERG
1) Top level: `iceberg_decode_reco.fcl`
```json
services.RawDigitPrepService.AdcChannelToolNames: [
         "digitReader",
         "pd_adcPedestalFit",
         "adcSampleCalibration",
         "pdsp_sticky_codes_ped",
         "pdsp_adcMitigate",
         "pdsp_timingMitigate",
         "adcCorrectUndershootKe",
         "pdsp_noiseRemovalKe",
         "adcKeepAllSignalFinder",
         "adcScaleKeToAdc",
         "pdsp_RemoveBadChannels",
         "adcVintageDeconvoluter" ]
```
Compare to pDSP, the last tool `adcVintageDeconvoluter` needs to be turned off for integrating wirecell signal processing.

One can compare consistency with pDSP via `fhicl-dump iceberg_decode_reco.fcl`, and get the below.
```json
      caldata: {
         ApaChannelCounts: [
            2560
         ]
         BeamEventLabel: ""
         ChannelGroups: [
            "apas"
         ]
         DecoderTool: "IcebergDecoder"
         DeltaTickCount: 5e-3
         DigitLabel: "tpcrawdecoder:daq"
         KeepChannels: []
         LogLevel: 1
         OnlineChannelMapTool: "pd_onlineChannelMapByFemb"
         OutputDigitName: ""
         OutputTimeStampName: "dataprep"
         OutputWireName: "dataprep"
         SkipChannels: []
         SkipEmptyChannels: true
         module_type: "DataPrepByApaModule"
      }
```