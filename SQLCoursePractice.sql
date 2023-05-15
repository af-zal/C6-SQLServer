use [70-461]

-- create employee table
CREATE TABLE employee (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    salary DECIMAL(10, 2) NOT NULL
);


INSERT INTO employee (employee_id, first_name, last_name, hire_date, salary)
VALUES (1, 'John', 'Doe', '2021-01-01', 50000),
       (2, 'Jane', 'Smith', '2021-02-01', 60000),
       (3, 'Bob', 'Johnson', '2021-03-01', 70000),
       (4, 'Alice', 'Williams', '2021-04-01', 80000);


-- summarize data from employee table
SELECT COUNT(*) AS total_employees, AVG(salary) AS average_salary FROM employee;


SELECT * FROM employee ORDER BY salary DESC;

ALTER TABLE employee ADD email VARCHAR(100);

UPDATE employee SET email = CONCAT(first_name, '.', last_name, '@company.com');

DELETE FROM employee WHERE employee_id = 4;

-- create second table to maintain constraints, primary key, and foreign key
CREATE TABLE department (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL
);

INSERT INTO department (department_id, department_name)
VALUES (1, 'Sales'),
       (2, 'Marketing'),
       (3, 'Finance');

INSERT INTO department (department_id, department_name)
VALUES (4, 'Development'),
       (5, 'Support');

-- add foreign key constraint to employee table
ALTER TABLE employee ADD department_id INT;

delete from employee;

-- Insert some data into the employee table with department IDs
INSERT INTO employee (employee_id, first_name, last_name, hire_date, salary, department_id)
VALUES (1, 'John', 'Doe', '2021-01-01', 50000,1),
       (2, 'Jane', 'Smith', '2021-02-01', 60000,1),
       (3, 'Bob', 'Johnson', '2021-03-01', 70000,2),
       (4, 'Alice', 'Williams', '2021-04-01', 80000,3);


-- set foreign key constraint to reference department table
ALTER TABLE employee ADD CONSTRAINT FK_employee_department
    FOREIGN KEY (department_id)
    REFERENCES department(department_id);


	
SELECT * FROM employee;
SELECT * FROM department;

-- Inner join to combine employee and department data

SELECT e.employee_id, e.first_name, e.last_name, d.department_name
FROM employee e
INNER JOIN department d
ON e.department_id = d.department_id;

-- Left outer join to include all departments, even those with no employees
-- return all rows from the left-hand table plus records in the right-hand table with matching values
SELECT d.department_id, d.department_name, e.employee_id, e.first_name, e.last_name
FROM department d
LEFT OUTER JOIN employee e
ON d.department_id = e.department_id;

-- Right outer join to include all employees, even those without departments
-- returns all rows from the right-hand table and only those with matching values in the left-hand table
SELECT e.employee_id, e.first_name, e.last_name, d.department_id, d.department_name
FROM employee e
RIGHT OUTER JOIN department d
ON e.department_id = d.department_id;

SELECT d.department_id, d.department_name,  e.employee_id, e.first_name, e.last_name
FROM department d
RIGHT OUTER JOIN employee e
ON d.department_id = e.department_id;

-- Full outer join to include all employees and departments
-- Returns all rows from both tables with NULL values where the JOIN condition is not true
SELECT e.employee_id, e.first_name, e.last_name, d.department_id, d.department_name
FROM employee e
FULL OUTER JOIN department d
ON e.department_id = d.department_id;


-- Create a view that combines employee and department data
CREATE VIEW employee_department_view AS
SELECT e.employee_id, e.first_name, e.last_name, d.department_name
FROM employee e
INNER JOIN department d
ON e.department_id = d.department_id;

-- Create a view that aggregates employee data by department
CREATE VIEW department_summary_view AS
SELECT d.department_id, d.department_name, COUNT(e.employee_id) AS num_employees, AVG(e.salary) AS avg_salary
FROM department d
LEFT OUTER JOIN employee e
ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name;

SELECT * FROM employee_department_view;
SELECT * FROM department_summary_view;

-- Create a secure view that combines employee and department data
CREATE VIEW dbo.emp_dept_view WITH SCHEMABINDING
AS
SELECT e.employee_id, e.first_name, e.last_name, d.department_name
FROM dbo.employee e
INNER JOIN dbo.department d
ON e.department_id = d.department_id;

-- Add a check option to prevent modifications that violate the view's schema
WITH CHECK OPTION;

-- Delete a row from the employee_department_view
DELETE FROM employee_department_view
WHERE employee_id = 1;

