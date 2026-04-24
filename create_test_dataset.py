import csv
import random

# Create synthetic binary classification dataset
random.seed(42)
rows = 1000

features = ['feature_' + str(i) for i in range(1, 11)]
headers = features + ['label']

data = []
for i in range(rows):
    row = [str(random.gauss(50, 15)) for _ in range(10)]
    label = '1' if sum(float(x) for x in row) > 500 else '0'
    row.append(label)
    data.append(row)

with open('test_dataset.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerows(data)

print(f'Created test_dataset.csv with {len(data)} rows')
