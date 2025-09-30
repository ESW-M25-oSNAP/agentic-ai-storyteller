#ifndef MESSAGE_HPP
#define MESSAGE_HPP

#include <string>
#include "json.hpp"

using json = nlohmann::json;

struct Message {
    std::string type;
    std::string agent_id;
    std::string task_id;
    std::string subtask;
    json data;

    Message(const std::string& t, const std::string& aid, const std::string& tid, 
            const std::string& st, const json& d)
        : type(t), agent_id(aid), task_id(tid), subtask(st), data(d) {}

    json to_json() const {
        return json{
            {"type", type},
            {"agentId", agent_id},
            {"taskId", task_id},
            {"subtask", subtask},
            {"data", data}
        };
    }

    static Message from_json(const json& j) {
        return Message(
            j.value("type", ""),
            j.value("agentId", ""),
            j.value("taskId", ""),
            j.value("subtask", ""),
            j.value("data", json{})
        );
    }
};

#endif // MESSAGE_HPP