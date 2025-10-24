
#include "DeviceClient.h"
#include <iostream>
#include <unistd.h>
#include <arpa/inet.h>
#include <android/log.h>
#include <fstream>
#include <numeric>
#include <chrono>
#include <sstream>
#include <cstring>
#include <sys/statvfs.h>
#include <dirent.h>
#include <sys/stat.h>

#define LOG_TAG "DeviceClient"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Constructor implementation
DeviceClient::DeviceClient(const std::string& ip, int port, const std::string& id)
    : orchestrator_ip(ip), port(port), agent_id(id), has_npu(true), sock(-1) {
    // Only initialize members here. Do not connect or start threads in constructor.
}
// Destructor implementation
DeviceClient::~DeviceClient() {
    if (sock != -1) {
        close(sock);
    }
}

// Connect to orchestrator and register
bool DeviceClient::connect() {
    int retries = 5;
    while (retries > 0) {
        sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            LOGE("Failed to create socket");
            return false;
        }
        sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, orchestrator_ip.c_str(), &addr.sin_addr);
        if (::connect(sock, (sockaddr*)&addr, sizeof(addr)) == 0) {
            LOGI("Connected to orchestrator");
            // Send registration with comprehensive metrics
            json metrics = {
                {"battery", get_battery_level()},
                {"cpu_load", get_cpu_load()},
                {"ram", get_ram_usage()},
                {"storage", get_storage_info()}
            };
            json capabilities = {
                {"deviceId", agent_id},
                {"hasNpu", has_npu},
                {"capabilities", has_npu ? json::array({"classify", "segment", "generate_story"}) : json::array({"classify", "generate_story"})},
                {"metrics", metrics}
            };
            send_message(Message{"register", agent_id, "", "", capabilities});
            std::thread([this] { send_status(); }).detach();
            std::thread([this] { listen(); }).detach();
            return true;
        } else {
            close(sock);
            LOGE("Connect failed, retrying in 5s...");
            std::this_thread::sleep_for(std::chrono::seconds(5));
            retries--;
        }
    }
    return false;
}

// NPU driver detection
bool has_nnapi_driver() {
    const char* dirs[] = {"/vendor/lib/hw", "/vendor/lib64/hw", "/system/lib/hw", "/system/lib64/hw"};
    for (const char* dir : dirs) {
        DIR* d = opendir(dir);
        if (!d) continue;
        struct dirent* entry;
        while ((entry = readdir(d)) != nullptr) {
            if (strstr(entry->d_name, "neuralnetworks") && strstr(entry->d_name, ".so")) {
                closedir(d);
                return true;
            }
        }
        closedir(d);
    }
    return false;
}

void DeviceClient::listen() {
    std::string message_buffer;
    
    while (true) {
        char buffer[8192];
        ssize_t len = recv(sock, buffer, sizeof(buffer) - 1, 0);
        if (len <= 0) {
            LOGE("Connection lost, reconnecting...");
            close(sock);
            if (!connect()) break;
            continue;
        }
        buffer[len] = '\0';
        message_buffer += std::string(buffer);
        
        // Look for complete JSON messages (simple approach)
        size_t start = 0;
        while (start < message_buffer.length()) {
            // Find the start of a JSON object
            size_t json_start = message_buffer.find('{', start);
            if (json_start == std::string::npos) break;
            
            // Find the matching closing brace
            int brace_count = 0;
            size_t json_end = json_start;
            bool in_string = false;
            bool escaped = false;
            
            for (size_t i = json_start; i < message_buffer.length(); i++) {
                char c = message_buffer[i];
                
                if (escaped) {
                    escaped = false;
                    continue;
                }
                
                if (c == '\\' && in_string) {
                    escaped = true;
                    continue;
                }
                
                if (c == '"') {
                    in_string = !in_string;
                    continue;
                }
                
                if (!in_string) {
                    if (c == '{') brace_count++;
                    else if (c == '}') {
                        brace_count--;
                        if (brace_count == 0) {
                            json_end = i + 1;
                            break;
                        }
                    }
                }
            }
            
            if (brace_count == 0) {
                // We have a complete JSON message
                std::string json_str = message_buffer.substr(json_start, json_end - json_start);
                try {
                    json msg = json::parse(json_str);
                    LOGI("Received message type: %s", msg["type"].get<std::string>().c_str());
                    handle_message(Message{msg["type"], msg["agent_id"], msg["task_id"], msg["subtask"], msg["data"]});
                    start = json_end;
                } catch (const std::exception& e) {
                    LOGE("Parse error: %s", e.what());
                    start = json_start + 1;
                }
            } else {
                // Incomplete message, wait for more data
                break;
            }
        }
        
        // Remove processed messages from buffer
        if (start > 0) {
            message_buffer = message_buffer.substr(start);
        }
    }
}

