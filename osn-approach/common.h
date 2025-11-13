#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>

// Constants
#define MAX_USERNAME 64
#define MAX_BUFFER 8192
#define MAX_CLIENTS 100

// Error Codes
#define SUCCESS 200
#define ERR_SS_UNAVAILABLE 503
#define ERR_INVALID_OPERATION 405

// Ports
#define NM_CLIENT_PORT 8081

// Message Types
typedef enum {
    MSG_REG_CLIENT,       // Client Registration
    MSG_ACK,              // Acknowledgment
    MSG_SLM_PROMPT,       // Client requests SLM execution
    MSG_SLM_BID_REQUEST,  // NM asks for bids
    MSG_SLM_BID_RESPONSE, // Client responds with bid
    MSG_SLM_EXECUTE,      // Client executes SLM prompt
    MSG_SLM_RESULT        // Result of SLM execution
} MessageType;

// SLM Bid structure
typedef struct {
    char username[MAX_USERNAME];
    int sock;
    int has_npu;
    int npu_free;
    float compute_score;    // x
    float memory_score;     // y
    float latency_score;    // z
    float power_score;      // w
    float total_bid;
    char ip[INET_ADDRSTRLEN];
    int port;
} SLMBid;

// Client Info
typedef struct {
    char username[MAX_USERNAME];
    char ip[INET_ADDRSTRLEN];
    int sock;
    time_t connected;
    int has_npu;
    int npu_free;
} ClientInfo;

// Message Structure
typedef struct {
    MessageType type;
    int status;
    char sender[MAX_USERNAME];
    char data[MAX_BUFFER];
    
    // SLM fields
    int has_npu;
    int npu_free;
    float bid_x;
    float bid_y;
    float bid_z;
    float bid_w;
    float bid_total;
    char target_ip[INET_ADDRSTRLEN];
    int target_port;
} Message;

// Function declarations
void init_message(Message *msg);
int send_message(int sock, Message *msg);
int recv_message(int sock, Message *msg);
void serialize_message(Message *msg, char *buffer);
void deserialize_message(char *buffer, Message *msg);
char* get_timestamp();
void trim_whitespace(char *str);

#endif // COMMON_H  