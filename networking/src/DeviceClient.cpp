#include "DeviceClient.h"
#include <iostream>
#include <unistd.h>
#include <arpa/inet.h>
#include <android/log.h>
#include <fstream>
#include <numeric>
#include <chrono>

#define LOG_TAG "DeviceClient"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

DeviceClient::DeviceClient(const std::string& ip, int port, const std::string& id, bool has_npu)
    : orchestrator_ip(ip), port(port), agent_id(id), has_npu(has_npu) {
    std::thread([this] { send_status(); }).detach();  // Periodic status
}

DeviceClient::~DeviceClient() {
    if (sock >= 0) close(sock);
}

bool DeviceClient::connect() {
    int retries = 5;
    while (retries > 0) {
        sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            LOGE("Socket creation failed");
            return false;
        }

        sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, orchestrator_ip.c_str(), &addr.sin_addr);

        if (::connect(sock, (sockaddr*)&addr, sizeof(addr)) == 0) {
            LOGI("Connected to orchestrator");
            // Send registration
            json capabilities = {
                {"deviceId", agent_id},
                {"hasNpu", has_npu},
                {"capabilities", has_npu ? json::array({"classify", "segment", "generate_story"}) : json::array({"classify", "generate_story"})},
                {"metrics", {{"battery", get_battery_level()}, {"cpu_load", get_cpu_load()}, {"image_model_free", image_model_free}, {"text_model_free", text_model_free}}}
            };
            send_message(Message{"register", agent_id, "", "", capabilities});
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

void DeviceClient::listen() {
    char buffer[4096];
    while (true) {
        ssize_t len = recv(sock, buffer, sizeof(buffer) - 1, 0);
        if (len <= 0) {
            LOGE("Connection lost, reconnecting...");
            close(sock);
            if (!connect()) break;
            continue;
        }
        buffer[len] = '\0';
        try {
            json msg = json::parse(buffer);
            handle_message(Message{msg["type"], msg["agent_id"], msg["task_id"], msg["subtask"], msg["data"]});
        } catch (const std::exception& e) {
            LOGE("Parse error: %s", e.what());
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
            {"image_model_free", image_model_free},
            {"text_model_free", text_model_free}
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

void DeviceClient::handle_message(const Message& msg) {
    if (msg.type == "task") {
        // Placeholder: Handle classify, segment, generate_story
        json result = {{"status", "completed"}};
        send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
        send_status();
    }
}