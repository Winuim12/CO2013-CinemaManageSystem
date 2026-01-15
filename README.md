# CO2013 Cinema Management System

## Overview

**CO2013 Cinema Management System** is a web-based application built with **Flask (Python)** that simulates the core functionalities of a cinema’s management and ticketing system. It was developed as part of the *CO2013 – Database Systems* course to demonstrate database interactions, MVC design patterns, and CRUD operations.

---

## Features

This system supports the following functionalities:

- **Movie Listings:** View, add, edit, and delete movie records
- **Session & Screening Management:** Schedule movie showtimes
- **Ticket Booking:** Reserve tickets for specific sessions
- **Customer Interaction:** Manage customer orders and seat assignments
- **Reports / Statistics:** (if implemented) View basic cinema statistics

---

## Technologies Used

| Component   | Technology        |
|-------------|------------------|
| Backend     | Python, Flask     |
| Frontend    | HTML, CSS         |
| Templating  | Jinja2            |
| Database    | SQLite / MySQL   |
| Dependencies| See requirements.txt |

---

## Project Structure

```

├── controllers/       # Flask route controllers
├── models/            # Data models & database logic
├── static/            # Static files (CSS, images)
├── templates/         # Jinja2 HTML templates
├── utils/             # Helper scripts & utilities
├── app.py             # Application entry point
├── config.py          # App configuration
├── requirements.txt   # Python dependencies

````

*The project follows the typical MVC structure used in Flask apps.* :contentReference[oaicite:1]{index=1}

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Winuim12/CO2013-CinemaManageSystem.git
cd CO2013-CinemaManageSystem
````

---

### 2. Create & Activate a Virtual Environment

```bash
python -m venv venv
# macOS/Linux
source venv/bin/activate
# Windows
venv\Scripts\activate
```

---

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

---

### 4. Configure the Database

* If using **SQLite (default)**, no additional setup is needed.
* If using **MySQL/PostgreSQL**, update `config.py` with your DB credentials.

Run migrations (if applicable) or initialize your database:

```bash
# Example (may vary based on how models are defined)
python app.py
```

---

### 5. Run the Application

```bash
python app.py
```

You should see output like:

```
 * Running on http://127.0.0.1:5000/
```

Open your browser and visit:

```
http://localhost:5000
```

---

## Usage

Once the app is running:

1. Navigate to the homepage
2. Browse the list of movies
3. Create or manage screenings
4. Book tickets for a session
5. View customer reservations

*(Include screenshots or example routes here if available.)*

---

## Future Enhancements

Here are ideas you can implement later:

* User authentication (Admin vs. Customer roles)
* Printable tickets
* Email confirmations for bookings
* Responsive UI / Frontend framework (React/Vue)
* Analytics dashboard

---

## Authors & Credits

**Project for CO2013 – Database Systems**
Ho Chi Minh City University of Technology (HCMUT)

Developed by:

* KimCuongHoang / Winuim *

---

## License

This project is for **educational purposes only**.