-- An index is a database object used to improve query performance, while an indexed view is a type of view that has an associated index for faster query results.
-- Create an indexed view that summarizes employee data by department
CREATE VIEW dbo.department_summary_indexed_view WITH SCHEMABINDING
AS
SELECT d.department_id, d.department_name, COUNT_BIG(e.employee_id) AS num_employees, AVG(e.salary) AS avg_salary
FROM dbo.department d
LEFT OUTER JOIN dbo.employee e
ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
WITH CHECK OPTION;

-- Create a clustered index on the view
CREATE UNIQUE CLUSTERED INDEX idx_department_summary ON department_summary_indexed_view(department_id);


CREATE TABLE audit_employee (
  audit_id INT IDENTITY(1,1) PRIMARY KEY,
  employee_id INT NOT NULL,
  action VARCHAR(10) NOT NULL,
  action_date DATETIME NOT NULL DEFAULT(GETDATE())
);

--AFTER triggers execute after the original DML operation, while INSTEAD OF triggers execute instead of the original DML operation.
CREATE TRIGGER tr_employee_audit
ON employee
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  IF EXISTS (SELECT * FROM inserted)
  BEGIN
    INSERT INTO audit_employee (employee_id, action)
    SELECT employee_id, 'INSERT'
    FROM inserted;

    UPDATE audit_employee
    SET action = 'UPDATE'
    WHERE employee_id IN (SELECT employee_id FROM inserted);

    DELETE FROM audit_employee
    WHERE employee_id IN (SELECT employee_id FROM deleted);
  END;
  ELSE
  BEGIN
    DELETE FROM audit_employee
    WHERE employee_id IN (SELECT employee_id FROM deleted);
  END;
END;

--prevent error for department table
CREATE TRIGGER tr_department_prevent_delete
ON department
INSTEAD OF DELETE
AS
BEGIN
  RAISERROR ('Deleting departments is not allowed.', 16, 1);
END;

delete from department;

--stored procedure to insert new record into employee
CREATE PROCEDURE sp_employee_insert
  @first_name VARCHAR(50),
  @last_name VARCHAR(50),
  @department_id INT
AS
BEGIN
  INSERT INTO employee (first_name, last_name, department_id)
  VALUES (@first_name, @last_name, @department_id);
END;

ALTER PROCEDURE sp_employee_insert
  @first_name VARCHAR(50),
  @last_name VARCHAR(50),
  @department_id INT
AS
BEGIN
  BEGIN TRY
    INSERT INTO employee (first_name, last_name, department_id)
    VALUES (@first_name, @last_name, @department_id);
  END TRY
  BEGIN CATCH
    -- Log the error message to an error table
    --INSERT INTO error_log (error_message)
    --VALUES (ERROR_MESSAGE());

    -- Rethrow the error to the caller
    THROW;
  END CATCH
END;

EXEC sp_employee_insert 'Af', 'Sk', 1;

--while and return
CREATE PROCEDURE sp_my_stored_proc (@input_value INT)
AS
BEGIN
    DECLARE @counter INT = 1
    DECLARE @result INT = 0

    WHILE @counter <= @input_value
    BEGIN
        SET @result = @result + @counter
        SET @counter = @counter + 1
    END

    RETURN @result
END

DECLARE @output_value INT
EXEC @output_value = sp_my_stored_proc @input_value = 5
SELECT @output_value as 'Result'

--TRY/CATCH/THROW
CREATE PROCEDURE sp_my_stored_p (@input_value INT)
AS
BEGIN
    DECLARE @result INT = 0
    BEGIN TRY
        IF @input_value <= 0
        BEGIN
            -- Throw a custom error using THROW
            THROW 50000, 'Invalid input value. Must be greater than zero.', 1;
        END

        -- Divide by zero to generate an error
        SELECT @result = 10 / 0;
    END TRY
    BEGIN CATCH
        -- Catch the error and handle it
        IF ERROR_NUMBER() = 8134
        BEGIN
            -- Raise a custom error using RAISERROR
            RAISERROR('Divide by zero error', 16, 1);
        END
        ELSE
        BEGIN
            -- Print the error message to the console
            PRINT ERROR_MESSAGE();
        END
    END CATCH

    -- Return the result if no error occurred
    RETURN @result
END

EXEC sp_my_stored_p @input_value = 0

--Aggregate queries
SELECT COUNT(*) FROM employee;
SELECT SUM(salary) FROM employee;
SELECT AVG(salary) FROM employee;
SELECT MAX(salary) FROM employee;
SELECT MIN(salary) FROM employee;

-- Get the number of employees in each department
SELECT d.department_name, COUNT(*) FROM employee e
JOIN department d ON e.department_id = d.department_id
GROUP BY d.department_name;

-- Get the total salary of employees in each department
SELECT d.department_name, SUM(salary) FROM employee e
JOIN department d ON e.department_id = d.department_id
GROUP BY d.department_name;

