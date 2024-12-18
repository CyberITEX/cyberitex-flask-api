#!/bin/bash

# Find all test files and run pytest for each file individually
echo "Running all test files individually..."
for test_file in $(find tests -name "test_*.py"); do
    echo "Running $test_file"
    pytest -v $test_file
    echo "----------------------------------------"
done

echo "All tests executed."
