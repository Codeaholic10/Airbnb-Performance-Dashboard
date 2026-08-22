# Airbnb Performance Data Analytics Project

An end-to-end industry-standard Data Analytics project based on the **Maven Analytics Airbnb Dataset**.

This project extends a baseline Power BI dashboard into a full analytical pipeline:
$$\text{Raw Data (CSV)} \longrightarrow \text{Python (Cleaning \& EDA)} \longrightarrow \text{SQL (Schema, Views \& Queries)} \longrightarrow \text{Power BI (Dashboard \& Insights)}$$

---

## 📁 Project Directory Structure

```text
Airbnb-Analytics/
│
├── data/
│   ├── raw/                       # Source raw CSV files (Listings.csv, Reviews.csv)
│   ├── cleaned/                   # Preprocessed & validated CSV files for SQL import
│   └── dictionaries/              # Field data dictionaries
│
├── notebooks/
│   └── airbnb_eda.py              # Reproducible Python EDA and cleaning workflow
│
├── sql/
│   └── business_analysis.sql      # Business questions, SQL answers, and reusable view logic
│
├── docs/
│   └── airbnb.pdf                 # Dashboard export / presentation artifact
│
├── reports/
│   ├── insights.md                # Detailed business insights summary
│   └── recommendations.md         # Strategic executive recommendations
│
├── README.md                      # Project documentation
└── requirements.txt               # Python package dependencies
```

---

## 📊 Preserved Core KPIs & Dashboard Targets

- **Total Listings:** `279,712`
- **Total Cities:** `10`
- **Total Hosts:** `182,024`
- **Property Types:** `144`
- **Total Reviews:** `5,373K` (`5,373,143`)

---

## ⚙️ Tech Stack & Prerequisites
- **Python:** `pandas`, `numpy`, `matplotlib`, `seaborn`, `sqlalchemy`
- **SQL Engine:** `PostgreSQL` / `DuckDB` / `SQLite`
- **BI Tool:** `Power BI Desktop`

---

## 🚀 How to Run

1. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
2. **Run the EDA:** Open `notebooks/airbnb_eda.py` in VS Code or run it as a Python script to generate cleaned CSVs and figures.
3. **Run SQL Analysis:** Execute `sql/business_analysis.sql` against the cleaned `listings` and `reviews` tables.
4. **Review Insights:** Read `reports/insights.md` and `reports/recommendations.md` for the business summary.
