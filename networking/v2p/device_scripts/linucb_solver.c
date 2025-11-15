/*
 * LinUCB Solver - Local Learning Model for Edge Devices
 * 
 * Implements Ridge Regression + Lower Confidence Bound (LCB) for latency prediction
 * 
 * Features: [1.0, cpu_load/100, ram_load/100, prompt_length/1000]
 * Goal: Minimize Latency (Cost) using LCB
 * 
 * Math:
 *   - Matrix A: Covariance matrix (4x4), initialized as Identity or warm-started
 *   - Vector b: Reward accumulator (4x1), initialized as Zeros or warm-started
 *   - getScore: Score = θ^T·x - α·σ (Lower Confidence Bound for minimization)
 *     where θ = A^(-1)·b, σ = sqrt(x^T·A^(-1)·x)
 *   - train: Update A += x·x^T, b += x·y (actual latency)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define DIM 4
#define ALPHA 1.0  // Exploration parameter (can be tuned)

typedef struct {
    double A[DIM][DIM];  // Covariance matrix
    double b[DIM];       // Reward vector
    double alpha;        // Exploration parameter
} LinUCBSolver;

/* Initialize solver with Identity matrix for A and zeros for b */
void linucb_init(LinUCBSolver *solver, double alpha) {
    solver->alpha = alpha;
    
    // Initialize A as Identity matrix
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            solver->A[i][j] = (i == j) ? 1.0 : 0.0;
        }
    }
    
    // Initialize b as zeros
    for (int i = 0; i < DIM; i++) {
        solver->b[i] = 0.0;
    }
}

/* Load solver state from files (warm start) */
int linucb_load(LinUCBSolver *solver, const char *a_file, const char *b_file, double alpha) {
    FILE *fa, *fb;
    
    solver->alpha = alpha;
    
    // Load A matrix
    fa = fopen(a_file, "r");
    if (!fa) {
        fprintf(stderr, "Warning: Could not open %s, initializing as Identity\n", a_file);
        linucb_init(solver, alpha);
        return 0;
    }
    
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            if (fscanf(fa, "%lf", &solver->A[i][j]) != 1) {
                fprintf(stderr, "Error reading A matrix\n");
                fclose(fa);
                return -1;
            }
        }
    }
    fclose(fa);
    
    // Load b vector
    fb = fopen(b_file, "r");
    if (!fb) {
        fprintf(stderr, "Warning: Could not open %s, initializing as zeros\n", b_file);
        for (int i = 0; i < DIM; i++) {
            solver->b[i] = 0.0;
        }
        return 0;
    }
    
    for (int i = 0; i < DIM; i++) {
        if (fscanf(fb, "%lf", &solver->b[i]) != 1) {
            fprintf(stderr, "Error reading b vector\n");
            fclose(fb);
            return -1;
        }
    }
    fclose(fb);
    
    return 0;
}

/* Save solver state to files */
int linucb_save(const LinUCBSolver *solver, const char *a_file, const char *b_file) {
    FILE *fa, *fb;
    
    // Save A matrix
    fa = fopen(a_file, "w");
    if (!fa) {
        fprintf(stderr, "Error: Could not write to %s\n", a_file);
        return -1;
    }
    
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            fprintf(fa, "%.10f ", solver->A[i][j]);
        }
        fprintf(fa, "\n");
    }
    fclose(fa);
    
    // Save b vector
    fb = fopen(b_file, "w");
    if (!fb) {
        fprintf(stderr, "Error: Could not write to %s\n", b_file);
        return -1;
    }
    
    for (int i = 0; i < DIM; i++) {
        fprintf(fb, "%.10f\n", solver->b[i]);
    }
    fclose(fb);
    
    return 0;
}

