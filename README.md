# 🛒 E-Commerce App (Backend + Frontend)

A full-stack E-Commerce application with Django REST Framework backend and Flutter frontend.

---

## 📋 Table of Contents

1. Project Structure
2. Requirements
3. Backend Setup
4. Frontend Setup
5. How to Use the App
6. Login Credentials
7. Troubleshooting
8. Contact

---

## 📁 Project Structure

Project_Flutter/
├── backend/ # Django Backend
│ ├── manage.py
│ ├── db.sqlite3 # SQLite Database (already has data!)
│ ├── requirements.txt
│ ├── ecommerce_backend/ # Settings
│ ├── accounts/ # User Authentication
│ ├── products/ # Products, Orders, Cart
│ ├── shops/ # Shops Management
│ ├── shopadmin/ # Shop Owner Admin Panel
│ ├── superadmin/ # Super Admin Panel
│ └── templates/
│
├── frontend/ # Flutter App
│ ├── pubspec.yaml
│ ├── lib/
│ ├── android/
│ ├── ios/
│ └── web/
│
└── README.md

---

## 🔧 Requirements

Before running this project, install these tools:

### Backend:

- Python 3.10 or higher: https://www.python.org/downloads/
- pip (comes with Python)

### Frontend:

- Flutter SDK 3.0 or higher: https://docs.flutter.dev/get-started/install/windows
- Android Studio: https://developer.android.com/studio
- VS Code: https://code.visualstudio.com/
- Chrome: https://www.google.com/chrome/

### Operating System:

- Windows 10/11 (Recommended)
- macOS
- Linux

---

## 🖥️ Backend Setup (Windows)

### Step 1: Clone the Project

Open PowerShell or Command Prompt (CMD) and run:

    git clone https://github.com/tonghengkeo-aub/aub-batch-09-y3-s1-e-g8-E-Commerce-App.git
    cd aub-batch-09-y3-s1-e-g8-E-Commerce-App/backend

### Step 2: Create Virtual Environment

PowerShell:

    python -m venv venv
    .\venv\Scripts\Activate.ps1

CMD:

    python -m venv venv
    venv\Scripts\activate.bat

If PowerShell blocks the script, run this first:

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

### Step 3: Install Dependencies

    pip install --upgrade pip
    pip install -r requirements.txt

### Step 4: Verify Database File Exists

    dir db.sqlite3

You should see: db.sqlite3 (size ~276 KB)

### Step 5: Run the Backend Server

    python manage.py runserver

Backend is now running at: http://127.0.0.1:8000/

IMPORTANT: You do NOT need to run:

- makemigrations
- migrate
- createsuperuser

Because db.sqlite3 already contains all the data.

---

## 📱 Frontend Setup (Flutter)

### Step 1: Open a NEW Terminal

Keep the Backend terminal running! Open a new PowerShell/CMD window.

    cd aub-batch-09-y3-s1-e-g8-E-Commerce-App/frontend

### Step 2: Check Flutter Installation

    flutter --version
    flutter doctor

### Step 3: Install Flutter Dependencies

    flutter clean
    flutter pub get

### Step 4: Run the Flutter App

For Chrome (Web):

    flutter run -d chrome --web-port=59909

For Android Emulator:

    flutter run -d android

Frontend is now running at: http://localhost:59909/

---

## 🚀 How to Use the App

### Access URLs

| Panel             | URL                               |
| ----------------- | --------------------------------- |
| Super Admin Panel | http://127.0.0.1:8000/admin/      |
| Shop Admin Panel  | http://127.0.0.1:8000/shop-admin/ |
| Backend API       | http://127.0.0.1:8000/api/        |
| Flutter Web App   | http://localhost:59909/           |

### Access Different Shops

| Shop             | URL                                       |
| ---------------- | ----------------------------------------- |
| Super Admin Shop | http://localhost:59909/#/super-admin-shop |
| ANS Shop         | http://localhost:59909/#/ans-shop         |
| DNS Shop         | http://localhost:59909/#/dns-shop         |

---

## 🔑 Login Credentials

### Super Admin (Django Admin Panel)

- URL: http://127.0.0.1:8000/admin/
- Email: admin@gmail.com
- Password: admin$1234

### Shop Owner (Shop Admin Panel)

- URL: http://127.0.0.1:8000/shop-admin/
- Email: Hok123@gmail.com
- Password: Me$1234

### Customer (Flutter App)

- URL: http://localhost:59909/#/ans-shop
- Email: Roth123@gmail.com
- Password: Me$1234

### Delivery Person (Flutter App)

- URL: http://localhost:59909/#/super-admin-shop
- Email: delivery123@gmail.com
- Password: Me$1234

---

## ✨ Features

### Backend:

- JWT Authentication
- Google OAuth Login
- Multi-Shop Support
- Product Management
- Order Management
- Live Delivery Tracking
- Real-time Chat
- ABA PayWay Payment
- Bakong Payment
- Telegram Notifications

### Frontend:

- Customer App
- Delivery App
- Shop Owner Dashboard
- Live Order Tracking
- Chat with Delivery
- Multi-Shop Theme

---

## 🐛 Troubleshooting

### Backend Issues

Issue 1: ModuleNotFoundError - No module named 'django'

Solution:

    cd backend
    venv\Scripts\activate
    pip install -r requirements.txt

Issue 2: PowerShell blocks venv activation

Solution:

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Issue 3: Database appears empty

Solution:

    dir db.sqlite3
    git pull origin main

### Frontend Issues

Issue 1: flutter pub get fails

Solution:

    flutter clean
    flutter pub get

Issue 2: Chrome doesn't open

Solution:

    flutter run -d web-server --web-port=59909

Issue 3: CORS error

Solution: Make sure Backend is running at http://127.0.0.1:8000/

---

## 📝 Notes

### Database (SQLite)

- The database file backend/db.sqlite3 is included in this repository.
- It contains sample data:
  - 11 Users
  - 3 Shops
  - 12 Products
  - 11 Orders
- You do NOT need to run migrations or create a superuser.

### Default Ports

- Django Backend: 8000
- Flutter Web: 59909

---

## 📞 Contact

Student: Keo Tongheng
Course: AUB Batch 09, Year 3, Semester 1
Group: 8
GitHub: https://github.com/tonghengkeo-aub

---

## 📄 License

This project is for educational purposes only.
