#!/data/data/com.termux/files/usr/bin/env kotlinc -script
//@file:DependsOn("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")

import java.io.File
import java.io.InputStreamReader
import java.lang.ProcessBuilder

val SNPE_DIR = "/data/local/tmp/snpe-bundle"
val GENIE_DIR = "/data/local/tmp/genie-bundle"
val LABELS = "$SNPE_DIR/imagenet_slim_labels.txt"
val POSTPROCESS_BIN = "$SNPE_DIR/postprocess"
val OUTPUT_DIR = "$SNPE_DIR/output"
val GENIE_CFG = "$GENIE_DIR/genie_config.json"

fun runCommand(dir: String, vararg command: String): String {
    val pb = ProcessBuilder(*command)
        .directory(File(dir))
        .redirectErrorStream(true)
        .apply {
            environment()["LD_LIBRARY_PATH"] = dir + ":" + (environment()["LD_LIBRARY_PATH"] ?: "")
            environment()["ADSP_LIBRARY_PATH"] = "$dir/hexagon-v75/unsigned:" + (environment()["ADSP_LIBRARY_PATH"] ?: "")
        }
    val process = pb.start()
    val output = process.inputStream.bufferedReader().readText()
    process.waitFor()
    return output
}

fun runInception() {
    println("[agent] Running InceptionV3 (SNPE)...")
    runCommand(SNPE_DIR,
        "./snpe-net-run",
        "--container", "./inception_v3.dlc",
        "--input_list", "./target_raw_list.txt",
        "--output_dir", OUTPUT_DIR,
        "--use_dsp"
    )
}

fun postprocessAll(): String {
    val outputDir = File(OUTPUT_DIR)
    var labels = ""
    outputDir.listFiles { file -> file.isDirectory && file.name.startsWith("Result_") }?.sorted()?.forEachIndexed { idx, resultDir ->
        val rawFile = File(resultDir, "InceptionV3/Predictions/Reshape_1:0.raw")
        println("[agent] Postprocessing index $idx -> $rawFile")
        val ppOut = if (!rawFile.exists()) {
            "0.0 -1 missing_file"
        } else {
            try {
                runCommand("", POSTPROCESS_BIN, rawFile.absolutePath, LABELS).trim()
            } catch (e: Exception) {
                "0.0 -1 missing_file"
            }
        }
        val parts = ppOut.split(" ", limit = 3)
        val maxVal = parts.getOrNull(0) ?: "0.0"
        val maxIdx = parts.getOrNull(1) ?: "-1"
        val label = parts.getOrNull(2) ?: "missing_file"
        println("[agent] $rawFile -> $label (idx=$maxIdx, score=$maxVal)")
        labels += "$label; "
    }
    return labels
}

fun runGenie(query: String) {
    println("[agent] Running Genie for query: $query")
    val pb = ProcessBuilder("./genie-t2t-run", "-c", GENIE_CFG,
        "-p", "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n$query<|eot_id|><|start_header_id|>assistant<|end_header_id|>")
        .directory(File(GENIE_DIR))
        .redirectErrorStream(true)
        .apply {
            environment()["LD_LIBRARY_PATH"] = GENIE_DIR
            environment()["ADSP_LIBRARY_PATH"] = "$GENIE_DIR/hexagon-v75/unsigned"
        }
    val process = pb.start()
    process.inputStream.bufferedReader().forEachLine { println(it) }
    process.waitFor()
}

