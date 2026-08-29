---
name: vibe-engineering-workflow
description: "Master Smart Router for engineering work: định tuyến theo độ rõ/rủi ro, tôn trọng repository policy, yêu cầu verification evidence và duy trì handoff context khi cần."
---

# Vibe Engineering Workflow (Master Smart Router)

Skill này là **Bộ Điều Hướng Thông Minh (Smart Router & Engineering Lifecycle)** dành riêng cho Đại Ka khi phát triển phần mềm và Vibe Coding.

## 🎯 Triết lý hành động:
> **"Luôn chọn quy trình nhẹ nhất đủ để giảm mơ hồ và rủi ro triển khai; không suy đoán, luôn nêu rõ bằng chứng và bảo toàn dữ liệu người dùng."**

---

## 🔍 Bước 0: Kiểm Tra Điều Kiện Tiên Quyết (Prerequisite Check)

Trước khi bắt đầu, Agent kiểm tra repository instructions, branch/CI policy và các skill sẵn có. Bộ `mattpocock/skills` là enhancement tùy chọn:
- Kiểm tra các skill cốt lõi: `grill-me`, `grill-with-docs`, `tdd`, `to-spec`, `to-tickets`, `wayfinder`, `diagnosing-bugs`, `code-review`, `handoff`.

### Khi thiếu skill tùy chọn
Không dừng task chỉ vì thiếu `mattpocock/skills`. Thông báo ngắn và dùng fallback nội bộ tương ứng: làm rõ yêu cầu, viết acceptance criteria, test-first khi có seam, và ghi lại handoff. Chỉ đề xuất cài đặt khi người dùng yêu cầu hoặc thiếu skill thực sự chặn mục tiêu.

---

## 🚦 Ma Trận Định Tuyến Công Việc (Router Decision Matrix)

### Rubric phân loại
- **Clear:** acceptance criteria, phạm vi và hành vi mong đợi đã đủ để test/verify.
- **Unclear:** còn quyết định sản phẩm/kỹ thuật có thể thay đổi implementation hoặc acceptance criteria.
- **Small:** một vùng mã nhỏ, không migration/public API/breaking change, và có thể verify trong một vòng ngắn.
- **Large:** chạm nhiều module, public API/data migration, thay đổi kiến trúc, hoặc rủi ro/verification đáng kể.

| Nhóm | Phân loại | Hành động & Chiến lược Git/Branch | Workflow thực thi |
| :--- | :--- | :--- | :--- |
| **🟢 Nhóm 1** | **Clear & Small** | **Direct Branch:** Làm trực tiếp trên branch hiện tại, lưu Rollback commit hash | `tdd` (nếu có test seam) hoặc Implement trực tiếp ➜ Pre-check |
| **🟡 Nhóm 2** | **Unclear & Small** | **Feature Branch (tùy chọn):** Làm rõ yêu cầu trước khi code | `grill-with-docs` (hoặc `grill-me`) ➜ `research`/`prototype` ➜ `to-spec` nhẹ ➜ `implement` |
| **🔵 Nhóm 3** | **Clear & Large** | **New Branch + PR:** Tạo `feature/<name>`, xẻ tracer-bullet tickets | `to-spec` ➜ `to-tickets` ➜ `implement` (**1 ticket / 1 fresh session**) ➜ PR review |
| **🟣 Nhóm 4** | **Unclear & Large** | **Wayfinder Branch:** Gỡ nút thắt quyết định kiến trúc trước | `wayfinder` (resolve decision map) ➜ `to-spec` ➜ `to-tickets` ➜ `implement` |

---

## 🌿 Chiến Lược Branching, PR & Rollback An Toàn

1. **Khi nào tạo Branch & PR mới?**
   - **Tạo Branch / PR khi:** Tính năng mới lớn (Large feature), Refactor kiến trúc hệ thống, hoặc thay đổi có nguy cơ breaking change.
   - **Có thể không cần PR khi:** task nhỏ và repository policy cho phép. Không tự ý bypass protected branch, required review hoặc CI.
2. **Kế hoạch Rollback Dự Phòng (Zero-Risk Anchor):**
   - Trước khi sửa đổi lớn, luôn lưu lại **Base Commit Hash** vào `CONTEXT.md` (ví dụ: `Rollback Anchor: abc1234`).
   - Nếu xảy ra lỗi nghiêm trọng: kiểm tra trạng thái working tree; với commit đã publish ưu tiên `git revert`. Chỉ hard reset sau xác nhận rõ của người dùng.

---

## 📋 Giao Thức Pre-Check 4 Bước (Pre-Check Gate)

Trước khi kết luận **"HOÀN THÀNH / DONE"**, Agent **BẮT BUỘC** tự kiểm tra 4 tiêu chí sau và báo cáo kết quả:

- [ ] **1. Logic Correctness (Đúng Logic):** Đã chạy test/lệnh thực thi phù hợp chưa? Báo rõ lệnh và kết quả; nếu chưa chạy, nêu lý do.
- [ ] **2. Workflow & Code Cleanliness (Sạch sẽ):** Không để lại debug output, biến/import/code thừa do thay đổi hiện tại tạo ra.
- [ ] **3. Missing Features & Edge Cases (Tính năng & Trường hợp biên):** Có sót điều kiện biên, xử lý lỗi mạng, timeout, hoặc trạng thái loading/empty không?
- [ ] **4. Latent Risks & Security (Rủi ro & Bảo mật):** Có nguy cơ lộ API Key, đụng độ state, memory leak, hoặc vi phạm `.gitignore` không?

---

## 📝 Quy Ước Duy Trì Living `CONTEXT.md`

1. **Vị trí:** Dùng handoff/context convention hiện có của repository. Chỉ tạo `CONTEXT.md` khi repository chưa có convention phù hợp và task đủ lớn để cần handoff.
2. **Nội dung bắt buộc trong `CONTEXT.md`:**
   - **Current Goal:** Mục tiêu hiện tại của dự án/tính năng.
   - **Decisions & Architecture:** Các quyết định kỹ thuật đã chốt.
   - **What was done:** Những việc vừa hoàn thành (kèm Base Commit Hash để rollback).
   - **Next Steps:** Các bước tiếp theo cần làm.
3. **Thời điểm cập nhật:**
   - Sau khi hoàn thành một mốc quan trọng.
    - Trước khi kết thúc session hoặc trước khi chạy `/handoff`.
4. **An toàn:** Không ghi secrets, token, dữ liệu cá nhân hoặc output nhạy cảm vào context.

---

## 🛡️ Bộ Quy Tắc Bất Biến (Strict Invariants)

1. **Surgical Changes:** Chỉ sửa đúng những dòng code phục vụ yêu cầu.
2. **Strict Verification:** Không báo xong nếu chưa thực sự chạy lệnh/test trên máy.
3. **Single Ticket Scope:** Với task lớn, chỉ làm 1 ticket trên 1 session để bảo vệ context window.
4. **Zero Secrets in Git:** Tuyệt đối không commit file `.env`, service keys, hay token cá nhân.
