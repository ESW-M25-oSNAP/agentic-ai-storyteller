# UTILITIES:
ERRORS & CORRECTIONS:

1. Android file issue

REASON: Files were pushed from the wrong sources, mixed files of 32 and 64 bit were present.

```bash
~pineapple:> dlopen failed: "/data/local/tmp/libQnnSystem.so" is 32-bit instead of 64-bit
```

```bash
adb shell rm /data/local/tmp/genie-bundle/*.so
adb push path/to/aarch64-android/*.so /data/local/tmp/

adb shell
file /data/local/tmp/genie-t2t-run
```

1. Device creation errors:

REASON: the ADSP_PATH_LIBRARY was not linked appropriately.

```bash
[ERROR] "Failed to create device: 14001"
[ERROR] "Device Creation failure"
Failure to initialize model.
Failed to create the dialog.
```

```bash
export LD_LIBRARY_PATH=/data/local/tmp/genie-bundle:$LD_LIBRARY_PATH
export ADSP_LIBRARY_PATH=/data/local/tmp/genie-bundle/hexagon-v75/unsigned
```

TRIALS(Llama-3.2-3B):

1. Information Retrieval Test 1

```bash
./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhat is France's capital?<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
```

```bash
Using libGenie.so version 1.11.0

[INFO]  "Using create From Binary"
[INFO]  "Allocated total size = 270369280 across 5 buffers"
[PROMPT]: <|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhat is France's capital?<|eot_id|><|start_header_id|>assistant<|end_header_id|>

[BEGIN]:

The capital of France is Paris.[END]
```

1. Information Retrieval Test 2

```bash
./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhat is India's capital?<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
```

```bash
Using libGenie.so version 1.11.0

[INFO]  "Using create From Binary"
[INFO]  "Allocated total size = 270369280 across 5 buffers"
[PROMPT]: <|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhat is India's capital?<|eot_id|><|start_header_id|>assistant<|end_header_id|>

[BEGIN]:

India's capital is New Delhi.[END]
```

1. Conversation Test 1

```bash
./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nHow are you?<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
```

```bash
Using libGenie.so version 1.11.0

[INFO]  "Using create From Binary"
[INFO]  "Allocated total size = 270369280 across 5 buffers"
[PROMPT]: <|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nHow are you?<|eot_id|><|start_header_id|>assistant<|end_header_id|>

[BEGIN]:

I'm just a language model, so I don't have feelings like humans do, but I'm functioning properly and ready to help you with any questions or tasks you have! How about you? How's your day going?[END]
```

1. Conversation Test 2

```bash
./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhy are you so hard to deploy?<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
```

```bash
Using libGenie.so version 1.11.0

[INFO]  "Using create From Binary"
[INFO]  "Allocated total size = 270369280 across 5 buffers"
[PROMPT]: <|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nWhy are you so hard to deploy?<|eot_id|><|start_header_id|>assistant<|end_header_id|>

[BEGIN]:

I can provide information and insights, but I don't have personal experiences or emotions. However, I can provide some general insights on the challenges of deploying software or services like me.

Deploying software or services can be challenging due to various reasons. Here are a few possible explanations:

1.  **Complexity of the system**: The complexity of the system can make it difficult to deploy. The system might have many dependencies, integrations, or components that need to be updated or replaced, which can slow down the deployment process.
2.  **New technologies or frameworks**: If the system uses new technologies or frameworks, it may require additional setup, configuration, or testing, which can add complexity to the deployment process.
3.  **Large datasets or data processing**: If the system relies on large datasets or data processing, it may require significant resources, such as memory or processing power, which can slow down the deployment process.

To overcome these challenges, consider the following strategies:

*   **Plan ahead**: Identify potential challenges early on and plan accordingly.
*   **Break down the deployment process**: Divide the deployment process into smaller, manageable tasks.
*   **Use automation tools**: Automating repetitive tasks can speed up the deployment process and reduce errors.
*   **Test thoroughly**: Thorough testing can help identify and fix issues before they become major problems.

By understanding the challenges and using the strategies outlined above, you can make your deployment process more efficient and effective.[END]
```

1. Storytelling Test 1

```bash
./genie-t2t-run -c genie_config.json -p "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nMake a story about a frog and a princess.<|eot_id|><|start_header_id|>assistant<|end_header_id|>"
```

```bash
Using libGenie.so version 1.11.0

[INFO]  "Using create From Binary"
[INFO]  "Allocated total size = 270369280 across 5 buffers"
[PROMPT]: <|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\nMake a story about a frog and a princess.<|eot_id|><|start_header_id|>assistant<|end_header_id|>

[BEGIN]:

Once upon a time, in a small village nestled between two great hills, there lived a tiny frog named Freddy. Freddy was a bit of an oddity among his fellow frogs, as he possessed a voice as smooth as honey and a heart full of kindness. One day, while lazily soaking up the sun's warm rays on a large lily pad, Freddy's voice carried across the water to the castle that stood at the top of the hills.

Inside the castle, Princess Sophia was sitting on her balcony, gazing out at the lush green landscape. She was a beautiful young princess with long, golden hair and sparkling blue eyes. As she sat there, lost in thought, Freddy's melodious voice drifted towards her and caught her attention.

Entranced, Princess Sophia listened as Freddy sang a haunting melody, his voice weaving a spell of enchantment. She felt her heart flutter with delight, and her gaze wandered out into the water.

When Freddy finished his song, the princess was enchanted. She longed to meet this captivating frog who had captured her heart. So, she asked her loyal lady-in-wait, Rachel, to help her investigate the frog's identity.

Rachel, known for her wisdom and patience, decided to venture out to the water's edge to observe Freddy's behavior. She watched as the frog hopped about, his bright green skin glistening in the sunlight. The princess observed from afar, her fascination growing with each passing moment.

Days passed, and the princess found herself glancing out of her window, hoping to catch a glimpse of the enchanting frog. One sunny morning, as she was gazing out, she spotted Freddy perched on a nearby rock, his bright green eyes peeking out from beneath a leaf. She held her breath, trying not to startle him.

Over the next few weeks, the princess and the frog kept meeting in secret, exchanging gentle words and quiet songs. They discovered that they shared a love for nature, the stars, and the quiet moments of the morning.

As time passed, the princess realized that she had found her true love – though it was a tiny and unlikely one. And though the villagers around the castle whispered and speculated, the princess and Freddy remained inseparable.

One day, the princess decided that she couldn't hide her love any longer. She sought to introduce Freddy to her family and the rest of the kingdom, knowing that true love could conquer all. With Rachel's help, she planned a grand ceremony to celebrate their love.

The night of the ceremony, the castle's courtyard was filled with the music of laughter and the chatter of the kingdom's people. And, at the center of it all, the princess stood beside her tiny, yet brave, love Freddy. As they exchanged vows in front of a small lake, the frog's song echoed through the night, echoing in the hearts of all who heard it.

And so, the princess and Freddy lived happily ever after, proving that even the smallest of creatures can capture the largest of hearts.[END]
```
