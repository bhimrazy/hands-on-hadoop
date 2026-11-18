"""Writes sales.csv and customers.csv next to this script. Fixed seed, so the output never changes."""
import csv
import random
from datetime import date, timedelta
from pathlib import Path

random.seed(7)
here = Path(__file__).parent

countries = ["Nepal", "India", "Japan", "Brazil", "Kenya"]
cities = {"Nepal": "Kathmandu", "India": "Pune", "Japan": "Osaka", "Brazil": "Recife", "Kenya": "Nairobi"}
products = {"notebook": 3.5, "pen": 1.2, "backpack": 24.0, "lamp": 18.5, "headphones": 39.9, "bottle": 9.0}
names = ["Asha", "Bikash", "Chen", "Dina", "Eli", "Farah", "Gita", "Hiro", "Ines", "Jomo"]

customers = []
for customer_id in range(1, 41):
    country = random.choice(countries)
    name = f"{random.choice(names)} {chr(64 + (customer_id % 26) + 1)}."
    customers.append((customer_id, name, country, cities[country]))

with open(here / "customers.csv", "w", newline="") as f:
    writer = csv.writer(f, lineterminator="\n")
    writer.writerow(["customer_id", "name", "country", "city"])
    writer.writerows(customers)

start = date(2026, 1, 1)
with open(here / "sales.csv", "w", newline="") as f:
    writer = csv.writer(f, lineterminator="\n")
    writer.writerow(["order_id", "customer_id", "product", "country", "quantity", "unit_price", "order_date"])
    for order_id in range(1, 301):
        customer_id, _, country, _ = random.choice(customers)
        product = random.choice(list(products))
        writer.writerow([
            order_id,
            customer_id,
            product,
            country,
            random.randint(1, 5),
            products[product],
            (start + timedelta(days=random.randint(0, 89))).isoformat(),
        ])
