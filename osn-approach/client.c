#include "common.h"
#include <signal.h>
#include <fcntl.h>
#include <sys/select.h>

typedef struct {
    char username[MAX_USERNAME];
    int nm_sock;
    int connected;
    char nm_ip[INET_ADDRSTRLEN];
    int nm_port;
    int has_npu;
    int npu_free;
    int waiting_for_prompt_response;
    char pending_prompt[MAX_BUFFER];
} Client;

Client client;

// Signal handling
int sig_pipe[2] = {-1, -1};
volatile sig_atomic_t sigint_received = 0;

void sigint_handler(int signo) {
    (void)signo;
    if (sig_pipe[1] != -1) {
        const char b = 'I';
        ssize_t r = write(sig_pipe[1], &b, 1);
        (void)r;
    }
    sigint_received = 1;
}

// SLM execution listener
static int slm_listener_sock = -1;
static int slm_listener_port = 0;

void* slm_execution_listener(void* arg) {
    (void)arg;
    
    slm_listener_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (slm_listener_sock < 0) {
        printf("[SLM] Failed to create listener socket\n");
        return NULL;
    }
    
    int opt = 1;
    setsockopt(slm_listener_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = 0;
    
    if (bind(slm_listener_sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        printf("[SLM] Failed to bind listener socket\n");
        close(slm_listener_sock);
        return NULL;
    }
    
    socklen_t len = sizeof(addr);
    if (getsockname(slm_listener_sock, (struct sockaddr*)&addr, &len) == 0) {
        slm_listener_port = ntohs(addr.sin_port);
        printf("[SLM] Listening on port %d\n", slm_listener_port);
    }
    
    listen(slm_listener_sock, 5);
    
    while (1) {
        int exec_sock = accept(slm_listener_sock, NULL, NULL);
        if (exec_sock < 0) continue;
        
        Message msg;
        if (recv_message(exec_sock, &msg) < 0) {
            close(exec_sock);
            continue;
        }
        
        if (msg.type == MSG_SLM_EXECUTE) {
            printf("\n[SLM] Executing prompt: %s\n", msg.data);
            printf("[SLM] EXECUTION DONE\n");
            printf("> "); // Re-print prompt
            fflush(stdout);
            
            Message response;
            init_message(&response);
            response.type = MSG_SLM_RESULT;
            response.status = SUCCESS;
            strcpy(response.data, "SLM EXECUTION DONE");
            
            send_message(exec_sock, &response);
        }
        
        close(exec_sock);
    }
    
    return NULL;
}

void handle_slm_prompt(char *prompt) {
    if (!prompt || strlen(prompt) == 0) {
        printf("Usage: SLM_PROMPT \"<your prompt here>\"\n");
        return;
    }
    
    printf("[SLM] Requesting execution for: %s\n", prompt);
    
    Message msg;
    init_message(&msg);
    msg.type = MSG_SLM_PROMPT;
    strcpy(msg.sender, client.username);
    strncpy(msg.data, prompt, MAX_BUFFER - 1);
    msg.target_port = slm_listener_port;
    
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    if (getsockname(client.nm_sock, (struct sockaddr*)&local_addr, &addr_len) == 0) {
        inet_ntop(AF_INET, &local_addr.sin_addr, msg.target_ip, INET_ADDRSTRLEN);
    } else {
        strcpy(msg.target_ip, "127.0.0.1");
    }
    
    send_message(client.nm_sock, &msg);
    
    // Mark that we're waiting for a response
    client.waiting_for_prompt_response = 1;
    strncpy(client.pending_prompt, prompt, MAX_BUFFER - 1);
}

void handle_prompt_response(Message *response) {
    if (!client.waiting_for_prompt_response) {
        return;
    }
    
    client.waiting_for_prompt_response = 0;
    
    if (response->status == SUCCESS) {
        printf("[SLM] Selected executor: %s:%d\n", response->target_ip, response->target_port);
        
        int exec_sock = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in exec_addr;
        exec_addr.sin_family = AF_INET;
        exec_addr.sin_port = htons(response->target_port);
        inet_pton(AF_INET, response->target_ip, &exec_addr.sin_addr);
        
        if (connect(exec_sock, (struct sockaddr*)&exec_addr, sizeof(exec_addr)) == 0) {
            Message exec_msg;
            init_message(&exec_msg);
            exec_msg.type = MSG_SLM_EXECUTE;
            strcpy(exec_msg.data, client.pending_prompt);
            
            send_message(exec_sock, &exec_msg);
            
            Message result;
            if (recv_message(exec_sock, &result) >= 0) {
                printf("[SLM] Result: %s\n", result.data);
            }
        } else {
            printf("[SLM] Failed to connect to executor\n");
        }
        
        close(exec_sock);
    } else {
        printf("Error: No executors available\n");
    }
}

void handle_slm_bid_request(Message *bid_req) {
    (void)bid_req;
    
    Message response;
    init_message(&response);
    response.type = MSG_SLM_BID_RESPONSE;
    strcpy(response.sender, client.username);
    
    // Always submit a bid, but adjust scores based on capabilities
    if (client.has_npu && client.npu_free) {
        // High scores for NPU-enabled devices
        response.bid_x = 0.8f + ((float)rand() / RAND_MAX) * 0.2f;
        response.bid_y = 0.7f + ((float)rand() / RAND_MAX) * 0.3f;
        response.bid_z = 0.6f + ((float)rand() / RAND_MAX) * 0.4f;
        response.bid_w = 0.9f + ((float)rand() / RAND_MAX) * 0.1f;
        
        printf("\n[SLM] Submitting bid (NPU): ");
    } else {
        // Lower scores for CPU-only devices (but still valid bids!)
        response.bid_x = 0.3f + ((float)rand() / RAND_MAX) * 0.2f;
        response.bid_y = 0.4f + ((float)rand() / RAND_MAX) * 0.2f;
        response.bid_z = 0.2f + ((float)rand() / RAND_MAX) * 0.3f;
        response.bid_w = 0.3f + ((float)rand() / RAND_MAX) * 0.2f;
        
        printf("\n[SLM] Submitting bid (CPU): ");
    }
    
    response.bid_total = (response.bid_x * 0.3f + 
                         response.bid_y * 0.2f + 
                         response.bid_z * 0.3f + 
                         response.bid_w * 0.2f);
    
    response.status = SUCCESS;
    response.target_port = slm_listener_port;
    
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    if (getsockname(client.nm_sock, (struct sockaddr*)&local_addr, &addr_len) == 0) {
        inet_ntop(AF_INET, &local_addr.sin_addr, response.target_ip, INET_ADDRSTRLEN);
    } else {
        strcpy(response.target_ip, "127.0.0.1");
    }
    
    printf("%.3f (x=%.2f, y=%.2f, z=%.2f, w=%.2f)\n",
           response.bid_total, response.bid_x, response.bid_y, 
           response.bid_z, response.bid_w);
    printf("> ");
    fflush(stdout);
    
    send_message(client.nm_sock, &response);
}

void init_client() {
    printf("Enter username: ");
    fgets(client.username, MAX_USERNAME, stdin);
    trim_whitespace(client.username);
    
    client.connected = 0;
    client.waiting_for_prompt_response = 0;
    
    printf("Do you have an NPU? (y/n): ");
    char npu_input[10];
    fgets(npu_input, sizeof(npu_input), stdin);
    client.has_npu = (npu_input[0] == 'y' || npu_input[0] == 'Y') ? 1 : 0;
    client.npu_free = client.has_npu ? 1 : 0;
    
    printf("[Client] Username: %s, NPU: %s\n", client.username, client.has_npu ? "Yes" : "No");
    
    pthread_t slm_thread;
    pthread_create(&slm_thread, NULL, slm_execution_listener, NULL);
    pthread_detach(slm_thread);
    
    sleep(1);
}

void connect_to_nm() {
    client.nm_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (client.nm_sock < 0) {
        perror("Socket creation failed");
        exit(1);
    }
    
    struct sockaddr_in nm_addr;
    nm_addr.sin_family = AF_INET;
    nm_addr.sin_port = htons(client.nm_port);
    inet_pton(AF_INET, client.nm_ip, &nm_addr.sin_addr);
    
    if (connect(client.nm_sock, (struct sockaddr*)&nm_addr, sizeof(nm_addr)) < 0) {
        perror("Connection to NM failed");
        exit(1);
    }

    Message msg;
    init_message(&msg);
    
    struct sockaddr_in local_addr;
    socklen_t addr_len = sizeof(local_addr);
    if (getsockname(client.nm_sock, (struct sockaddr*)&local_addr, &addr_len) == 0) {
        inet_ntop(AF_INET, &local_addr.sin_addr, msg.data, INET_ADDRSTRLEN);
    } else {
        strcpy(msg.data, "127.0.0.1");
    }
    
    msg.type = MSG_REG_CLIENT;
    strcpy(msg.sender, client.username);
    msg.has_npu = client.has_npu;
    msg.npu_free = client.npu_free;
    
    send_message(client.nm_sock, &msg);
    
    Message response;
    recv_message(client.nm_sock, &response);
    
    if (response.status == SUCCESS) {
        client.connected = 1;
        printf("[Client] Connected to Name Server at %s:%d\n", client.nm_ip, client.nm_port);
    } else {
        printf("[Client] Registration failed\n");
        exit(1);
    }
}

void command_loop() {
    char line[MAX_BUFFER];
    
    printf("\nWelcome %s! Type commands (or 'help' for list, 'exit' to quit):\n", client.username);
    
    while (1) {
        printf("\n> ");
        fflush(stdout);

        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(STDIN_FILENO, &rfds);
        FD_SET(client.nm_sock, &rfds);

        if (sig_pipe[0] != -1) {
            FD_SET(sig_pipe[0], &rfds);
        }
        
        int maxfd = STDIN_FILENO;
        if (client.nm_sock > maxfd) maxfd = client.nm_sock;
        if (sig_pipe[0] > maxfd) maxfd = sig_pipe[0];

        int sel = select(maxfd + 1, &rfds, NULL, NULL, NULL);
        if (sel < 0) {
            if (errno == EINTR) continue;
            perror("select");
            break;
        }

        // Check for signal
        if (sig_pipe[0] != -1 && FD_ISSET(sig_pipe[0], &rfds)) {
            char buf[64];
            while (read(sig_pipe[0], buf, sizeof(buf)) > 0) {}
            printf("\nReceived interrupt, exiting client.\n");
            break;
        }

        // Check for messages from NM
        if (FD_ISSET(client.nm_sock, &rfds)) {
            Message msg;
            if (recv_message(client.nm_sock, &msg) < 0) {
                printf("\nConnection to NM lost\n");
                break;
            }
            
            if (msg.type == MSG_SLM_BID_REQUEST) {
                handle_slm_bid_request(&msg);
            } else if (client.waiting_for_prompt_response) {
                // This is the response to our SLM_PROMPT request
                handle_prompt_response(&msg);
            }
        }

        // Check for user input
        if (FD_ISSET(STDIN_FILENO, &rfds)) {
            if (!fgets(line, sizeof(line), stdin)) {
                break;
            }
            
            trim_whitespace(line);
            
            if (strlen(line) == 0) {
                continue;
            }

            if (strcmp(line, "exit") == 0 || strcmp(line, "quit") == 0) {
                printf("Goodbye!\n");
                break;
            } else if (strcmp(line, "help") == 0) {
                printf("Available commands:\n");
                printf("  SLM_PROMPT \"<prompt>\" - Execute SLM prompt\n");
                printf("  exit                  - Exit client\n");
            } else if (strncmp(line, "SLM_PROMPT", 10) == 0) {
                char *prompt_start = strchr(line, '"');
                if (prompt_start) {
                    prompt_start++;
                    char *prompt_end = strrchr(prompt_start, '"');
                    if (prompt_end) {
                        *prompt_end = '\0';
                        handle_slm_prompt(prompt_start);
                    } else {
                        printf("Error: Missing closing quote\n");
                    }
                } else {
                    printf("Usage: SLM_PROMPT \"<your prompt here>\"\n");
                }
            } else {
                printf("Unknown command: %s\n", line);
                printf("Type 'help' for list of commands\n");
            }
        }
    }
}

int main(int argc, char *argv[]) {
    if (pipe(sig_pipe) < 0) {
        perror("pipe");
        return 1;
    }

    int flags = fcntl(sig_pipe[0], F_GETFL, 0);
    if (flags >= 0) fcntl(sig_pipe[0], F_SETFL, flags | O_NONBLOCK);
    flags = fcntl(sig_pipe[1], F_GETFL, 0);
    if (flags >= 0) fcntl(sig_pipe[1], F_SETFL, flags | O_NONBLOCK);
    
    struct sigaction sa;
    sa.sa_handler = sigint_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, NULL);

    signal(SIGPIPE, SIG_IGN);

    if (argc != 3) {
        printf("Usage: %s <nm_ip> <nm_port>\n", argv[0]);
        printf("Example: %s 127.0.0.1 8081\n", argv[0]);
        return 1;
    }
    
    strncpy(client.nm_ip, argv[1], INET_ADDRSTRLEN - 1);
    client.nm_ip[INET_ADDRSTRLEN - 1] = '\0';
    client.nm_port = atoi(argv[2]);
    
    if (client.nm_port <= 0 || client.nm_port > 65535) {
        printf("Error: Invalid port number. Must be between 1 and 65535.\n");
        return 1;
    }
    
    init_client();
    connect_to_nm();
    command_loop();
    
    close(client.nm_sock);

    if (sig_pipe[0] != -1) close(sig_pipe[0]);
    if (sig_pipe[1] != -1) close(sig_pipe[1]);
    return 0;
}