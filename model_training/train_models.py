import glob  # Used to easily find files
import json

import pandas as pd
from sklearn.linear_model import LinearRegression

# --- Configuration ---

# This pattern finds all CSVs starting with 'slm_performance_data'
CSV_FILE_PATTERN = "slm_performance_data*.csv"

# The output file where parameters will be stored
PARAMETERS_FILE = "model_parameters.json"

# Model features and targets
FEATURES = ["cpu_load", "ram_load", "prompt_length"]
TARGET_TTFT = "ttft_sec"
TARGET_SPEED = "stream_speed_tps"


def load_data_from_files(file_pattern):
    """
    Loads and concatenates all CSV files matching the given pattern.
    """
    all_dataframes = []

    # --- REQUIREMENT 1: Print file names ---
    # glob.glob finds all files matching the pattern
    file_list = glob.glob(file_pattern)

    if not file_list:
        print(f"No files found matching pattern: {file_pattern}")
        return None

    # This print statement lists all files that will be read
    print(f"Found {len(file_list)} files for training:")
    print(file_list)
    print("-" * 30)  # Separator
    # --- End Requirement 1 ---

    for filename in file_list:
        try:
            df = pd.read_csv(filename)
            all_dataframes.append(df)
            # This prints each file as it's loaded
            print(f" - Loaded '{filename}' ({len(df)} rows)")
        except Exception as e:
            print(f" - Error loading '{filename}': {e}")

    if not all_dataframes:
        print("No data was successfully loaded.")
        return None

    # Combine all individual dataframes into one large one
    combined_data = pd.concat(all_dataframes, ignore_index=True)
    print(f"\nTotal training rows: {len(combined_data)}")
    return combined_data


def train_model(data, features, target_name):
    """
    Trains a linear regression model and returns its parameters as a dictionary.
    """
    try:
        X = data[features]
        y = data[target_name]

        model = LinearRegression()
        model.fit(X, y)

        intercept = model.intercept_
        coefficients = model.coef_

        # Store coefficients in a feature-name-keyed dictionary
        coeff_dict = {feature: coeff for feature, coeff in zip(features, coefficients)}

        print(f"Successfully trained model for: {target_name}")

        return {"intercept": intercept, "coefficients": coeff_dict}

    except KeyError as e:
        print(f"Error training {target_name}: Missing column {e}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred during training for {target_name}: {e}")
        return None


def main():
    """
    Main function to load all data, train both models, and save parameters.
    """
    data = load_data_from_files(CSV_FILE_PATTERN)

    if data is None:
        print("Halting due to data loading errors.")
        return

    # This dictionary will hold all parameters
    all_parameters = {}

    # Train and store parameters for the TTFT model
    params_ttft = train_model(data, FEATURES, TARGET_TTFT)
    if params_ttft:
        all_parameters[TARGET_TTFT] = params_ttft

    # Train and store parameters for the Stream Speed model
    params_speed = train_model(data, FEATURES, TARGET_SPEED)
    if params_speed:
        all_parameters[TARGET_SPEED] = params_speed

    # Check if any models were successfully trained
    if all_parameters:
        # --- REQUIREMENT 2: Print parameters to console ---
        print("\n" + "=" * 40)
        print("--- Generated Model Parameters (Console) ---")
        # Use json.dumps to pretty-print the dictionary to the console
        print(json.dumps(all_parameters, indent=4))
        print("=" * 40 + "\n")
        # --- End Requirement 2 ---

        # Now, write the same parameters to the file
        try:
            with open(PARAMETERS_FILE, "w") as f:
                json.dump(all_parameters, f, indent=4)
            print(f"Successfully wrote all model parameters to '{PARAMETERS_FILE}'")
        except Exception as e:
            print(f"\nError writing parameters to file: {e}")
    else:
        print("\nNo models were trained, so no parameters file was written.")


if __name__ == "__main__":
    main()
