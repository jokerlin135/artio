---
name: keeping-supabase-alive
description: >
  Keep Supabase free tier (freetier) always alive via cron-job.org API (or GitHub Actions).
  Prevents auto-pause and project deletion caused by 7-day inactivity rule.
  Supports multi-project management with a single CRONJOB_API key from .env.local,
  forces real PostgreSQL engine wakeup query, and provides automated setup scripts.
skills:
  - bash-linux
  - deployment-procedures
---

# Supabase Keep-Alive Skill (cron-job.org & Multi-Project API)

## 🎯 Vấn Đề (Problem)

Supabase **Free Tier** sẽ tự động tạm dừng (**auto-pause**) các project sau **7 ngày** không có truy vấn API/DB thực tế.
Sau **90 ngày** bị tạm dừng, project sẽ bị **xóa vĩnh viễn (permanently deleted)** không thể khôi phục.

---

## ⚡ Giải Pháp Tối Ưu: cron-job.org API (Khuyên Dùng Hàng Đầu)

So sánh giải pháp:

| Tiêu chí | GitHub Actions Scheduled Workflow | **cron-job.org API (Khuyên dùng)** |
|---|---|---|
| **Độ tin cậy 24/7** | ⚠️ Bị **GitHub tự động tắt sau 60 ngày** nếu repo không có commit mới. | ✅ **Chạy độc lập 24/7/365**, không bao giờ bị dừng do repo không commit. |
| **Quản lý đa dự án** | Phải config từng secret và workflow cho từng repo. | ✅ **1 `CRONJOB_API` key quản lý hàng chục / hàng trăm project** tập trung. |
| **Tần suất an toàn** | Chạy mỗi 4 ngày (`0 8 */4 * *`). | ✅ **Mỗi 4 giờ hoặc mỗi ngày** linh hoạt, có log response chi tiết. |

---

## 🔑 Cấu Hình Biến Môi Trường (`.env.local`)

Mỗi thư mục dự án cần khai báo các biến trong `.env.local`:

```env
# Supabase Project Config
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Cron-job.org Management API Key (Dùng chung cho 1 hoặc nhiều projects)
CRONJOB_API=+YBj0ZPXBaN9P9Rxw4qEoi0nyBxbN4RQFOWZXihd5Fw=
```

> **Lưu ý Multi-Project:** 1 tài khoản cron-job.org với 1 key `CRONJOB_API` có thể tạo và quản lý cron jobs cho **rất nhiều dự án khác nhau** cùng lúc. Mỗi dự án chỉ cần đặt tên Job theo cú pháp: `[Tên Project] - Supabase PostgreSQL DB Keep-Alive`.

---

## 🛠️ Script Tự Động Thiết Lập Keep-Alive Qua API (One-Shot Setup)

Chạy script Python sau trong thư mục project có chứa `.env.local`:

```python
import json, requests

# 1. Đọc config từ .env.local
with open('.env.local') as f:
    env = dict(line.strip().split('=', 1) for line in f if '=' in line and not line.strip().startswith('#'))

api_url = env.get('SUPABASE_URL', '').rstrip('/')
anon_key = env.get('SUPABASE_ANON_KEY', '')
cron_api = env.get('CRONJOB_API', '')
project_name = env.get('PROJECT_NAME', 'LoveTime')

if not all([api_url, anon_key, cron_api]):
    print('❌ Thiếu SUPABASE_URL, SUPABASE_ANON_KEY hoặc CRONJOB_API trong .env.local')
    exit(1)

cron_headers = {
    'Authorization': f'Bearer {cron_api}',
    'Content-Type': 'application/json'
}

# 2. Tạo Job 1: PostgreSQL DB Query Wakeup (Chạy mỗi 4 giờ)
# Bắt buộc ping bảng thực tế để ép PostgreSQL Engine query thật
job_db_payload = {
    'job': {
        'url': f'{api_url}/rest/v1/couples?limit=1',  # Thay 'couples' bằng 1 public table bất kỳ của app
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
        'title': f'{project_name} - Supabase PostgreSQL DB Keep-Alive'
    }
}

# 3. Tạo Job 2: Auth Service Ping (Chạy mỗi 6 giờ)
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
        'title': f'{project_name} - Supabase Auth Service Ping'
    }
}

r1 = requests.put('https://api.cron-job.org/jobs', headers=cron_headers, json=job_db_payload)
r2 = requests.put('https://api.cron-job.org/jobs', headers=cron_headers, json=job_auth_payload)

print('✅ DB Keep-Alive Job Status:', r1.status_code, r1.text)
print('✅ Auth Ping Job Status:', r2.status_code, r2.text)
```

---

## 🔍 Quy Tắc Vàng Về Endpoint (Why Ping A Real Table?)

| Endpoint | Mục Đích | Auth Headers | Tại Sao Cần Thiết? |
|---|---|---|---|
| `/rest/v1/[table]?limit=1` | **Đánh thức PostgreSQL Engine** | `apikey` + `Authorization: Bearer <anon>` | **Bắt buộc!** Nếu chỉ ping root `/rest/v1/` hoặc `/auth/`, API Gateway (Kong) có thể cache/trả 200 mà database thật vẫn ngủ đông. Query bảng thực tế đảm bảo DB được tính active 100%. |
| `/auth/v1/settings` | **Ping Auth Service** | `apikey` | Giữ ấm dịch vụ Auth & Kong Gateway. |

---

## ⚠️ Giải Pháp Dự Phòng (Fallback: GitHub Actions)

Nếu không có `CRONJOB_API`, sử dụng workflow `.github/workflows/supabase-keepalive.yml`:
* Chạy mỗi 4 ngày: `- cron: '0 8 */4 * *'` (Tuyệt đối **KHÔNG dùng `*/5`** vì tháng 2 có 28 ngày tạo ra khoảng trống 8 ngày từ 25/2 → 5/3 gây pause DB!).
* Phải truy cập tab **Actions** trên GitHub mỗi tháng hoặc commit code định kỳ để tránh GitHub tự tắt schedule sau 60 ngày.

---

## ✅ Danh Sách Kiểm Tra Hoàn Tất (Verification Checklist)

- [ ] File `.env.local` đã khai báo `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CRONJOB_API`.
- [ ] Job DB Wakeup ping tới 1 bảng thực tế và nhận **HTTP 200** khi test.
- [ ] Job xuất hiện đầy đủ trên [cron-job.org Dashboard](https://console.cron-job.org/).
- [ ] `.env.local` đã nằm trong `.gitignore` để bảo mật secrets.
