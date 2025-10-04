# STRUCTURE:

These directories are present in /data/local/tmp on the edge-android device. The desired directory structure tree is as follows:
The ```.so``` files are too big to be pushed on to the github. They are in the SDK.

```c
src
├── agent-bundle
│   ├── agent.kts
│   ├── primitive_agent.sh
│   └── run_agent.sh
├── genie-bundle
│   ├── genie_config.json
│   ├── genie_profile.txt
│   ├── genie-t2t-run
│   ├── htp_backend_ext_config.json
│   ├── libcalculator.so
│   ├── libGenie.so
│   ├── libhta_hexagon_runtime_qnn.so
│   ├── libhta_hexagon_runtime_snpe.so
│   ├── libPlatformValidatorShared.so
│   ├── libQnnChrometraceProfilingReader.so
│   ├── libQnnCpuNetRunExtensions.so
│   ├── libQnnCpu.so
│   ├── libQnnDspNetRunExtensions.so
│   ├── libQnnDsp.so
│   ├── libQnnDspV66CalculatorStub.so
│   ├── libQnnDspV66Stub.so
│   ├── libQnnGenAiTransformerCpuOpPkg.so
│   ├── libQnnGenAiTransformerModel.so
│   ├── libQnnGenAiTransformer.so
│   ├── libQnnGpuNetRunExtensions.so
│   ├── libQnnGpuProfilingReader.so
│   ├── libQnnGpu.so
│   ├── libQnnHtaNetRunExtensions.so
│   ├── libQnnHta.so
│   ├── libQnnHtpNetRunExtensions.so
│   ├── libQnnHtpOptraceProfilingReader.so
│   ├── libQnnHtpPrepare.so
│   ├── libQnnHtpProfilingReader.so
│   ├── libQnnHtp.so
│   ├── libQnnHtpV68CalculatorStub.so
│   ├── libQnnHtpV68Stub.so
│   ├── libQnnHtpV69CalculatorStub.so
│   ├── libQnnHtpV69Stub.so
│   ├── libQnnHtpV73CalculatorStub.so
│   ├── libQnnHtpV73Stub.so
│   ├── libQnnHtpV75CalculatorStub.so
│   ├── libQnnHtpV75Stub.so
│   ├── libQnnHtpV79CalculatorStub.so
│   ├── libQnnHtpV79Stub.so
│   ├── libQnnIr.so
│   ├── libQnnJsonProfilingReader.so
│   ├── libQnnLpaiNetRunExtensions.so
│   ├── libQnnLpaiProfilingReader.so
│   ├── libQnnLpai.so
│   ├── libQnnLpaiStub.so
│   ├── libQnnModelDlc.so
│   ├── libQnnNetRunDirectV79Stub.so
│   ├── libQnnSaver.so
│   ├── libQnnSystem.so
│   ├── libQnnTFLiteDelegate.so
│   ├── libSnpeDspV66Stub.so
│   ├── libSnpeHta.so
│   ├── libSnpeHtpPrepare.so
│   ├── libSnpeHtpV68CalculatorStub.so
│   ├── libSnpeHtpV68Stub.so
│   ├── libSnpeHtpV69CalculatorStub.so
│   ├── libSnpeHtpV69Stub.so
│   ├── libSnpeHtpV73CalculatorStub.so
│   ├── libSnpeHtpV73Stub.so
│   ├── libSnpeHtpV75CalculatorStub.so
│   ├── libSnpeHtpV75Stub.so
│   ├── libSnpeHtpV79CalculatorStub.so
│   ├── libSnpeHtpV79Stub.so
│   ├── libSNPE.so
│   ├── llama3-3b-eaglet-htp.json
│   └── tokenizer.json
├── README.md
└── snpe-bundle
    ├── combined_labels.txt
    ├── --container
    ├── cropped
    │   ├── IMG_20250928_061818.jpg
    │   ├── IMG_20250928_061818.raw
    │   ├── IMG_20250928_070556.jpg
    │   ├── IMG_20250928_070556.raw
    │   ├── IMG_20250928_092838.jpg
    │   └── IMG_20250928_092838.raw
    ├── imagenet_slim_labels.txt
    ├── images
    │   ├── IMG_20250928_061818.jpg
    │   ├── IMG_20250928_070556.jpg
    │   └── IMG_20250928_092838.jpg
    ├── inception_v3
    │   └── output
    │       ├── Result_0
    │       │   └── InceptionV3
    │       │       └── Predictions
    │       │           └── Reshape_1:0.raw
    │       ├── Result_1
    │       │   └── InceptionV3
    │       │       └── Predictions
    │       │           └── Reshape_1:0.raw
    │       ├── Result_2
    │       │   └── InceptionV3
    │       │       └── Predictions
    │       │           └── Reshape_1:0.raw
    │       └── Result_3
    │           └── InceptionV3
    │               └── Predictions
    │                   └── Reshape_1:0.raw
    ├── inception_v3.dlc
    ├── --input_list
    ├── libcalculator.so
    ├── libGenie.so
    ├── libhta_hexagon_runtime_qnn.so
    ├── libhta_hexagon_runtime_snpe.so
    ├── libPlatformValidatorShared.so
    ├── libQnnChrometraceProfilingReader.so
    ├── libQnnCpuNetRunExtensions.so
    ├── libQnnCpu.so
    ├── libQnnDspNetRunExtensions.so
    ├── libQnnDsp.so
    ├── libQnnDspV66CalculatorStub.so
    ├── libQnnDspV66Stub.so
    ├── libQnnGenAiTransformerCpuOpPkg.so
    ├── libQnnGenAiTransformerModel.so
    ├── libQnnGenAiTransformer.so
    ├── libQnnGpuNetRunExtensions.so
    ├── libQnnGpuProfilingReader.so
    ├── libQnnGpu.so
    ├── libQnnHtaNetRunExtensions.so
    ├── libQnnHta.so
    ├── libQnnHtpNetRunExtensions.so
    ├── libQnnHtpOptraceProfilingReader.so
    ├── libQnnHtpPrepare.so
    ├── libQnnHtpProfilingReader.so
    ├── libQnnHtp.so
    ├── libQnnHtpV68CalculatorStub.so
    ├── libQnnHtpV68Stub.so
    ├── libQnnHtpV69CalculatorStub.so
    ├── libQnnHtpV69Stub.so
    ├── libQnnHtpV73CalculatorStub.so
    ├── libQnnHtpV73Stub.so
    ├── libQnnHtpV75CalculatorStub.so
    ├── libQnnHtpV75Stub.so
    ├── libQnnHtpV79CalculatorStub.so
    ├── libQnnHtpV79Stub.so
    ├── libQnnIr.so
    ├── libQnnJsonProfilingReader.so
    ├── libQnnLpaiNetRunExtensions.so
    ├── libQnnLpaiProfilingReader.so
    ├── libQnnLpai.so
    ├── libQnnLpaiStub.so
    ├── libQnnModelDlc.so
    ├── libQnnNetRunDirectV79Stub.so
    ├── libQnnSaver.so
    ├── libQnnSystem.so
    ├── libQnnTFLiteDelegate.so
    ├── libSnpeDspV66Stub.so
    ├── libSnpeHta.so
    ├── libSnpeHtpPrepare.so
    ├── libSnpeHtpV68CalculatorStub.so
    ├── libSnpeHtpV68Stub.so
    ├── libSnpeHtpV69CalculatorStub.so
    ├── libSnpeHtpV69Stub.so
    ├── libSnpeHtpV73CalculatorStub.so
    ├── libSnpeHtpV73Stub.so
    ├── libSnpeHtpV75CalculatorStub.so
    ├── libSnpeHtpV75Stub.so
    ├── libSnpeHtpV79CalculatorStub.so
    ├── libSnpeHtpV79Stub.so
    ├── libSNPE.so
    ├── output
    │   ├── Result_0
    │   │   └── InceptionV3
    │   │       └── Predictions
    │   │           └── Reshape_1:0.raw
    │   ├── Result_1
    │   │   └── InceptionV3
    │   │       └── Predictions
    │   │           └── Reshape_1:0.raw
    │   └── Result_2
    │       └── InceptionV3
    │           └── Predictions
    │               └── Reshape_1:0.raw
    ├── --output_dir
    ├── postprocess
    ├── preprocess_android
    ├── snpe-net-run
    └── target_raw_list.txt

30 directories, 156 files
```
