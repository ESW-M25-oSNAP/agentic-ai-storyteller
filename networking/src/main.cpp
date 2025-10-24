#include "DeviceClient.h"
#include <iostream>

int main(int argc, char* argv[]) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << " <A|B> <orchestrator-ip> <port>" << std::endl;
        return 1;
    }

    std::string agent_id = argv[1];
    std::string ip = argv[2];
    int port = std::stoi(argv[3]);
    DeviceClient client(ip, port, agent_id);
    if (!client.connect()) {
        std::cerr << "Connection failed" << std::endl;
        return 1;
    }

    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    return 0;
}