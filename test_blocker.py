# Security issue: using eval
user_input = input("Enter code: ")
eval(user_input)  # CRITICAL SECURITY ISSUE

# Hardcoded password
password = "admin123"  # SECURITY ISSUE
