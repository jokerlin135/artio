#!/usr/bin/env python3
import json
import urllib.request
import os

# 1. Đọc config từ .env.local
env_file = os.path.join(os.path.dirname(__file__), '..', '.env.local')
if not os.path.exists(env_file):
    print("❌ Không tìm thấy .env.local")
    exit(1)

env = {}
with open(env_file) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            env[k.strip()] = v.strip()

api_url = env.get('SUPABASE_URL', '').rstrip('/')
anon_key = env.get('SUPABASE_ANON_KEY', '')
cron_api = env.get('CRONJOB_API', '')
project_name = env.get('PROJECT_NAME', 'Artio')

if not all([api_url, anon_key, cron_api]):
    print('❌ Thiếu SUPABASE_URL, SUPABASE_ANON_KEY hoặc CRONJOB_API trong .env.local')
    exit(1)

cron_headers = {
    'Authorization': f'Bearer {cron_api}',
    'Content-Type': 'application/json'
}

# 2. Lấy danh sách jobs hiện tại để tránh tạo trùng lặp
list_req = urllib.request.Request('https://api.cron-job.org/jobs', headers=cron_headers)
existing_jobs = {}
with urllib.request.urlopen(list_req) as resp:
    data = json.loads(resp.read().decode())
    for j in data.get('jobs', []):
        existing_jobs[j.get('title')] = j.get('jobId')

print(f"📊 Tìm thấy {len(existing_jobs)} jobs hiện có trên cron-job.org")

# 3. Payload Job 1: PostgreSQL DB Query Wakeup (Chạy mỗi 4 giờ)
# Query trực tiếp bảng templates để kích hoạt PostgreSQL Engine
title_db = f'{project_name} - Supabase PostgreSQL DB Keep-Alive'
job_db_payload = {
    'job': {
        'url': f'{api_url}/rest/v1/templates?select=id&limit=1',
        'enabled': True,
        'saveResponses': True,
        'schedule': {
            'timezone': 'Asia/Ho_Chi_Minh',
            'expiresAt': 0,
            'hours': [0, 4, 8, 12, 16, 20],
            'minutes': [15],
            'mdays': [-1],
            'months': [-1],
            'wdays': [-1]
        },
        'requestMethod': 0, # GET
        'extendedData': {
            'headers': {
                'apikey': anon_key,
                'Authorization': f'Bearer {anon_key}'
            }
        },
        'title': title_db
    }
}

# 4. Payload Job 2: Auth Service Ping (Chạy mỗi 6 giờ)
title_auth = f'{project_name} - Supabase Auth Service Ping'
job_auth_payload = {
    'job': {
        'url': f'{api_url}/auth/v1/settings',
        'enabled': True,
        'saveResponses': True,
        'schedule': {
            'timezone': 'Asia/Ho_Chi_Minh',
            'expiresAt': 0,
            'hours': [2, 8, 14, 20],
            'minutes': [30],
            'mdays': [-1],
            'months': [-1],
            'wdays': [-1]
        },
        'requestMethod': 0, # GET
        'extendedData': {
            'headers': {
                'apikey': anon_key
            }
        },
        'title': title_auth
    }
}

def create_or_update_job(title, payload):
    job_id = existing_jobs.get(title)
    if job_id:
        print(f"🔄 Đang cập nhật job hiện có [{title}] (ID: {job_id})...")
        url = f'https://api.cron-job.org/jobs/{job_id}'
        req = urllib.request.Request(url, headers=cron_headers, data=json.dumps(payload).encode(), method='PATCH')
    else:
        print(f"✨ Đang tạo job mới [{title}]...")
        url = 'https://api.cron-job.org/jobs'
        req = urllib.request.Request(url, headers=cron_headers, data=json.dumps(payload).encode(), method='PUT')
    
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode())
        print(f"✅ [{title}] thành công: HTTP {resp.status} - {res}")

create_or_update_job(title_db, job_db_payload)
create_or_update_job(title_auth, job_auth_payload)
print("\n🎉 Toàn bộ cron jobs cho Artio đã được kích hoạt thành công trên console.cron-job.org!")
