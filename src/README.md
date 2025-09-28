#STRUCTURE:

These directories are present in /data/local/tmp on the edge-android device. The desired directory structure tree is as follows:

/data/local/tmp
├── agent-bundle
│   ├── primitive_agent.sh
│   └── run_agent.sh
├── genie-bundle
│   ├── genie_config.json
│   ├── genie_profile.txt
│   ├── genie-t2t-run
│   ├── hexagon-v75
│   │   └── unsigned
│   │       ├── libCalculator_skel.so
│   │       ├── libQnnHtpV75Skel.so
│   │       ├── libQnnHtpV75.so
│   │       ├── libQnnSaver.so
│   │       ├── libQnnSystem.so
│   │       └── libSnpeHtpV75Skel.so
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
    ├── data
    │   ├── chairs.jpg
    │   ├── imagenet_slim_labels.txt
    │   ├── inception_v3_2016_08_28_frozen.pb.tar.gz
    │   ├── inception_v3_model.dlc
    │   ├── notice_sign.jpg
    │   ├── plastic_cup.jpg
    │   ├── target_raw_list.txt
    │   └── tensorflow-info.py
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
    │       ├── Result_3
    │       │   └── InceptionV3
    │       │       └── Predictions
    │       │           └── Reshape_1:0.raw
    │       ├── SNPEDiag_0.log
    │       ├── SNPEDiag_1.log
    │       ├── SNPEDiag_2.log
    │       ├── SNPEDiag_3.log
    │       ├── SNPEDiag_4.log
    │       ├── SNPEDiag_5.log
    │       ├── SNPEDiag_6.log
    │       ├── SNPEDiag_7.log
    │       ├── SNPEDiag_8.log
    │       └── SNPEDiag_9.log
    ├── inception_v3.dlc
    ├── --input_list
    ├── libcalculator.so
    ├── libc++_shared.so
    ├── libGenie.so
    ├── libhta_hexagon_runtime_qnn.so
    ├── libhta_hexagon_runtime_snpe.so
    ├── libopencv_java4.so
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
    ├── libSnpeHtpV75Skel.so
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
    │   ├── Result_2
    │   │   └── InceptionV3
    │   │       └── Predictions
    │   │           └── Reshape_1:0.raw
    │   ├── SNPEDiag_0.log
    │   ├── SNPEDiag_1.log
    │   ├── SNPEDiag_2.log
    │   └── SNPEDiag_3.log
    ├── --output_dir
    ├── platformValidator
    │   └── output
    │       └── Result.csv
    ├── postprocess
    ├── preprocess_android
    ├── preprocessed
    ├── snpe
    │   └── lib
    │       └── unsigned
    │           ├── libCalculator_skel.so
    │           ├── libQnnHtpV69Skel.so
    │           ├── libQnnHtpV69.so
    │           ├── libQnnSaver.so
    │           ├── libQnnSystem.so
    │           └── libSnpeHtpV69Skel.so
    ├── snpeexample
    │   ├── aarch64-android
    │   │   ├── bin
    │   │   └── lib
    │   │       ├── libcalculator.so
    │   │       ├── libGenie.so
    │   │       ├── libhta_hexagon_runtime_qnn.so
    │   │       ├── libhta_hexagon_runtime_snpe.so
    │   │       ├── libPlatformValidatorShared.so
    │   │       ├── libQnnChrometraceProfilingReader.so
    │   │       ├── libQnnCpuNetRunExtensions.so
    │   │       ├── libQnnCpu.so
    │   │       ├── libQnnDspNetRunExtensions.so
    │   │       ├── libQnnDsp.so
    │   │       ├── libQnnDspV66CalculatorStub.so
    │   │       ├── libQnnDspV66Stub.so
    │   │       ├── libQnnGenAiTransformerCpuOpPkg.so
    │   │       ├── libQnnGenAiTransformerModel.so
    │   │       ├── libQnnGenAiTransformer.so
    │   │       ├── libQnnGpuNetRunExtensions.so
    │   │       ├── libQnnGpuProfilingReader.so
    │   │       ├── libQnnGpu.so
    │   │       ├── libQnnHtaNetRunExtensions.so
    │   │       ├── libQnnHta.so
    │   │       ├── libQnnHtpNetRunExtensions.so
    │   │       ├── libQnnHtpOptraceProfilingReader.so
    │   │       ├── libQnnHtpPrepare.so
    │   │       ├── libQnnHtpProfilingReader.so
    │   │       ├── libQnnHtp.so
    │   │       ├── libQnnHtpV68CalculatorStub.so
    │   │       ├── libQnnHtpV68Stub.so
    │   │       ├── libQnnHtpV69CalculatorStub.so
    │   │       ├── libQnnHtpV69Stub.so
    │   │       ├── libQnnHtpV73CalculatorStub.so
    │   │       ├── libQnnHtpV73Stub.so
    │   │       ├── libQnnHtpV75CalculatorStub.so
    │   │       ├── libQnnHtpV75Stub.so
    │   │       ├── libQnnHtpV79CalculatorStub.so
    │   │       ├── libQnnHtpV79Stub.so
    │   │       ├── libQnnIr.so
    │   │       ├── libQnnJsonProfilingReader.so
    │   │       ├── libQnnLpaiNetRunExtensions.so
    │   │       ├── libQnnLpaiProfilingReader.so
    │   │       ├── libQnnLpai.so
    │   │       ├── libQnnLpaiStub.so
    │   │       ├── libQnnModelDlc.so
    │   │       ├── libQnnNetRunDirectV79Stub.so
    │   │       ├── libQnnSaver.so
    │   │       ├── libQnnSystem.so
    │   │       ├── libQnnTFLiteDelegate.so
    │   │       ├── libSnpeDspV66Stub.so
    │   │       ├── libSnpeHta.so
    │   │       ├── libSnpeHtpPrepare.so
    │   │       ├── libSnpeHtpV68CalculatorStub.so
    │   │       ├── libSnpeHtpV68Stub.so
    │   │       ├── libSnpeHtpV69CalculatorStub.so
    │   │       ├── libSnpeHtpV69Stub.so
    │   │       ├── libSnpeHtpV73CalculatorStub.so
    │   │       ├── libSnpeHtpV73Stub.so
    │   │       ├── libSnpeHtpV75CalculatorStub.so
    │   │       ├── libSnpeHtpV75Stub.so
    │   │       ├── libSnpeHtpV79CalculatorStub.so
    │   │       ├── libSnpeHtpV79Stub.so
    │   │       └── libSNPE.so
    │   └── dsp
    │       └── lib
    │           ├── libCalculator_skel.so
    │           ├── libQnnHtpV73QemuDriver.so
    │           ├── libQnnHtpV73Skel.so
    │           ├── libQnnHtpV73.so
    │           ├── libQnnSaver.so
    │           ├── libQnnSystem.so
    │           └── libSnpeHtpV73Skel.so
    ├── snpe-net-run
    ├── target_raw_list.txt
    └── word_rnn
        ├── input_list.txt
        ├── input.raw
        ├── word_rnn_adb.sh
        └── word_rnn.dlc

46 directories, 264 files
