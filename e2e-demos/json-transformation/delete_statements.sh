#!/bin/bash

echo "Starting statement deletion..."
export 
# Store the list in a variable first
statements=$(confluent flink statement list --url http://localhost:8084 --environment dev-rental)
echo "Raw statements:"
echo "$statements"

# Process and show each step

echo -e "\nAfter grep:"
echo "$statements" | cut -d '|' -f2 | grep cli

echo -e "\nProcessing each statement:"
echo "$statements" | \
  cut -d '|' -f2 | \
  grep cli | \
  while read -r name; do
    echo "Found statement: $name"
    echo "Running: confluent flink statement delete $name --url http://localhost:8084 --environment dev-rental --force"
    confluent flink statement delete "$name" --url http://localhost:8084 --environment dev-rental --force
    echo "Finished deleting $name"
  done

echo "Script completed"