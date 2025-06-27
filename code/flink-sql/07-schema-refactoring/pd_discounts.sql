CREATE TABLE discounts (
    discount_id SERIAL PRIMARY KEY,
    discount_name VARCHAR(255) NOT NULL,
    discount_type VARCHAR(50) NOT NULL, -- e.g., 'percentage', 'fixed_amount'
    discount_value DECIMAL(5, 2) NOT NULL, -- e.g., 0.10 for 10%, or 5.00 for $5
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);