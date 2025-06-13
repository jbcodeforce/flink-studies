create table cars (car_id VARCHAR(40) NOT NULL, car_model VARCHAR(100), status VARCHAR(10),
    capacity INT,
    color VARCHAR(10),
    cab_plate VARCHAR(20),
    base_park_lot VARCHAR(10),
    creation_date TIMESTAMP,
    update_date TIMESTAMP,
    PRIMARY KEY(car_id)
);