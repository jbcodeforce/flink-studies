package org.acme;

import java.time.LocalDate;

public class ExampleData {
    
    public static final Customer[] CUSTOMERS =
    new Customer[] {
      new Customer(12L, "Alice", LocalDate.of(1984, 3, 12)),
      new Customer(32L, "Bob", LocalDate.of(1990, 10, 14)),
      new Customer(7L, "Kyle", LocalDate.of(1979, 2, 23))
    };
}