void DeviceClient::send_message(const Message& msg) {
    json j = {{"type", msg.type}, {"agent_id", msg.agent_id}, {"task_id", msg.task_id}, {"subtask", msg.subtask}, {"data", msg.data}};
    std::string data = j.dump();
    send(sock, data.c_str(), data.size(), 0);
}

void DeviceClient::send_status() {
    while (true) {
        json metrics = {
            {"battery", get_battery_level()},
            {"cpu_load", get_cpu_load()},
            {"ram", get_ram_usage()},
            {"storage", get_storage_info()}
        };
        send_message(Message{"status", agent_id, "", "", {{"metrics", metrics}}});
        std::this_thread::sleep_for(std::chrono::seconds(30));
    }
}

float DeviceClient::get_cpu_load() {
    auto read_cpu_stats = []() -> std::vector<long long> {
        std::ifstream file("/proc/stat");
        std::string line;
        std::getline(file, line);
        std::istringstream iss(line);
        std::string cpu;
        iss >> cpu;
        std::vector<long long> stats(10, 0);
        for (auto& s : stats) iss >> s;
        return stats;
    };

    auto stats1 = read_cpu_stats();
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    auto stats2 = read_cpu_stats();

    long long idle1 = stats1[3] + stats1[4];
    long long idle2 = stats2[3] + stats2[4];
    long long total1 = std::accumulate(stats1.begin(), stats1.end(), 0LL);
    long long total2 = std::accumulate(stats2.begin(), stats2.end(), 0LL);

    long long total_diff = total2 - total1;
    long long idle_diff = idle2 - idle1;
    return total_diff > 0 ? 1.0f - static_cast<float>(idle_diff) / total_diff : 0.0f;
}

int DeviceClient::get_battery_level() {
    std::ifstream file("/sys/class/power_supply/battery/capacity");
    int level = -1;
    if (file) file >> level;
    return level;
}

json DeviceClient::get_ram_usage() {
    std::ifstream file("/proc/meminfo");
    std::string line;
    long long mem_total = 0, mem_available = 0;
    
    while (std::getline(file, line)) {
        if (line.find("MemTotal:") == 0) {
            std::istringstream iss(line);
            std::string label;
            iss >> label >> mem_total;
        } else if (line.find("MemAvailable:") == 0) {
            std::istringstream iss(line);
            std::string label;
            iss >> label >> mem_available;
        }
        if (mem_total > 0 && mem_available > 0) break;
    }
    
    long long mem_used = mem_total - mem_available;
    float ram_usage_percent = mem_total > 0 ? (float)mem_used / mem_total * 100.0f : 0.0f;
    
    return json{
        {"total_mb", mem_total / 1024},
        {"used_mb", mem_used / 1024},
        {"available_mb", mem_available / 1024},
        {"usage_percent", ram_usage_percent}
    };
}

