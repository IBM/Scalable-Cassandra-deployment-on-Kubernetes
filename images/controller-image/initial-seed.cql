-- Drop the keyspace if it exists
DROP KEYSPACE IF EXISTS my_cassandra_keyspace;

-- Create our keyspace
CREATE KEYSPACE my_cassandra_keyspace WITH replication ={ 'class': 'SimpleStrategy', 'replication_factor': 2 };

-- Use the keyspace
USE my_cassandra_keyspace;

-- Table: employee
CREATE TABLE employee(
   emp_id int PRIMARY KEY,
   emp_name text,
   emp_city text,
   emp_sal varint,
   emp_phone varint
);

-- Insert Data

INSERT INTO employee (emp_id, emp_name, emp_city,emp_phone, emp_sal) VALUES(1,'David', 'SF', 9848022338, 50000);
INSERT INTO employee (emp_id, emp_name, emp_city,emp_phone, emp_sal) VALUES(2,'Robin', 'SJC', 9848022339, 40000);
INSERT INTO employee (emp_id, emp_name, emp_city,emp_phone, emp_sal) VALUES(3,'Bob', 'Austin', 9848022330, 45000);
