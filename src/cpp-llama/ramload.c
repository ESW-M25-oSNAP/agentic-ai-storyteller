#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <string.h>

typedef struct {
    size_t mb;  // megabytes to allocate
} thread_arg_t;

void* ram_stress(void* arg) {
    thread_arg_t* a = (thread_arg_t*)arg;
    size_t bytes = a->mb * 1024 * 1024;
    char* buffer = malloc(bytes);
    if (!buffer) {
        perror("malloc");
        return NULL;
    }

    printf("Allocated %zu MB, starting memory write loop...\n", a->mb);

    // Write to each page continuously to keep it resident
    size_t page = 4096;
    while (1) {
        for (size_t i = 0; i < bytes; i += page)
            buffer[i] = (char)(i % 256);  // touch each page
        usleep(100000);  // 100 ms pause between sweeps
    }

    // never reached, but for cleanliness:
    free(buffer);
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <megabytes> [threads]\n", argv[0]);
        return 1;
    }

    int mb = atoi(argv[1]);
    int threads = (argc >= 3) ? atoi(argv[2]) : 1;

    printf("Simulating ~%d MB memory load using %d thread(s)\n", mb, threads);

    pthread_t tid[threads];
    thread_arg_t arg = { .mb = mb / threads };

    for (int i = 0; i < threads; i++)
        pthread_create(&tid[i], NULL, ram_stress, &arg);

    for (int i = 0; i < threads; i++)
        pthread_join(tid[i], NULL);

    return 0;
}
