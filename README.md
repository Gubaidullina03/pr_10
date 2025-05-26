# pr_10
## Аналитика с использованием сложных типов данных. Поиск и анализ продаж.

## Цель
Освоить навыки создания внутренней поисковой системы в базе данных PostgreSQL с использованием материализованных представлений и индексов GIN. Научиться преобразовывать запросы для поиска клиентов по различным критериям, включая их контактные данные и историю покупок. 

## Упражнение 1
Идентифицировать всех клиентов, купивших самокат Blade; используем данные, хранящиеся как JSNOB.

1. выделить каждую продажу в отдельную строку с помощью
функции JSONB_ARRAY_ELEMENTS;
```sql
CREATE TEMP TABLE customer_sales_single_sale_json AS (
SELECT
customer_json,
JSONB_ARRAY_ELEMENTS(customer_json -> 'sales') AS sale_json
FROM customer_sales LIMIT 10
);
```

Получим результат:

![пр 10 упр 1](https://github.com/user-attachments/assets/9eb414a6-e240-4162-9ef2-97b12f08dccd)


2. Отфильтровать этот вывод и получить записи, где product_name — «Blade»:
```sql
SELECT DISTINCT customer_json
FROM customer_sales_single_sale_json
WHERE sale_json ->> 'product_name' = 'Blade';
```

Получим результат:


![пр 10 упр 1 (1)](https://github.com/user-attachments/assets/6d6eea42-bf79-4174-992e-dfc2d3113099)

## Упражение 2
Количественно определить ключевые слова, которые соответствуют рейтингу выше среднего или рейтингу ниже среднего, используя текстовую аналитику. В базе данных есть доступ к некоторым отзывам клиентов, а также к рейтингам вероятности того, что клиент порекомендует своим друзьям компанию.

1. Посмотрим, какие данные есть:
```sql
SELECT * FROM customer_survey limit 5;
```

Получим результат:


![пр 10 упр 2](https://github.com/user-attachments/assets/464f762e-a4ae-41ba-9359-a9d5c3786f04)


2. Чтобы проанализировать текст, нужно разобрать его на отдельные слова и связанные с ними рейтинги.
```sql
SELECT UNNEST(STRING_TO_ARRAY(feedback, ' ')) AS word, rating
FROM customer_survey limit 10;
```

Получим результат:


![пр 10 упр 2 (1)](https://github.com/user-attachments/assets/afc127b5-0846-427f-84ef-fdfde55cb531)


3. Стандартизируем текст с помощью функции ts_lexize и стемминга(процесс нахождения основы слова для заданного исходного слова) английского языка english_stem. Затем удалим символы, которые не являются буквами в исходном тексте, используя REGEXP_REPLACE. Объединив эти две функции вместе с нашим исходным запросом, получим следующее:
```sql
SELECT
(TS_LEXIZE('english_stem',
UNNEST(STRING_TO_ARRAY(
REGEXP_REPLACE(feedback, '[^a-zA-Z]+', ' ', 'g'),
' ')
)))[1] AS token, rating
FROM customer_survey
LIMIT 10;
```

Получим результат:


![пр 10 упр 2 (2)](https://github.com/user-attachments/assets/d6d46bf4-ad36-40d1-a83e-35d2cf946773)

4. На следующем шаге найдем средний рейтинг, связанный с каждым токеном. Можем сделать это, просто используя предложение GROUP BY:
```sql
SELECT
(TS_LEXIZE('english_stem',
UNNEST(STRING_TO_ARRAY(
REGEXP_REPLACE(feedback, '[^a-zA-Z]+', ' ', 'g'),
' ')
)))[1] AS token,
AVG(rating) AS avg_rating
FROM customer_survey
GROUP BY 1
HAVING COUNT(1) >= 3
ORDER BY 2;
```

Получим результат:


![пр 10 упр 2 (3)](https://github.com/user-attachments/assets/1a00f44a-3106-4d11-adc2-27ff56bae5d6)

5. Проверим предположения, отфильтровав ответы на опросы, содержащие эти токены, с помощью выражения ILIKE следующим образом:
```sql
SELECT * FROM customer_survey WHERE feedback ILIKE '%pop%';
```

Получим результат:


![пр 10 упр 2 (4)](https://github.com/user-attachments/assets/92af3cfa-8832-4f1d-997e-b50689be334b)


## Практическое задание №10
Руководитель отдела продаж выявил проблему: у отдела продаж нет простого
способа поиска клиента. К счастью, вы согасились создать проверенную внутреннюю
поисковую систему, которая сделает всех клиентов доступными для поиска по их
контактной информации и продуктам, которые они приобрели в прошлом:

## Задачи:
1. Используя таблицу customer_sales, создать доступное для поиска представление с одной записью для каждого клиента. Это представление должно быть
изолировано от столбца customer_id и доступно для поиска по всей базе данных, которое связано с этим клиентом:
• имя,
• адрес электронной почты,
• телефон,
• приобретенные продукты.
Можно также включить и другие поля.
2. Создать доступный для поиска индекс для представления.
3. У кулера с водой продавец спрашивает, можете ли вы использовать свой новый поисковый прототип, чтобы найти покупателя по имени Дэнни, купившего скутер
Bat. Создать ЗАПРОС на представление с возможностью поиска, используя ключевые слова «Danny Bat». Какое количество строк вы получили?
4. Отдел продаж хочет знать, насколько часто люди покупают скутер и автомобиль. Выполнить перекрестное соединение таблицы продуктов, чтобы получить
все пары продуктов и удалите одинаковые пары (например, если название продукта совпадает). Для каждой пары выполнить поиск в представлении, чтобы узнать, сколько
клиентов соответствует обоим продуктам в паре. Можно предположить, что выпуски ограниченной серии можно сгруппировать вместе с их аналогом стандартной модели
(например, Bat и Bat Limited Edition можно считать одним и тем же скутером).

## Выполнение задания

1. Создадим материализованное представление для таблицы customer_sales:
```sql
CREATE MATERIALIZED VIEW customer_search2 AS (
SELECT
customer_json -> 'customer_id' AS customer_id, customer_json,to_tsvector('english', customer_json) AS search_vector FROM customer_sales
);
```

Получим результат:


![пр 10 пр 1](https://github.com/user-attachments/assets/dd36d9b6-1d80-4baa-a2be-81303da29147)



2. Создадим  индекс GIN в представлении:
```sql
CREATE INDEX customer_search_gin_idx2 ON customer_search2 USING GIN(search_vector);
```

Получим результат:


![пр 10 пр 2](https://github.com/user-attachments/assets/6a5e076b-63f7-45bf-9f74-1bbcdda7b8e1)


3. Выполним запрос, используя новую базу данных с возможностью поиска:
```sql
SELECT
customer_id,
customer_json
FROM customer_search2
WHERE search_vector @@ plainto_tsquery('english', 'Danny Bat');
```

Получим результат:


![пр 10 пр 3](https://github.com/user-attachments/assets/81d1d9a0-1eb1-4a30-901a-fa0308bf60d1)


4. Вывести уникальный список скутеров и автомобилей (и удаление граниченных выпусков) с помощью DISTINCT:
```sql
SELECT DISTINCT
p1.model,
p2.model
FROM products p1
LEFT JOIN products p2 ON TRUE
WHERE p1.product_type = 'scooter'
AND p2.product_type = 'automobile'
AND p1.model NOT ILIKE '%Limited
Edition%';
```

Получим результат:


![пр 10 пр 4](https://github.com/user-attachments/assets/d5469978-6100-4bc7-88b7-4f1cd88c3934)



5. Преобразуем вывод в запрос:
```sql
SELECT DISTINCT
plainto_tsquery('english', p1.model) &&
plainto_tsquery('english', p2.model)
FROM products p1
LEFT JOIN products p2 ON TRUE
WHERE p1.product_type = 'scooter'
AND p2.product_type = 'automobile'
AND p1.model NOT ILIKE '%Limited Edition%';
```


Получим результат:


![пр 10 пр 5](https://github.com/user-attachments/assets/0c887079-214c-4d88-8d47-8864d80a98a9)

## Вывод
Освоила навыки создания внутренней поисковой системы в базе данных PostgreSQL с использованием материализованных представлений и индексов GIN. Научилась преобразовывать запросы для поиска клиентов по различным критериям, включая их контактные данные и историю покупок. Научилась обрабатывать и анализировать данные с помощью SQL, включая использование tsvector, tsquery, plainto_tsquery.

## Структура репозитория:
- `Gubaidullina_Alina_Ilshatovna_pr10.sql` — SQL скрипт.

