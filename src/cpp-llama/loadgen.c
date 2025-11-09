// This code is designed to manipulate the cpu load on a given device.
// If I run it with parameter 0<x<=100, it wants to waste that amount of the CPU's time
// It does this by using the principle of "duty cycling"
// i.e. it repeatedly alternates between busy work and sleep in short, repeated cycles, such that the ratio of (busy time):(total time) = CPU Load you want

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>

typedef struct {
    int load;
} thread_arg_t;

void* worker(void* arg) {
    thread_arg_t* t = (thread_arg_t*)arg;
    const int cycle_ms = 100;  // control cycle length
    struct timespec start, now;

    while (1) {
        clock_gettime(CLOCK_MONOTONIC, &start);
        long busy_time = (long)cycle_ms * t->load / 100;
        long idle_time = cycle_ms - busy_time;

        // Busy spin for busy_time ms
        do {
            clock_gettime(CLOCK_MONOTONIC, &now);
        } while (((now.tv_sec - start.tv_sec) * 1000 +
                  (now.tv_nsec - start.tv_nsec) / 1000000) < busy_time);

        // Sleep for idle_time ms
        if (idle_time > 0)
            usleep(idle_time * 1000);
    }
    return NULL;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <load_percent> [num_threads]\n", argv[0]);
        return 1;
    }

    int load = atoi(argv[1]);
    int nthreads = (argc >= 3) ? atoi(argv[2]) : sysconf(_SC_NPROCESSORS_ONLN);
    if (load < 0 || load > 100) {
        fprintf(stderr, "Load must be between 0 and 100.\n");
        return 1;
    }

    printf("Starting %d threads targeting ~%d%% CPU load per thread.\n", nthreads, load);

    pthread_t* tids = malloc(sizeof(pthread_t) * nthreads);
    thread_arg_t arg = { load };

    for (int i = 0; i < nthreads; ++i)
        pthread_create(&tids[i], NULL, worker, &arg);

    for (int i = 0; i < nthreads; ++i)
        pthread_join(tids[i], NULL);

    free(tids);
    return 0;
}
