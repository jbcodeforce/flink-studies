import yfinance as yf
import pandas as pd
import matplotlib.pyplot as plt

# Download BTC-USD data (last 200 days)
ticker = "BTC-USD"
data = yf.download(ticker, period="200d")

# Compute moving averages
data['MA20'] = data['Close'].rolling(window=20).mean()
data['MA50'] = data['Close'].rolling(window=50).mean()

# Plot
plt.figure(figsize=(12, 6))
plt.plot(data.index, data['Close'], label='Close Price', color='black')
plt.plot(data.index, data['MA20'], label='20-Day MA', color='blue')
plt.plot(data.index, data['MA50'], label='50-Day MA', color='red')
plt.title(f'{ticker} Moving Averages')
plt.xlabel('Date')
plt.ylabel('Price (USD)')
plt.legend()
plt.grid(True)

# Save figure
plt.tight_layout()
plt.savefig('btc_ma.png')
plt.close()