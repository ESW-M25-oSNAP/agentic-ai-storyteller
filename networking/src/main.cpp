#include "device_client.hpp"
#include "utils.hpp"
#include <iostream>
#include <thread>
#include <chrono>
#include <string>

int main(int argc, char* argv[]) {
    std::string ip = "192.168.1.100";  // Orchestrator IP
    int port = 8080;
    std::string agent_id = (argc > 1 && std::string(argv[1]) == "A") ? "A" : "B";
    bool has_npu = (agent_id == "A");

    std::cout << "Starting device client: " << agent_id << std::endl;
    std::cout << "NPU available: " << (has_npu ? "Yes" : "No") << std::endl;

    DeviceClient client(ip, port, agent_id, has_npu);
    
    if (!client.connect()) {
        std::cerr << "Connection failed" << std::endl;
        return 1;
    }

    std::cout << "Connected to orchestrator at " << ip << ":" << port << std::endl;

    // Example: Send image (replace with your capture logic)
    std::vector<uint8_t> image_bytes = load_image();
    client.send_image(image_bytes);

    // Keep running
    std::cout << "Client running. Press Ctrl+C to exit." << std::endl;
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    return 0;
}