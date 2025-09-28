# INSTRUCTIONS TO RUN:

## 1. Llama-3.2-3B-Instruct:

***LOCATION:*** `src/genie-bundle/`

***COMMAND:***

```c
export LD_LIBRARY_PATH=$PWD
export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned/
./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWrite a short story about the triviality of life.<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
```

***OUTPUT:*** CLI

## 2. InceptionV3

***LOCATION:*** `src/snpe-bundle/`

***COMMAND:*** 

```c
export LD_LIBRARY_PATH=$PWD
export ADSP_LIBRARY_PATH=/data/local/tmp/genie-bundle/hexagon-v75/unsigned/
./snpe-net-run --container inception_v3.dlc --input_list target_raw_list.txt --output_dir output
```

***OUTPUT:*** output/

### POSTPROCESSING:
***FILE:*** postprocess

***COMMAND:***

```c
./postprocess output/Result_x/InceptionV3/Predictions/Reshape_1:0.raw imagenet_slim_labels.txt
```

The prediction appears on the terminal as: <Prediction Probability> <Class index> <Class label>

## 3. Agent (PRIMITIVE)

***LOCATION:*** `src/agent-bundle`

***COMMAND:***

```c
chmod +x primitive_agent.sh
./primitive_agent.sh
```

### OPTIONS:
1. `query <text>` : Llama-3.2-3B-Instruct is invoked to reply to the query.
2. `image <num>` : <num> refers to the number of images last taken by the camera to run an inference on using InceptionV3, Llama-3.2-3B-Instruct is invoked to make a story 
                 from the predictions of the previous model.
3. `both <num>:<text>` : A combination of (1) and (2).


