import json

# --- Configuration ---
PARAMETERS_FILE = "model_parameters.json"


def _load_parameters(file_path):
    """
    Internal function to load model parameters from the JSON file.
    """
    try:
        with open(file_path, "r") as f:
            params = json.load(f)

        # Verify that the expected keys are present
        if "ttft_sec" not in params or "stream_speed_tps" not in params:
            raise KeyError(
                "File is missing required model keys ('ttft_sec', 'stream_speed_tps')"
            )

        print(f"Successfully loaded model parameters from '{file_path}'")
        return params

    except FileNotFoundError:
        print(f"FATAL ERROR: Model parameters file not found: '{file_path}'")
        print("Please run 'train_models.py' first.")
        return None
    except json.JSONDecodeError:
        print(f"FATAL ERROR: Could not decode JSON from '{file_path}'.")
        return None
    except Exception as e:
        print(f"FATAL ERROR: An unexpected error occurred loading parameters: {e}")
        return None


# --- Global Parameters ---
# Load parameters ONCE when this module is imported.
_model_params = _load_parameters(PARAMETERS_FILE)


def predict_ttft_sec(cpu_load, ram_load, prompt_length):
    """
    Predicts the Time to First Token (TTFT) in seconds.
    Reads parameters from the loaded 'model_parameters.json' file.
    """
    if _model_params is None:
        return -1  # Indicate error

    try:
        # Get the specific parameters for this model
        params = _model_params["ttft_sec"]
        intercept = params["intercept"]
        coeffs = params["coefficients"]

        # Calculate the prediction
        prediction = (
            intercept
            + (coeffs["cpu_load"] * cpu_load)
            + (coeffs["ram_load"] * ram_load)
            + (coeffs["prompt_length"] * prompt_length)
        )

        return max(0, prediction)  # Time can't be negative

    except KeyError as e:
        print(f"Error during TTFT prediction: Missing parameter {e}")
        return -1
    except Exception as e:
        print(f"An error occurred during TTFT prediction: {e}")
        return -1


def predict_stream_speed_tps(cpu_load, ram_load, prompt_length):
    """
    Predicts the stream speed in tokens per second (tps).
    Reads parameters from the loaded 'model_parameters.json' file.
    """
    if _model_params is None:
        return -1  # Indicate error

    try:
        # Get the specific parameters for this model
        params = _model_params["stream_speed_tps"]
        intercept = params["intercept"]
        coeffs = params["coefficients"]

        # Calculate the prediction
        prediction = (
            intercept
            + (coeffs["cpu_load"] * cpu_load)
            + (coeffs["ram_load"] * ram_load)
            + (coeffs["prompt_length"] * prompt_length)
        )

        return max(0, prediction)  # Speed can't be negative

    except KeyError as e:
        print(f"Error during Speed prediction: Missing parameter {e}")
        return -1
    except Exception as e:
        print(f"An error occurred during Speed prediction: {e}")
        return -1


# --- Example Usage ---
# This part only runs if you execute this script directly (e.g., `python predictor.py`)
if __name__ == "__main__":
    if _model_params is not None:
        print("\n--- Running Prediction Examples ---")

        # Example 1: Low load, short prompt
        cpu = 10
        ram = 20
        prompt = 50

        ttft = predict_ttft_sec(cpu, ram, prompt)
        speed = predict_stream_speed_tps(cpu, ram, prompt)

        print(f"--- Low Load Example (CPU: {cpu}%, RAM: {ram}%, Prompt: {prompt}) ---")
        print(f"Predicted TTFT: {ttft:.2f} seconds")
        print(f"Predicted Speed: {speed:.2f} tokens/sec")
        print("\n")

        # Example 2: High load, long prompt
        cpu = 80
        ram = 75
        prompt = 200

        ttft = predict_ttft_sec(cpu, ram, prompt)
        speed = predict_stream_speed_tps(cpu, ram, prompt)

        print(f"--- High Load Example (CPU: {cpu}%, RAM: {ram}%, Prompt: {prompt}) ---")
        print(f"Predicted TTFT: {ttft:.2f} seconds")
        print(f"Predicted Speed: {speed:.2f} tokens/sec")
    else:
        print("\nCannot run examples because model parameters failed to load.")
