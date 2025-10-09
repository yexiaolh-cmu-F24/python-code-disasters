"""
Clean Python code example for testing Scenario B.
This file has no code quality issues and should pass SonarQube analysis.
"""


def greet(name: str) -> str:
    """
    Returns a greeting message.
    
    Args:
        name: The name to greet
        
    Returns:
        A greeting string
    """
    if not name:
        return "Hello, stranger!"
    return f"Hello, {name}!"


def calculate_sum(numbers: list) -> int:
    """
    Calculate the sum of a list of numbers.
    
    Args:
        numbers: List of integers to sum
        
    Returns:
        The sum of all numbers
    """
    if not numbers:
        return 0
    return sum(numbers)


def main():
    """Main function to demonstrate clean code."""
    # Test greeting function
    print(greet("World"))
    print(greet(""))
    
    # Test calculation function
    numbers = [1, 2, 3, 4, 5]
    total = calculate_sum(numbers)
    print(f"Sum of {numbers} is {total}")


if __name__ == "__main__":
    main()

