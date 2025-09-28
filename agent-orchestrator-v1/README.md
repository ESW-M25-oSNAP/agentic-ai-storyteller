# SCRIPTS

The two files are used for preprocessing and postprocessing images to and from InceptionV3 respectively.

After compliling, use the following:

## PREPROCESS:
Input images must be present in `/images`.

Output pairs of .jpg and .raw files are rendered in `/preprocessed`.

```c
./preprocess ./images ./preprocessed 299 bilinear
```

## POSTPROCESS:
Path to raw files of prediction must be fed as `<input.raw>`.

Labels for inference must be fed as `<label.txt>`.

Final predictions are printed on to the terminal.

```c
./postprocess <input.raw> <label.txt>
``` 
