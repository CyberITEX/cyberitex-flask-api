import secrets
import string
from flask import current_app


def generate_passphrase(num_words=3, separator="-", min_length=12):
    # Ensure password meets minimum length
    if num_words < 2:
        raise ValueError(
            "Passphrase should contain at least 3 words for better security."
        )

    # Select random words from the word list
    words = [secrets.choice(current_app.config['WORDS_LIST']) for _ in range(num_words)]

    # Join words with a separator (like '-' or another character)
    passphrase = separator.join(words)

    # If passphrase is too short, add more complexity
    while len(passphrase) < min_length:
        passphrase += separator + secrets.choice(current_app.config['WORDS_LIST'])

    # Add complexity: one uppercase letter, one digit, one special character
    passphrase += secrets.choice(string.ascii_uppercase)  # Add an uppercase letter
    passphrase += secrets.choice(string.digits)  # Add a digit
    passphrase += secrets.choice(string.digits)  # Add a digit
    passphrase += secrets.choice("!$#%&*+-=?@_")  # Add a special character

    return passphrase