-- Get the average salary of employees in each department
SELECT d.department_name, AVG(salary) FROM employee e
JOIN department d ON e.department_id = d.department_id
GROUP BY d.department_name;


--over partition by
-- Calculate the running total of salaries for each department
SELECT d.department_name, e.salary,
  SUM(e.salary) OVER (PARTITION BY d.department_id ORDER BY e.employee_id) AS running_total
FROM employee e
JOIN department d ON e.department_id = d.department_id;

SELECT department_id, first_name, last_name, salary, 
       ROW_NUMBER() OVER(PARTITION BY department_id ORDER BY salary DESC) as rank
FROM employee;

--row_number() - assigns a unique sequential integer to each row within a result set partition.
SELECT department_name, first_name, last_name, salary,
       ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY salary DESC) AS row_num
FROM employee
JOIN department ON employee.employee_id = department.department_id;

--rank() - This function assigns a rank to each row within a result set partition based on the ORDER BY clause. 
--If there are ties, the same rank is assigned to each tied row and the next rank is skipped.
SELECT d.department_name, e.first_name, e.last_name, e.salary,
       RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS rank_num
FROM employee e
JOIN department d ON e.department_id = d.department_id;

--dense_rank() - assigns a rank to each row within a result set partition based on the ORDER BY clause, similar to the RANK() function. 
--However, if there are ties, the same rank is assigned to each tied row and the next rank is not skipped.
SELECT d.department_name, e.first_name, e.last_name, e.salary,
       DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS dense_rank_num
FROM employee e
JOIN department d ON e.department_id = d.department_id;


--NTILE(): distributes the rows in a result set into a specified number of groups, called tiles. 
--The number of tiles is specified as an argument to the NTILE function.
SELECT department.department_name, employee.first_name, employee.last_name, employee.salary,
       NTILE(3) OVER (PARTITION BY employee.department_id ORDER BY employee.salary DESC) AS tile_num
FROM employee
JOIN department ON employee.department_id = department.department_id;


select *from employee
--Sub-queries
SELECT department_name FROM department
WHERE department_id IN (SELECT department_id FROM employee WHERE salary > 60000 );

SELECT first_name, last_name, salary, department_name FROM employee e
JOIN department d ON e.department_id = d.department_id
WHERE salary > (SELECT AVG(salary) FROM employee WHERE department_id = e.department_id);

SELECT first_name, last_name, salary, department_name FROM employee e JOIN department d ON e.department_id = d.department_id
WHERE salary = (SELECT MAX(salary) FROM employee WHERE department_id = e.department_id);

SELECT department_name
FROM department
WHERE department_id IN (SELECT department_id FROM employee GROUP BY department_id HAVING COUNT(*) > 1);

--ANY returns all employees whose salary is greater than any of the average salaries in their department, 
--while SOME returns all employees whose salary is greater than at least one of the average salaries in their department. 
--ALL returns all employees whose salary is greater than all of the average salaries in their department.

SELECT department_id, first_name, last_name, salary
FROM employee
WHERE salary > ANY (
    SELECT AVG(salary)
    FROM employee
    WHERE department_id = employee.department_id
    GROUP BY department_id
)

SELECT department_id, first_name, last_name, salary
FROM employee
WHERE salary > some (
    SELECT AVG(salary)
    FROM employee
    WHERE department_id = employee.department_id
    GROUP BY department_id
);

SELECT department_id, first_name, last_name, salary
FROM employee
WHERE salary > ALL (
    SELECT AVG(salary)
    FROM employee
    WHERE department_id = employee.department_id
    GROUP BY department_id
)

--WITH
WITH nums(n) AS (
    SELECT 1 UNION ALL
    SELECT n+1 FROM nums WHERE n < 10
)
SELECT n FROM nums;

--grouping and aggregating data
WITH dept_avg_salary AS (
    SELECT department_id, AVG(salary) AS avg_salary
    FROM employee
    GROUP BY department_id
)
SELECT department_name, avg_salary
FROM department
JOIN dept_avg_salary ON department.department_id = dept_avg_salary.department_id
WHERE avg_salary > (SELECT AVG(avg_salary) FROM dept_avg_salary);

--Pivoting is the process of converting rows into columns, while unpivoting is the process of converting columns into rows.

SELECT department_name, [1] AS Q1, [2] AS Q2, [3] AS Q3, [4] AS Q4
FROM (
    SELECT d.department_name, e.salary, DATEPART(Q, e.hire_date) AS Quarter
    FROM employee e
    INNER JOIN department d ON e.department_id = d.department_id
) AS SourceTable
PIVOT (
    SUM(salary)
    FOR Quarter IN ([1], [2], [3], [4])
) AS PivotTable;