fun interactiveLoop(defaultMode: Boolean = true) {
    println("[agent] Interactive mode. Type 'quit' to exit.")
    println("\nCommands: run | query <text> | dual <text> | image | both <text> | quit")
    while (true) {
        print("> ")
        val input = readLine()?.trim() ?: continue
        if (input.lowercase() == "quit") break
        val tokens = input.split(" ", limit = 2)
        val cmd = tokens[0]
        val rest = tokens.getOrNull(1) ?: ""

        when (cmd) {
            "run" -> {
                runInception()
                val labels = postprocessAll()
                val query = "Write a short story that includes these objects: $labels"
                runGenie(query)
            }
            "query" -> if (rest.isNotBlank()) runGenie(rest) else println("Usage: query <text>")
            "dual" -> {
                runInception()
                val labels = postprocessAll()
                val query = "$rest $labels"
                runGenie(query)
            }
            "image" -> {
                runInception()
                val latestDir = File(OUTPUT_DIR).listFiles { f -> f.isDirectory && f.name.startsWith("Result_") }?.sorted()?.lastOrNull()
                val rawFile = latestDir?.resolve("InceptionV3/Predictions/Reshape_1:0.raw")
                val labels = if (rawFile != null && rawFile.exists()) {
                    runCommand("", POSTPROCESS_BIN, rawFile.absolutePath, LABELS).split(" ", limit = 3).getOrElse(2) { "missing_file" }
                } else "missing_file"
                val query = "Write a short story that includes these objects: $labels"
                runGenie(query)
            }
            "both" -> if (rest.isNotBlank()) {
                runInception()
                val latestDir = File(OUTPUT_DIR).listFiles { f -> f.isDirectory && f.name.startsWith("Result_") }?.sorted()?.lastOrNull()
                val rawFile = latestDir?.resolve("InceptionV3/Predictions/Reshape_1:0.raw")
                val labels = if (rawFile != null && rawFile.exists()) {
                    runCommand("", POSTPROCESS_BIN, rawFile.absolutePath, LABELS).split(" ", limit = 3).getOrElse(2) { "" }
                } else ""
                val query = "Write a short story that includes these objects: $labels. Additionally, incorporate this input: $rest"
                runGenie(query)
            } else println("Usage: both <text>")
            else -> println("Unknown command: $cmd\nCommands: run | query <text> | dual <text> | image | both <text> | quit")
        }
    }
}

fun Loop(defaultMode: Boolean = true) {
    println("[agent] Interactive mode. Type 'quit' to exit.")
    println("\nCommands: query <text> | image | both <text> | quit")
    while (true) {
        print("> ")
        val input = readLine()?.trim() ?: continue
        if (input.lowercase() == "quit") break
        val tokens = input.split(" ", limit = 2)
        val cmd = tokens[0]
        val rest = tokens.getOrNull(1) ?: ""

        when (cmd) {
            "query" -> if (rest.isNotBlank()) runGenie(rest) else println("Usage: query <text>")
            "image" -> {
                runInception()
                val latestDir = File(OUTPUT_DIR).listFiles { f -> f.isDirectory && f.name.startsWith("Result_") }?.sorted()?.lastOrNull()
                val rawFile = latestDir?.resolve("InceptionV3/Predictions/Reshape_1:0.raw")
                val labels = if (rawFile != null && rawFile.exists()) {
                    runCommand("", POSTPROCESS_BIN, rawFile.absolutePath, LABELS).split(" ", limit = 3).getOrElse(2) { "missing_file" }
                } else "missing_file"
                val query = "Write a short story that includes these objects: $labels"
                runGenie(query)
            }
            "both" -> if (rest.isNotBlank()) {
                runInception()
                val latestDir = File(OUTPUT_DIR).listFiles { f -> f.isDirectory && f.name.startsWith("Result_") }?.sorted()?.lastOrNull()
                val rawFile = latestDir?.resolve("InceptionV3/Predictions/Reshape_1:0.raw")
                val labels = if (rawFile != null && rawFile.exists()) {
                    runCommand("", POSTPROCESS_BIN, rawFile.absolutePath, LABELS).split(" ", limit = 3).getOrElse(2) { "" }
                } else ""
                val query = "Write a short story that includes these objects: $labels. Additionally, incorporate this input: $rest"
                runGenie(query)
            } else println("Usage: both <text>")
            else -> println("Unknown command: $cmd\nCommands: query <text> | image | both <text> | quit")
        }
    }
}

fun main() {
    val args = args.toList()
    val mode = args.getOrNull(0)?.lowercase() ?: ""

    when (mode) {
        "single" -> {
            println("[agent] Mode: single batch run")
            runInception()
            val labels = postprocessAll()
            val query = "Write a short story that includes these objects: $labels"
            runGenie(query)
        }
        "query" -> {
            val query = args.drop(1).joinToString(" ")
            if (query.isNotBlank()) runGenie(query) else println("Usage: query <text>")
        }
        "loop" -> interactiveLoop()
        "dual" -> {
            val query = args.drop(1).joinToString(" ")
            runInception()
            val labels = postprocessAll()
            val dualQuery = "$query $labels"
            runGenie(dualQuery)
        }
        "" -> Loop()
        else -> println("Usage: {single | query \"text\" | loop | dual \"text\"}")
    }
}

main()

