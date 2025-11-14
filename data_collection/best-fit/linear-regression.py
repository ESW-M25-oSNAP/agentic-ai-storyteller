import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score, mean_squared_error

# Load your data
df = pd.read_csv('ttft-final.csv')

# Prepare features (X) and target (y)
X = df[['cpu_load', 'ram_load', 'prompt_length']]
y = df['ttft_sec']

# Create and fit the model
model = LinearRegression()
model.fit(X, y)

# Get the coefficients
print(f"Intercept: {model.intercept_}")
print(f"Coefficients: {dict(zip(X.columns, model.coef_))}")

# Evaluate the model
y_pred = model.predict(X)
print(f"R² Score: {r2_score(y, y_pred)}")
print(f"RMSE: {mean_squared_error(y, y_pred, squared=False)}")

# Your best fit function:
print(f"\nttft_sec = {model.intercept_:.4f} + "
      f"{model.coef_[0]:.4f}*cpu_load + "
      f"{model.coef_[1]:.4f}*ram_load + "
      f"{model.coef_[2]:.4f}*prompt_length")