json DeviceClient::get_storage_info() {
    json storage_info;
    
    // Get storage info for /data partition using statfs
    struct statvfs stat;
    if (statvfs("/data", &stat) == 0) {
        unsigned long long total = stat.f_blocks * stat.f_frsize;
        unsigned long long free_space = stat.f_bfree * stat.f_frsize;
        unsigned long long used = total - free_space;
        
        storage_info["total_gb"] = total / (1024.0 * 1024.0 * 1024.0);
        storage_info["free_gb"] = free_space / (1024.0 * 1024.0 * 1024.0);
        storage_info["used_gb"] = used / (1024.0 * 1024.0 * 1024.0);
        storage_info["usage_percent"] = total > 0 ? (float)used / total * 100.0f : 0.0f;
    } else {
        LOGE("Failed to get storage info");
        storage_info["total_gb"] = 0;
        storage_info["free_gb"] = 0;
        storage_info["used_gb"] = 0;
        storage_info["usage_percent"] = 0;
    }
    
    return storage_info;
}

void DeviceClient::handle_message(const Message& msg) {
    if (msg.type == "bid_request") {
        handle_bid_request(msg);
    } else if (msg.type == "task") {
        handle_task(msg);
    }
}

void DeviceClient::handle_bid_request(const Message& msg) {
    LOGI("Received bid request for task %s", msg.task_id.c_str());
    
    // Send bid with current metrics
    json bid_data = {
        {"cpu_load", get_cpu_load()},
        {"battery", get_battery_level()},
        {"ram", get_ram_usage()},
        {"storage", get_storage_info()},
        {"has_npu", has_npu},
        {"timestamp", std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count()}
    };
    
    send_message(Message{"bid", agent_id, msg.task_id, msg.subtask, bid_data});
    LOGI("Sent bid for task %s with CPU load %.2f", msg.task_id.c_str(), get_cpu_load());
}

void DeviceClient::handle_task(const Message& msg) {
    LOGI("Received task %s, subtask: %s", msg.task_id.c_str(), msg.subtask.c_str());
    
    if (msg.subtask == "classify" && msg.data.contains("image_base64")) {
        handle_image_classification_task(msg);
    } else {
        // Placeholder for other tasks
        json result = {{"status", "completed"}};
        send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
        send_status();
    }
}

void DeviceClient::handle_image_classification_task(const Message& msg) {
    try {
        // Extract image data
        std::string image_base64 = msg.data["image_base64"];
        
        // Create a proper image filename with timestamp  
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::string image_filename = "image_" + std::to_string(time_t) + ".jpg";
        std::string output_path = "/data/local/tmp/" + image_filename;
        
        // Save directly to /data/local/tmp which we know works
        LOGI("Saving image as: %s", image_filename.c_str());
        
        // Decode base64 image
        std::string decoded_image = decode_base64(image_base64);
        LOGI("Decoded image size: %zu bytes", decoded_image.length());
        
        // Save image to specified path
        LOGI("Attempting to save image to: %s", output_path.c_str());
        std::ofstream file(output_path, std::ios::binary);
        if (file.is_open()) {
            file.write(decoded_image.c_str(), decoded_image.length());
            file.close();
            LOGI("Image saved successfully to %s, size: %zu bytes", output_path.c_str(), decoded_image.length());
            
            // Verify the file was actually written
            std::ifstream verify_file(output_path, std::ios::binary | std::ios::ate);
            if (verify_file.is_open()) {
                size_t file_size = verify_file.tellg();
                LOGI("Verified: File exists with size %zu bytes", file_size);
                verify_file.close();
            } else {
                LOGE("Verification failed: Cannot read back the saved file");
            }
            
            // Mark image model as busy
            // ...existing code...
            
            // Run Inception-V3 classification
            std::string classification_result = run_inception_v3(output_path);
            
            // Mark image model as free again
            // ...existing code...
            
            if (!classification_result.empty()) {
                // Send classification result
                json result = {
                    {"status", "classification_complete"},
                    {"output_path", output_path},
                    {"image_size", decoded_image.length()},
                    {"classification", classification_result}
                };
                send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
                LOGI("Classification completed: %s", classification_result.c_str());
            } else {
                json result = {{"status", "error"}, {"message", "Classification failed"}};
                send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
            }
        } else {
            LOGE("Failed to open file for writing: %s", output_path.c_str());
            
            // Try to get more information about why it failed
            std::string ls_cmd = "ls -la /data/local/tmp/received-images/ 2>&1";
            FILE* ls_fp = popen(ls_cmd.c_str(), "r");
            if (ls_fp) {
                char ls_output[512];
                LOGE("Directory listing:");
                while (fgets(ls_output, sizeof(ls_output), ls_fp)) {
                    LOGE("  %s", ls_output);
                }
                pclose(ls_fp);
            }
            
            // Check permissions
            std::string perm_cmd = "ls -ld /data/local/tmp/received-images 2>&1";
            FILE* perm_fp = popen(perm_cmd.c_str(), "r");
            if (perm_fp) {
                char perm_output[256];
                if (fgets(perm_output, sizeof(perm_output), perm_fp)) {
                    LOGE("Directory permissions: %s", perm_output);
                }
                pclose(perm_fp);
            }
            
            json result = {{"status", "error"}, {"message", "Failed to open file for writing"}};
            send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
        }
        
        send_status();
        
    } catch (const std::exception& e) {
        LOGE("Error handling image classification task: %s", e.what());
        json result = {{"status", "error"}, {"message", e.what()}};
        send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
    }
}

