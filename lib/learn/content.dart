// Learning content for the Learn tab. Lesson bodies use a tiny markup:
// "## " heading, "- " bullet, "> " tip box, lines between ``` are code.

class QuizQ {
  final String q;
  final List<String> options;
  final int answer;
  final String why;
  const QuizQ(this.q, this.options, this.answer, this.why);
}

class Lesson {
  final String key;
  final String title;
  final int minutes;
  final String body;
  final List<QuizQ> quiz;
  final String video; // YouTube search phrase
  final String? practice; // 'sheet' or 'sql'
  const Lesson(this.key, this.title, this.minutes, this.body, this.quiz, this.video, {this.practice});
}

class Track {
  final String key;
  final String title;
  final String emoji;
  final String blurb;
  final List<Lesson> lessons;
  const Track(this.key, this.title, this.emoji, this.blurb, this.lessons);
}

const tracks = <Track>[
  Track('fnd', 'Data Analysis Foundations', '🧭', 'What analysts do, types of data, cleaning and basic statistics.', [
    Lesson('fnd1', 'What is data analysis?', 6, r'''
Data analysis is turning raw facts into answers that help people decide. A shop owner asking "which product sells best in December?" needs data analysis.

## What a data analyst does
- Collects data from spreadsheets, apps and databases
- Cleans it so it is correct and consistent
- Looks for patterns, totals and trends
- Shares findings with charts and short reports

## The 6 steps
- **Ask**: what question are we answering?
- **Prepare**: find and collect the right data
- **Process**: clean it (fix errors, remove duplicates)
- **Analyse**: calculate, compare, find patterns
- **Share**: charts, dashboards, a clear message
- **Act**: the business makes a decision

> You already analyse data every day. Tracking the baby's feeds and seeing "she feeds more in the evening" is a real insight!
''', [
      QuizQ('What is the FIRST step in data analysis?', ['Make a chart', 'Ask a clear question', 'Clean the data', 'Buy software'], 1,
          'Everything starts with a clear question. It decides what data you need.'),
      QuizQ('Removing duplicate rows happens in which step?', ['Share', 'Act', 'Process', 'Ask'], 2,
          'Process (cleaning) is where you fix errors and remove duplicates.'),
      QuizQ('Which is the best example of an insight?', ['We have 500 rows', 'Sales drop every January by about 30%', 'The file is in Excel', 'Data is important'], 1,
          'An insight is a useful pattern someone can act on.'),
    ], 'what does a data analyst do beginner'),
    Lesson('fnd2', 'Types of data', 6, r'''
Data comes in different types, and the type decides what you can do with it.

## Numbers vs. categories
- **Quantitative** (numbers): price, age, quantity. You can add and average them.
- **Qualitative** (categories/text): city, product name, payment method. You count and group them.

## Tables
Most data lives in tables:
- Each **row** is one record (one order, one customer)
- Each **column** is one field (date, city, price)
- The first row is usually the **header**

## Common data types
- Text (string): "Lagos"
- Whole number (integer): 3
- Decimal: 8500.50
- Date: 2025-11-21
- True/False (boolean)

> Keep one type per column. A "Price" column with "₦8,500" and "8500" mixed together causes errors later.
''', [
      QuizQ('Which of these is quantitative data?', ['City', 'Product name', 'Quantity sold', 'Payment method'], 2,
          'Quantity is a number you can add or average.'),
      QuizQ('In a sales table, one row usually represents...', ['One column', 'One record, like one order', 'The whole dataset', 'A chart'], 1,
          'Each row is a single record.'),
      QuizQ('What should a single column contain?', ['Any mix of types', 'One consistent type of data', 'Only text', 'Only dates'], 1,
          'Consistent types make calculations reliable.'),
    ], 'types of data quantitative qualitative explained'),
    Lesson('fnd3', 'Cleaning data', 7, r'''
Real data is messy. Analysts often spend most of their time cleaning it. Clean data = trustworthy results.

## Common problems
- **Duplicates**: the same order entered twice
- **Missing values**: an empty "city" cell
- **Inconsistent spelling**: "Lagos", "lagos", "LAGOS "
- **Wrong types**: numbers saved as text
- **Typos and outliers**: a price of ₦85,000,000 for diapers

## How to fix them
- Remove exact duplicate rows
- Decide how to handle blanks: fill, mark as "Unknown", or remove the row
- Trim extra spaces and use the same capitalisation
- Convert text numbers into real numbers
- Check very high or low values and confirm them

> Never overwrite the original file. Keep a copy of the raw data and clean a new copy.
''', [
      QuizQ('"Lagos " and "lagos" in the same column are an example of...', ['Outliers', 'Inconsistent formatting', 'Correct data', 'A pivot table'], 1,
          'Same value, different spelling/spacing. Trim and standardise.'),
      QuizQ('What should you do with the raw data file?', ['Delete it', 'Overwrite it while cleaning', 'Keep it and clean a copy', 'Email it to everyone'], 2,
          'Always keep the original so you can start again if needed.'),
      QuizQ('A diaper price of ₦85,000,000 is probably...', ['A great deal', 'An outlier or typo to check', 'Normal', 'A date'], 1,
          'Unusually extreme values should be checked.'),
    ], 'data cleaning for beginners excel'),
    Lesson('fnd4', 'Basic statistics', 7, r'''
A few simple numbers describe a whole dataset.

## The big four
- **Mean (average)**: add all values, divide by how many. 2, 4, 6 → 12 ÷ 3 = 4
- **Median**: the middle value when sorted. 1, 3, 100 → 3
- **Mode**: the most common value
- **Range**: biggest minus smallest

## Mean or median?
The mean is pulled by extreme values. Salaries of 50k, 60k, 70k and 2,000k have a mean of 545k, but the median (65k) describes a "typical" person much better.

## Percentage change
```
(new - old) / old × 100
```
Sales went from 200 to 250: (250 − 200) ÷ 200 × 100 = **25% increase**.

> When someone says "average", ask: mean or median? It can change the story.
''', [
      QuizQ('What is the median of 3, 9, 4?', ['4', '9', '5.3', '3'], 0, 'Sorted: 3, 4, 9. The middle value is 4.'),
      QuizQ('Sales went from 400 to 300. What is the % change?', ['+25%', '-25%', '-33%', '-100%'], 1, '(300 − 400) ÷ 400 × 100 = −25%.'),
      QuizQ('Which is better for typical income when a few people earn a LOT more?', ['Mean', 'Median', 'Range', 'Sum'], 1,
          'The median is not pulled up by extreme values.'),
    ], 'mean median mode explained simply'),
  ]),
  Track('xl', 'Excel & Google Sheets', '📗', 'Formulas, functions, lookups, cleaning, pivot tables and charts.', [
    Lesson('xl1', 'Cells, ranges and formulas', 7, r'''
A spreadsheet is a grid. Columns are letters (A, B, C), rows are numbers (1, 2, 3). Each box is a **cell**, named by column + row, like **B3**.

## Formulas start with =
```
=A1+B1
=B2*C2
=(A1+A2)/2
```

## Ranges
A range is a block of cells: **A1:A10** means A1 down to A10.

## Copying formulas
If C2 has `=A2*B2` and you copy it down, C3 becomes `=A3*B3`. That's a **relative** reference.

To lock a cell, use **$**: `=B2*$F$1` always uses F1 (an **absolute** reference). Useful for a tax rate or exchange rate in one cell.

> Try it in the Spreadsheet Lab: put prices in column A, quantities in B, and `=A1*B1` in C1.
''', [
      QuizQ('What does every formula start with?', ['+', '=', '#', '@'], 1, 'Formulas begin with the equals sign.'),
      QuizQ('Which reference stays fixed when copied?', ['A1', 'A\$1 only', '\$A\$1', 'A:A'], 2, 'Dollar signs on both column and row lock the reference.'),
      QuizQ('The range B2:B5 contains how many cells?', ['2', '3', '4', '5'], 2, 'B2, B3, B4 and B5.'),
    ], 'excel formulas for beginners relative absolute reference', practice: 'sheet'),
    Lesson('xl2', 'Core functions', 7, r'''
Functions are ready-made formulas.

## The essentials
```
=SUM(B2:B20)       total
=AVERAGE(B2:B20)   mean
=MIN(B2:B20)       smallest
=MAX(B2:B20)       biggest
=COUNT(B2:B20)     how many numbers
=COUNTA(A2:A20)    how many non-empty cells
=ROUND(B2, 0)      round to whole number
```

## Combine them
```
=MAX(B2:B20)-MIN(B2:B20)    range
=ROUND(AVERAGE(B2:B20), 2)  average to 2 decimals
```

> COUNT only counts numbers. If your "numbers" are stored as text, COUNT will skip them. That's a clue the data needs cleaning!
''', [
      QuizQ('Which function gives the total of a range?', ['COUNT', 'SUM', 'MAX', 'TOTALIZE'], 1, 'SUM adds all the numbers.'),
      QuizQ('COUNTA counts...', ['Only numbers', 'Non-empty cells', 'Empty cells', 'Sums'], 1, 'COUNTA counts anything that isn\'t blank.'),
      QuizQ('=MAX(A1:A5)-MIN(A1:A5) calculates the...', ['Mean', 'Median', 'Range', 'Mode'], 2, 'Biggest minus smallest is the range.'),
    ], 'excel SUM AVERAGE COUNT MIN MAX tutorial', practice: 'sheet'),
    Lesson('xl3', 'IF, COUNTIF, SUMIF and lookups', 9, r'''
## IF: make decisions
```
=IF(B2>=10000, "High", "Low")
```

## Conditional counts and totals
```
=COUNTIF(C2:C100, "Lagos")            orders from Lagos
=SUMIF(C2:C100, "Lagos", D2:D100)     sales from Lagos
=AVERAGEIF(C2:C100, "Abuja", D2:D100)
```

## Looking things up
You have a product ID and want its price from another table:
```
=XLOOKUP(A2, Products!A:A, Products!C:C)
```
Older Excel uses VLOOKUP:
```
=VLOOKUP(A2, Products!A:C, 3, FALSE)
```
FALSE means "exact match". Almost always use it.

> XLOOKUP works in Excel 365 and Google Sheets. It's easier and safer than VLOOKUP.
''', [
      QuizQ('Which formula counts how many cells in C2:C50 say "Kano"?', ['=SUM(C2:C50,"Kano")', '=COUNTIF(C2:C50,"Kano")', '=IF(C2="Kano")', '=COUNT("Kano")'], 1,
          'COUNTIF counts cells that meet a condition.'),
      QuizQ('In VLOOKUP, FALSE as the last argument means...', ['Approximate match', 'Exact match', 'Ignore errors', 'Sort first'], 1, 'FALSE = exact match.'),
      QuizQ('=IF(A1>50,"Pass","Fail") returns what when A1 is 40?', ['Pass', 'Fail', '40', 'Error'], 1, '40 is not greater than 50, so "Fail".'),
    ], 'excel IF COUNTIF SUMIF XLOOKUP tutorial'),
    Lesson('xl4', 'Sort, filter and clean', 7, r'''
## Sort and filter
- **Sort** reorders rows (A→Z, biggest first). Select the whole table so rows stay together.
- **Filter** hides rows you don't need. Data → Filter, then click the arrow on a header.

## Cleaning functions
```
=TRIM(A2)       removes extra spaces
=PROPER(A2)     "adaEZE okafor" → "Adaeze Okafor"
=UPPER(A2)  =LOWER(A2)
=VALUE(A2)      text "8500" → number 8500
=LEFT(A2, 3)  =RIGHT(A2, 4)  =LEN(A2)
```

## Built-in tools
- **Remove duplicates**: Data → Remove duplicates
- **Text to columns**: split "Adaeze Okafor" into first and last name
- **Conditional formatting**: colour cells, e.g. red if sales < 5,000

> Clean in a new column (e.g. =TRIM(PROPER(A2))), check it, then paste as values.
''', [
      QuizQ('Which function removes extra spaces?', ['CLEAN', 'TRIM', 'SPACE', 'CUT'], 1, 'TRIM removes leading, trailing and double spaces.'),
      QuizQ('Before sorting, you should...', ['Select only one column', 'Select the whole table', 'Delete headers', 'Save as PDF'], 1,
          'Otherwise one column moves and the rows get mixed up.'),
      QuizQ('PROPER("ngozi NWOSU") gives...', ['NGOZI NWOSU', 'ngozi nwosu', 'Ngozi Nwosu', 'Ngozi nwosu'], 2, 'PROPER capitalises the first letter of each word.'),
    ], 'excel data cleaning TRIM PROPER remove duplicates'),
    Lesson('xl5', 'Pivot tables and charts', 9, r'''
A **pivot table** summarises thousands of rows in seconds, without formulas.

## Make one
- Click inside your table
- Insert → PivotTable
- Drag **City** to Rows
- Drag **Sales** to Values (it shows Sum of Sales)
- Drag **Month** to Columns to compare months

Now you can answer "Which city sold the most each month?" instantly.

## Charts
- **Column/bar**: compare categories (sales by city)
- **Line**: change over time (sales by month)
- **Pie**: parts of a whole. Only use with a few slices!

## Good chart habits
- Clear title that states the point: "Lagos brings 40% of revenue"
- Label axes, remove clutter
- Sort bars from biggest to smallest

> Pivot table + chart = your first mini dashboard. Great for your portfolio.
''', [
      QuizQ('What is a pivot table best for?', ['Typing data', 'Summarising lots of rows quickly', 'Fixing typos', 'Sending emails'], 1,
          'Pivot tables group and total data quickly.'),
      QuizQ('Best chart for sales over 12 months?', ['Pie', 'Line', 'Scatter', 'Map'], 1, 'Line charts show change over time.'),
      QuizQ('A good chart title...', ['Says "Chart 1"', 'States the main point', 'Is left blank', 'Lists every number'], 1,
          'A title like "Lagos brings 40% of revenue" tells the story.'),
    ], 'excel pivot table tutorial beginners'),
  ]),
  Track('sql', 'SQL Basics', '🗄️', 'Ask questions of databases. Practise live in the SQL Lab.', [
    Lesson('sql1', 'Databases and SELECT', 7, r'''
A **database** stores tables. **SQL** is the language to ask them questions. Every analyst job asks for it.

Your SQL Lab has three practice tables:
- **customers** (id, name, city, joined_on)
- **products** (id, name, category, price)
- **orders** (id, customer_id, product_id, qty, order_date)

## SELECT
```
SELECT name, city
FROM customers;
```
Get every column:
```
SELECT * FROM products;
```
Rename a column with AS:
```
SELECT name, price AS price_naira FROM products;
```

> Open the SQL Lab and run SELECT * FROM customers. You've just queried a database!
''', [
      QuizQ('Which keyword chooses the columns?', ['FROM', 'SELECT', 'WHERE', 'TABLE'], 1, 'SELECT lists the columns you want.'),
      QuizQ('SELECT * means...', ['Select nothing', 'Select all columns', 'Multiply', 'Select the first row'], 1, '* means every column.'),
      QuizQ('Which tells SQL which table to read?', ['FROM', 'AS', 'INTO', 'GET'], 0, 'FROM names the table.'),
    ], 'SQL SELECT tutorial for beginners', practice: 'sql'),
    Lesson('sql2', 'Filtering with WHERE', 8, r'''
WHERE keeps only rows that match a condition.
```
SELECT * FROM customers
WHERE city = 'Lagos';
```

## Operators
- `=`, `<>` (not equal), `>`, `<`, `>=`, `<=`
- `AND`, `OR`, `NOT`
- `IN ('Lagos', 'Abuja')`
- `BETWEEN 5000 AND 10000`
- `LIKE 'Baby%'` (starts with Baby)

```
SELECT name, price FROM products
WHERE category = 'Food' AND price > 10000;

SELECT * FROM products
WHERE name LIKE '%Soap%';
```

> Text goes in single quotes: 'Lagos'. Numbers don't: 10000.
''', [
      QuizQ('Which finds customers in Lagos OR Abuja?', ["WHERE city = 'Lagos' AND city = 'Abuja'", "WHERE city IN ('Lagos','Abuja')", "WHERE city LIKE Lagos", "WHERE Lagos OR Abuja"], 1,
          'IN matches any value in the list.'),
      QuizQ("LIKE 'Baby%' matches...", ['Anything ending in Baby', 'Anything starting with Baby', 'Exactly Baby%', 'Nothing'], 1, '% means "anything after".'),
      QuizQ('Which operator means "not equal"?', ['!=', '<>', 'Both work in most databases', 'NOT='], 2, 'Both != and <> work in PostgreSQL and most databases.'),
    ], 'SQL WHERE clause AND OR IN LIKE', practice: 'sql'),
    Lesson('sql3', 'Sorting and limiting', 5, r'''
## ORDER BY
```
SELECT name, price FROM products
ORDER BY price DESC;
```
- ASC = smallest first (default)
- DESC = biggest first

Sort by two columns:
```
SELECT * FROM customers
ORDER BY city, name;
```

## LIMIT
Top 3 most expensive products:
```
SELECT name, price FROM products
ORDER BY price DESC
LIMIT 3;
```

## DISTINCT
Unique values only:
```
SELECT DISTINCT city FROM customers;
```
''', [
      QuizQ('Which shows the most expensive product first?', ['ORDER BY price', 'ORDER BY price DESC', 'ORDER BY price ASC', 'SORT price UP'], 1, 'DESC = descending, biggest first.'),
      QuizQ('LIMIT 5 returns...', ['5 columns', 'At most 5 rows', 'Rows 5 onwards', 'Every 5th row'], 1, 'LIMIT caps the number of rows.'),
      QuizQ('SELECT DISTINCT city returns...', ['Every row', 'Each city once', 'Only Lagos', 'The number of cities'], 1, 'DISTINCT removes duplicates.'),
    ], 'SQL ORDER BY LIMIT DISTINCT', practice: 'sql'),
    Lesson('sql4', 'Counting and grouping', 9, r'''
## Aggregate functions
`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
```
SELECT COUNT(*) AS total_orders FROM orders;
SELECT AVG(price) FROM products;
```

## GROUP BY
One result per group:
```
SELECT city, COUNT(*) AS customers
FROM customers
GROUP BY city
ORDER BY customers DESC;
```

## HAVING
Filter groups (WHERE filters rows, HAVING filters groups):
```
SELECT category, AVG(price) AS avg_price
FROM products
GROUP BY category
HAVING AVG(price) > 8000;
```

> Every column in SELECT must be in GROUP BY or inside an aggregate like SUM().
''', [
      QuizQ('Which counts rows?', ['SUM(*)', 'COUNT(*)', 'TOTAL()', 'ROWS()'], 1, 'COUNT(*) counts rows.'),
      QuizQ('Which filters AFTER grouping?', ['WHERE', 'HAVING', 'ORDER BY', 'LIMIT'], 1, 'HAVING filters groups.'),
      QuizQ('To get total quantity per product_id, you need...', ['GROUP BY product_id', 'ORDER BY qty', 'DISTINCT qty', 'LIMIT 1'], 0, 'Group by the thing you want one row for.'),
    ], 'SQL GROUP BY HAVING COUNT SUM tutorial', practice: 'sql'),
    Lesson('sql5', 'Joining tables', 10, r'''
Orders only store customer_id and product_id. To see names and prices, **JOIN** the tables.

```
SELECT o.id, c.name, c.city, o.qty
FROM orders o
JOIN customers c ON c.id = o.customer_id;
```
`o` and `c` are short nicknames (aliases).

## Three tables
```
SELECT c.name, p.name AS product, o.qty, o.qty * p.price AS amount
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN products p ON p.id = o.product_id
ORDER BY amount DESC;
```

## Revenue by city
```
SELECT c.city, SUM(o.qty * p.price) AS revenue
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN products p ON p.id = o.product_id
GROUP BY c.city
ORDER BY revenue DESC;
```

## JOIN types
- **INNER JOIN** (JOIN): only matching rows
- **LEFT JOIN**: all rows from the left table, even with no match
''', [
      QuizQ('What does JOIN ... ON c.id = o.customer_id do?', ['Deletes orders', 'Matches each order to its customer', 'Sorts customers', 'Counts rows'], 1,
          'ON says which columns connect the tables.'),
      QuizQ('Which keeps ALL customers, even those with no orders?', ['INNER JOIN', 'LEFT JOIN from customers', 'GROUP BY', 'DISTINCT'], 1,
          'LEFT JOIN keeps every row of the left table.'),
      QuizQ('In "FROM orders o", what is o?', ['A typo', 'An alias (nickname) for orders', 'A column', 'A function'], 1, 'Aliases make queries shorter.'),
    ], 'SQL JOIN explained inner left join', practice: 'sql'),
    Lesson('sql6', 'Real analyst questions', 10, r'''
Put it all together. Try each in the SQL Lab.

## Best-selling products
```
SELECT p.name, SUM(o.qty) AS units
FROM orders o JOIN products p ON p.id = o.product_id
GROUP BY p.name
ORDER BY units DESC
LIMIT 5;
```

## Revenue by month
```
SELECT date_trunc('month', order_date) AS month,
       SUM(o.qty * p.price) AS revenue
FROM orders o JOIN products p ON p.id = o.product_id
GROUP BY month
ORDER BY month;
```

## Labelling with CASE
```
SELECT name, price,
  CASE WHEN price >= 12000 THEN 'Premium'
       WHEN price >= 6000 THEN 'Standard'
       ELSE 'Budget' END AS tier
FROM products;
```

> Write the question in plain English first, then translate it to SQL, one clause at a time.
''', [
      QuizQ('CASE WHEN is used to...', ['Join tables', 'Create labels based on conditions', 'Delete rows', 'Count rows'], 1, 'CASE creates new values from rules.'),
      QuizQ("date_trunc('month', order_date) does what?", ['Deletes dates', 'Rounds dates down to the month', 'Adds a month', 'Formats as text'], 1,
          'It groups dates into months.'),
      QuizQ('Good first step before writing a query?', ['Guess', 'Write the question in plain English', 'Use SELECT * always', 'Skip WHERE'], 1,
          'Clear question → clear query.'),
    ], 'SQL for data analysis practice questions', practice: 'sql'),
  ]),
  Track('bi', 'Dashboards & Power BI', '📊', 'Pick the right charts, design KPIs and tell stories with data.', [
    Lesson('bi1', 'Choosing the right chart', 6, r'''
## Match the chart to the question
- **Compare categories** → bar/column chart
- **Change over time** → line chart
- **Part of a whole** → pie/donut (max 4–5 slices) or stacked bar
- **Relationship between two numbers** → scatter plot
- **One key number** → big number card (KPI)
- **Exact values** → a table

## Avoid
- 3D charts (they distort sizes)
- Too many colours
- Pie charts with 10 slices
- Bars that don't start at zero

> Use one highlight colour for the thing you want people to notice, and grey for everything else.
''', [
      QuizQ('Best chart to compare sales across 6 cities?', ['Pie', 'Bar chart', 'Line', 'Scatter'], 1, 'Bars compare categories clearly.'),
      QuizQ('Best chart for one headline number like "Total revenue"?', ['KPI card', 'Pie', 'Scatter', 'Map'], 0, 'A big number card is clearest.'),
      QuizQ('Why avoid 3D charts?', ['They load slowly', 'They distort sizes', 'They are illegal', 'They need Python'], 1, 'Perspective makes values look bigger or smaller.'),
    ], 'how to choose the right chart data visualization'),
    Lesson('bi2', 'KPIs and dashboard design', 7, r'''
A **KPI** (Key Performance Indicator) is a number that shows if things are going well: total revenue, orders this month, average order value, % growth.

## Dashboard layout
- **Top row**: 3–5 KPI cards
- **Middle**: the main trend (line chart over time)
- **Bottom**: breakdowns (by city, by product)
- **Side or top**: filters (date range, region)

## Rules of thumb
- One dashboard = one audience and one purpose
- Most important things top-left
- Compare to something: last month, target, last year
- Keep it to one screen

> Example KPI set for a shop: Revenue, Orders, Average order value, Top product.
''', [
      QuizQ('What is a KPI?', ['A type of chart', 'A key number that shows performance', 'A database', 'A formula error'], 1, 'KPIs measure what matters.'),
      QuizQ('Where should KPI cards usually go?', ['Bottom right', 'Top of the dashboard', 'Hidden page', 'Footer'], 1, 'People read top-left first.'),
      QuizQ('Why compare KPIs to last month or a target?', ['It looks busy', 'A number alone has no context', 'It is required by law', 'To add colour'], 1,
          'Context shows if the number is good or bad.'),
    ], 'dashboard design best practices KPI'),
    Lesson('bi3', 'A tour of Power BI', 9, r'''
**Power BI Desktop** is free from Microsoft (Windows). Many Nigerian companies list it in analyst jobs.

## The workflow
- **Get Data**: Excel, CSV, SQL databases and more
- **Power Query** (Transform data): clean it: remove columns, fix types, split, merge
- **Model**: connect tables (orders → customers) by matching columns
- **Report**: drag fields onto visuals: cards, bars, lines, slicers
- **Publish**: share to the Power BI service

## DAX (Power BI formulas)
```
Total Revenue = SUM(Sales[Amount])
Orders = COUNTROWS(Sales)
Avg Order = DIVIDE([Total Revenue], [Orders])
```

## Free alternatives
Google Looker Studio (in the browser) and Excel charts are great for practice.

> Practise with a free dataset from Kaggle, then add the dashboard to your Portfolio.
''', [
      QuizQ('Where do you clean data in Power BI?', ['Power Query', 'Slicer', 'Publish', 'DAX card'], 0, 'Power Query (Transform data) is for cleaning.'),
      QuizQ('DAX is...', ['A chart type', 'The formula language of Power BI', 'A database', 'A file format'], 1, 'DAX creates measures like Total Revenue.'),
      QuizQ('A slicer is used to...', ['Filter the report', 'Delete data', 'Write SQL', 'Print'], 0, 'Slicers let viewers filter visuals.'),
    ], 'Power BI tutorial for beginners full'),
    Lesson('bi4', 'Telling a story with data', 6, r'''
Numbers persuade people when they come with a clear message.

## The story structure
- **Context**: what question did we ask?
- **Finding**: what did we discover? (one sentence)
- **Evidence**: the chart that proves it
- **Action**: what should we do next?

## Example
"Lagos customers bring 40% of revenue but only 30% of orders, because they buy bigger baskets. **Recommendation:** offer free delivery in Lagos for orders over ₦20,000."

## Tips
- Lead with the answer, not the method
- One message per slide or chart
- Use plain words: "fell by a quarter" beats "−24.7%"

> Practise: write a 3-sentence story about your own Kids tracker. What pattern do you see in the feeds or sleep?
''', [
      QuizQ('What should you lead with?', ['The method', 'The main finding', 'A list of tools', 'Your CV'], 1, 'Busy people want the answer first.'),
      QuizQ('What does a good data story end with?', ['A joke', 'A recommended action', 'More data', 'Nothing'], 1, 'Insights should lead to action.'),
      QuizQ('How many main messages per chart?', ['One', 'Three', 'As many as possible', 'None'], 0, 'One clear message per chart.'),
    ], 'data storytelling for analysts'),
  ]),
  Track('py', 'Python for Data', '🐍', 'Python basics, pandas DataFrames and charts.', [
    Lesson('py1', 'Python basics', 8, r'''
Python is a friendly programming language used for data analysis. Practise free in your browser with **Google Colab** (colab.research.google.com).

## Variables and types
```
name = "Adaeze"
age = 28
price = 8500.50
is_member = True
print(name, age)
```

## Lists
```
sales = [1200, 3400, 2500]
print(sum(sales))        # 7100
print(len(sales))        # 3
print(max(sales))        # 3400
```

## Loops and conditions
```
for s in sales:
    if s > 2000:
        print("Big sale:", s)
```

> Indentation (spaces at the start of a line) matters in Python.
''', [
      QuizQ('What does print(len([5, 8, 2])) show?', ['15', '3', '8', '2'], 1, 'len counts the items: 3.'),
      QuizQ('Which is a list?', ['"sales"', '[10, 20, 30]', '10.5', 'True'], 1, 'Square brackets make a list.'),
      QuizQ('In Python, indentation...', ['Is ignored', 'Defines code blocks', 'Is only for style', 'Causes errors always'], 1,
          'Indented lines belong to the if/for above them.'),
    ], 'python for beginners data analysis google colab'),
    Lesson('py2', 'pandas DataFrames', 9, r'''
**pandas** is the Python library for tables. A table is called a **DataFrame**.

```
import pandas as pd

df = pd.read_csv("sales.csv")
df.head()        # first 5 rows
df.shape         # (rows, columns)
df.info()        # column types and blanks
df.describe()    # mean, min, max...
```

## Select columns
```
df["city"]
df[["city", "amount"]]
```

## New columns
```
df["amount"] = df["qty"] * df["price"]
```

> In Colab, upload a CSV with the folder icon on the left, then read it with pd.read_csv.
''', [
      QuizQ('What is a DataFrame?', ['A chart', 'A pandas table', 'A loop', 'A database server'], 1, 'DataFrames are tables in pandas.'),
      QuizQ('df.head() shows...', ['The last rows', 'The first 5 rows', 'Column names only', 'A chart'], 1, 'head() previews the top rows.'),
      QuizQ('Which gives summary statistics?', ['df.describe()', 'df.print()', 'df.stats', 'df.sum_all()'], 0, 'describe() shows count, mean, min, max and more.'),
    ], 'pandas tutorial for beginners dataframe'),
    Lesson('py3', 'Filter, group and sort', 9, r'''
Same ideas as SQL, in pandas.

## Filter
```
lagos = df[df["city"] == "Lagos"]
big = df[df["amount"] > 10000]
both = df[(df["city"] == "Lagos") & (df["amount"] > 10000)]
```

## Group
```
df.groupby("city")["amount"].sum()
df.groupby("category")["price"].mean()
```

## Sort
```
df.sort_values("amount", ascending=False).head(10)
```

## Clean
```
df = df.drop_duplicates()
df["city"] = df["city"].str.strip().str.title()
df["amount"] = df["amount"].fillna(0)
```
''', [
      QuizQ('Which keeps only Lagos rows?', ['df.city("Lagos")', 'df[df["city"] == "Lagos"]', 'df.sort("Lagos")', 'df.groupby("Lagos")'], 1, 'Boolean filtering with ==.'),
      QuizQ('df.groupby("city")["amount"].sum() is like SQL...', ['ORDER BY', 'GROUP BY with SUM', 'JOIN', 'LIMIT'], 1, 'Same idea as GROUP BY.'),
      QuizQ('drop_duplicates() does what?', ['Removes repeated rows', 'Deletes columns', 'Sorts', 'Fills blanks'], 0, 'It removes duplicate rows.'),
    ], 'pandas groupby filter sort tutorial'),
    Lesson('py4', 'Charts and your next steps', 8, r'''
## Charts with pandas
```
import matplotlib.pyplot as plt

df.groupby("city")["amount"].sum().sort_values().plot(kind="barh")
plt.title("Revenue by city")
plt.show()
```
- `kind="line"` for trends, `"bar"` / `"barh"` for comparisons, `"hist"` for distributions

## Your roadmap to a junior analyst role
- Finish all tracks here
- Take a structured course (e.g. Google Data Analytics on Coursera, often with financial aid)
- Build 3 projects: Excel dashboard, SQL analysis, Power BI or Python report
- Share them on LinkedIn and GitHub. Add them to your **Portfolio** here
- Practise with real datasets on Kaggle

> Your MomOS data is a great first project: "What I learned from 3 months of baby sleep data."
''', [
      QuizQ('Which chart type shows a trend over time?', ['hist', 'line', 'pie', 'barh only'], 1, 'Line charts show trends.'),
      QuizQ('How many portfolio projects is a good start?', ['0', 'About 3', '50', 'Only a certificate'], 1, 'A few strong projects beat many weak ones.'),
      QuizQ('Where can you find free practice datasets?', ['Kaggle', 'Only paid sites', 'Nowhere', 'Instagram'], 0, 'Kaggle has thousands of free datasets.'),
    ], 'matplotlib pandas plot tutorial beginners'),
  ]),
];

Lesson? lessonByKey(String key) {
  for (final t in tracks) {
    for (final l in t.lessons) {
      if (l.key == key) return l;
    }
  }
  return null;
}

Track trackOf(String lessonKey) => tracks.firstWhere((t) => t.lessons.any((l) => l.key == lessonKey));
