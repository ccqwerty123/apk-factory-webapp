import sys
from datetime import datetime

def save_message(message):
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open('output.txt', 'a') as f:
        f.write(f"{current_time} - {message}\n")

if __name__ == "__main__":
    message = sys.argv[1]
    save_message(message)
