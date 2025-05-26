--Практическая работа №10

--Упражнение 1
--Идентифицировать всех клиентов,
--купивших самокат Blade; используем
--данные, хранящиеся как JSNOB.

--1. выделить каждую продажу в отдельную строку с помощью
--функции JSONB_ARRAY_ELEMENTS;

CREATE TEMP TABLE customer_sales_single_sale_json AS (
SELECT
customer_json,
JSONB_ARRAY_ELEMENTS(customer_json -> 'sales') AS sale_json
FROM customer_sales LIMIT 10
);

--2. отфильтровать этот вывод и получить записи, где
--product_name — «Blade»:

SELECT DISTINCT customer_json
FROM customer_sales_single_sale_json
WHERE sale_json ->> 'product_name' = 'Blade';

-- отфильтровать этот вывод и получить записи, где
--product_name — «Blade»:

SELECT DISTINCT JSONB_PRETTY(customer_json)
FROM customer_sales_single_sale_json
WHERE sale_json ->> 'product_name' = 'Blade' ;



--Упражение 2
--Количественно определить ключевые слова,
--которые соответствуют рейтингу выше среднего или
--рейтингу ниже среднего, используя текстовую
--аналитику. В базе данных есть доступ к некоторым
--отзывам клиентов, а также к рейтингам вероятности
--того, что клиент порекомендует своим друзьям
--компанию.

--1. посмотрим, какие данные есть:

SELECT * FROM customer_survey limit 5;


--2. Чтобы проанализировать текст, нужно разобрать его
--на отдельные слова и связанные с ними рейтинги.


SELECT UNNEST(STRING_TO_ARRAY(feedback, ' ')) AS word, rating
FROM customer_survey limit 10;

--3. Стандартизируем текст с помощью функции
--ts_lexize и стемминга(процесс нахождения основы
--слова для заданного исходного слова) английского
--языка english_stem.
--Затем удалим символы, которые не являются
--буквами в исходном тексте, используя
--REGEXP_REPLACE. Объединив эти две функции
--вместе с нашим исходным запросом, получим
--следующее:

SELECT
(TS_LEXIZE('english_stem',
UNNEST(STRING_TO_ARRAY(
REGEXP_REPLACE(feedback, '[^a-zA-Z]+', ' ', 'g'),
' ')
)))[1] AS token, rating
FROM customer_survey
LIMIT 10;


--4. На следующем шаге найдем средний рейтинг, связанный с каждым
--токеном. Можем сделать это, просто используя предложение GROUP BY:

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


--5. Проверим предположения, отфильтровав ответы на опросы,
--содержащие эти токены, с помощью выражения ILIKE
--следующим образом:

SELECT * FROM customer_survey WHERE feedback ILIKE '%pop%';


--Практическое задание №10

--Руководитель отдела продаж выявил проблему: у отдела продаж нет простого
--способа поиска клиента. К счастью, вы согасились создать проверенную внутреннюю
--поисковую систему, которая сделает всех клиентов доступными для поиска по их
--контактной информации и продуктам, которые они приобрели в прошлом:
--1. Используя таблицу customer_sales, создайте доступное для поиска
--представление с одной записью для каждого клиента. Это представление должно быть
--изолировано от столбца customer_id и доступно для поиска по всей базе данных,
--которое связано с этим клиентом:
--• имя,
--• адрес электронной почты,
--• телефон,
--• приобретенные продукты.
--Можно также включить и другие поля.
--2. Создайте доступный для поиска индекс для представления.
--3. У кулера с водой продавец спрашивает, можете ли вы использовать свой
--новый поисковый прототип, чтобы найти покупателя по имени Дэнни, купившего скутер
--Bat. Создайте ЗАПРОС на представление с возможностью поиска, используя ключевые
--слова «Danny Bat». Какое количество строк вы получили?
--4. Отдел продаж хочет знать, насколько часто люди покупают скутер и
--автомобиль. Выполните перекрестное соединение таблицы продуктов, чтобы получить
--все пары продуктов и удалите одинаковые пары (например, если название продукта
--совпадает). Для каждой пары выполните поиск в представлении, чтобы узнать, сколько
--клиентов соответствует обоим продуктам в паре. Можно предположить, что выпуски
--ограниченной серии можно сгруппировать вместе с их аналогом стандартной модели
--(например, Bat и Bat Limited Edition можно считать одним и тем же скутером).

--1. Создадим материализованное представление для таблицы
--customer_sales:

CREATE MATERIALIZED VIEW customer_search2 AS (
SELECT
customer_json -> 'customer_id' AS customer_id, customer_json,to_tsvector('english', customer_json) AS search_vector FROM customer_sales
);

--2. Создадим  индекс GIN в представлении:


CREATE INDEX customer_search_gin_idx2 ON customer_search2 USING GIN(search_vector);

--3. Выполним запрос, используя новую базу данных с возможностью
--поиска:

SELECT
customer_id,
customer_json
FROM customer_search2
WHERE search_vector @@ plainto_tsquery('english', 'Danny Bat');


--4. Вывести уникальный список скутеров и автомобилей (и удаление
--ограниченных выпусков) с помощью DISTINCT:

SELECT DISTINCT
p1.model,
p2.model
FROM products p1
LEFT JOIN products p2 ON TRUE
WHERE p1.product_type = 'scooter'
AND p2.product_type = 'automobile'
AND p1.model NOT ILIKE '%Limited
Edition%';

--5. Преобразуем вывод в запрос:

SELECT DISTINCT
plainto_tsquery('english', p1.model) &&
plainto_tsquery('english', p2.model)
FROM products p1
LEFT JOIN products p2 ON TRUE
WHERE p1.product_type = 'scooter'
AND p2.product_type = 'automobile'
AND p1.model NOT ILIKE '%Limited Edition%';


--6. Запрос базы данных, используя каждый из объектов tsquery, и
--подсчитать вхождения для каждого объекта:

--Запрос базы данных, используя каждый из объектов tsquery, и
--подсчитать вхождения для каждого объекта:
