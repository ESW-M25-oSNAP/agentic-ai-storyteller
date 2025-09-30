#ifndef DEVICE_CLIENT_HPP
#define DEVICE_CLIENT_HPP

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string>
#include <vector>
#include <cstdint>
#include "json.hpp"
#include "message.hpp"

using json = nlohmann::json;

class DeviceClient {
private:
    int sock;
    std::string orchestrator_ip;
    int port;
    std::string agent_id;
    bool has_npu;

public:
    DeviceClient(const std::string& ip, int p, const std::string& id, bool npu)
        : orchestrator_ip(ip), port(p), agent_id(id), has_npu(npu), sock(-1) {}

    ~DeviceClient() {
        if (sock >= 0) {
            close(sock);
        }
    }

    bool connect();
    void send_message(const Message& msg);
    void send_image(const std::vector<uint8_t>& image_bytes);
    void listen();
    void handle_message(const Message& msg);

private:
    int get_battery_level();
    float get_cpu_load();
};

#endif // DEVICE_CLIENT_HPP