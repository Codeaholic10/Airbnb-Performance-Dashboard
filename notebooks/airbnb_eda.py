"""
Airbnb EDA and visualization workflow.

Run from the project root:
    python notebooks/airbnb_eda.py

Outputs:
    reports/eda_summary.md
    reports/figures/price_by_city_room_type.png
    reports/figures/monthly_reviews_trend.png
"""

from __future__ import annotations

from pathlib import Path

import matplotlib
import pandas as pd
import seaborn as sns


matplotlib.use("Agg")

import matplotlib.pyplot as plt

ROOT_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT_DIR / "data" / "raw"
REPORTS_DIR = ROOT_DIR / "reports"
FIGURES_DIR = REPORTS_DIR / "figures"

LISTINGS_PATH = RAW_DIR / "Listings.csv"
REVIEWS_PATH = RAW_DIR / "Reviews.csv"


def pct_missing(frame: pd.DataFrame) -> pd.Series:
    """Return missing percentages, sorted highest first."""
    return (frame.isna().mean() * 100).sort_values(ascending=False)


def markdown_table(frame: pd.DataFrame) -> str:
    """Render a small DataFrame as a markdown table without optional packages."""
    table = frame.reset_index()
    if table.columns[0] == "index":
        table = table.rename(columns={"index": "metric"})
    columns = [str(column) for column in table.columns]
    rows = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join(["---"] * len(columns)) + " |",
    ]
    for row in table.itertuples(index=False):
        rows.append("| " + " | ".join(str(value) for value in row) + " |")
    return "\n".join(rows)


def profile_reviews() -> tuple[dict[str, object], pd.Series, pd.Series]:
    """Profile the large reviews file in chunks."""
    total_rows = 0
    min_date = None
    max_date = None
    unique_listings: set[int] = set()
    unique_reviewers: set[int] = set()
    seen_review_ids: set[int] = set()
    duplicate_review_ids = 0
    monthly_chunks = []
    listing_review_counts = None

    for chunk in pd.read_csv(
        REVIEWS_PATH,
        usecols=["listing_id", "review_id", "date", "reviewer_id"],
        dtype={"listing_id": "Int64", "review_id": "Int64", "reviewer_id": "Int64"},
        parse_dates=["date"],
        chunksize=500_000,
    ):
        total_rows += len(chunk)

        chunk_min = chunk["date"].min()
        chunk_max = chunk["date"].max()
        min_date = chunk_min if min_date is None or chunk_min < min_date else min_date
        max_date = chunk_max if max_date is None or chunk_max > max_date else max_date

        unique_listings.update(chunk["listing_id"].dropna().astype(int).unique())
        unique_reviewers.update(chunk["reviewer_id"].dropna().astype(int).unique())

        review_ids = chunk["review_id"].dropna().astype(int)
        duplicate_review_ids += int(review_ids.isin(seen_review_ids).sum())
        seen_review_ids.update(review_ids.unique())

        monthly_chunks.append(
            chunk.assign(month=chunk["date"].dt.to_period("M").dt.to_timestamp())
            .groupby("month")
            .size()
        )

        counts = chunk["listing_id"].value_counts()
        listing_review_counts = (
            counts
            if listing_review_counts is None
            else listing_review_counts.add(counts, fill_value=0)
        )

    monthly_reviews = (
        pd.concat(monthly_chunks, axis=1, sort=True).fillna(0).sum(axis=1).sort_index()
    )
    listing_review_counts = listing_review_counts.astype(int).rename("review_count")

    review_profile = {
        "rows": total_rows,
        "date_min": min_date.date(),
        "date_max": max_date.date(),
        "unique_listings": len(unique_listings),
        "unique_reviewers": len(unique_reviewers),
        "duplicate_review_ids": duplicate_review_ids,
    }
    return review_profile, monthly_reviews, listing_review_counts


