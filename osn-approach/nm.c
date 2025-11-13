#include "common.h"
#include <sys/time.h>
#include <time.h>

typedef struct {
    ClientInfo client_list[MAX_CLIENTS];
    int client_count;
    pthread_mutex_t client_mutex;
    
    int client_sock;
    volatile int running;
} NameServer;

NameServer nm;

void* handle_client_connection(void* arg);
void* client_listener(void* arg);

// Per-client bid state
typedef struct {
    int waiting_for_bid;
    Message bid_response;
    int bid_received;
    pthread_mutex_t bid_mutex;
    pthread_cond_t bid_cond;
} ClientBidState;

// Thread-safe bid collection structure
typedef struct {
    SLMBid bids[MAX_CLIENTS];
    int bid_count;
    pthread_mutex_t bid_mutex;
    int expected_bids;
    int responses_received;
} BidCollection;

typedef struct {
    int client_index;
    char prompt[MAX_BUFFER];
    BidCollection *collection;
} BidRequestArgs;

// Global array to track bid states for each client
ClientBidState client_bid_states[MAX_CLIENTS];

void init_client_bid_state(int idx) {
    client_bid_states[idx].waiting_for_bid = 0;
    client_bid_states[idx].bid_received = 0;
    pthread_mutex_init(&client_bid_states[idx].bid_mutex, NULL);
    pthread_cond_init(&client_bid_states[idx].bid_cond, NULL);
}

void destroy_client_bid_state(int idx) {
    pthread_mutex_destroy(&client_bid_states[idx].bid_mutex);
    pthread_cond_destroy(&client_bid_states[idx].bid_cond);
}

void* send_bid_request_and_wait(void* arg) {
    BidRequestArgs *args = (BidRequestArgs*)arg;
    int idx = args->client_index;
    BidCollection *collection = args->collection;
    
    pthread_mutex_lock(&nm.client_mutex);
    ClientInfo *cli = &nm.client_list[idx];
    int sock = cli->sock;
    char username[MAX_USERNAME];
    strcpy(username, cli->username);
    pthread_mutex_unlock(&nm.client_mutex);
    
    // Prepare bid request message
    Message bid_request;
    init_message(&bid_request);
    bid_request.type = MSG_SLM_BID_REQUEST;
    strcpy(bid_request.data, args->prompt);
    bid_request.has_npu = 1;
    bid_request.npu_free = 1;
    
    // CRITICAL: Lock mutex BEFORE setting flag, KEEP IT LOCKED through send and into wait
    pthread_mutex_lock(&client_bid_states[idx].bid_mutex);
    client_bid_states[idx].waiting_for_bid = 1;
    client_bid_states[idx].bid_received = 0;
    
    printf("[NM] Sending bid request to %s...\n", username);
    
    // Send while holding the lock
    if (send_message(sock, &bid_request) < 0) {
        printf("[NM] Failed to send bid request to %s\n", username);
        client_bid_states[idx].waiting_for_bid = 0;
        pthread_mutex_unlock(&client_bid_states[idx].bid_mutex);
        
        pthread_mutex_lock(&collection->bid_mutex);
        collection->responses_received++;
        pthread_mutex_unlock(&collection->bid_mutex);
        
        free(args);
        return NULL;
    }
    
    // Setup timeout (mutex still locked from above)
    struct timespec timeout;
    clock_gettime(CLOCK_REALTIME, &timeout);
    timeout.tv_sec += 3;
    
    printf("[NM] Waiting for bid response from %s...\n", username);
    
    // Wait (this will atomically release mutex and wait, then reacquire on wake)
    while (!client_bid_states[idx].bid_received && client_bid_states[idx].waiting_for_bid) {
        int result = pthread_cond_timedwait(&client_bid_states[idx].bid_cond, 
                                           &client_bid_states[idx].bid_mutex, 
                                           &timeout);
        if (result == ETIMEDOUT) {
            printf("[NM] Timeout waiting for bid from %s\n", username);
            client_bid_states[idx].waiting_for_bid = 0;
            pthread_mutex_unlock(&client_bid_states[idx].bid_mutex);
            
            pthread_mutex_lock(&collection->bid_mutex);
            collection->responses_received++;
            pthread_mutex_unlock(&collection->bid_mutex);
            
            free(args);
            return NULL;
        }
    }
    
    // Got response, extract it
    Message bid_response = client_bid_states[idx].bid_response;
    client_bid_states[idx].waiting_for_bid = 0;
    pthread_mutex_unlock(&client_bid_states[idx].bid_mutex);
    
    // Process the bid
    pthread_mutex_lock(&collection->bid_mutex);
    
    if (bid_response.type != MSG_SLM_BID_RESPONSE) {
        printf("[NM] Unexpected response type from %s: %d\n", username, bid_response.type);
    } else if (bid_response.status != SUCCESS) {
        printf("[NM] %s declined to bid (status: %d)\n", username, bid_response.status);
    } else {
        // Store the valid bid
        int bid_idx = collection->bid_count;
        strcpy(collection->bids[bid_idx].username, username);
        collection->bids[bid_idx].sock = sock;
        collection->bids[bid_idx].compute_score = bid_response.bid_x;
        collection->bids[bid_idx].memory_score = bid_response.bid_y;
        collection->bids[bid_idx].latency_score = bid_response.bid_z;
        collection->bids[bid_idx].power_score = bid_response.bid_w;
        collection->bids[bid_idx].total_bid = bid_response.bid_total;
        strcpy(collection->bids[bid_idx].ip, bid_response.target_ip);
        collection->bids[bid_idx].port = bid_response.target_port;
        
        printf("[NM] ✓ Bid #%d from %s: %.3f (x=%.2f, y=%.2f, z=%.2f, w=%.2f) at %s:%d\n",
               bid_idx + 1,
               username, bid_response.bid_total,
               bid_response.bid_x, bid_response.bid_y,
               bid_response.bid_z, bid_response.bid_w,
               bid_response.target_ip, bid_response.target_port);
        
        collection->bid_count++;
    }
    
    collection->responses_received++;
    pthread_mutex_unlock(&collection->bid_mutex);
    
    free(args);
    return NULL;
}

