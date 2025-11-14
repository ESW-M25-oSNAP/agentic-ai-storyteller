from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.svm import SVR
from sklearn.metrics import r2_score, mean_squared_error
import pandas as pd

df = pd.read_csv('ttft-final.csv')
X = df[['cpu_load', 'ram_load', 'prompt_length']]
y = df['ttft_sec']

models = {
    'Linear': LinearRegression(),
    'Polynomial (deg 2)': LinearRegression(),
    'Random Forest': RandomForestRegressor(n_estimators=100, random_state=42),
    'Gradient Boosting': GradientBoostingRegressor(random_state=42),
    'SVR': SVR(kernel='rbf')
}

# For polynomial
poly = PolynomialFeatures(degree=2, include_bias=False)
X_poly = poly.fit_transform(X)

results = {}
for name, model in models.items():
    if name == 'Polynomial (deg 2)':
        model.fit(X_poly, y)
        y_pred = model.predict(X_poly)
    else:
        model.fit(X, y)
        y_pred = model.predict(X)
    
    r2 = r2_score(y, y_pred)
    rmse = mean_squared_error(y, y_pred, squared=False)
    results[name] = {'R2': r2, 'RMSE': rmse}
    print(f"{name}: R² = {r2:.4f}, RMSE = {rmse:.4f}")
