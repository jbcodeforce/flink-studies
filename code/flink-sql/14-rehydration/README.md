# Rehydration 

The rehydration pattern means rebuilding current state from an event log, CDC stream, or compacted Kafka topic, then resuming incremental processing. 
Internal Confluent examples call out CDC rehydration as a common scenario, and also recommend compacted topics for current-state rehydration.

## Classical Rehydratation

## Mixing historical data with fresh data

An adaptation of this pattern is to load historical data with newly created data to combine to get a full view.