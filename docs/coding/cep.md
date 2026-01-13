# Complex event processing

The goal of CEP is to analyzing pattern relationships between streamed events. Complex processing can be done using Flink using three capabilities: 

* Stateful Function
* [Flink CEP](https://ci.apache.org/projects/flink/flink-docs-release-1.13/dev/libs/cep.html) is a library to assess event pattern within a data stream.
* Flink SQL with pattern recognition

## Use cases

* Real-time marketing
* Anomalies detection
* Financial apps to check the trend in the stock market.
* Credit card fraud detection.
* RFID based tracking and monitoring systems

## Concepts

It uses the [pattern API](https://ci.apache.org/projects/flink/flink-docs-release-1.13/docs/libs/cep/#the-pattern-api) to define complex pattern sequences 
that we want to extract from the input stream.

The events in the DataStream to which you want to apply pattern matching must implement proper `equals() `
and `hashCode()` methods because FlinkCEP uses them for comparing and matching events.

The approach is to define simple patterns and then combine them in pattern sequence. 

A **pattern** can be either a singleton (accept a single event) or a looping pattern (accept more than one).

Here is a generic pattern to illustrate the following sequencing of events like: A B* C

```java
Pattern
        .begin("A").where(/* conditions */)
        .next("B").oneOrMore().optional().where(/* conditions */)
        .next("C").where(/* conditions */)
```

**Quantifier** specificies the pattern type.  

```java
pattern.oneOrMore()
pattern.times(#ofTimes)
pattern.times(#fromTimes, #toTimes)
// expecting 1 or more occurrences and repeating as many as possible
pattern.oneOrMore().greedy();
```

Each pattern can have one or more **conditions** based on which it accepts events.

```java
pattern.where() 
pattern.or()
pattern.until()
```

With **Iterative condition** we can specify a condition that accepts subsequent events 
based on properties of the previously accepted events or a statistic over a subset of them. 
Iterative conditions can be powerful, especially in combination with looping patterns, e.g. `oneOrMore()`.

We can combine patterns by specifying the desired **contiguity conditions** between them.

FlinkCEP supports the following forms of contiguity between events:

* **Strict Contiguity**: Expects all matching events to appear strictly one after the other, without any non-matching events in-between (use `next()` function).
* **Relaxed Contiguity**: Ignores non-matching events appearing in-between the matching ones (use `followedBy()`): "“skip non-matching events till the next matching one"
* **Non-Deterministic Relaxed Contiguity**: Further relaxes contiguity, allowing additional matches that ignore some matching events (use `followedByAny()`).