std::string DeviceClient::run_inception_v3(const std::string& image_path) {
    LOGI("Running Inception-V3 on image: %s", image_path.c_str());
    
    try {
        // Step 1: Move image to SNPE bundle directory
        if (!move_image_to_snpe_bundle(image_path)) {
            LOGE("Failed to move image to SNPE bundle");
            return "";
        }
        
        // Step 2: Preprocess image (using the stored filename)
        if (!preprocess_image(current_image_filename)) {
            LOGE("Failed to preprocess image");
            return "";
        }
        
        // Step 3: Run SNPE inference
        if (!run_snpe_inference()) {
            LOGE("SNPE inference failed");
            return "";
        }
        
        // Step 4: Post-process and get results
        std::string classification = get_classification_result();
        return classification;
        
    } catch (const std::exception& e) {
        LOGE("Exception in run_inception_v3: %s", e.what());
        return "";
    }
}

bool DeviceClient::move_image_to_snpe_bundle(const std::string& image_path) {
    LOGI("Moving image from %s to SNPE bundle", image_path.c_str());
    
    // Extract image filename from path
    std::string filename = image_path.substr(image_path.find_last_of("/") + 1);
    std::string target_path = "/data/local/tmp/snpe-bundle/images/" + filename;
    
    // Create images directory if it doesn't exist
    std::string mkdir_cmd = "mkdir -p /data/local/tmp/snpe-bundle/images";
    system(mkdir_cmd.c_str());
    
    // Copy image to SNPE bundle images directory  
    std::string copy_cmd = "cp " + image_path + " " + target_path;
    int result = system(copy_cmd.c_str());
    
    if (result == 0) {
        LOGI("Image copied to %s", target_path.c_str());
        
        // Store the filename for later use
        current_image_filename = filename;
        return true;
    } else {
        LOGE("Failed to copy image to SNPE bundle");
        return false;
    }
}

std::string DeviceClient::get_image_name(const std::string& image_path) {
    // Extract just the filename without path
    size_t last_slash = image_path.find_last_of("/");
    if (last_slash != std::string::npos) {
        return image_path.substr(last_slash + 1);
    }
    return image_path;
}

bool DeviceClient::preprocess_image(const std::string& image_name) {
    LOGI("Preprocessing image: %s", image_name.c_str());
    
    std::string snpe_bundle_dir = "/data/local/tmp/snpe-bundle";
    
    // Clear the target_raw_list.txt file first
    std::string clear_cmd = "cd " + snpe_bundle_dir + " && > target_raw_list.txt";
    system(clear_cmd.c_str());
    
    // Change to SNPE bundle directory and run preprocessing
    std::string preprocess_cmd = "cd " + snpe_bundle_dir + " && "
                               "export LD_LIBRARY_PATH=$PWD && "
                               "./preprocess_android ./images ./cropped 299 bilinear";
    
    LOGI("Running preprocess command: %s", preprocess_cmd.c_str());
    
    int result = system(preprocess_cmd.c_str());
    if (result != 0) {
        LOGE("Preprocessing failed with code: %d", result);
        return false;
    }
    
    // Add the processed image to target_raw_list.txt
    std::string raw_filename = current_image_filename;
    // Replace extension with .raw
    size_t dot_pos = raw_filename.find_last_of(".");
    if (dot_pos != std::string::npos) {
        raw_filename = raw_filename.substr(0, dot_pos) + ".raw";
    } else {
        raw_filename += ".raw";
    }
    
    std::string list_cmd = "cd " + snpe_bundle_dir + " && echo \"cropped/" + raw_filename + "\" >> target_raw_list.txt";
    system(list_cmd.c_str());
    
    LOGI("Added cropped/%s to target_raw_list.txt", raw_filename.c_str());
    
    // Verify the raw file exists
    std::string check_cmd = "ls -la " + snpe_bundle_dir + "/cropped/" + raw_filename;
    LOGI("Checking if raw file exists: %s", check_cmd.c_str());
    system(check_cmd.c_str());
    
    return true;
}