def write_summary(
    listings: pd.DataFrame,
    review_profile: dict[str, object],
    city_summary: pd.DataFrame,
    room_summary: pd.DataFrame,
    missing: pd.Series,
) -> None:
    """Write a compact EDA summary for quick review."""
    price = listings["price"].describe(percentiles=[0.25, 0.5, 0.75, 0.9, 0.95, 0.99])
    rating = listings["review_scores_rating"].describe(
        percentiles=[0.25, 0.5, 0.75, 0.9, 0.95, 0.99]
    )

    lines = [
        "# Airbnb EDA Summary",
        "",
        "## Dataset Overview",
        "",
        f"- Listings rows: {len(listings):,}",
        f"- Review rows: {review_profile['rows']:,}",
        f"- Cities: {listings['city'].nunique():,}",
        f"- Hosts: {listings['host_id'].nunique():,}",
        f"- Property types: {listings['property_type'].nunique():,}",
        f"- Review date range: {review_profile['date_min']} to {review_profile['date_max']}",
        f"- Listings with at least one review: {review_profile['unique_listings']:,}",
        f"- Unique reviewers: {review_profile['unique_reviewers']:,}",
        f"- Duplicate listing IDs: {int(listings['listing_id'].duplicated().sum()):,}",
        f"- Duplicate review IDs: {review_profile['duplicate_review_ids']:,}",
        "",
        "## Data Quality Notes",
        "",
        "- `Listings.csv` requires `latin1` encoding because some listing names contain non-UTF-8 bytes.",
        "- The `district` field is mostly unavailable and should not be treated as a primary geography.",
        "- Review score fields are missing for roughly one-third of listings, mainly listings without enough review history.",
        "- Price has a strong right tail, so medians and percentiles are more reliable than averages for pricing analysis.",
        "",
        "### Highest Missingness",
        "",
        markdown_table(missing.head(10).round(2).to_frame("missing_pct")),
        "",
        "## Price Distribution",
        "",
        markdown_table(price.round(2).to_frame("price")),
        "",
        "## Rating Distribution",
        "",
        markdown_table(rating.round(2).to_frame("review_scores_rating")),
        "",
        "## City Summary",
        "",
        markdown_table(city_summary),
        "",
        "## Room Type Summary",
        "",
        markdown_table(room_summary),
        "",
        "## Key Findings",
        "",
        "- Paris has the largest supply, while Rome and Paris generate the highest review volume.",
        "- Entire-place listings dominate the marketplace and carry the highest median price among common room types.",
        "- Mexico City, Bangkok, and Cape Town show much higher nominal median prices, so currency differences should be considered before cross-city price comparisons.",
        "- Review activity accelerates sharply after 2015, dips around early 2020, and partially recovers by late 2020.",
        "",
        "## Generated Visualizations",
        "",
        "- `reports/figures/price_by_city_room_type.png`",
        "- `reports/figures/monthly_reviews_trend.png`",
        "",
    ]

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    (REPORTS_DIR / "eda_summary.md").write_text("\n".join(lines), encoding="utf-8")


def make_visualizations(
    listings_with_reviews: pd.DataFrame,
    monthly_reviews: pd.Series,
) -> None:
    """Create the requested visualizations."""
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    sns.set_theme(style="whitegrid", palette="Set2")

    common_room_types = ["Entire place", "Private room", "Hotel room", "Shared room"]
    city_room_price = (
        listings_with_reviews[listings_with_reviews["room_type"].isin(common_room_types)]
        .groupby(["city", "room_type"], as_index=False)["price"]
        .median()
    )

    city_order = (
        listings_with_reviews.groupby("city")["listing_id"]
        .count()
        .sort_values(ascending=False)
        .index
    )

    plt.figure(figsize=(13, 7))
    sns.barplot(
        data=city_room_price,
        x="city",
        y="price",
        hue="room_type",
        order=city_order,
    )
    plt.title("Median Listing Price by City and Room Type")
    plt.xlabel("City")
    plt.ylabel("Median price in local currency")
    plt.xticks(rotation=35, ha="right")
    plt.legend(title="Room type", ncol=2)
    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "price_by_city_room_type.png", dpi=180)
    plt.close()

    plt.figure(figsize=(13, 6))
    monthly_reviews.plot(color="#2F6F73", linewidth=2)
    plt.title("Monthly Airbnb Review Volume")
    plt.xlabel("Review month")
    plt.ylabel("Reviews")
    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "monthly_reviews_trend.png", dpi=180)
    plt.close()


def main() -> None:
    listings = pd.read_csv(LISTINGS_PATH, encoding="latin1", low_memory=False)
    listings["host_since"] = pd.to_datetime(listings["host_since"], errors="coerce")

    review_profile, monthly_reviews, listing_review_counts = profile_reviews()

    listings_with_reviews = listings.merge(
        listing_review_counts,
        how="left",
        left_on="listing_id",
        right_index=True,
    )
    listings_with_reviews["review_count"] = (
        listings_with_reviews["review_count"].fillna(0).astype(int)
    )

    city_summary = (
        listings_with_reviews.groupby("city")
        .agg(
            listings=("listing_id", "size"),
            median_price=("price", "median"),
            avg_rating=("review_scores_rating", "mean"),
            total_reviews=("review_count", "sum"),
            pct_superhost=("host_is_superhost", lambda s: (s == "t").mean() * 100),
        )
        .round(2)
        .sort_values("listings", ascending=False)
    )

    room_summary = (
        listings_with_reviews.groupby("room_type")
        .agg(
            listings=("listing_id", "size"),
            median_price=("price", "median"),
            avg_reviews=("review_count", "mean"),
            avg_rating=("review_scores_rating", "mean"),
        )
        .round(2)
        .sort_values("listings", ascending=False)
    )

    missing = pct_missing(listings)
    make_visualizations(listings_with_reviews, monthly_reviews)
    write_summary(listings, review_profile, city_summary, room_summary, missing)

    print("EDA complete")
    print(f"Summary: {REPORTS_DIR / 'eda_summary.md'}")
    print(f"Figure: {FIGURES_DIR / 'price_by_city_room_type.png'}")
    print(f"Figure: {FIGURES_DIR / 'monthly_reviews_trend.png'}")


if __name__ == "__main__":
    main()
