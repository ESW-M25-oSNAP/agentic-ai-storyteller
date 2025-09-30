#include "device_client.hpp"
#include "utils.hpp"
#include <iostream>
#include <thread>
#include <cstring>

bool DeviceClient::connect() {
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << "Socket creation failed" << std::endl;
        return false;
    }

    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, orchestrator_ip.c_str(), &addr.sin_addr) <= 0) {
        std::cerr << "Invalid address" << std::endl;
        close(sock);
        sock = -1;
        return false;
    }

    if (::connect(sock, (sockaddr*)&addr, sizeof(addr)) < 0) {
        std::cerr << "Connection failed" << std::endl;
        close(sock);
        sock = -1;
        return false;
    }

    // Send registration
    json capabilities = {
        {"deviceId", agent_id},
        {"hasNpu", has_npu},
        {"capabilities", has_npu ? 
            json::array({"classification", "segmentation", "textGeneration"}) : 
            json::array({"classification", "textGeneration"})},
        {"metrics", {
            {"battery", get_battery_level()}, 
            {"cpuLoad", get_cpu_load()}
        }}
    };
    
    Message msg{"register", agent_id, "", "", capabilities};
    send_message(msg);

    // Start listener thread
    std::thread([this] { listen(); }).detach();
    
    return true;
}

void DeviceClient::send_message(const Message& msg) {
    if (sock < 0) {
        std::cerr << "Socket not connected" << std::endl;
        return;
    }

    std::string json_str = msg.to_json().dump();
    std::string to_send = json_str + "\n";
    
    ssize_t sent = send(sock, to_send.c_str(), to_send.size(), 0);
    if (sent < 0) {
        std::cerr << "Send failed" << std::endl;
    }
}

void DeviceClient::send_image(const std::vector<uint8_t>& image_bytes) {
    std::string base64 = base64_encode(image_bytes);
    Message msg{"image", agent_id, "", "", {{"image", base64}}};
    send_message(msg);
}

void DeviceClient::listen() {
    char buffer[4096];
    
    while (sock >= 0) {
        memset(buffer, 0, sizeof(buffer));
        ssize_t len = recv(sock, buffer, sizeof(buffer) - 1, 0);
        
        if (len <= 0) {
            if (len < 0) {
                std::cerr << "Receive error" << std::endl;
            } else {
                std::cerr << "Connection closed by server" << std::endl;
            }
            break;
        }
        
        buffer[len] = '\0';
        
        try {
            auto j = json::parse(buffer);
            Message msg = Message::from_json(j);
            handle_message(msg);
        } catch (const std::exception& e) {
            std::cerr << "Parse error: " << e.what() << std::endl;
        }
    }
    
    if (sock >= 0) {
        close(sock);
        sock = -1;
    }
}

void DeviceClient::handle_message(const Message& msg) {
    if (msg.type == "task") {
        try {
            // Process task (e.g., classify or segment)
            std::string base64 = msg.data["image"];
            auto image_bytes = base64_decode(base64);
            
            json result;
            if (msg.subtask == "classify") {
                result = classify_image(image_bytes);
            } else if (msg.subtask == "segment" && has_npu) {
                result = segment_image(image_bytes);
            } else {
                result = {{"error", "Unsupported task or missing NPU"}};
            }
            
            send_message(Message{"result", agent_id, msg.task_id, msg.subtask, result});
        } catch (const std::exception& e) {
            std::cerr << "Task handling error: " << e.what() << std::endl;
            json error_result = {{"error", e.what()}};
            send_message(Message{"result", agent_id, msg.task_id, msg.subtask, error_result});
        }
    }
}

int DeviceClient::get_battery_level() {
    // TODO: Implement with sysfs or Android APIs if needed
    // Example: read from /sys/class/power_supply/battery/capacity
    return 80;
}

float DeviceClient::get_cpu_load() {
    // TODO: Implement with /proc/stat parsing
    return 0.5f;
}