bool DeviceClient::run_snpe_inference() {
    LOGI("Running SNPE inference");
    
    std::string snpe_bundle_dir = "/data/local/tmp/snpe-bundle";
    
    // Run SNPE inference with your exact command
    std::string snpe_cmd = "cd " + snpe_bundle_dir + " && "
                          "export LD_LIBRARY_PATH=$PWD && "
                          "./snpe-net-run --container inception_v3.dlc --input_list target_raw_list.txt --output_dir output";
    
    LOGI("Running SNPE command: %s", snpe_cmd.c_str());
    
    int result = system(snpe_cmd.c_str());
    if (result == 0) {
        LOGI("SNPE inference completed successfully");
        return true;
    } else {
        LOGE("SNPE inference failed with code: %d", result);
        return false;
    }
}

std::string DeviceClient::get_classification_result() {
    LOGI("Getting classification result");
    
    std::string snpe_bundle_dir = "/data/local/tmp/snpe-bundle";
    
    // Find the Result_x directory (should be Result_3 as you mentioned)
    std::string find_result_cmd = "ls -1 " + snpe_bundle_dir + "/output/Result_*/InceptionV3/Predictions/Reshape_1:0.raw 2>/dev/null | head -1";
    
    FILE* fp = popen(find_result_cmd.c_str(), "r");
    if (fp == nullptr) {
        LOGE("Failed to find result file");
        return "";
    }
    
    char result_file_path[512];
    if (fgets(result_file_path, sizeof(result_file_path), fp) == nullptr) {
        LOGE("No result file found");
        pclose(fp);
        return "";
    }
    
    // Remove newline
    result_file_path[strcspn(result_file_path, "\n")] = 0;
    pclose(fp);
    
    LOGI("Found result file: %s", result_file_path);
    
    // Run postprocessing to get human-readable classification
    std::string postprocess_cmd = "cd " + snpe_bundle_dir + " && "
                                 "./postprocess " + std::string(result_file_path) + " imagenet_slim_labels.txt";
    
    LOGI("Running postprocess command: %s", postprocess_cmd.c_str());
    
    fp = popen(postprocess_cmd.c_str(), "r");
    if (fp == nullptr) {
        LOGE("Failed to run postprocessing");
        return "";
    }
    
    std::string result;
    char line[512];
    while (fgets(line, sizeof(line), fp) != nullptr) {
        result += line;
    }
    
    pclose(fp);
    
    // Clean up the result
    if (!result.empty()) {
        // Remove trailing newline
        while (!result.empty() && (result.back() == '\n' || result.back() == '\r')) {
            result.pop_back();
        }
        LOGI("Final classification result: %s", result.c_str());
    }
    
    return result;
}

std::string DeviceClient::decode_base64(const std::string& encoded) {
    // Simple base64 decoder implementation
    const std::string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string decoded;
    int val = 0, valb = -8;
    
    for (char c : encoded) {
        if (c == '=') break;
        auto pos = chars.find(c);
        if (pos == std::string::npos) continue;
        
        val = (val << 6) + pos;
        valb += 6;
        if (valb >= 0) {
            decoded.push_back(char((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    
    return decoded;
}