/* Gauss-Jordan elimination to compute A^(-1) */
int matrix_inverse(double A[DIM][DIM], double A_inv[DIM][DIM]) {
    double temp[DIM][DIM * 2];
    
    // Create augmented matrix [A | I]
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            temp[i][j] = A[i][j];
            temp[i][j + DIM] = (i == j) ? 1.0 : 0.0;
        }
    }
    
    // Forward elimination
    for (int i = 0; i < DIM; i++) {
        // Find pivot
        double max_val = fabs(temp[i][i]);
        int max_row = i;
        for (int k = i + 1; k < DIM; k++) {
            if (fabs(temp[k][i]) > max_val) {
                max_val = fabs(temp[k][i]);
                max_row = k;
            }
        }
        
        // Swap rows if needed
        if (max_row != i) {
            for (int k = 0; k < DIM * 2; k++) {
                double tmp = temp[i][k];
                temp[i][k] = temp[max_row][k];
                temp[max_row][k] = tmp;
            }
        }
        
        // Check for singular matrix
        if (fabs(temp[i][i]) < 1e-10) {
            fprintf(stderr, "Error: Matrix is singular or near-singular\n");
            return -1;
        }
        
        // Scale pivot row
        double pivot = temp[i][i];
        for (int k = 0; k < DIM * 2; k++) {
            temp[i][k] /= pivot;
        }
        
        // Eliminate column
        for (int j = 0; j < DIM; j++) {
            if (j != i) {
                double factor = temp[j][i];
                for (int k = 0; k < DIM * 2; k++) {
                    temp[j][k] -= factor * temp[i][k];
                }
            }
        }
    }
    
    // Extract inverse from augmented matrix
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            A_inv[i][j] = temp[i][j + DIM];
        }
    }
    
    return 0;
}

/* Calculate optimistic score (Lower Confidence Bound for minimization) */
double linucb_get_score(const LinUCBSolver *solver, const double x[DIM]) {
    double A_inv[DIM][DIM];
    double theta[DIM];
    double A_inv_x[DIM];
    double mean_latency;
    double uncertainty;
    double score;
    
    // Step 1: Compute A^(-1)
    double A_copy[DIM][DIM];
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            A_copy[i][j] = solver->A[i][j];
        }
    }
    
    if (matrix_inverse(A_copy, A_inv) != 0) {
        fprintf(stderr, "Error: Could not invert matrix\n");
        return 1e9;  // Return very high score on error
    }
    
    // Step 2: Compute θ = A^(-1) · b
    for (int i = 0; i < DIM; i++) {
        theta[i] = 0.0;
        for (int j = 0; j < DIM; j++) {
            theta[i] += A_inv[i][j] * solver->b[j];
        }
    }
    
    // Step 3: Compute mean latency = θ^T · x
    mean_latency = 0.0;
    for (int i = 0; i < DIM; i++) {
        mean_latency += theta[i] * x[i];
    }
    
    // Step 4: Compute A^(-1) · x
    for (int i = 0; i < DIM; i++) {
        A_inv_x[i] = 0.0;
        for (int j = 0; j < DIM; j++) {
            A_inv_x[i] += A_inv[i][j] * x[j];
        }
    }
    
    // Step 5: Compute uncertainty σ = sqrt(x^T · A^(-1) · x)
    uncertainty = 0.0;
    for (int i = 0; i < DIM; i++) {
        uncertainty += x[i] * A_inv_x[i];
    }
    uncertainty = sqrt(fabs(uncertainty));  // Use fabs to handle numerical errors
    
    // Step 6: Compute LCB score = mean - α·σ (optimistic about lower latency)
    score = mean_latency - (solver->alpha * uncertainty);
    
    return score;
}

/* Train the model with actual latency feedback */
void linucb_train(LinUCBSolver *solver, const double x[DIM], double actual_latency) {
    // Update A: A_new = A_old + x·x^T
    for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
            solver->A[i][j] += x[i] * x[j];
        }
    }
    
    // Update b: b_new = b_old + x·y
    for (int i = 0; i < DIM; i++) {
        solver->b[i] += x[i] * actual_latency;
    }
}

/* Print solver state for debugging */
void linucb_print(const LinUCBSolver *solver) {
    printf("LinUCB Solver State (alpha=%.2f):\n", solver->alpha);
    printf("Matrix A:\n");
    for (int i = 0; i < DIM; i++) {
        printf("  ");
        for (int j = 0; j < DIM; j++) {
            printf("%.4f ", solver->A[i][j]);
        }
        printf("\n");
    }
    printf("Vector b:\n");
    printf("  ");
    for (int i = 0; i < DIM; i++) {
        printf("%.4f ", solver->b[i]);
    }
    printf("\n");
}

