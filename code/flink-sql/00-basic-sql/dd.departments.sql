CREATE TABLE departments (
	department_id SERIAL PRIMARY KEY,
	department_name CHARACTER VARYING (30) NOT NULL,
	location_id INTEGER,
	FOREIGN KEY (location_id) REFERENCES locations (location_id) ON UPDATE CASCADE ON DELETE CASCADE
);