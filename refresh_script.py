import requests
import time
from datetime import datetime

def try_refresh(url, headers, retries=2, retry_interval=60):
    max_attempts = retries + 1
    for attempt in range(max_attempts):
        try:
            response = requests.get(url, headers=headers) # 在这里添加了headers参数
            response.raise_for_status()
            print(f"[{datetime.now()}] Refresh successful: {url}")
            return
        except requests.RequestException as e:
            print(f"[{datetime.now()}] Refresh failed: {url} (Attempt {attempt + 1} of {max_attempts})")
            if attempt < retries:
                time.sleep(retry_interval)


if __name__ == "__main__":
    urls_to_refresh = [
        "https://f8e5d6c2-bdd6-40a7-b7f8-6d4eaf2df046-00-1sf3dehs964tq.sisko.replit.dev/",
        # 在这里添加其他需要刷新的网址
    ]
    custom_headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
        "Accept-Language": "en-US,en;q=0.5",
        # 可以根据需要添加其他头部信息
    }
    refresh_interval = 120 # 每2分钟刷新一次

    start_time = time.time()
    end_time = start_time + refresh_interval
    while time.time() < end_time:
        for url in urls_to_refresh:
            try_refresh(url, headers=custom_headers)
        # 等待2分钟，然后再次尝试
        time.sleep(refresh_interval)