/* Main function for testing and CLI interface */
int main(int argc, char *argv[]) {
    LinUCBSolver solver;
    
    if (argc < 2) {
        printf("Usage:\n");
        printf("  %s init <a_file> <b_file> [alpha]              - Initialize solver\n", argv[0]);
        printf("  %s load <a_file> <b_file> [alpha]              - Load solver state\n", argv[0]);
        printf("  %s score <a_file> <b_file> <cpu> <ram> <plen> [alpha] - Get score\n", argv[0]);
        printf("  %s train <a_file> <b_file> <cpu> <ram> <plen> <latency> [alpha] - Train model\n", argv[0]);
        printf("  %s print <a_file> <b_file> [alpha]             - Print state\n", argv[0]);
        printf("\nFeatures:\n");
        printf("  cpu:  CPU load (0-100)\n");
        printf("  ram:  RAM load (0-100)\n");
        printf("  plen: Prompt length (tokens)\n");
        printf("  alpha: Exploration parameter (default: 1.0)\n");
        return 1;
    }
    
    const char *cmd = argv[1];
    double alpha = (argc > 3 && strcmp(cmd, "init") == 0) ? atof(argv[4]) :
                   (argc > 3 && strcmp(cmd, "load") == 0) ? atof(argv[4]) :
                   (argc > 7 && strcmp(cmd, "score") == 0) ? atof(argv[7]) :
                   (argc > 8 && strcmp(cmd, "train") == 0) ? atof(argv[8]) :
                   (argc > 4 && strcmp(cmd, "print") == 0) ? atof(argv[4]) :
                   ALPHA;
    
    if (strcmp(cmd, "init") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Error: init requires <a_file> <b_file> [alpha]\n");
            return 1;
        }
        linucb_init(&solver, alpha);
        if (linucb_save(&solver, argv[2], argv[3]) == 0) {
            printf("Initialized solver with Identity matrix and saved to %s, %s\n", argv[2], argv[3]);
        }
    }
    else if (strcmp(cmd, "load") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Error: load requires <a_file> <b_file> [alpha]\n");
            return 1;
        }
        if (linucb_load(&solver, argv[2], argv[3], alpha) == 0) {
            printf("Loaded solver from %s, %s\n", argv[2], argv[3]);
            linucb_print(&solver);
        }
    }
    else if (strcmp(cmd, "score") == 0) {
        if (argc < 7) {
            fprintf(stderr, "Error: score requires <a_file> <b_file> <cpu> <ram> <plen> [alpha]\n");
            return 1;
        }
        
        if (linucb_load(&solver, argv[2], argv[3], alpha) != 0) {
            return 1;
        }
        
        // Parse features: [1.0, cpu/100, ram/100, plen/1000]
        double x[DIM];
        x[0] = 1.0;
        x[1] = atof(argv[4]) / 100.0;
        x[2] = atof(argv[5]) / 100.0;
        x[3] = atof(argv[6]) / 1000.0;
        
        double score = linucb_get_score(&solver, x);
        printf("%.6f\n", score);  // Just output the score for easy shell parsing
    }
    else if (strcmp(cmd, "train") == 0) {
        if (argc < 8) {
            fprintf(stderr, "Error: train requires <a_file> <b_file> <cpu> <ram> <plen> <latency> [alpha]\n");
            return 1;
        }
        
        if (linucb_load(&solver, argv[2], argv[3], alpha) != 0) {
            return 1;
        }
        
        // Parse features: [1.0, cpu/100, ram/100, plen/1000]
        double x[DIM];
        x[0] = 1.0;
        x[1] = atof(argv[4]) / 100.0;
        x[2] = atof(argv[5]) / 100.0;
        x[3] = atof(argv[6]) / 1000.0;
        
        double latency = atof(argv[7]);
        
        linucb_train(&solver, x, latency);
        
        if (linucb_save(&solver, argv[2], argv[3]) == 0) {
            printf("Trained model with latency=%.6f and saved to %s, %s\n", latency, argv[2], argv[3]);
        }
    }
    else if (strcmp(cmd, "print") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Error: print requires <a_file> <b_file> [alpha]\n");
            return 1;
        }
        
        if (linucb_load(&solver, argv[2], argv[3], alpha) == 0) {
            linucb_print(&solver);
        }
    }
    else {
        fprintf(stderr, "Unknown command: %s\n", cmd);
        return 1;
    }
    
    return 0;
}
