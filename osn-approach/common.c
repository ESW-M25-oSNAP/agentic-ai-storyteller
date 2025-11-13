#include "common.h"
#include <sys/time.h>

void init_message(Message *msg) {
    memset(msg, 0, sizeof(Message));
    msg->status = SUCCESS;
    msg->type = MSG_ACK;
}

void serialize_message(Message *msg, char *buffer) {
    sprintf(buffer, "%d|%d|%s|%d|%d|%f|%f|%f|%f|%f|%s|%d|%s",
            msg->type,           // 0
            msg->status,         // 1
            msg->sender,         // 2
            msg->has_npu,        // 3
            msg->npu_free,       // 4
            msg->bid_x,          // 5
            msg->bid_y,          // 6
            msg->bid_z,          // 7
            msg->bid_w,          // 8
            msg->bid_total,      // 9
            msg->target_ip,      // 10
            msg->target_port,    // 11
            msg->data);          // 12 (LAST)
}

void deserialize_message(char *buffer, Message *msg) {
    init_message(msg);
    char *p = buffer;
    int field = 0;

    while (field < 13 && p) {
        char *sep;
        size_t len;
        
        if (field == 12) {  // Last field is data
            sep = NULL;
            len = strlen(p);
        } else {
            sep = strchr(p, '|');
            len = sep ? (size_t)(sep - p) : strlen(p);
        }

        char token_buf[MAX_BUFFER];
        if (len > sizeof(token_buf) - 1) len = sizeof(token_buf) - 1;
        memcpy(token_buf, p, len);
        token_buf[len] = '\0';

        if (len > 0) {
            switch (field) {
                case 0: msg->type = atoi(token_buf); break;
                case 1: msg->status = atoi(token_buf); break;
                case 2: 
                    strncpy(msg->sender, token_buf, MAX_USERNAME-1); 
                    msg->sender[MAX_USERNAME-1] = '\0'; 
                    break;
                case 3: msg->has_npu = atoi(token_buf); break;
                case 4: msg->npu_free = atoi(token_buf); break;
                case 5: msg->bid_x = atof(token_buf); break;
                case 6: msg->bid_y = atof(token_buf); break;
                case 7: msg->bid_z = atof(token_buf); break;
                case 8: msg->bid_w = atof(token_buf); break;
                case 9: msg->bid_total = atof(token_buf); break;
                case 10:
                    strncpy(msg->target_ip, token_buf, INET_ADDRSTRLEN-1); 
                    msg->target_ip[INET_ADDRSTRLEN-1] = '\0'; 
                    break;
                case 11: msg->target_port = atoi(token_buf); break;
                case 12: 
                    strncpy(msg->data, token_buf, MAX_BUFFER-1); 
                    msg->data[MAX_BUFFER-1] = '\0'; 
                    break;
            }
        }

        field++;
        if (!sep) break;
        p = sep + 1;
    }
}

int send_message(int sock, Message *msg) {
    char buffer[MAX_BUFFER * 2];
    serialize_message(msg, buffer);
    
    int len = strlen(buffer);
    int total_sent = 0;
    
    int sent = send(sock, &len, sizeof(int), MSG_NOSIGNAL);
    if (sent < 0) {
        return -1;
    }
    
    while (total_sent < len) {
        int s = send(sock, buffer + total_sent, len - total_sent, MSG_NOSIGNAL);
        if (s < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        total_sent += s;
    }
    
    return 0;
}

int recv_message(int sock, Message *msg) {
    int len;
    
    int received = recv(sock, &len, sizeof(int), MSG_WAITALL);
    if (received <= 0) {
        return -1;
    }
    
    if (len >= MAX_BUFFER * 2 || len <= 0) {
        return -1;
    }
    
    char buffer[MAX_BUFFER * 2];
    int total_received = 0;
    
    while (total_received < len) {
        received = recv(sock, buffer + total_received, len - total_received, 0);
        if (received <= 0) {
            return -1;
        }
        total_received += received;
    }
    
    buffer[len] = '\0';
    deserialize_message(buffer, msg);
    
    return 0;
}

char* get_timestamp() {
    static char timestamp[64];
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    return timestamp;
}

void trim_whitespace(char *str) {
    char *end;
    
    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') {
        str++;
    }
    
    if (*str == 0) return;
    
    end = str + strlen(str) - 1;
    while (end > str && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) {
        end--;
    }
    
    *(end + 1) = '\0';
}