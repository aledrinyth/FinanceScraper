import os
from flask import Flask, request, jsonify
import pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support import expected_conditions as EC
import traceback

# Initialize the Flask app
app = Flask(__name__)

def setup_driver():
    """Configures and returns a headless Chrome WebDriver."""
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--window-size=1920x1080")
    chrome_options.page_load_strategy = 'eager'  # 'none' is also an option

    
    # Use the service object to manage chromedriver
    service = Service(ChromeDriverManager().install())
    # service = webdriver.chrome.service.Service()
    driver = webdriver.Chrome(service=service, options=chrome_options)
    return driver

def scrape_financial_table(driver, url):
    """Navigates to a URL and scrapes the main financial table."""
    driver.get(url)
    
    # Wait for and click the "Expand All" button
    expand_button = WebDriverWait(driver, 20).until(
        EC.element_to_be_clickable((By.CSS_SELECTOR, "button.link2-btn[data-ylk*='expand']"))
    )
    expand_button.click()

    # Wait for the table container to be present
    table_container = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, "div.tableContainer"))
    )

    # Scrape headers
    header_elements = table_container.find_elements(By.CSS_SELECTOR, ".tableHeader .column")
    headers = [header.text for header in header_elements]

    # Scrape rows
    all_rows_data = []
    row_elements = table_container.find_elements(By.CSS_SELECTOR, ".tableBody .row")
    for row_element in row_elements:
        try:
            row_title = row_element.find_element(By.CSS_SELECTOR, "div.rowTitle").text
        except:
            row_title = "N/A"
        
        data_columns = row_element.find_elements(By.CSS_SELECTOR, "div.column:not(.sticky)")
        row_values = [col.text for col in data_columns]
        full_row = [row_title] + row_values
        all_rows_data.append(full_row)

    # Create DataFrame and convert to JSON-friendly format
    df = pd.DataFrame(all_rows_data, columns=headers)
    return df.to_dict('records') # Return as a list of dictionaries

# Define a simple health check route
@app.route('/', methods=['GET'])
def health_check():
    return "Scraper service is running."

# This is our main API endpoint
@app.route('/scrape', methods=['POST'])
def scrape():
    # Get the ticker from the incoming JSON request body
    data = request.get_json()
    if not data or 'ticker' not in data:
        return jsonify({"error": "Ticker is required in the request body"}), 400
    
    ticker = "AAPL"
    # ticker = data['ticker']
    driver = None # Initialize driver to None

    try:
        driver = setup_driver()
        
        # Scrape all three pages
        base_url = f"https://au.finance.yahoo.com/quote/{ticker}"
        income_statement = scrape_financial_table(driver, f"{base_url}/financials")
        balance_sheet = scrape_financial_table(driver, f"{base_url}/balance-sheet")
        cash_flow = scrape_financial_table(driver, f"{base_url}/cash-flow")
        
        # Combine results into a single JSON response
        result = {
            "ticker": ticker,
            "incomeStatement": income_statement,
            "balanceSheet": balance_sheet,
            "cashFlow": cash_flow
        }

        print(result)
        
        return jsonify(result)

    except Exception as e:
        error_traceback = traceback.format_exc()
        # Print the detailed traceback to your Render logs
        print("AN ERROR OCCURRED:")
        print(error_traceback)
        # Return a proper error message if something goes wrong
        return jsonify({"error": f"An error occurred: {str(e)}",
                        "traceback": error_traceback}), 500

    finally:
        # IMPORTANT: Always quit the driver to free up resources
        if driver:
            driver.quit()

if __name__ == "__main__":
    # Use Gunicorn as the server in production (Render will do this)
    # The following is for local testing only
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))