void handle_slm_prompt(int requesting_client_sock, Message *msg) {
    Message response;
    init_message(&response);
    
    printf("[NM] SLM prompt request from %s: %s\n", msg->sender, msg->data);
    
    // Initialize bid collection
    SLMBid bids[MAX_CLIENTS];
    int bid_count = 0;
    
    pthread_mutex_lock(&nm.client_mutex);
    
    printf("[NM] Scanning clients for execution (including requester)...\n");
    
    // Serial pass through all clients - INCLUDING the requester
    for (int i = 0; i < nm.client_count; i++) {
        ClientInfo *cli = &nm.client_list[i];
        
        // Check if this client has free NPU
        if (cli->has_npu && cli->npu_free) {
            // Found free NPU - instant winner!
            printf("[NM] 🏆 Found free NPU on %s - winner selected immediately\n", cli->username);
            
            response.status = SUCCESS;
            
            // If it's the requester, use their own listener
            if (strcmp(cli->username, msg->sender) == 0) {
                strcpy(response.target_ip, msg->target_ip);
                response.target_port = msg->target_port;
                printf("[NM] Using requester's own NPU (local execution)\n");
            } else {
                // Need to get the remote client's listener info
                pthread_mutex_lock(&client_bid_states[i].bid_mutex);
                client_bid_states[i].waiting_for_bid = 1;
                client_bid_states[i].bid_received = 0;
                
                Message bid_request;
                init_message(&bid_request);
                bid_request.type = MSG_SLM_BID_REQUEST;
                strcpy(bid_request.data, msg->data);
                bid_request.has_npu = 1;
                bid_request.npu_free = 1;
                
                printf("[NM] Requesting endpoint info from %s...\n", cli->username);
                if (send_message(cli->sock, &bid_request) >= 0) {
                    // Wait for response from client handler thread
                    struct timespec timeout;
                    clock_gettime(CLOCK_REALTIME, &timeout);
                    timeout.tv_sec += 2;
                    
                    while (!client_bid_states[i].bid_received && client_bid_states[i].waiting_for_bid) {
                        int result = pthread_cond_timedwait(&client_bid_states[i].bid_cond, 
                                                           &client_bid_states[i].bid_mutex, 
                                                           &timeout);
                        if (result == ETIMEDOUT) {
                            printf("[NM] Timeout getting endpoint from %s\n", cli->username);
                            break;
                        }
                    }
                    
                    if (client_bid_states[i].bid_received) {
                        Message bid_resp = client_bid_states[i].bid_response;
                        if (bid_resp.status == SUCCESS) {
                            strcpy(response.target_ip, bid_resp.target_ip);
                            response.target_port = bid_resp.target_port;
                            printf("[NM] Got endpoint: %s:%d\n", response.target_ip, response.target_port);
                        } else {
                            printf("[NM] Client declined, falling back\n");
                            strcpy(response.target_ip, cli->ip);
                            response.target_port = 0;
                        }
                    } else {
                        printf("[NM] No response received, falling back\n");
                        strcpy(response.target_ip, cli->ip);
                        response.target_port = 0;
                    }
                    
                    client_bid_states[i].waiting_for_bid = 0;
                    pthread_mutex_unlock(&client_bid_states[i].bid_mutex);
                } else {
                    printf("[NM] Failed to send request to %s\n", cli->username);
                    strcpy(response.target_ip, cli->ip);
                    response.target_port = 0;
                    
                    client_bid_states[i].waiting_for_bid = 0;
                    pthread_mutex_unlock(&client_bid_states[i].bid_mutex);
                }
            }
            
            pthread_mutex_unlock(&nm.client_mutex);
            printf("[NM] Sending winner info to %s\n", msg->sender);
            send_message(requesting_client_sock, &response);
            return;
        }
    }
    
    // No free NPU found - collect bids serially from all clients (including requester)
    printf("[NM] No free NPU found, collecting bids from all clients...\n");
    
    for (int i = 0; i < nm.client_count; i++) {
        ClientInfo *cli = &nm.client_list[i];
        
        printf("[NM] Requesting bid from %s...\n", cli->username);
        
        // Reset bid state
        pthread_mutex_lock(&client_bid_states[i].bid_mutex);
        client_bid_states[i].waiting_for_bid = 1;
        client_bid_states[i].bid_received = 0;
        
        // Send bid request
        Message bid_request;
        init_message(&bid_request);
        bid_request.type = MSG_SLM_BID_REQUEST;
        strcpy(bid_request.data, msg->data);
        
        if (send_message(cli->sock, &bid_request) >= 0) {
            // Setup timeout
            struct timespec timeout;
            clock_gettime(CLOCK_REALTIME, &timeout);
            timeout.tv_sec += 3;
            
            // Wait for response serially (blocking)
            while (!client_bid_states[i].bid_received && client_bid_states[i].waiting_for_bid) {
                int result = pthread_cond_timedwait(&client_bid_states[i].bid_cond, 
                                                   &client_bid_states[i].bid_mutex, 
                                                   &timeout);
                if (result == ETIMEDOUT) {
                    printf("[NM] Timeout waiting for bid from %s\n", cli->username);
                    break;
                }
            }
            
            // Process response if received
            if (client_bid_states[i].bid_received) {
                Message bid_resp = client_bid_states[i].bid_response;
                if (bid_resp.type == MSG_SLM_BID_RESPONSE && bid_resp.status == SUCCESS) {
                    bids[bid_count].sock = cli->sock;
                    strcpy(bids[bid_count].username, cli->username);
                    bids[bid_count].has_npu = cli->has_npu;
                    bids[bid_count].npu_free = cli->npu_free;
                    bids[bid_count].compute_score = bid_resp.bid_x;
                    bids[bid_count].memory_score = bid_resp.bid_y;
                    bids[bid_count].latency_score = bid_resp.bid_z;
                    bids[bid_count].power_score = bid_resp.bid_w;
                    bids[bid_count].total_bid = bid_resp.bid_total;
                    strcpy(bids[bid_count].ip, bid_resp.target_ip);
                    bids[bid_count].port = bid_resp.target_port;
                    
                    printf("[NM] ✓ Bid from %s: %.3f (x=%.2f, y=%.2f, z=%.2f, w=%.2f) at %s:%d\n",
                           cli->username, bid_resp.bid_total,
                           bid_resp.bid_x, bid_resp.bid_y, bid_resp.bid_z, bid_resp.bid_w,
                           bid_resp.target_ip, bid_resp.target_port);
                    bid_count++;
                } else {
                    printf("[NM] %s declined to bid\n", cli->username);
                }
            } else {
                printf("[NM] No response received from %s\n", cli->username);
            }
        } else {
            printf("[NM] Failed to send bid request to %s\n", cli->username);
        }
        
        client_bid_states[i].waiting_for_bid = 0;
        pthread_mutex_unlock(&client_bid_states[i].bid_mutex);
    }
    
    pthread_mutex_unlock(&nm.client_mutex);
    
    printf("[NM] Bid collection complete: received %d valid bids\n", bid_count);
    
    if (bid_count == 0) {
        printf("[NM] No valid bids received\n");
        response.status = ERR_SS_UNAVAILABLE;
        send_message(requesting_client_sock, &response);
        return;
    }
    
    // Select best bid (highest total)
    int best_idx = 0;
    for (int i = 1; i < bid_count; i++) {
        if (bids[i].total_bid > bids[best_idx].total_bid) {
            best_idx = i;
        }
    }
    
    printf("[NM] 🏆 Selected winner: %s with bid %.3f at %s:%d\n", 
           bids[best_idx].username, bids[best_idx].total_bid,
           bids[best_idx].ip, bids[best_idx].port);
    
    // Send winner info back to requester
    response.status = SUCCESS;
    strcpy(response.target_ip, bids[best_idx].ip);
    response.target_port = bids[best_idx].port;
    
    printf("[NM] Sending winner info to %s\n", msg->sender);
    if (send_message(requesting_client_sock, &response) < 0) {
        printf("[NM] ✗ Failed to send response to requester\n");
    } else {
        printf("[NM] ✓ Successfully sent winner info to requester\n");
    }
}

void* slm_prompt_handler(void* arg) {
    typedef struct {
        int sock;
        Message msg;
    } PromptArgs;
    
    PromptArgs *args = (PromptArgs *)arg;
    handle_slm_prompt(args->sock, &args->msg);
    free(args);
    return NULL;
}

void init_name_server() {
    nm.client_count = 0;
    nm.running = 1;
    
    pthread_mutex_init(&nm.client_mutex, NULL);
    
    // Initialize bid states for all possible clients
    for (int i = 0; i < MAX_CLIENTS; i++) {
        init_client_bid_state(i);
    }
    
    printf("[NM] Name Server initialized\n");
    printf("[NM] Client Port: %d\n", NM_CLIENT_PORT);
}

void* handle_client_connection(void* arg) {
    int client_sock = *((int*)arg);
    free(arg);
    
    Message msg;
    if (recv_message(client_sock, &msg) < 0 || msg.type != MSG_REG_CLIENT) {
        close(client_sock);
        return NULL;
    }
    
    pthread_mutex_lock(&nm.client_mutex);
    
    if (nm.client_count >= MAX_CLIENTS) {
        pthread_mutex_unlock(&nm.client_mutex);
        close(client_sock);
        return NULL;
    }
    
    int idx = nm.client_count;
    strcpy(nm.client_list[idx].username, msg.sender);
    strcpy(nm.client_list[idx].ip, msg.data);
    nm.client_list[idx].sock = client_sock;
    nm.client_list[idx].connected = time(NULL);
    nm.client_list[idx].has_npu = msg.has_npu;
    nm.client_list[idx].npu_free = msg.npu_free;
    nm.client_count++;
    
    pthread_mutex_unlock(&nm.client_mutex);
    
    printf("[NM] Client %s connected (NPU: %s)\n", msg.sender, msg.has_npu ? "Yes" : "No");
    
    Message response;
    init_message(&response);
    response.status = SUCCESS;
    send_message(client_sock, &response);
    
    // Handle client requests - THIS THREAD HANDLES ALL MESSAGES FROM THIS CLIENT
    while (nm.running) {
        if (recv_message(client_sock, &msg) < 0) {
            break;
        }
        
        // Check if this is a bid response
        pthread_mutex_lock(&client_bid_states[idx].bid_mutex);
        if (client_bid_states[idx].waiting_for_bid && msg.type == MSG_SLM_BID_RESPONSE) {
            // Store the bid response and signal the waiting thread
            client_bid_states[idx].bid_response = msg;
            client_bid_states[idx].bid_received = 1;
            pthread_cond_signal(&client_bid_states[idx].bid_cond);
            pthread_mutex_unlock(&client_bid_states[idx].bid_mutex);
            continue;  // Don't process as regular message
        }
        pthread_mutex_unlock(&client_bid_states[idx].bid_mutex);
        
        // Handle other message types
        switch (msg.type) {
            case MSG_SLM_PROMPT: {
                // Create a new thread to handle the SLM prompt so this thread
                // can continue processing messages (including bid responses)
                typedef struct {
                    int sock;
                    Message msg;
                } PromptArgs;
                
                PromptArgs *args = malloc(sizeof(PromptArgs));
                args->sock = client_sock;
                args->msg = msg;
                
                pthread_t prompt_thread;
                pthread_create(&prompt_thread, NULL, slm_prompt_handler, args);
                pthread_detach(prompt_thread);
                break;
            }
            
            default:
                init_message(&response);
                response.status = ERR_INVALID_OPERATION;
                send_message(client_sock, &response);
                break;
        }
    }
    
    pthread_mutex_lock(&nm.client_mutex);
    for (int i = 0; i < nm.client_count; i++) {
        if (nm.client_list[i].sock == client_sock) {
            printf("[NM] Client %s disconnected\n", nm.client_list[i].username);
            for (int j = i; j < nm.client_count - 1; j++) {
                nm.client_list[j] = nm.client_list[j + 1];
            }
            nm.client_count--;
            break;
        }
    }
    pthread_mutex_unlock(&nm.client_mutex);
    
    close(client_sock);
    return NULL;
}

void* client_listener(void* arg) {
    (void)arg;
    
    nm.client_sock = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(nm.client_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(NM_CLIENT_PORT);
    
    bind(nm.client_sock, (struct sockaddr*)&addr, sizeof(addr));
    listen(nm.client_sock, MAX_CLIENTS);
    
    printf("[NM] Listening for Clients on port %d\n", NM_CLIENT_PORT);
    
    while (nm.running) {
        int *client_sock = malloc(sizeof(int));
        *client_sock = accept(nm.client_sock, NULL, NULL);
        
        if (*client_sock < 0) {
            free(client_sock);
            continue;
        }
        
        pthread_t tid;
        pthread_create(&tid, NULL, handle_client_connection, client_sock);
        pthread_detach(tid);
    }
    
    return NULL;
}

int main() {
    init_name_server();
    
    pthread_t client_thread;
    pthread_create(&client_thread, NULL, client_listener, NULL);
    
    printf("[NM] Name Server running. Press Ctrl+C to stop.\n");
    
    pthread_join(client_thread, NULL);
    
    return 0;
}