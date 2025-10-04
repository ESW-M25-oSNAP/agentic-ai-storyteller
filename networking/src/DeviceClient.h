#ifndef DEVICE_CLIENT_H
#define DEVICE_CLIENT_H

#include <string>
#include <vector>
#include <nlohmann/json.hpp>
#include <sys/socket.h>
#include <netinet/in.h>
#include <thread>

using json = nlohmann::json;

struct Message {
    std::string type;
    std::string agent_id;
    std::string task_id;
    std::string subtask;
    json data;
};

class DeviceClient {
public:
    DeviceClient(const std::string& ip, int port, const std::string& id, bool has_npu);
    ~DeviceClient();
    bool connect();
    void listen();
    void send_message(const Message& msg);
    void send_status();

private:
    std::string orchestrator_ip;
    int port;
    std::string agent_id;
    bool has_npu;
    int sock = -1;
    bool image_model_free = true;
    bool text_model_free = true;
    float get_cpu_load();
    int get_battery_level();
    void handle_message(const Message& msg);
};

#endif