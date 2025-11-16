/*
 * Multi-LinUCB Solver v3 - Multi-Objective for Edge SLM with Token Predictor
 * * Logic: 
 * 1. Predicts TTFT (Time to First Token)
 * 2. Predicts TPS (Tokens Per Second)
 * 3. Calls external predictor to estimate output tokens
 * 4. Combines them: Latency = TTFT + (Tokens / TPS)
 * 5. Applies Optimism: Score = Latency - (Alpha * Uncertainty)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define DIM 4
#define ALPHA 0.5 // Exploration parameter
#define PREDICTOR_PATH "/data/local/tmp/cppllama-bundle/llama.cpp/predictor"
#define DEFAULT_TOKENS 75  // Fallback if predictor fails

// Data Structures
typedef struct {
    double A[DIM][DIM];     // Shared Covariance Matrix
    double b_ttft[DIM];     // Weights for TTFT
    double b_speed[DIM];    // Weights for Speed
    double alpha;
} MultiLinUCB;

// --- HARDCODED WARM START DATA ---
// (Paste the output from the Python script here)
// Example placeholders (REPLACE THESE with python output):
double A_init[DIM][DIM] = {
    {2913.000000, 1424.420000, 1426.100000, 553.260000},
    {1424.420000, 948.489600, 696.370400, 273.258900},
    {1426.100000, 696.370400, 952.864800, 270.945720},
    {553.260000, 273.258900, 270.945720, 141.763110}
};
double b_ttft_init[DIM] = {50352.775448, 29158.869048, 24677.918716, 11773.252430};
double b_speed_init[DIM] = {18712.935297, 7022.409791, 9165.157313, 3868.617305};
// ---------------------------------


// Initialize
void solver_init(MultiLinUCB *solver) {
    solver->alpha = ALPHA;
    
    // Copy Warm Start values
    memcpy(solver->A, A_init, sizeof(A_init));
    memcpy(solver->b_ttft, b_ttft_init, sizeof(b_ttft_init));
    memcpy(solver->b_speed, b_speed_init, sizeof(b_speed_init));
}

// Matrix Inversion (Gauss-Jordan)
int invert_matrix(double A[DIM][DIM], double A_inv[DIM][DIM]) {
    double temp[DIM][2 * DIM];
    
    // Build Augmented Matrix [A | I]
    for(int i=0; i<DIM; i++) {
        for(int j=0; j<DIM; j++) temp[i][j] = A[i][j];
        for(int j=0; j<DIM; j++) temp[i][j+DIM] = (i==j) ? 1.0 : 0.0;
    }

    // Elimination
    for(int i=0; i<DIM; i++) {
        double pivot = temp[i][i];
        if(fabs(pivot) < 1e-9) return -1; // Singular
        
        for(int j=0; j<2*DIM; j++) temp[i][j] /= pivot;
        
        for(int k=0; k<DIM; k++) {
            if(k != i) {
                double factor = temp[k][i];
                for(int j=0; j<2*DIM; j++) temp[k][j] -= factor * temp[i][j];
            }
        }
    }

    // Extract Inverse
    for(int i=0; i<DIM; i++) {
        for(int j=0; j<DIM; j++) A_inv[i][j] = temp[i][j+DIM];
    }
    return 0;
}

// Call external predictor to estimate output tokens
double predict_tokens(const char* prompt) {
    char command[8192];  // Large buffer for prompt
    char result[256];
    FILE *fp;
    
    // Escape single quotes in prompt
    char escaped_prompt[4096];
    int j = 0;
    for (int i = 0; prompt[i] != '\0' && j < 4090; i++) {
        if (prompt[i] == '\'') {
            escaped_prompt[j++] = '\'';
            escaped_prompt[j++] = '\\';
            escaped_prompt[j++] = '\'';
            escaped_prompt[j++] = '\'';
        } else {
            escaped_prompt[j++] = prompt[i];
        }
    }
    escaped_prompt[j] = '\0';
    
    // Build command with proper environment setup
    snprintf(command, sizeof(command), 
        "cd /data/local/tmp/cppllama-bundle/llama.cpp && "
        "export LD_LIBRARY_PATH=$PWD/build/bin && "
        "%s '%s' 2>/dev/null", 
        PREDICTOR_PATH, escaped_prompt);
    
    // Execute predictor
    fp = popen(command, "r");
    if (fp == NULL) {
        fprintf(stderr, "Warning: Failed to run predictor, using default %d tokens\n", DEFAULT_TOKENS);
        return DEFAULT_TOKENS;
    }
    
    // Read output (predictor should output just a number)
    if (fgets(result, sizeof(result), fp) != NULL) {
        double tokens = atof(result);
        pclose(fp);
        
        // Sanity check
        if (tokens > 0 && tokens < 10000) {
            return tokens;
        }
    }
    
    pclose(fp);
    fprintf(stderr, "Warning: Predictor returned invalid value, using default %d tokens\n", DEFAULT_TOKENS);
    return DEFAULT_TOKENS;
}

// Core Scoring Function
// Note: Expects RAW values (cpu: 0-100, ram: 0-100, prompt_len: actual length)
double get_score(MultiLinUCB *solver, double cpu, double ram, double prompt_len, double pred_tokens) {
    // 1. Construct Feature Vector x [Bias, NormCPU, NormRAM, NormLen]
    // Normalize the raw input values to 0-1 range
    double x[DIM] = {
        1.0, 
        cpu / 100.0,        // CPU: 0-100 -> 0-1
        ram / 100.0,        // RAM: 0-100 -> 0-1
        prompt_len / 1000.0 // Prompt: actual length -> normalized
    };

    // 2. Invert A
    double A_inv[DIM][DIM];
    if(invert_matrix(solver->A, A_inv) != 0) return 9999.0; // Fail safe

    // 3. Calculate Weights (Theta = A_inv * b)
    double theta_ttft[DIM] = {0};
    double theta_speed[DIM] = {0};

    for(int i=0; i<DIM; i++) {
        for(int j=0; j<DIM; j++) {
            theta_ttft[i] += A_inv[i][j] * solver->b_ttft[j];
            theta_speed[i] += A_inv[i][j] * solver->b_speed[j];
        }
    }

    // 4. Predict Individual Components (Dot Product)
    double pred_ttft = 0.0;
    double pred_speed = 0.0;
    double uncertainty_sq = 0.0;

    // Also calculate Uncertainty term: x^T * A_inv * x
    // First calculate (A_inv * x)
    double A_inv_x[DIM] = {0};
    for(int i=0; i<DIM; i++) {
        for(int j=0; j<DIM; j++) A_inv_x[i] += A_inv[i][j] * x[j];
    }

    for(int i=0; i<DIM; i++) {
        pred_ttft += theta_ttft[i] * x[i];
        pred_speed += theta_speed[i] * x[i];
        uncertainty_sq += x[i] * A_inv_x[i];
    }

    double uncertainty = sqrt(fabs(uncertainty_sq));

    // 5. Apply Formula: Latency = TTFT + (Tokens / Speed)
    // Guard against div/0 or negative speed
    if(pred_speed < 0.1) pred_speed = 0.1; 
    
    double total_latency = pred_ttft + (pred_tokens / pred_speed);

    // 6. Apply Lower Confidence Bound (Optimism)
    double score = total_latency - (solver->alpha * uncertainty);
    
    return score;
}

// Training Function (Update Brain)
// Note: Expects RAW values (cpu: 0-100, ram: 0-100, prompt_len: actual length)
void train(MultiLinUCB *solver, double cpu, double ram, double prompt_len, double actual_ttft, double actual_speed) {
    // Normalize raw values to match scoring function
    double x[DIM] = { 
        1.0, 
        cpu/100.0,        // CPU: 0-100 -> 0-1
        ram/100.0,        // RAM: 0-100 -> 0-1
        prompt_len/1000.0 // Prompt: actual length -> normalized
    };

    // Update A += x * x^T
    for(int i=0; i<DIM; i++) {
        for(int j=0; j<DIM; j++) {
            solver->A[i][j] += x[i] * x[j];
        }
    }

    // Update b += x * y
    for(int i=0; i<DIM; i++) {
        solver->b_ttft[i] += x[i] * actual_ttft;
        solver->b_speed[i] += x[i] * actual_speed;
    }
}

// Main CLI for Testing
int main(int argc, char *argv[]) {
    if(argc < 2) {
        printf("Multi-LinUCB Solver - Edge SLM Orchestration\n");
        printf("Usage:\n");
        printf("  Score (with prompt): %s score <cpu> <ram> <prompt_len> \"<prompt>\"\n", argv[0]);
        printf("  Score (manual):      %s score <cpu> <ram> <prompt_len> <pred_tokens>\n", argv[0]);
        printf("  Train:               %s train <cpu> <ram> <prompt_len> <actual_ttft> <actual_speed>\n", argv[0]);
        printf("\nExamples:\n");
        printf("  %s score 45.2 60.5 150 \"What is the capital of France?\"\n", argv[0]);
        printf("  %s score 45.2 60.5 150 75\n", argv[0]);
        printf("  %s train 45.2 60.5 150 2.5 8.3\n", argv[0]);
        return 1;
    }

    MultiLinUCB solver;
    solver_init(&solver);
    
    const char* mode = argv[1];
    
    if (strcmp(mode, "score") == 0) {
        if(argc < 5) {
            printf("Error: score mode requires at least 4 arguments\n");
            printf("Usage: %s score <cpu> <ram> <prompt_len> <pred_tokens_or_prompt>\n", argv[0]);
            return 1;
        }
        
        double cpu = atof(argv[2]);
        double ram = atof(argv[3]);
        double prompt_len = atof(argv[4]);
        double pred_tokens;
        
        // Check if 5th argument is a prompt string or a number
        if (argc >= 6) {
            // Try to parse as number first
            char *endptr;
            double val = strtod(argv[5], &endptr);
            
            // If conversion consumed the whole string, it's a number
            if (*endptr == '\0' && endptr != argv[5]) {
                pred_tokens = val;
            } else {
                // It's a prompt string, use predictor
                pred_tokens = predict_tokens(argv[5]);
                fprintf(stderr, "Predicted tokens: %.0f\n", pred_tokens);
            }
        } else {
            // No 5th argument, use default
            pred_tokens = DEFAULT_TOKENS;
            fprintf(stderr, "Using default tokens: %.0f\n", pred_tokens);
        }
        
        double score = get_score(&solver, cpu, ram, prompt_len, pred_tokens);
        printf("%.6f\n", score);
        
    } else if (strcmp(mode, "train") == 0) {
        if(argc < 7) {
            printf("Error: train mode requires 6 arguments\n");
            printf("Usage: %s train <cpu> <ram> <prompt_len> <actual_ttft> <actual_speed>\n", argv[0]);
            return 1;
        }
        
        double cpu = atof(argv[2]);
        double ram = atof(argv[3]);
        double prompt_len = atof(argv[4]);
        double actual_ttft = atof(argv[5]);
        double actual_speed = atof(argv[6]);
        
        train(&solver, cpu, ram, prompt_len, actual_ttft, actual_speed);
        printf("Training completed\n");
        
    } else {
        printf("Error: Unknown mode '%s'\n", mode);
        printf("Valid modes: score, train\n");
        return 1;
    }

    return 0;
}