SELECT department_name, Quarter, Salary
FROM (
    SELECT d.department_name, [1] AS Q1, [2] AS Q2, [3] AS Q3, [4] AS Q4
    FROM (
        SELECT e.department_id, e.salary, DATEPART(Q, e.hire_date) AS Quarter
        FROM employee e
    ) AS SourceTable
    PIVOT (
        SUM(salary)
        FOR Quarter IN ([1], [2], [3], [4])
    ) AS PivotTable
    INNER JOIN department d ON PivotTable.department_id = d.department_id
) AS UnpivotTable
UNPIVOT (
    Salary FOR Quarter IN (Q1, Q2, Q3, Q4)
) AS UnpivotOperation;


--A CTE (Common Table Expression) is a temporary named result set that you can reference within a SELECT, INSERT, UPDATE, or DELETE statement. 
--It is similar to a derived table or a subquery, but it can be referenced multiple times within a query.
WITH cte_employee_dept AS (
  SELECT e.employee_id, e.first_name, e.last_name, d.department_name
  FROM employee e
  INNER JOIN department d
  ON e.department_id = d.department_id
)
SELECT department_name, COUNT(employee_id) AS num_employees
FROM cte_employee_dept
GROUP BY department_name;

--GUID, Sequence
SELECT NEWID()
CREATE SEQUENCE seq_id START WITH 1 INCREMENT BY 1

CREATE TABLE employee (
  employee_id INT PRIMARY KEY,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  department_id INT,
  employee_code VARCHAR(10) DEFAULT CONCAT('EMP', NEXT VALUE FOR seq_id)
);


--XML Data
alter table employee
add details XML;

-- Insert employee data with XML details
DECLARE @employee_details XML;
SET @employee_details = 
'<EmployeeDetails>
  <Salary>50000</Salary>
  <Department>Marketing</Department>
  <Address>
    <Street>123 Main St</Street>
    <City>New York</City>
    <State>NY</State>
    <Zip>10001</Zip>
  </Address>
</EmployeeDetails>';

INSERT INTO employee (employee_id, first_name, last_name, hire_date,salary,department_id, details)
VALUES (5, 'Jonathan', 'Wick', '2021-05-01',50000,4, @employee_details);

select *from employee;

-- Query XML data using XQuery
SELECT employee_id, first_name, last_name, email,
  details.value('(EmployeeDetails/Salary)[1]', 'INT') AS salary,
  details.value('(EmployeeDetails/Department)[1]', 'VARCHAR(50)') AS department,
  details.query('EmployeeDetails/Address') AS address
FROM employee;

-- Update XML data using modify()
UPDATE employee
SET details.modify('replace value of (EmployeeDetails/Department/text())[1] with "Sales"')
WHERE employee_id = 5;

-- Delete XML data using modify()
UPDATE employee
SET details.modify('delete (EmployeeDetails/Address)')
WHERE employee_id = 5;

--JSON
SELECT d.department_name, e.first_name, e.last_name, e.salary
FROM department d
JOIN employee e ON d.department_id = e.department_id
FOR JSON AUTO;

--insert json into both tables
DECLARE @json NVARCHAR(MAX) = N'{
  "department_name": "HR",
  "employee": [    { "first_name": "Samantha", "last_name": "Jones", "salary": 60000 },    { "first_name": "Mark", "last_name": "Davis", "salary": 70000 }  ]
}';

-- Insert the department
INSERT INTO department (department_name)
SELECT JSON_VALUE(@json, '$.department_name');

-- Get the department ID
DECLARE @department_id INT = SCOPE_IDENTITY();

-- Insert the employees
INSERT INTO employee (first_name, last_name, salary, department_id)
SELECT first_name, last_name, salary, @department_id
FROM OPENJSON(@json, '$.employee')
WITH (
  first_name NVARCHAR(50),
  last_name NVARCHAR(50),
  salary DECIMAL(18,2)
);


--Transaction
--A transaction is a sequence of one or more operations that are executed as a single logical unit of work
BEGIN TRANSACTION
UPDATE employee SET salary = salary * 1.1 WHERE department_id = 1
UPDATE employee SET salary = salary * 1.2 WHERE department_id = 2
COMMIT TRANSACTION
-- If any of the updates fail, the entire transaction will be rolled back, and the salaries will be restored to their previous values.

select *from employee;

CREATE PROCEDURE sp_employee_update_salary
    @department_id INT,
    @percentage FLOAT
AS
BEGIN
    BEGIN TRANSACTION
    UPDATE employee SET salary = salary * (1 + @percentage) WHERE department_id = @department_id
    IF @@ERROR <> 0
    BEGIN
        ROLLBACK TRANSACTION
        RETURN
    END
    COMMIT TRANSACTION
END









































