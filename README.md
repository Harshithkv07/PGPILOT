<div align="center">

# 🏠 PGPILOT
### *The Smart PG Management System*

**A powerful, offline-first Flutter desktop application built to simplify every aspect of running a Paying Guest accommodation — from tenant onboarding to rent collection and financial reporting.**

<br/>

> ### 📢 Coming Soon
> ☁️ **Cloud Version** with full sync is in active development — launching soon!
> 🌐 **Website:** [Link Coming Soon] — learn everything interactively and request a trial.

</div>

---

<div align="center">

## ✨ First Look

*A sleek dark-themed interface that greets you the moment you launch.*

<img src="assets/screenshots/Screenshot 2026-06-19 130719.png" width="800" alt="Welcome Screen"/>

</div>

---

## 🚀 Key Features

| Feature | Description |
|---|---|
| 🏢 **Room Dashboard** | Visual room grid with real-time occupancy status (Full / Partial / Empty) |
| 👨‍🎓 **Student Management** | Add, view, and manage complete tenant profiles |
| 💸 **Rent Tracking** | Monthly revenue tracker with paid/pending statuses |
| 📊 **Daily Accounts** | Log income and expenses with daily opening/closing balances |
| 📤 **Excel Export** | One-click export of room and rent data to Excel |
| 💬 **WhatsApp Integration** | Send payment reminders directly via WhatsApp |
| 🔒 **Local-First & Offline** | Fully offline SQLite database — no internet needed |

---

## 📸 Feature Showcase

### 🏠 Room Dashboard

> *Get an instant bird's-eye view of your entire PG. Every room's status — Full, Partial, or Empty — is color-coded for clarity at a glance.*

<div align="center">
<img src="assets/screenshots/Screenshot 2026-06-19 130936.png" width="800" alt="Room Dashboard Overview"/>
<br/><br/>
<img src="assets/screenshots/Screenshot 2026-06-19 131818.png" width="800" alt="Room Dashboard Grid"/>
<br/><br/>

**Dashboard at a glance:**
- 🟥 **Red** = Room is **Full**
- 🟨 **Yellow/Amber** = Room is **Partially Occupied**
- 🟩 **Green** = Room is **Empty** (beds available)

Use **Add Room**, **Delete Room**, **Set Prices**, and **Excel Export** right from the toolbar.

---

### 👨‍🎓 Students List

> *All your tenants in one clean, searchable list. Instantly call, message, or view full profiles.*

<div align="center">
<img src="assets/screenshots/Screenshot 2026-06-19 131833.png" width="800" alt="Students List"/>
<br/><br/>
  
Each student card shows their **name**, **room number**, and quick-action buttons:
- 📞 **Call** — opens the dialer
- 💬 **WhatsApp** — opens a chat instantly
- 👁️ **View Profile** — opens the full student detail panel

---

### 🗂️ Student Profile & Rent History

> *A complete dossier for every tenant — personal info, family contacts, academic details, and a full rent payment timeline.*

<div align="center">

| Student Profile | Rent Payment History |
|:---:|:---:|
| <img src="assets/screenshots/Screenshot 2026-06-19 131041.png" width="420" alt="Student Profile"/> | <img src="assets/screenshots/Screenshot 2026-06-19 131105.png" width="420" alt="Rent Payment History"/> |

</div>

The **Rent History** panel shows:
- ✅ Months paid (with payment date & mode)
- ⏳ Months pending
- Summary card: **Total Months | Paid | Pending**

---

### ➕ Add New Student

> *Onboard a new tenant in seconds. The form captures everything — personal, family, and academic details — organized in two clean panels.*

<div align="center">
<img src="assets/screenshots/Screenshot 2026-06-19 130734.png" width="800" alt="Add New Student Form"/>
</div>

Fields include:
- **Student Name**, **Date of Birth**, **Contact Number**
- **Father's & Mother's Name and Number**
- **College/Workplace**, **Hometown**, **Residence Address**
- **Room Assignment**, **Advance Amount**, **Agreement Status**

---

### 💸 Rent Management

> *Track monthly collections, mark payments, and see exactly how much revenue you've collected vs. your potential.*

<div align="center">
<img src="assets/screenshots/Screenshot 2026-06-19 131121.png" width="800" alt="Rent Management Screen"/>
<br/><br/>
<img src="assets/screenshots/Screenshot 2026-06-19 131144.png" width="800" alt="Payment Mode Dialog"/>
</div>

**Monthly Revenue Tracker** shows:
- 💰 Amount **Collected** vs. **Potential**
- 📊 Visual progress bar with percentage
- Per-student rows with **Paid / Pending** status badges
- Mark payments as **Cash** or **UPI** with a single tap

---

## 🛠️ Tech Stack

```
Framework      →  Flutter (>=3.5.4 <4.0.0)
State Mgmt     →  Provider
Local Database →  Sqflite (SQLite)
File Export    →  Excel + File Picker + Open Filex
Messaging      →  URL Launcher (WhatsApp deep links)
Platform       →  Windows Desktop
```

---

## 📁 Project Architecture

The project follows a clean, **layered architecture** separating UI, business logic, and data:

```
lib/
├── core/           →  Constants, themes, validators, utilities
├── data/           →  Database helpers, repositories, services
├── logic/          →  Provider classes (state & business logic)
├── presentation/   →  Screens, widgets, dialogs (UI layer)
└── main.dart       →  Application entry point
```

---

## ⚡ Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/Harshithkv07/PGHACKED.git

# 2. Navigate into the project
cd PGHACKED

# 3. Fetch dependencies
flutter pub get

# 4. Run on Windows
flutter run -d windows
```

> **Prerequisites:** Flutter SDK (>=3.5.4), Windows 10/11 with desktop support enabled.

---

<div align="center">

**Built with ❤️ using Flutter · Designed for PG Owners who mean business**

</div>
