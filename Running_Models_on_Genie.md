- Download the necessary files pertaining to the model with the brief outline as below
  
```
/model-bundle
  ├── model.bin
  ├── genie_config.json
  └── tokenizer.json
```

- Create a new folder under /data/local/tmp or use the existing genie-bundle folder.
- run using the appropriate engine as: genie-t2t-run (for example)

  ```
  adb shell
  cd /data/local/tmp/genie-bundle/
  export LD_LIBRARY_PATH=$PWD
  export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned
  ./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhat is France's capital?<|eot_id|><|start_header_id|>assistant<|end_header_id|>"```

