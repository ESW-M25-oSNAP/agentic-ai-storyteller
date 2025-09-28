import tensorflow as tf

model_filename = 'inception_v3_2016_08_28_frozen.pb'

with tf.io.gfile.GFile(model_filename, 'rb') as f:
    graph_def = tf.compat.v1.GraphDef()
    graph_def.ParseFromString(f.read())

with tf.Graph().as_default() as graph:
    tf.import_graph_def(graph_def, name='')

    # Print all placeholder/input nodes:
    print("Input nodes (Placeholders):")
    for op in graph.get_operations():
        if op.type == "Placeholder":
            print(op.name, op.outputs[0].shape)

    # Optionally print output nodes (typical types are Softmax, Reshape, etc.)
    print("\nPossible output nodes:")
    for op in graph.get_operations():
        if op.type in ["Softmax", "Reshape", "Identity"]:
            print(op.name, op.type, op.outputs[0].shape)

