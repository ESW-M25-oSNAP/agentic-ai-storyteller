# A basic pipeline orchestrator

We have used a bash script to create a basic pipeline between:
- Inception-V3, an image classification model
- Llama-3 3B, a small language model

The prompt has both text and an image. The image classification model identifies the preprocessed image, and pipes it's output to llama-3


