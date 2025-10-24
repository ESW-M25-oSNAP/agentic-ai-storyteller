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
    DeviceClient(const std::string& ip, int port, const std::string& id);
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
    std::string current_image_filename;
    float get_cpu_load();
    int get_battery_level();
    json get_ram_usage();
    json get_storage_info();
    void handle_message(const Message& msg);
    void handle_bid_request(const Message& msg);
    void handle_task(const Message& msg);
    void handle_image_classification_task(const Message& msg);
    std::string decode_base64(const std::string& encoded);
    std::string run_inception_v3(const std::string& image_path);
    bool move_image_to_snpe_bundle(const std::string& image_path);
    std::string get_image_name(const std::string& image_path);
    bool preprocess_image(const std::string& image_name);
    bool run_snpe_inference();
    std::string get_classification_result();
};

#endif