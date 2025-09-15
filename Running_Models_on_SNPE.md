- Download the necessary files pertaining to the model.
- Push the folder into the target device as:
  ```
  adb push * /data/local/tmp/<model>
  ```

- Copy the folder named hexagon-v75 from the snpe-bundle in the target device folder.
  ```
  adb pull /data/local/tmp/snpe-bundle/hexagon-v75 ~/Downloads
  adb push ~/Downloads/hexagon-v75 /data/local/tmp/<model>/
  ```
- Copy the snpe-net-run executable from the snpe-bundle to your model folder.
  ```
  cp /data/local/tmp/snpe-bundle/snpe-net-run /data/local/tmp/<model>/
  ```

- Run the executable similar to the following example command:
  ```
  export LD_LIBRARY_PATH=$PWD
  export ADSP_LIBRARY_PATH=$PWD/hexagon-v75/unsigned

  ./snpe-net-run --container mobilenet_v2-mobilenet-v2-w8a16.dlc --input_list images.txt --output_dir output --use_dsp
  ```
